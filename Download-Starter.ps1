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

$filteredReleases = @()
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
        $filteredReleases += $release
    }
}

if ($filteredReleases.Count -eq 0) {
    Write-Error "No releases with starter packages found. Starter packages are distributed with releases starting from a specific version."
}

Write-Host "Found $($filteredReleases.Count) release(s) with starter packages" -ForegroundColor Green

# Reassign to $releasesResponse for consistency with Download.ps1
$releasesResponse = $filteredReleases

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

# Download and validate the selected starter package
$zipAsset = $selectedStarter.Asset
$shaAsset = $selectedRelease.assets | Where-Object -FilterScript {
    $_.name -eq "$($zipAsset.name).sha256"
} | Select-Object -First 1

# Check both assets before attempting to use them in error messages
if (-not $zipAsset -or -not $shaAsset) {
    if (-not $zipAsset) {
        Write-Error "No zip file found in release assets"
    }
    if (-not $shaAsset) {
        Write-Error "No SHA256 checksum file found. Cannot proceed without validation."
    }
    return
}

# Create temporary directory for downloads
$tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bolt-starter-download-$([Guid]::NewGuid())"
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

    # Extract to temporary location to inspect contents
    Write-Host "`nExtracting package contents..." -ForegroundColor Cyan
    $tempExtractPath = Join-Path -Path $tempDir -ChildPath "extract"

    try {
        Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to extract archive: $_"
    }

    # Get list of files in the package
    $filesToExtract = Get-ChildItem -Path $tempExtractPath -Recurse -File

    # Display package contents
    Write-Host "`nPackage contents ($($filesToExtract.Count) files):" -ForegroundColor Cyan
    $filesToExtract | Select-Object -First 5 | ForEach-Object {
        $relativePath = $_.FullName.Substring($tempExtractPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        Write-Host "  - $relativePath" -ForegroundColor Gray
    }
    if ($filesToExtract.Count -gt 5) {
        Write-Host "  ... and $($filesToExtract.Count - 5) more files" -ForegroundColor Gray
    }

    # Prompt for target directory
    Write-Host "`nTarget Directory Configuration:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Enter the target directory for starter package installation." -ForegroundColor White

    # Build smart examples and default based on starter name and existing directories
    $starterName = $selectedStarter.Name
    $smartExamples = @()
    $smartDefault = $null

    # Add starter-specific example
    $smartExamples += ".build/$starterName"

    # Check for existing .build subdirectories
    $buildPath = Join-Path -Path $PWD -ChildPath ".build"
    if (Test-Path -Path $buildPath) {
        $existingDirs = Get-ChildItem -Path $buildPath -Directory -ErrorAction SilentlyContinue | Select-Object -First 3
        foreach ($dir in $existingDirs) {
            $example = ".build/$($dir.Name)"
            if ($smartExamples -notcontains $example) {
                $smartExamples += $example
            }
        }
        # If .build exists, use starter-specific subdirectory as default
        $smartDefault = ".build/$starterName"
    } else {
        # If .build doesn't exist, use it as default
        $smartDefault = ".build"
        $smartExamples = @(".build", ".build/$starterName") + $smartExamples[1..($smartExamples.Count-1)]
    }

    Write-Host "Examples: $($smartExamples -join ', ')" -ForegroundColor Gray
    Write-Host ""

    $extractPath = $null
    $attempts = 0

    while ($attempts -lt $maxAttempts) {
        $attempts++
        $userInput = Read-Host "Target directory [default: $smartDefault]"

        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            $userInput = $smartDefault
        }

        # Validate and resolve path
        try {
            # Remove any leading/trailing whitespace and normalize path separators
            $userInput = $userInput.Trim()

            # Build the full path relative to current directory
            $extractPath = Join-Path -Path $PWD -ChildPath $userInput

            # Validate the path doesn't escape the current directory
            $resolvedExtractPath = [System.IO.Path]::GetFullPath($extractPath)
            $resolvedPWD = [System.IO.Path]::GetFullPath($PWD)

            if (-not $resolvedExtractPath.StartsWith($resolvedPWD, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Target directory must be within the current directory"
            }

            Write-Host "Target directory: $extractPath" -ForegroundColor Green
            break
        } catch {
            if ($attempts -lt $maxAttempts) {
                Write-Host "Invalid directory path: $_" -ForegroundColor Yellow
                $extractPath = $null
            } else {
                Write-Error "Invalid directory path after $maxAttempts attempts: $_"
            }
        }
    }

    # Check for file conflicts with the selected target directory
    Write-Host "`nChecking for file conflicts..." -ForegroundColor Cyan

    # Check which files already exist in target directory
    $conflictingFiles = @()
    foreach ($file in $filesToExtract) {
        $relativePath = $file.FullName.Substring($tempExtractPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $targetFile = Join-Path -Path $extractPath -ChildPath $relativePath

        if (Test-Path -Path $targetFile) {
            $conflictingFiles += $relativePath
        }
    }

    # Handle conflicts if any exist
    if ($conflictingFiles.Count -gt 0) {
        Write-Host "`n⚠ File Conflicts Detected" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "The following files already exist in the target directory:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($file in $conflictingFiles) {
            Write-Host "  - $file" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "`nWhat would you like to do?" -ForegroundColor Cyan
        Write-Host "  1. Overwrite existing files" -ForegroundColor White
        Write-Host "  2. Cancel installation" -ForegroundColor White
        Write-Host ""

        $userChoice = $null
        $attempts = 0

        while ($attempts -lt $maxAttempts) {
            $attempts++
            $userInput = Read-Host "Enter your choice (1-2)"

            if ($userInput -match '^[12]$') {
                $userChoice = [int]$userInput
                break
            }

            if ($attempts -lt $maxAttempts) {
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Yellow
            } else {
                Write-Error "Invalid choice after $maxAttempts attempts. Cancelling installation."
            }
        }

        if ($userChoice -eq 2) {
            Write-Host "`nInstallation cancelled by user." -ForegroundColor Yellow
            return
        }

        Write-Host "`nProceeding with overwrite..." -ForegroundColor Cyan
    } else {
        Write-Host "✓ No file conflicts detected" -ForegroundColor Green
    }

    # Create target directory if it doesn't exist
    if (-not (Test-Path -Path $extractPath)) {
        Write-Host "`nCreating target directory: $extractPath" -ForegroundColor Cyan
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
    }

    # Extract to target directory
    Write-Host "`nExtracting to target directory..." -ForegroundColor Cyan

    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to extract archive: $_"
    }

    Write-Banner -Color Green "✓ Extracted to: $extractPath"

    # Success message
    Write-Banner -Color Green "✓ Starter package download and installation completed successfully!"
    Write-Host "`nInstalled starter: $($selectedStarter.Name)" -ForegroundColor Cyan
    Write-Host "Target directory: $extractPath" -ForegroundColor Cyan
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Review the tasks in target directory" -ForegroundColor White
    Write-Host "  2. Run: .\bolt.ps1 -ListTasks" -ForegroundColor White
    Write-Host "  3. Execute tasks: .\bolt.ps1 <task-name>" -ForegroundColor White
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
