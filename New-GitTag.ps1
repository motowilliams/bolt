<#
.SYNOPSIS
    Creates and pushes a git tag based on the latest version in CHANGELOG.md.

.DESCRIPTION
    Parses CHANGELOG.md to find the most recent version (first version section after [Unreleased]),
    creates a git tag for that version, and pushes it to the remote repository.

    Supports -WhatIf for safe preview of operations before execution.

.PARAMETER WhatIf
    Shows what would happen without actually creating or pushing the tag.

.EXAMPLE
    .\New-GitTag.ps1
    Creates and pushes a tag for the latest version in CHANGELOG.md

.EXAMPLE
    .\New-GitTag.ps1 -WhatIf
    Shows what tag would be created without executing git commands

.NOTES
    Requires:
    - Git to be installed and in PATH
    - CHANGELOG.md to exist in the repository root
    - Git repository to be properly configured with a remote
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#Requires -Version 7.0

# Strict error handling
$ErrorActionPreference = 'Stop'

function Get-LatestVersionFromChangelog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogPath
    )

    if (-not (Test-Path -Path $ChangelogPath -PathType Leaf)) {
        throw "CHANGELOG.md not found at: $ChangelogPath"
    }

    $content = Get-Content -Path $ChangelogPath -Raw

    # Match version pattern: ## [X.Y.Z] - YYYY-MM-DD
    # This matches the first version section after [Unreleased]
    $versionPattern = '##\s+\[(\d+\.\d+\.\d+(?:-[\w.]+)?)\]\s+-\s+\d{4}-\d{2}-\d{2}'

    if ($content -match $versionPattern) {
        return $Matches[1]
    }

    throw "No version found in CHANGELOG.md. Expected format: ## [X.Y.Z] - YYYY-MM-DD"
}

function Test-GitRepository {
    [CmdletBinding()]
    param()

    $gitCmd = Get-Command -Name git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        throw "Git command not found. Please ensure Git is installed and in PATH."
    }

    $gitRoot = git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not in a git repository. Please run this script from within a git repository."
    }

    # Check for remote
    $remotes = git remote 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remotes)) {
        throw "No git remote configured. Please configure a remote repository."
    }
}

function Test-TagExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TagName
    )

    # Check local tags
    $localTag = git tag -l $TagName 2>&1
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($localTag)) {
        return $true
    }

    # Check remote tags
    git ls-remote --tags origin "refs/tags/$TagName" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $remoteTags = git ls-remote --tags origin "refs/tags/$TagName" 2>&1
        if (-not [string]::IsNullOrWhiteSpace($remoteTags)) {
            return $true
        }
    }

    return $false
}

# Main script execution
try {
    Write-Host "Git Tag Creator - Based on CHANGELOG.md" -ForegroundColor Cyan
    Write-Host ""

    # Validate environment
    Write-Verbose "Checking git repository..."
    Test-GitRepository

    # Get changelog path
    $changelogPath = Join-Path -Path $PSScriptRoot -ChildPath "CHANGELOG.md"

    # Parse version from changelog
    Write-Host "Parsing CHANGELOG.md..." -ForegroundColor Gray
    $version = Get-LatestVersionFromChangelog -ChangelogPath $changelogPath

    Write-Host "  Found version: $version" -ForegroundColor Gray
    Write-Host ""

    # Construct tag name
    $tagName = "v$version"

    # Check if tag already exists
    if (Test-TagExists -TagName $tagName) {
        Write-Host "✗ Tag '$tagName' already exists (locally or remotely)" -ForegroundColor Red
        Write-Host "  Please update CHANGELOG.md with a new version before creating a tag." -ForegroundColor Yellow
        exit 1
    }

    # Create tag
    if ($PSCmdlet.ShouldProcess($tagName, "Create git tag")) {
        Write-Host "Creating tag: $tagName" -ForegroundColor Cyan
        git tag $tagName

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create git tag '$tagName'"
        }

        Write-Host "  ✓ Tag created successfully" -ForegroundColor Green
    }
    else {
        Write-Host "Would create tag: $tagName" -ForegroundColor Yellow
    }

    Write-Host ""

    # Push tag to remote
    if ($PSCmdlet.ShouldProcess($tagName, "Push tag to remote")) {
        Write-Host "Pushing tag to remote..." -ForegroundColor Cyan
        git push origin $tagName

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push tag '$tagName' to remote"
        }

        Write-Host "  ✓ Tag pushed successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "✓ Tag '$tagName' created and pushed to remote" -ForegroundColor Green
        Write-Host "  GitHub Actions will now trigger the release workflow." -ForegroundColor Gray
    }
    else {
        Write-Host "Would push tag to remote: $tagName" -ForegroundColor Yellow
    }

    exit 0
}
catch {
    Write-Host ""
    Write-Host "✗ Error: $_" -ForegroundColor Red
    exit 1
}
