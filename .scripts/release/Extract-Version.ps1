#Requires -Version 7.0

<#
.SYNOPSIS
    Extracts version from git tag for release workflow
.DESCRIPTION
    Parses the git tag to extract version information. For pre-release versions,
    splits the version into full version (with suffix) and manifest version (without suffix)
    since PowerShell module manifests don't support semantic versioning pre-release suffixes.
.PARAMETER EventName
    The GitHub event name (push, workflow_dispatch, etc.)
.PARAMETER GitRef
    The Git reference (e.g., refs/tags/v0.1.0)
.PARAMETER OutputFile
    Path to GitHub Actions output file
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$EventName,
    
    [Parameter(Mandatory = $false)]
    [string]$GitRef = "",
    
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

# Extract version from tag (e.g., v0.1.0 -> 0.1.0)
if ($EventName -eq "workflow_dispatch") {
    # For manual runs, use a test version
    $fullVersion = "0.0.0"
    $manifestVersion = "0.0.0"
}
else {
    # Remove 'refs/tags/v' prefix
    $fullVersion = $GitRef -replace '^refs/tags/v', ''
    
    # PowerShell module manifests don't support semantic versioning pre-release suffixes
    # Strip any pre-release suffix (e.g., 1.0.0-beta -> 1.0.0) for manifest
    $manifestVersion = $fullVersion -replace '-.*$', ''
}

# Output to GitHub Actions
"VERSION=$fullVersion" | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
"MANIFEST_VERSION=$manifestVersion" | Out-File -FilePath $OutputFile -Encoding UTF8 -Append

Write-Host "Full version (for release): $fullVersion" -ForegroundColor Cyan
Write-Host "Manifest version (for .psd1): $manifestVersion" -ForegroundColor Cyan
