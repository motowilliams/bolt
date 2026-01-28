# TASK: build
# DESCRIPTION: Compiles Bicep files to ARM JSON templates
# DEPENDS: format, lint

Write-Host "Building Bicep templates..." -ForegroundColor Cyan

# ===== Bicep Command Detection =====
# Check for configured tool path first
if ($BoltConfig.BicepToolPath) {
    $bicepToolPath = $BoltConfig.BicepToolPath
    if (-not (Test-Path -Path $bicepToolPath -PathType Leaf)) {
        Write-Error "Bicep CLI not found at configured path: $bicepToolPath. Please check BicepToolPath in bolt.config.json or install Bicep: https://aka.ms/bicep-install"
        exit 1
    }
    $bicepCmd = $bicepToolPath
}
else {
    # Fall back to PATH search
    $bicepCmdObj = Get-Command bicep -ErrorAction SilentlyContinue
    if (-not $bicepCmdObj) {
        Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install or configure BicepToolPath in bolt.config.json"
        exit 1
    }
    $bicepCmd = "bicep"
}

# ===== Find Bicep Files =====
# Find all main*.bicep files (e.g., main.bicep, main.dev.bicep)
# Modules are not compiled directly - they're referenced by main files
# Using configured path
if ($BoltConfig.BicepPath) {
    # Use configured path (relative to project root)
    $iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.BicepPath
}
else {
    Write-Error "BicepPath not configured in bolt.config.json. Please add 'BicepPath' property pointing to your Bicep source files."
    exit 1
}
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "main*.bicep" -File -Force -ErrorAction SilentlyContinue

if ($bicepFiles.Count -eq 0) {
    Write-Host "No Bicep files found to build." -ForegroundColor Yellow
    exit 0
}

$buildSuccess = $true

foreach ($file in $bicepFiles) {
    $outputFile = $file.FullName -replace '\.bicep$', '.json'
    Write-Host "  Compiling: $($file.Name) -> $([System.IO.Path]::GetFileName($outputFile))" -ForegroundColor Gray

    & $bicepCmd build $file.FullName --outfile $outputFile

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
