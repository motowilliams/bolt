#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

# Validate version format (SemVer)
if ($Version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$') {
    Write-Error "Invalid version format. Use SemVer (e.g., 1.0.0 or 1.0.0-beta)"
    exit 1
}

# Define package name
$toolchain = "dotnet"
$packageName = "bolt-starter-$toolchain-$Version"
$zipFile = "$packageName.zip"
$checksumFile = "$zipFile.sha256"

# Create release directory
$releaseDir = New-Item -Path $OutputDirectory -ItemType Directory -Force
$tempDir = Join-Path $releaseDir "temp-$packageName"
New-Item -Path $tempDir -ItemType Directory -Force

try {
    # Copy task files
    $taskFiles = Get-ChildItem -Path $PSScriptRoot -Filter "Invoke-*.ps1" -File
    foreach ($file in $taskFiles) {
        Copy-Item -Path $file.FullName -Destination $tempDir -Force
    }

    # Create zip archive
    $zipPath = Join-Path $releaseDir $zipFile
    Compress-Archive -Path "$tempDir/*" -DestinationPath $zipPath -Force

    # Generate SHA256 checksum
    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    $checksumPath = Join-Path $releaseDir $checksumFile
    "$hash  $zipFile" | Out-File -FilePath $checksumPath -Encoding ASCII -NoNewline

    Write-Host "✓ Created: $zipFile" -ForegroundColor Green
    Write-Host "✓ Created: $checksumFile" -ForegroundColor Green
    Write-Host "  SHA256: $hash" -ForegroundColor Gray

    exit 0
}
catch {
    Write-Error "Release creation failed: $_"
    exit 1
}
finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}
