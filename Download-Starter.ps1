# ==============================================================================
# CODING STANDARD EXCEPTION - EXIT CODES
# ==============================================================================
# This script intentionally does NOT use explicit exit codes (exit 0/exit 1)
# to support remote invocation via Invoke-Expression:
#   iex (irm https://github.com/motowilliams/bolt/.../Download-Starter.ps1)
#
# Also [CmdletBinding()] attribute is not used to avoid issues with remote execution
#
# Errors are handled via Write-Error which propagates correctly in both
# local and remote execution contexts.
#
# Approved by: motowilliams on 2025-12-29
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

# Filter releases to only those with starter packages (bolt-starter-*.zip)
Write-Host "Filtering releases with starter packages..." -ForegroundColor Cyan

$releasesWithStarters = @()
foreach ($release in $releasesResponse) {
    $starterAssets = $release.assets | Where-Object -FilterScript {
        $_.name -like "bolt-starter-*.zip" -and $_.name -notlike "*.sha256"
    }

    if ($starterAssets.Count -gt 0) {
        # Add a property to track available starters
        $starterNames = @()
        foreach ($asset in $starterAssets) {
            # Extract starter name from "bolt-starter-{name}-{version}.zip"
            if ($asset.name -match '^bolt-starter-([^-]+)-') {
                $starterNames += $matches[1]
            }
        }

        $release | Add-Member -MemberType NoteProperty -Name "StarterPackages" -Value $starterNames -Force
        $releasesWithStarters += $release
    }
}

if ($releasesWithStarters.Count -eq 0) {
    Write-Error "No releases with starter packages found. Starter packages are distributed with releases starting from a specific version."
}

Write-Host "Found $($releasesWithStarters.Count) release(s) with starter packages" -ForegroundColor Green

# Sort releases by name ascending (oldest first, newest last)
$sortedReleases = $releasesWithStarters | Sort-Object -Property name

# Display interactive menu
Write-Host "`nAvailable Releases with Starter Packages:" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

$menuItems = @()
$index = 1

foreach ($release in $sortedReleases) {
    $updatedDate = [DateTime]::Parse($release.updated_at).ToString("yyyy-MM-dd")
    $prereleaseTag = if ($release.prerelease) { " [PRERELEASE]" } else { "" }
    $startersAvailable = $release.StarterPackages -join ", "

    $displayName = "{0,3}. {1} (Updated: {2}){3}" -f $index, $release.name, $updatedDate, $prereleaseTag
    Write-Host $displayName -ForegroundColor $(if ($release.prerelease) { "Yellow" } else { "White" })
    Write-Host "       Available starters: $startersAvailable" -ForegroundColor Gray

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

# Get all starter packages from the selected release
$starterAssets = $selectedRelease.assets | Where-Object -FilterScript {
    $_.name -like "bolt-starter-*.zip" -and $_.name -notlike "*.sha256"
}

Write-Host "`nAvailable starter packages in $($selectedRelease.name):" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

$starterMenuItems = @()
$starterIndex = 1

foreach ($asset in $starterAssets) {
    # Extract starter name from "bolt-starter-{name}-{version}.zip"
    $starterName = "unknown"
    if ($asset.name -match '^bolt-starter-([^-]+)-') {
        $starterName = $matches[1]
    }

    $sizeKB = [math]::Round($asset.size / 1KB, 2)
    $displayName = "{0,3}. {1} ({2} KB)" -f $starterIndex, $starterName, $sizeKB
    Write-Host $displayName -ForegroundColor White

    $starterMenuItems += [PSCustomObject]@{
        Index = $starterIndex
        Asset = $asset
        Name  = $starterName
    }

    $starterIndex++
}

Write-Host ("=" * 80) -ForegroundColor Gray

# Prompt for starter selection
$selectedStarter = $null
$attempts = 0

while ($attempts -lt $maxAttempts) {
    $attempts++
    $promptText = "`nEnter the number of the starter package to download (1-$($starterMenuItems.Count))"
    $userInput = Read-Host $promptText

    if ($userInput -match '^\d+$') {
        $selectionNumber = [int]$userInput

        if ($selectionNumber -ge 1 -and $selectionNumber -le $starterMenuItems.Count) {
            $selectedStarter = $starterMenuItems[$selectionNumber - 1]
            break
        }
    }

    if ($attempts -lt $maxAttempts) {
        Write-Host "Invalid selection. Please enter a number between 1 and $($starterMenuItems.Count)." -ForegroundColor Yellow
    } else {
        Write-Error "Invalid selection after $maxAttempts attempts. Exiting."
    }
}

# Check if output directory already exists
$extractPath = Join-Path -Path $PWD -ChildPath ".build"

if (Test-Path -Path $extractPath) {
    Write-Error "Directory '$extractPath' already exists. This script installs starter packages to a '.build/' directory. Please remove it or run this script from a different location."
}

# Find the sha256 checksum for selected starter
$zipAsset = $selectedStarter.Asset
$shaAsset = $selectedRelease.assets | Where-Object -FilterScript {
    $_.name -eq "$($zipAsset.name).sha256"
} | Select-Object -First 1

if (-not $shaAsset) {
    Write-Error "No SHA256 checksum file found for $($zipAsset.name). Cannot proceed without validation."
}

# Create temporary directory for downloads
$tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bolt-starter-download-$([Guid]::NewGuid())"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

try {
    # Download zip file
    $zipPath = Join-Path -Path $tempDir -ChildPath $zipAsset.name
    Write-Host "`nDownloading $($zipAsset.name)..." -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to download starter package: $_"
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

    # Extract to .build directory
    Write-Host "`nExtracting to .build/ directory..." -ForegroundColor Cyan

    try {
        Expand-Archive -Path $zipPath -DestinationPath $PWD -ErrorAction Stop
    } catch {
        Write-Error "Failed to extract archive: $_"
    }

    Write-Banner -Color Green "✓ Extracted to: $extractPath"

    # Success message
    Write-Banner -Color Green "✓ Starter package download and installation completed successfully!"
    Write-Host "`nInstalled starter: $($selectedStarter.Name)" -ForegroundColor Cyan
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Review the tasks in .build/ directory" -ForegroundColor White
    Write-Host "  2. Run: .\bolt.ps1 -ListTasks" -ForegroundColor White
    Write-Host "  3. Execute tasks: .\bolt.ps1 <task-name>" -ForegroundColor White
    Write-Host ""
} finally {
    # Cleanup temporary directory
    if (Test-Path -Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
