#Requires -Version 7.0

<#
.SYNOPSIS
    Builds the Bolt module package for release
.DESCRIPTION
    Creates the module structure using New-BoltModule.ps1 and prepares
    the release directory for packaging.
.PARAMETER Version
    The version being released (e.g., 0.1.0, 1.0.0-beta)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

Write-Host "Building Bolt module package (version: $Version)..." -ForegroundColor Cyan

# Create release directory
$releaseDir = "release"
$moduleName = "Bolt"
$moduleDir = Join-Path -Path $releaseDir -ChildPath $moduleName

New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
Write-Host "Created module directory: $moduleDir" -ForegroundColor Gray

# Install module using New-BoltModule.ps1 (to generate module structure)
Write-Host "Installing module to release directory..." -ForegroundColor Gray
& pwsh -File infra/New-BoltModule.ps1 -Install -NoImport -ModuleOutputPath $releaseDir

# Verify module was created
if (-not (Test-Path -Path $moduleDir)) {
    Write-Error "❌ Module directory not created at $moduleDir"
    exit 1
}

Write-Host "✓ Module structure created successfully" -ForegroundColor Green
