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

if ($useDocker) {
    $absolutePath = [System.IO.Path]::GetFullPath($goPath)
    Write-Host "  Running go test in Docker..." -ForegroundColor Gray
    Write-Host ""

    & docker run --rm -v "${absolutePath}:/project" -w /project golang:1.22-alpine go test -v ./...

    if ($LASTEXITCODE -ne 0) {
        $testSuccess = $false
    }
}
else {
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
}

Write-Host ""

if (-not $testSuccess) {
    Write-Host "✗ Tests failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All tests passed!" -ForegroundColor Green
exit 0
