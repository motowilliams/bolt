#Requires -Version 7.0

<#
.SYNOPSIS
    Creates release archive with checksum
.DESCRIPTION
    Compresses the module directory into a zip file and generates
    a SHA256 checksum for verification.
.PARAMETER Version
    The version being released (e.g., 0.1.0, 1.0.0-beta)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$releaseDir = "release"
$moduleName = "Bolt"
$moduleDir = Join-Path -Path $releaseDir -ChildPath $moduleName

Write-Host "Creating release archive..." -ForegroundColor Cyan

# Create zip archive
$zipName = "Bolt-$Version.zip"
$zipPath = Join-Path -Path $releaseDir -ChildPath $zipName

# Compress module directory
Compress-Archive -Path $moduleDir -DestinationPath $zipPath -Force

if (-not (Test-Path -Path $zipPath)) {
    Write-Error "❌ Failed to create release archive at $zipPath"
    exit 1
}

$zipSize = (Get-Item -Path $zipPath).Length / 1KB
Write-Host "✓ Created release archive: $zipName ($([math]::Round($zipSize, 2)) KB)" -ForegroundColor Green

# Generate SHA256 checksum
$hash = Get-FileHash -Path $zipPath -Algorithm SHA256
$checksumFile = "$zipPath.sha256"
"$($hash.Hash)  $zipName" | Out-File -FilePath $checksumFile -Encoding UTF8

Write-Host "✓ Generated checksum file: $checksumFile" -ForegroundColor Green
Write-Host "  SHA256: $($hash.Hash)" -ForegroundColor Gray
