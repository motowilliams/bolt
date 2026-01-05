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

    Security considerations:
    - This script parses version information from CHANGELOG.md and uses it to create and push git tags.
    - Ensure that CHANGELOG.md comes from a trusted source and has not been tampered with, especially in automated CI/CD environments.
    - Run this script only in repositories and branches you trust, and consider validating the current commit or branch before use in pipelines.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#Requires -Version 7.0

# Strict error handling
$ErrorActionPreference = 'Stop'

function Get-GitErrorOutput {
    <#
    .SYNOPSIS
        Filters and extracts error messages from git command output.

    .DESCRIPTION
        Processes git command output to identify error and fatal messages.
        Used for consistent error handling across git operations.

    .PARAMETER Output
        The output from a git command (typically captured with 2>&1).

    .NOTES
        Error patterns are based on common Git error messages.
        May not match all variations across different Git versions or locales.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Output
    )

    return $Output | Where-Object {
        $_ -is [System.Management.Automation.ErrorRecord] -or $_ -imatch 'fatal|error'
    }
}

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

    # Match version pattern: ## [X.Y.Z] - YYYY-MM-DD or ## [X.Y.Z-suffix] - YYYY-MM-DD
    # This matches the first version section after [Unreleased]
    # Note: Uses horizontal whitespace ([ \t]) to prevent matching across multiple lines
    # Expects well-formed CHANGELOG.md entries following the Keep a Changelog format
    $versionPattern = '##[ \t]+\[(\d+\.\d+\.\d+(?:-[\w.]+)?)\][ \t]+-[ \t]+\d{4}-\d{2}-\d{2}'

    if ($content -match $versionPattern) {
        return $Matches[1]
    }

    throw "No version found in CHANGELOG.md. Expected format: ## [X.Y.Z] - YYYY-MM-DD or ## [X.Y.Z-suffix] - YYYY-MM-DD"
}

function Test-GitRepository {
    <#
    .SYNOPSIS
        Validates the git repository environment and remote connectivity.

    .DESCRIPTION
        Checks that Git is installed, the current directory is in a git repository,
        a remote is configured, and the remote is accessible. Provides specific
        error messages for different types of failures.

    .NOTES
        - Validates Git command availability
        - Verifies git repository status
        - Checks remote configuration
        - Tests remote connectivity
        - Error patterns are based on common Git error messages (Git 2.x)
        - May not match all variations across different Git versions or locales
    #>
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

    # Verify remote connectivity
    Write-Verbose "Verifying remote connectivity..."
    $lsRemoteOutput = git ls-remote --heads origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorOutput = Get-GitErrorOutput -Output $lsRemoteOutput
        # Network-related errors
        if ($errorOutput -imatch 'Could not resolve host|Connection.*refused|Network.*unreachable|timeout|timed out|connection timeout') {
            throw "Unable to connect to remote repository. Please check your network connection and try again.`nError: $($errorOutput -join '; ')"
        }
        # Authentication-related errors
        elseif ($errorOutput -imatch 'Authentication failed|Permission denied|could not read|access denied|unauthorized|invalid credentials') {
            throw "Authentication failed when accessing remote repository. Please check your credentials and access permissions.`nError: $($errorOutput -join '; ')"
        }
        # Other errors
        else {
            throw "Unable to access remote repository. Please verify your remote configuration.`nError: $($errorOutput -join '; ')"
        }
    }
}

function Test-TagNameFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TagName
    )

    $tagPattern = '^v\d+\.\d+\.\d+(-[\w.]+)?$'
    return $TagName -match $tagPattern
}

function Test-TagExists {
    <#
    .SYNOPSIS
        Checks if a git tag exists locally or remotely.

    .DESCRIPTION
        Validates tag name format and checks for tag existence in both local
        and remote repositories. If remote check fails due to network or
        authentication issues, a warning is displayed and the function returns
        false (indicating tag doesn't exist or couldn't verify).

    .PARAMETER TagName
        The name of the git tag to check (e.g., 'v1.0.0').

    .NOTES
        - Returns $true if tag exists locally or remotely
        - Returns $false if tag doesn't exist or remote check fails
        - Warning displayed if remote check encounters errors
        - Remote check failures are treated as "tag doesn't exist remotely" to allow
          operations to proceed (fail-open behavior). This prevents network issues
          from blocking tag creation entirely.
        - Error patterns are based on common Git error messages (Git 2.x)
        - May not match all variations across different Git versions or locales
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TagName
    )

    # Validate tag name format to prevent command injection
    if (-not (Test-TagNameFormat -TagName $TagName)) {
        throw "Invalid tag name format: '$TagName'. Expected format: v<major>.<minor>.<patch> or v<major>.<minor>.<patch>-<prerelease>"
    }

    # Check local tags
    $localTag = git tag -l -- $TagName 2>&1
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($localTag)) {
        return $true
    }

    # Check remote tags (capture output once for efficiency)
    $remoteTags = git ls-remote --tags origin "refs/tags/$TagName" 2>&1

    # Check for errors vs. empty result
    if ($LASTEXITCODE -ne 0) {
        # git ls-remote failed - could be network, authentication, or other issues
        $errorOutput = Get-GitErrorOutput -Output $remoteTags
        if ($errorOutput) {
            Write-Warning "Unable to check remote tags: $($errorOutput -join '; '). Proceeding with local check only."
        }
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($remoteTags)) {
        return $true
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

    # Validate tag name format to prevent command injection or invalid tags
    if (-not (Test-TagNameFormat -TagName $tagName)) {
        Write-Host "✗ Derived tag name '$tagName' is invalid." -ForegroundColor Red
        Write-Host "  Expected format: v<major>.<minor>.<patch> or v<major>.<minor>.<patch>-<prerelease>" -ForegroundColor Yellow
        Write-Host "  Parsed version from CHANGELOG.md: '$version'" -ForegroundColor Yellow
        exit 1
    }

    # Check if tag already exists
    if (Test-TagExists -TagName $tagName) {
        Write-Host "✗ Tag '$tagName' already exists (locally or remotely)" -ForegroundColor Red
        Write-Host "  Please update CHANGELOG.md with a new version before creating a tag." -ForegroundColor Yellow
        exit 1
    }

    # Create tag
    if ($PSCmdlet.ShouldProcess($tagName, "Create git tag")) {
        Write-Host "Creating tag: $tagName" -ForegroundColor Cyan
        git tag -- $tagName

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
        git push origin -- $tagName

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push tag '$tagName' to remote"
        }

        Write-Host "  ✓ Tag pushed successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "✓ Tag '$tagName' created and pushed to remote" -ForegroundColor Green

        if ($env:GITHUB_ACTIONS -eq 'true') {
            Write-Host "  GitHub Actions will now trigger the release workflow." -ForegroundColor Gray
        }
        else {
            Write-Host "  Release workflows that watch this tag can now run." -ForegroundColor Gray
        }
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
