#Requires -Version 7.0
<#
.SYNOPSIS
    Removes Docker fallback logic from non-Docker package starters.

.DESCRIPTION
    This script removes all Docker-related code from the non-Docker package starters,
    leaving only local CLI execution paths.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Packages to clean (non-Docker variants)
$packagesToClean = @(
    '.build-dotnet',
    '.build-golang',
    '.build-python',
    '.build-terraform',
    '.build-typescript'
)

$packagesRoot = Join-Path $PSScriptRoot 'packages'

Write-Host "Removing Docker fallback logic from non-Docker packages..." -ForegroundColor Cyan
Write-Host ""

foreach ($packageName in $packagesToClean) {
    $packagePath = Join-Path $packagesRoot $packageName

    if (-not (Test-Path -Path $packagePath)) {
        Write-Warning "Package not found: $packageName"
        continue
    }

    Write-Host "Processing package: $packageName" -ForegroundColor Yellow

    # Get all PowerShell task files
    $taskFiles = Get-ChildItem -Path $packagePath -Filter "Invoke-*.ps1" -File -ErrorAction SilentlyContinue

    foreach ($taskFile in $taskFiles) {
        Write-Host "  Cleaning: $($taskFile.Name)" -ForegroundColor Gray

        $content = Get-Content -Path $taskFile.FullName -Raw
        $originalContent = $content

        # Pattern 1: Remove Docker fallback check block
        $content = $content -replace '(?s)\s*# If \w+ not found, check for Docker.*?else\s*\{[^}]*\$\w+Cmd = "[^"]+"\s*\$useDocker = \$false\s*\}', @'

    if (-not $cmdObj) {
        Write-Error "$toolName not found. Please install $toolName or configure ${toolName}ToolPath in bolt.config.json"
        exit 1
    }
    $cmd = "$toolName"
'@

        # Pattern 2: Remove $useDocker variable initialization
        $content = $content -replace '\s*\$useDocker = \$false\s*\n', "`n"

        # Pattern 3: Remove Docker conditional blocks
        $content = $content -replace '(?s)\s*if \(\$useDocker\) \{[^}]+?docker run[^}]+?\}\s*else \{', ''
        $content = $content -replace '(?s)\}\s*$', ''

        # Save if changed
        if ($content -ne $originalContent) {
            Set-Content -Path $taskFile.FullName -Value $content -NoNewline
            Write-Host "    ✓ Updated" -ForegroundColor Green
        }
        else {
            Write-Host "    - No changes needed" -ForegroundColor Gray
        }
    }

    Write-Host ""
}

Write-Host "✓ Docker fallback removal complete!" -ForegroundColor Green
