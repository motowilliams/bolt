# TASK: format, fmt
# DESCRIPTION: Formats Bicep files using bicep format

Write-Host "Formatting Bicep files..." -ForegroundColor Cyan

# Check if bicep CLI is available
$bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
if (-not $bicepCmd) {
    Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install"
    exit 1
}

# Find all .bicep files (using config or fallback to default path)
if ($BoltConfig.IacPath) {
    # Use configured path (relative to project root)
    $iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
}
else {
    # Fallback to default location for backward compatibility
    $iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
}
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "*.bicep" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($bicepFiles.Count -eq 0) {
    Write-Host "No Bicep files found to format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($bicepFiles.Count) Bicep file(s)" -ForegroundColor Gray
Write-Host ""

$formatIssues = 0
$formattedCount = 0

foreach ($file in $bicepFiles) {
    $relativePath = Resolve-Path -Relative $file.FullName

    # Format the file in place
    Write-Host "  Formatting: $relativePath" -ForegroundColor Gray

    bicep format $file.FullName --outfile $file.FullName

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ $relativePath formatted" -ForegroundColor Green
        $formattedCount++
    }
    else {
        Write-Host "  ✗ $relativePath (format failed)" -ForegroundColor Red
        $formatIssues++
    }
}

Write-Host ""

if ($formatIssues -eq 0) {
    Write-Host "✓ Successfully formatted $formattedCount Bicep file(s)" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Failed to format $formatIssues file(s)" -ForegroundColor Red
    exit 1
}
