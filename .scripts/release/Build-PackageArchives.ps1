#Requires -Version 7.0

<#
.SYNOPSIS
    Builds release archives for all starter packages
.DESCRIPTION
    Discovers all starter packages in packages/.build-* directories that have
    a Create-Release.ps1 script and executes them to create release archives.
    
    Convention: Each packages/.build-* directory can include a Create-Release.ps1
    script that accepts -Version and -OutputDirectory parameters.
    
    All packages use the same version as the main Bolt module. If any package
    fails to build, the entire process stops (one error stops all).
.PARAMETER Version
    The version being released (e.g., 0.1.0, 1.0.0-beta)
.PARAMETER PackagesDirectory
    Root directory containing starter packages (default: packages)
.PARAMETER OutputDirectory
    Directory where release archives will be created (default: release)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$PackagesDirectory = "packages",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = 'Stop'

Write-Host "Building starter package archives (version: $Version)..." -ForegroundColor Cyan
Write-Host ""

# Resolve packages directory to absolute path
$PackagesDirectory = [System.IO.Path]::GetFullPath($PackagesDirectory)

# Validate packages directory exists
if (-not (Test-Path -Path $PackagesDirectory)) {
    Write-Host "⚠ No packages directory found at $PackagesDirectory" -ForegroundColor Yellow
    Write-Host "  Skipping package archive creation" -ForegroundColor Gray
    exit 0
}

# Discover all .build-* directories
$starterPackages = Get-ChildItem -Path $PackagesDirectory -Directory -Filter ".build-*" -Force

if ($starterPackages.Count -eq 0) {
    Write-Host "⚠ No starter packages found in $PackagesDirectory" -ForegroundColor Yellow
    Write-Host "  Skipping package archive creation" -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($starterPackages.Count) starter package(s):" -ForegroundColor Gray
foreach ($pkg in $starterPackages) {
    Write-Host "  - $($pkg.Name)" -ForegroundColor Gray
}
Write-Host ""

# Track packages that have Create-Release.ps1
$packagesWithScript = @()

foreach ($package in $starterPackages) {
    $releaseScript = Join-Path -Path $package.FullName -ChildPath "Create-Release.ps1"
    
    if (Test-Path -Path $releaseScript) {
        $packagesWithScript += @{
            Name = $package.Name
            Path = $package.FullName
            Script = $releaseScript
        }
    }
}

if ($packagesWithScript.Count -eq 0) {
    Write-Host "⚠ No starter packages have Create-Release.ps1 scripts" -ForegroundColor Yellow
    Write-Host "  Skipping package archive creation" -ForegroundColor Gray
    exit 0
}

Write-Host "Building archives for $($packagesWithScript.Count) package(s) with Create-Release.ps1:" -ForegroundColor Cyan
Write-Host ""

# Execute each package's Create-Release.ps1 script
$successCount = 0
$failedPackages = @()

foreach ($package in $packagesWithScript) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Building: $($package.Name)" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Execute the package's Create-Release.ps1 script
        & pwsh -File $package.Script -Version $Version -OutputDirectory $OutputDirectory
        
        # Check exit code
        if ($LASTEXITCODE -ne 0) {
            throw "Package build script exited with code $LASTEXITCODE"
        }
        
        $successCount++
        Write-Host ""
    }
    catch {
        $failedPackages += $package.Name
        Write-Host ""
        Write-Error "❌ Failed to build package: $($package.Name)"
        Write-Host "   Error: $_" -ForegroundColor Red
        Write-Host ""
        
        # One error stops all - exit immediately
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "❌ Package archive build failed" -ForegroundColor Red
        Write-Host "   Failed package: $($package.Name)" -ForegroundColor Red
        Write-Host "   Stopping all package builds (one error stops all)" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Summary
Write-Host "✓ Successfully built $successCount package archive(s)" -ForegroundColor Green

# List created archives
Write-Host ""
Write-Host "Created archives in $OutputDirectory/:" -ForegroundColor Gray
$archives = Get-ChildItem -Path $OutputDirectory -Filter "bolt-starter-*.zip"
foreach ($archive in $archives) {
    $size = ($archive.Length / 1KB)
    Write-Host "  - $($archive.Name) ($([math]::Round($size, 2)) KB)" -ForegroundColor Gray
}

exit 0
