# TASK: test
# DESCRIPTION: Runs Go tests using go test

Write-Host "Running Go tests..." -ForegroundColor Cyan

# Check if go CLI is available
$goCmd = Get-Command go -ErrorAction SilentlyContinue
if (-not $goCmd) {
    Write-Error "Go CLI not found. Please install: https://go.dev/doc/install"
    exit 1
}

# Find Go module path (using config or fallback to default path)
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

Write-Host "Running tests in: $goPath" -ForegroundColor Gray
Write-Host ""

$testSuccess = $true

# Run go test on all packages
Push-Location $goPath
try {
    Write-Host "  Running go test..." -ForegroundColor Gray
    Write-Host ""
    
    # Run go test with verbose output
    go test -v ./...
    
    if ($LASTEXITCODE -ne 0) {
        $testSuccess = $false
    }
}
finally {
    Pop-Location
}

Write-Host ""

if (-not $testSuccess) {
    Write-Host "✗ Tests failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All tests passed!" -ForegroundColor Green
exit 0
