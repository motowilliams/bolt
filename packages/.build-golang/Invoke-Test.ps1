# TASK: test
# DESCRIPTION: Runs Go tests using go test
# DEPENDS:

Write-Host "Running Go tests..." -ForegroundColor Cyan

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
        Write-Error "Go CLI not found. Please install Go: https://go.dev/doc/install or configure GoToolPath in bolt.config.json"
        exit 1
    }

    $goCmd = "go"
}

# ===== Find Go Module Path =====
if ($BoltConfig.GoPath) {
    $goPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.GoPath
}
else {
    Write-Error "GoPath not configured in bolt.config.json. Please add 'GoPath' property pointing to your Go source files."
    exit 1
}

if (-not (Test-Path -Path $goPath)) {
    Write-Host "No Go project found at path: $goPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Running tests in: $goPath" -ForegroundColor Gray
Write-Host ""

$testSuccess = $true

Push-Location $goPath
try {
    Write-Host "  Running go test..." -ForegroundColor Gray
    Write-Host ""
    & $goCmd test -v ./...

    if ($LASTEXITCODE -ne 0) {
        $testSuccess = $false
    }
}
finally { Pop-Location }

Write-Host ""

if (-not $testSuccess) {
    Write-Host "✗ Tests failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All tests passed!" -ForegroundColor Green
exit 0
