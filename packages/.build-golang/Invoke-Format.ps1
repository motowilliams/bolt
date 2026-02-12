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
        Write-Error "Go CLI not found. Please install Go: https://go.dev/doc/install or configure GoToolPath in bolt.config.json"
        exit 1
    }

    $goCmd = "go"
}

# ===== Find Go Files =====
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

Write-Host "Formatting Go files in: $goPath" -ForegroundColor Gray
Write-Host ""

$formatSuccess = $true

Push-Location $goPath
try {
    Write-Host "  Running go fmt..." -ForegroundColor Gray
    $output = & $goCmd fmt ./... 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Files formatted successfully" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ Format failed" -ForegroundColor Red
        $formatSuccess = $false
        $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    }
}
finally { Pop-Location }

Write-Host ""

if (-not $formatSuccess) {
    Write-Host "✗ Go formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Go files formatted successfully!" -ForegroundColor Green
exit 0
