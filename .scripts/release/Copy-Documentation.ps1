#Requires -Version 7.0

<#
.SYNOPSIS
    Copies documentation files to module package
.DESCRIPTION
    Copies essential documentation files and configuration schemas
    to the module directory for inclusion in the release.
#>

$releaseDir = "release"
$moduleName = "Bolt"
$moduleDir = Join-Path -Path $releaseDir -ChildPath $moduleName

Write-Host "Copying documentation files to module..." -ForegroundColor Cyan

# Copy essential documentation files
$docFiles = @(
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "IMPLEMENTATION.md"
)

foreach ($file in $docFiles) {
    if (Test-Path -Path $file) {
        Copy-Item -Path $file -Destination $moduleDir -Force
        Write-Host "  ✓ Copied: $file" -ForegroundColor Gray
    }
    else {
        Write-Host "  ⚠ Not found: $file" -ForegroundColor Yellow
    }
}

# Copy configuration schema files
Copy-Item -Path "bolt.config.schema.json" -Destination $moduleDir -Force -ErrorAction SilentlyContinue
Copy-Item -Path "bolt.config.example.json" -Destination $moduleDir -Force -ErrorAction SilentlyContinue

Write-Host "✓ Documentation files copied" -ForegroundColor Green
