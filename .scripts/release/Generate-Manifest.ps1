#Requires -Version 7.0

<#
.SYNOPSIS
    Generates the PowerShell module manifest for release
.DESCRIPTION
    Creates the .psd1 manifest file using generate-manifest.ps1 with
    proper version and metadata. Uses manifest version without pre-release suffix.
.PARAMETER Version
    The full version (e.g., 0.1.0, 1.0.0-beta)
.PARAMETER ManifestVersion
    The manifest version without suffix (e.g., 0.1.0, 1.0.0)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$ManifestVersion
)

$releaseDir = "release"
$moduleName = "Bolt"
$moduleDir = Join-Path -Path $releaseDir -ChildPath $moduleName
$modulePath = Join-Path -Path $moduleDir -ChildPath "$moduleName.psm1"

Write-Host "Generating module manifest..." -ForegroundColor Cyan
Write-Host "  Full version (for release): $Version" -ForegroundColor Gray
Write-Host "  Manifest version (for .psd1): $ManifestVersion" -ForegroundColor Gray

# Generate manifest using generate-manifest.ps1 with manifest version
# PowerShell module manifests don't support semantic versioning pre-release suffixes
& pwsh -File infra/generate-manifest.ps1 `
    -ModulePath $modulePath `
    -ModuleVersion $ManifestVersion `
    -Tags "Build,Orchestration,Tasks,PowerShell,Cross-Platform,DevOps" `
    -ProjectUri "https://github.com/motowilliams/bolt" `
    -LicenseUri "https://github.com/motowilliams/bolt/blob/main/LICENSE" `
    -ReleaseNotes "See https://github.com/motowilliams/bolt/blob/main/CHANGELOG.md for release notes"

# Verify manifest was created
$manifestPath = Join-Path -Path $moduleDir -ChildPath "$moduleName.psd1"
if (-not (Test-Path -Path $manifestPath)) {
    Write-Error "❌ Manifest file not created at $manifestPath"
    exit 1
}

Write-Host "✓ Manifest generated successfully" -ForegroundColor Green

# Validate manifest
Write-Host "Validating module manifest..." -ForegroundColor Gray
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
Write-Host "✓ Manifest validation passed: $($manifest.Name) v$($manifest.Version)" -ForegroundColor Green
