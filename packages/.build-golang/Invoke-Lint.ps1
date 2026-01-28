# TASK: lint
# DESCRIPTION: Validates Go code using go vet
# DEPENDS:

Write-Host "Linting Go files..." -ForegroundColor Cyan

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

# ===== Find Go Project Path =====
# Find all .go files (using config or fallback to default path)
if ($BoltConfig.GoPath) {
    # Use configured path (relative to project root)
    $goPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.GoPath
}
else {
    # Fallback to default location for backward compatibility
    $goPath = Join-Path $PSScriptRoot "tests" "app"
}

# Check if path exists
if (-not (Test-Path -Path $goPath)) {
    Write-Host "No Go project found at path: $goPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Checking Go code in: $goPath" -ForegroundColor Gray
Write-Host ""

$lintSuccess = $true

# Run go vet on all packages
Push-Location $goPath
try {
    Write-Host "  Running go vet..." -ForegroundColor Gray

    # Run go vet and capture output
    $output = & $goCmd vet ./... 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $lintSuccess = $false
        Write-Host ""
        Write-Host "  ✗ go vet found issues:" -ForegroundColor Red
        foreach ($line in $output) {
            Write-Host "    $line" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  ✓ No issues found" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

Write-Host ""

# Summary
Write-Host "Lint Summary:" -ForegroundColor Cyan

if (-not $lintSuccess) {
    Write-Host "  ✗ Linting failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "✗ Go vet found issues that need to be fixed" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ All checks passed" -ForegroundColor Green
Write-Host ""
Write-Host "✓ All Go code passed linting with no issues!" -ForegroundColor Green
exit 0
