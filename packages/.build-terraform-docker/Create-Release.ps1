#Requires -Version 7.0

<#
.SYNOPSIS
    Creates release archive for Terraform Docker starter package
.DESCRIPTION
    Packages the Terraform Docker starter package tasks into a zip file with checksum
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

$packageDir = $PSScriptRoot
$packageName = Split-Path -Path $packageDir -Leaf

if ($packageName -notmatch '^\.build-') {
    Write-Error "❌ Package directory must follow .build-* naming convention. Found: $packageName"
    exit 1
}

$starterName = $packageName -replace '^\.build-', ''

Write-Host "Creating $starterName starter package archive..." -ForegroundColor Cyan

if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

$stagingDir = Join-Path -Path $OutputDirectory -ChildPath "staging-$starterName"
if (Test-Path -Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

Write-Host "  Staging package contents..." -ForegroundColor Gray

$taskFiles = Get-ChildItem -Path $packageDir -Filter "Invoke-*.ps1" -File
if ($taskFiles.Count -eq 0) {
    Write-Error "❌ No task files found matching 'Invoke-*.ps1' pattern in $packageDir"
    exit 1
}

foreach ($file in $taskFiles) {
    Copy-Item -Path $file.FullName -Destination $stagingDir -Force
    Write-Host "    Added: $($file.Name)" -ForegroundColor Gray
}

$packageReadme = Join-Path -Path $packageDir -ChildPath "README.md"
if (Test-Path -Path $packageReadme) {
    Copy-Item -Path $packageReadme -Destination $stagingDir -Force
    Write-Host "    Added: README.md" -ForegroundColor Gray
}

$dockerfile = Join-Path -Path $packageDir -ChildPath "Dockerfile"
if (Test-Path -Path $dockerfile) {
    Copy-Item -Path $dockerfile -Destination $stagingDir -Force
    Write-Host "    Added: Dockerfile" -ForegroundColor Gray
}

$zipName = "bolt-starter-$starterName-$Version.zip"
$zipPath = Join-Path -Path $OutputDirectory -ChildPath $zipName

if (Test-Path -Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

Write-Host "  Creating archive: $zipName" -ForegroundColor Gray
Compress-Archive -Path "$stagingDir/*" -DestinationPath $zipPath -Force

$retryCount = 0
$maxRetries = 3
while ($retryCount -lt $maxRetries) {
    try {
        Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction Stop
        break
    }
    catch {
        $retryCount++
        if ($retryCount -ge $maxRetries) {
            Write-Warning "Could not remove staging directory after $maxRetries attempts. Continuing anyway..."
        }
        else {
            Start-Sleep -Milliseconds 500
        }
    }
}

$checksumName = "$zipName.sha256"
$checksumPath = Join-Path -Path $OutputDirectory -ChildPath $checksumName

Write-Host "  Generating checksum: $checksumName" -ForegroundColor Gray
$hash = Get-FileHash -Path $zipPath -Algorithm SHA256
"$($hash.Hash.ToLower())  $zipName" | Out-File -FilePath $checksumPath -Encoding ascii -NoNewline

Write-Host ""
Write-Host "✓ Release package created successfully" -ForegroundColor Green
Write-Host "  Archive: $zipPath" -ForegroundColor Gray
Write-Host "  Checksum: $checksumPath" -ForegroundColor Gray
Write-Host "  Size: $([Math]::Round((Get-Item $zipPath).Length / 1KB, 2)) KB" -ForegroundColor Gray

exit 0
