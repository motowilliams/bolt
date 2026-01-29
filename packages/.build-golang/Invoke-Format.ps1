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
    $useDocker = $false
}
else {
    # Fall back to PATH search
    $goCmdObj = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmdObj) {
        # If go not found, check for Docker
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            Write-Error "Go CLI not found and Docker is not available. Please install Go: https://go.dev/doc/install, Docker: https://docs.docker.com/get-docker/, or configure GoToolPath in bolt.config.json"
            exit 1
        }

        Write-Host "  Using Docker container for Go (local CLI not found)" -ForegroundColor Gray
        $useDocker = $true
    }
    else {
        $goCmd = "go"
        $useDocker = $false
    }
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

if ($useDocker) {
    $absolutePath = [System.IO.Path]::GetFullPath($goPath)
    Write-Host "  Running go fmt in Docker..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project golang:1.22-alpine go fmt ./... 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Files formatted successfully" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ Format failed" -ForegroundColor Red
        $formatSuccess = $false
        $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    }
}
else {
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
}

Write-Host ""

if (-not $formatSuccess) {
    Write-Host "✗ Go formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Go files formatted successfully!" -ForegroundColor Green
exit 0
