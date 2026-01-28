# TASK: format, fmt
# DESCRIPTION: Formats Go source files using gofmt
# DEPENDS:

Write-Host "Formatting Go files..." -ForegroundColor Cyan

# ===== Go Command Detection =====
# Check for configured tool path first
if ($BoltConfig.GoToolPath) {
    $goToolPath = $BoltConfig.GoToolPath
    if (-not (Test-Path -Path $goToolPath -PathType Leaf)) {
        Write-Error "Go CLI not found at configured path: $goToolPath. Please check GoToolPath in bolt.config.json or install Go: https://go.dev/doc/install"
        exit 1
    }
    $goCmd = $goToolPath
}
else {
    # Fall back to PATH search
    $goCmdObj = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmdObj) {
        Write-Error "Go CLI not found. Please install: https://go.dev/doc/install or configure GoToolPath in bolt.config.json"
        exit 1
    }
    $goCmd = "go"
}

# ===== Find Go Files =====
# Find all .go files (using config or fallback to default path)
if ($BoltConfig.GoPath) {
    # Use configured path (relative to project root)
    $goPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.GoPath
}
else {
    # Fallback to default location for backward compatibility
    $goPath = Join-Path $PSScriptRoot "tests" "app"
}
$goFiles = Get-ChildItem -Path $goPath -Filter "*.go" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($goFiles.Count -eq 0) {
    Write-Host "No Go files found to format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($goFiles.Count) Go file(s)" -ForegroundColor Gray
Write-Host ""

$formatIssues = 0
$formattedCount = 0

foreach ($file in $goFiles) {
    $relativePath = Resolve-Path -Relative $file.FullName

    # Format the file in place using gofmt
    Write-Host "  Formatting: $relativePath" -ForegroundColor Gray

    # gofmt -w writes the result to the file
    & $goCmd fmt $file.FullName | Out-Null

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
    Write-Host "✓ Successfully formatted $formattedCount Go file(s)" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Failed to format $formatIssues file(s)" -ForegroundColor Red
    exit 1
}
