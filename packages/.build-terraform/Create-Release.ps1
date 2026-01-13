#Requires -Version 7.0

<#
.SYNOPSIS
    Creates release archive for Terraform starter package
.DESCRIPTION
    Packages the Terraform starter package tasks into a zip file with checksum
    for distribution as a GitHub release asset.
.PARAMETER Version
    The version being released (e.g., 0.1.0, 1.0.0-beta)
.PARAMETER OutputDirectory
    Directory where release archives will be created (default: release)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = 'Stop'

Write-Host "Creating Terraform starter package archive..." -ForegroundColor Cyan

# Get the package directory (where this script is located)
$packageDir = $PSScriptRoot
$packageName = Split-Path -Path $packageDir -Leaf

# Validate package name follows convention
if ($packageName -notmatch '^\.build-') {
    Write-Error "❌ Package directory must follow .build-* naming convention. Found: $packageName"
    exit 1
}

# Extract starter name (e.g., ".build-terraform" -> "terraform")
$starterName = $packageName -replace '^\.build-', ''

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

# Create temporary staging directory for package contents
$stagingDir = Join-Path -Path $OutputDirectory -ChildPath "staging-$starterName"
if (Test-Path -Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

Write-Host "  Staging package contents..." -ForegroundColor Gray

# Copy task files (Invoke-*.ps1) - exclude test files
# Following Bolt convention: task files must be named Invoke-*.ps1
$taskFiles = Get-ChildItem -Path $packageDir -Filter "Invoke-*.ps1" -File
if ($taskFiles.Count -eq 0) {
    Write-Error "❌ No task files found matching 'Invoke-*.ps1' pattern in $packageDir"
    Write-Host "   Bolt convention requires task files to follow 'Invoke-*.ps1' naming pattern" -ForegroundColor Gray
    exit 1
}

foreach ($file in $taskFiles) {
    Copy-Item -Path $file.FullName -Destination $stagingDir -Force
    Write-Host "    Added: $($file.Name)" -ForegroundColor Gray
}

# Copy README if it exists in package directory
$packageReadme = Join-Path -Path $packageDir -ChildPath "README.md"
if (Test-Path -Path $packageReadme) {
    Copy-Item -Path $packageReadme -Destination $stagingDir -Force
    Write-Host "    Added: README.md" -ForegroundColor Gray
}

# Create archive name following convention: bolt-starter-{name}-{version}.zip
$zipName = "bolt-starter-$starterName-$Version.zip"
$zipPath = Join-Path -Path $OutputDirectory -ChildPath $zipName

# Remove existing archive if present
if (Test-Path -Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

# Create zip archive
Write-Host "  Creating archive: $zipName" -ForegroundColor Gray
Compress-Archive -Path "$stagingDir/*" -DestinationPath $zipPath -Force

# Clean up staging directory
Remove-Item -Path $stagingDir -Recurse -Force

# Verify archive was created
if (-not (Test-Path -Path $zipPath)) {
    Write-Error "❌ Failed to create release archive at $zipPath"
    exit 1
}

$zipSize = (Get-Item -Path $zipPath).Length / 1KB
Write-Host "✓ Created package archive: $zipName ($([math]::Round($zipSize, 2)) KB)" -ForegroundColor Green

# Generate SHA256 checksum
Write-Host "  Generating checksum..." -ForegroundColor Gray
$hash = Get-FileHash -Path $zipPath -Algorithm SHA256
$checksumFile = "$zipPath.sha256"
"$($hash.Hash)  $zipName" | Out-File -FilePath $checksumFile -Encoding UTF8

Write-Host "✓ Generated checksum file: $(Split-Path -Path $checksumFile -Leaf)" -ForegroundColor Green
Write-Host "  SHA256: $($hash.Hash)" -ForegroundColor Gray

Write-Host ""
Write-Host "✓ Terraform starter package release completed successfully" -ForegroundColor Green
exit 0
