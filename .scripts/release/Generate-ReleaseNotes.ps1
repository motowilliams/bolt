#Requires -Version 7.0

<#
.SYNOPSIS
    Generates release notes from CHANGELOG.md
.DESCRIPTION
    Extracts the relevant section from CHANGELOG.md for the version
    being released and saves it to a file for the GitHub release.
.PARAMETER Version
    The version being released (e.g., 0.1.0, 1.0.0-beta)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

Write-Host "Generating release notes for version: $Version" -ForegroundColor Cyan

# Extract release notes from CHANGELOG.md
$changelogContent = Get-Content -Path "CHANGELOG.md" -Raw

# Match the section for this version
$pattern = "(?s)## \[$Version\].*?(?=## \[|\z)"
if ($changelogContent -match $pattern) {
    $releaseNotes = $Matches[0]
    
    # Save to file
    $releaseNotes | Out-File -FilePath "release-notes.md" -Encoding UTF8
    Write-Host "✓ Release notes extracted from CHANGELOG.md" -ForegroundColor Green
}
else {
    Write-Host "⚠ Could not extract release notes from CHANGELOG.md, using default" -ForegroundColor Yellow
    "See [CHANGELOG.md](https://github.com/motowilliams/bolt/blob/main/CHANGELOG.md) for details." | Out-File -FilePath "release-notes.md" -Encoding UTF8
}
