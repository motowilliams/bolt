# ==============================================================================
# CODING STANDARD EXCEPTION - EXIT CODES
# ==============================================================================
# This script intentionally does NOT use explicit exit codes (exit 0/exit 1)
# to support remote invocation via Invoke-Expression:
#   iex (irm https://github.com/motowilliams/bolt/.../Download.ps1)
#
# Also [CmdletBinding()] attribute is not used to avoid issues with remote execution
#
# Errors are handled via Write-Error which propagates correctly in both
# local and remote execution contexts.
#
# Approved by: motowilliams on 2025-12-24
# Reason: Remote installation support
# ==============================================================================

$ProjectUri = "https://api.github.com/repos/motowilliams/bolt"

function Write-Banner {
    param (
        [string] $Message,
        [ConsoleColor] $Color = "Cyan",
        [int] $Width = 80
    )

    Write-Host ("=" * $Width) -ForegroundColor Gray
    Write-Host $Message -ForegroundColor $Color
    Write-Host ("=" * $Width) -ForegroundColor Gray
}

# Fetch all releases from GitHub API
Write-Host "Fetching releases from GitHub..." -ForegroundColor Cyan

try {
    $releasesResponse = Invoke-RestMethod -Uri "$ProjectUri/releases" -ErrorAction Stop
} catch {
    Write-Error "Failed to fetch releases from GitHub: $_"
}

if (-not $releasesResponse -or $releasesResponse.Count -eq 0) {
    Write-Error "No releases found"
}

# Sort releases by semantic version ascending (oldest first, newest last)
# Parse version numbers for proper semver comparison
$sortedReleases = $releasesResponse | Sort-Object -Property {
    # Extract version string (remove 'v' prefix if present)
    $versionString = $_.name -replace '^v', ''

    # Parse major.minor.patch and prerelease components
    if ($versionString -match '^(\d+)\.(\d+)\.(\d+)(-(.+))?$') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        $prerelease = $matches[5]

        # Create sortable value: major * 1000000 + minor * 1000 + patch
        # Prereleases sort before releases (subtract 0.5 if prerelease)
        $sortValue = ($major * 1000000) + ($minor * 1000) + $patch
        if ($prerelease) {
            $sortValue -= 0.5
        }

        return $sortValue
    }

    # Fallback to alphabetical if version parsing fails
    return $_.name
}

# Determine which release to download
$selectedRelease = $null

if ($PSCmdlet.ParameterSetName -eq 'AutoDownload') {
    # -Latest mode: Filter to stable releases and select first (newest)
    Write-Host "Finding latest stable release..." -ForegroundColor Cyan

    $stableReleases = $sortedReleases | Where-Object -FilterScript { -not $_.prerelease }

    if ($stableReleases.Count -eq 0) {
        Write-Error "No stable releases found"
    }

    $selectedRelease = $stableReleases[0]
    $updatedDate = [DateTime]::Parse($selectedRelease.updated_at).ToString("yyyy-MM-dd")
    Write-Host "Selected: $($selectedRelease.name) (Updated: $updatedDate)" -ForegroundColor Green
} else {
    # Interactive mode: Display menu of all releases
    Write-Host "`nAvailable Releases:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray

    $menuItems = @()
    $index = 1

    foreach ($release in $sortedReleases) {
        $updatedDate = [DateTime]::Parse($release.updated_at).ToString("yyyy-MM-dd")
        $prereleaseTag = if ($release.prerelease) { " [PRERELEASE]" } else { "" }
        $displayName = "{0,3}. {1} (Updated: {2}){3}" -f $index, $release.name, $updatedDate, $prereleaseTag

        Write-Host $displayName -ForegroundColor $(if ($release.prerelease) { "Yellow" } else { "White" })

        $menuItems += [PSCustomObject]@{
            Index   = $index
            Release = $release
        }

        $index++
    }

    Write-Host ("=" * 80) -ForegroundColor Gray

    # Find the newest non-prerelease as default
    $defaultIndex = $null
    for ($i = $menuItems.Count - 1; $i -ge 0; $i--) {
        if (-not $menuItems[$i].Release.prerelease) {
            $defaultIndex = $menuItems[$i].Index
            break
        }
    }

    # Prompt for release selection
    $selectedRelease = $null
    $attempts = 0
    $maxAttempts = 2

    while ($attempts -lt $maxAttempts) {
        $attempts++
        $promptText = if ($defaultIndex) {
            "`nEnter the number of the release to download (1-$($menuItems.Count)) [default: $defaultIndex]"
        } else {
            "`nEnter the number of the release to download (1-$($menuItems.Count))"
        }
        $userInput = Read-Host $promptText

        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($userInput) -and $defaultIndex) {
            $userInput = $defaultIndex.ToString()
        }

        if ($userInput -match '^\d+$') {
            $selectionNumber = [int]$userInput

            if ($selectionNumber -ge 1 -and $selectionNumber -le $menuItems.Count) {
                $selectedRelease = $menuItems[$selectionNumber - 1].Release
                break
            }
        }

        if ($attempts -lt $maxAttempts) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($menuItems.Count)." -ForegroundColor Yellow
        } else {
            Write-Error "Invalid selection after $maxAttempts attempts. Exiting."
        }
    }
}

# Check if Bolt/ directory already exists
$extractPath = Join-Path -Path $PWD -ChildPath "Bolt"

if (Test-Path -Path $extractPath) {
    Write-Error "Directory '$extractPath' already exists. Please remove it or run this script from a different location."
}

# Find the zip and sha256 assets
$zipAsset = $selectedRelease.assets | Where-Object -FilterScript { $_.name -like "*.zip" -and $_.name -notlike "*.sha256" } | Select-Object -First 1
$shaAsset = $selectedRelease.assets | Where-Object -FilterScript { $_.name -like "*.zip.sha256" } | Select-Object -First 1

if (-not $zipAsset) {
    Write-Error "No zip file found in release assets"
}

if (-not $shaAsset) {
    Write-Error "No SHA256 checksum file found for $($zipAsset.name). Cannot proceed without validation."
}

# Create temporary directory for downloads
$tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bolt-download-$([Guid]::NewGuid())"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

Write-Host "Temporary directory: $tempDir" -ForegroundColor Gray

try {
    # Download zip file
    $zipPath = Join-Path -Path $tempDir -ChildPath $zipAsset.name
    Write-Host "`nDownloading $($zipAsset.name)..." -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to download zip file: $_"
    }

    Write-Banner -Color Green "✓ Downloaded $($zipAsset.name)"

    # Download SHA256 file
    $shaPath = Join-Path -Path $tempDir -ChildPath $shaAsset.name
    Write-Host "`nDownloading $($shaAsset.name)..." -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $shaAsset.browser_download_url -OutFile $shaPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to download SHA256 file: $_"
    }

    Write-Banner -Color Green "✓ Downloaded $($shaAsset.name)"

    # Validate SHA256 checksum
    Write-Host -ForegroundColor Cyan "`nValidating SHA256 checksum..."

    $actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    $expectedHashContent = Get-Content -Path $shaPath -Raw
    $expectedHash = ($expectedHashContent -split "\s+")[0].Trim()

    if ($actualHash -ne $expectedHash) {
        Write-Error "SHA256 checksum validation failed!`nExpected: $expectedHash`nActual:   $actualHash"
    }

    Write-Banner -Color Green "✓ SHA256 checksum validated successfully"

    # Extract to current directory
    Write-Host "`nExtracting to current directory..." -ForegroundColor Cyan

    try {
        Expand-Archive -Path $zipPath -DestinationPath $PWD -ErrorAction Stop
    } catch {
        Write-Error "Failed to extract archive: $_"
    }

    Write-Banner -Color Green "✓ Extracted to: $extractPath"

    # Success message
    Write-Banner -Color Green "✓ Download and extraction completed successfully!"
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. cd Bolt" -ForegroundColor White
    Write-Host "  2. .\New-BoltModule.ps1 -Install" -ForegroundColor White
    Write-Host ""
} catch {
    # Ensure error is visible
    Write-Host "`n✗ Error occurred: $_" -ForegroundColor Red
    throw
} finally {
    # Cleanup temporary directory
    if (Test-Path -Path $tempDir) {
        try {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Stop
            Write-Host "`n✓ Temporary files cleaned up" -ForegroundColor Green
        } catch {
            Write-Host "`n⚠ Warning: Failed to clean up temporary directory" -ForegroundColor Yellow
            Write-Host "Temporary files are located at: $tempDir" -ForegroundColor Yellow
            Write-Host "You may need to manually delete this directory" -ForegroundColor Yellow
        }
    }
}
