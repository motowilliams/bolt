[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param (
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'AutoDownload')]
    [string]$ProjectUri = "https://api.github.com/repos/motowilliams/bolt",

    [Parameter(Mandatory, ParameterSetName = 'AutoDownload')]
    [switch]$Latest
)

begin {
    # Ensure we have https:// prefix
    if ($ProjectUri -notmatch '^https?://') {
        $ProjectUri = "https://$ProjectUri"
    }

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
}

process {
    # Fetch all releases from GitHub API
    Write-Host "Fetching releases from GitHub..." -ForegroundColor Cyan

    try {
        $releasesResponse = Invoke-RestMethod -Uri "$ProjectUri/releases" -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to fetch releases from GitHub: $_"
        exit 1
    }

    if (-not $releasesResponse -or $releasesResponse.Count -eq 0) {
        Write-Error "No releases found"
        exit 1
    }

    # Sort releases by name ascending (oldest first, newest last)
    $sortedReleases = $releasesResponse | Sort-Object -Property name

    # Determine which release to download
    $selectedRelease = $null

    if ($PSCmdlet.ParameterSetName -eq 'AutoDownload') {
        # -Latest mode: Filter to stable releases and select first (newest)
        Write-Host "Finding latest stable release..." -ForegroundColor Cyan

        $stableReleases = $sortedReleases | Where-Object { -not $_.prerelease }

        if ($stableReleases.Count -eq 0) {
            Write-Error "No stable releases found"
            exit 1
        }

        $selectedRelease = $stableReleases[0]
        $updatedDate = [DateTime]::Parse($selectedRelease.updated_at).ToString("yyyy-MM-dd")
        Write-Host "Selected: $($selectedRelease.name) (Updated: $updatedDate)" -ForegroundColor Green
    }
    else {
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

        # Prompt for selection
        $selection = $null
        $attempts = 0
        $maxAttempts = 2

        while ($attempts -lt $maxAttempts) {
            $attempts++
            $promptText = if ($defaultIndex) {
                "`nEnter the number of the release to download (1-$($menuItems.Count)) [default: $defaultIndex]"
            } else {
                "`nEnter the number of the release to download (1-$($menuItems.Count))"
            }
            $input = Read-Host $promptText

            # Use default if user pressed Enter without input
            if ([string]::IsNullOrWhiteSpace($input) -and $defaultIndex) {
                $input = $defaultIndex.ToString()
            }

            if ($input -match '^\d+$') {
                $selectionNumber = [int]$input

                if ($selectionNumber -ge 1 -and $selectionNumber -le $menuItems.Count) {
                    $selectedRelease = $menuItems[$selectionNumber - 1].Release
                    break
                }
            }

            if ($attempts -lt $maxAttempts) {
                Write-Host "Invalid selection. Please enter a number between 1 and $($menuItems.Count)." -ForegroundColor Yellow
            }
            else {
                Write-Error "Invalid selection after $maxAttempts attempts. Exiting."
                exit 1
            }
        }
    }

    # Check if Bolt/ directory already exists
    $extractPath = Join-Path -Path $PWD -ChildPath "Bolt"

    if (Test-Path -Path $extractPath) {
        Write-Error "Directory '$extractPath' already exists. Please remove it or run this script from a different location."
        exit 1
    }

    # Find the zip and sha256 assets
    $zipAsset = $selectedRelease.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notlike "*.sha256" } | Select-Object -First 1
    $shaAsset = $selectedRelease.assets | Where-Object { $_.name -like "*.zip.sha256" } | Select-Object -First 1

    if (-not $zipAsset) {
        Write-Error "No zip file found in release assets"
        exit 1
    }

    if (-not $shaAsset) {
        Write-Error "No SHA256 checksum file found in release assets. Cannot proceed without validation."
        exit 1
    }

    # Create temporary directory for downloads
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bolt-download-$([Guid]::NewGuid())"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    try {
        # Download zip file
        $zipPath = Join-Path -Path $tempDir -ChildPath $zipAsset.name
        Write-Host "`nDownloading $($zipAsset.name)..." -ForegroundColor Cyan

        try {
            Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to download zip file: $_"
            exit 1
        }

        Write-Banner -Color Green "✓ Downloaded $($zipAsset.name)"

        # Download SHA256 file
        $shaPath = Join-Path -Path $tempDir -ChildPath $shaAsset.name
        Write-Host "`nDownloading $($shaAsset.name)..." -ForegroundColor Cyan

        try {
            Invoke-WebRequest -Uri $shaAsset.browser_download_url -OutFile $shaPath -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to download SHA256 file: $_"
            exit 1
        }

        Write-Banner -Color Green "✓ Downloaded $($shaAsset.name)"

        # Validate SHA256 checksum
        Write-Host -ForegroundColor Cyan "`nValidating SHA256 checksum..."

        $actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
        $expectedHashContent = Get-Content -Path $shaPath -Raw
        $expectedHash = ($expectedHashContent -split "\s+")[0].Trim()

        if ($actualHash -ne $expectedHash) {
            Write-Error "SHA256 checksum validation failed!`nExpected: $expectedHash`nActual:   $actualHash"
            exit 1
        }

        Write-Banner -Color Green "✓ SHA256 checksum validated successfully"

        # Extract to current directory
        Write-Host "`nExtracting to current directory..." -ForegroundColor Cyan

        try {
            Expand-Archive -Path $zipPath -DestinationPath $PWD -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to extract archive: $_"
            exit 1
        }

        Write-Banner -Color Green "✓ Extracted to: $extractPath"

        # Success message
        Write-Banner -Color Green "✓ Download and extraction completed successfully!"
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "  1. cd Bolt" -ForegroundColor White
        Write-Host "  2. .\New-BoltModule.ps1 -Install" -ForegroundColor White
        Write-Host ""

        exit 0
    }
    finally {
        # Cleanup temporary directory
        if (Test-Path -Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
