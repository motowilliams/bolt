#Requires -Version 7.0

<#
.SYNOPSIS
    Copies documentation files to module package
.DESCRIPTION
    Copies essential documentation files and configuration schemas
    to the module directory for inclusion in the release.
#>

[CmdletBinding()]
param()

$releaseDir = "release"
$moduleName = "Bolt"
$moduleDir = Join-Path -Path $releaseDir -ChildPath $moduleName

Write-Host "Copying additional files to module..." -ForegroundColor Cyan

# Copy essential module files
@(
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "IMPLEMENTATION.md",
    "bolt.config.schema.json",
    "bolt.config.example.json",
    "Download.ps1",
    "Download-Starter.ps1",
    "New-BoltModule.ps1"
) | ForEach-Object {
    $file = $_
    if (Test-Path -Path $file) {
        Copy-Item -Path $file -Destination $moduleDir -Force
        Write-Host "  ✓ Copied: $file" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ Not found: $file" -ForegroundColor Yellow
    }
}

Write-Host "✓ Additional files copied" -ForegroundColor Green
