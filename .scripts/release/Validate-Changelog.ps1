#Requires -Version 7.0

<#
.SYNOPSIS
    Validates changelog entry for release version
.DESCRIPTION
    Checks that CHANGELOG.md contains an entry for the version being released.
    This prevents accidental releases without documentation.
.PARAMETER Version
    The version to validate (e.g., 0.1.0, 1.0.0-beta)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

Write-Host "Validating changelog entry for version: $Version" -ForegroundColor Cyan

# Read changelog
$changelogContent = Get-Content -Path "CHANGELOG.md" -Raw

# Check if version exists in changelog
if ($changelogContent -match "## \[$Version\]") {
    Write-Host "✓ Found changelog entry for version $Version" -ForegroundColor Green
}
else {
    Write-Error "❌ No changelog entry found for version $Version"
    Write-Host "Please add a changelog entry following the format:" -ForegroundColor Yellow
    Write-Host "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')" -ForegroundColor Yellow
    exit 1
}
