# TASK: build
# DESCRIPTION: Compiles Bicep files to ARM JSON templates
# DEPENDS: format, lint

Write-Host "Building Bicep templates..." -ForegroundColor Cyan

# Find all main*.bicep files (e.g., main.bicep, main.dev.bicep)
# Modules are not compiled directly - they're referenced by main files
# Using config or fallback to default path
if ($BoltConfig.IacPath) {
    # Use configured path (relative to project root)
    $iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
}
else {
    # Fallback to default location for backward compatibility
    $iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
}
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "main*.bicep" -File -Force -ErrorAction SilentlyContinue

if ($bicepFiles.Count -eq 0) {
    Write-Host "No Bicep files found to build." -ForegroundColor Yellow
    exit 0
}

# Check if bicep CLI is available
$bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
if (-not $bicepCmd) {
    Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install"
    exit 1
}

$buildSuccess = $true

foreach ($file in $bicepFiles) {
    $outputFile = $file.FullName -replace '\.bicep$', '.json'
    Write-Host "  Compiling: $($file.Name) -> $([System.IO.Path]::GetFileName($outputFile))" -ForegroundColor Gray

    bicep build $file.FullName --outfile $outputFile

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build $($file.Name)"
        $buildSuccess = $false
    }
    else {
        Write-Host "  ✓ $($file.Name) compiled successfully" -ForegroundColor Green
    }
}

if (-not $buildSuccess) {
    Write-Host "`nBuild failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✓ All Bicep files compiled successfully!" -ForegroundColor Green
exit 0
