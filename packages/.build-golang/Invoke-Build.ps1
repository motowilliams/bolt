# TASK: build
# DESCRIPTION: Builds Go application
# DEPENDS: format, lint, test

Write-Host "Building Go application..." -ForegroundColor Cyan

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

Write-Host "Building project in: $goPath" -ForegroundColor Gray
Write-Host ""

$buildSuccess = $true

# Determine output binary name from go.mod
$moduleName = "app"
$goModPath = Join-Path $goPath "go.mod"
if (Test-Path $goModPath) {
    $modContent = Get-Content $goModPath -Raw
    if ($modContent -match 'module\s+([^\s]+)') {
        $fullModuleName = $matches[1]
        $moduleName = $fullModuleName -replace '.*/([^/]+)$', '$1'
    }
}

# Create output directory
$outputDir = Join-Path $goPath "bin"
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

if ($useDocker) {
    $absolutePath = [System.IO.Path]::GetFullPath($goPath)
    $dockerOutputPath = "bin/$moduleName"  # Linux binary (no .exe)

    Write-Host "  Building binary in Docker: $dockerOutputPath" -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project golang:1.22-alpine go build -o $dockerOutputPath ./... 2>&1

    if ($LASTEXITCODE -ne 0) {
        $buildSuccess = $false
        Write-Host "  ✗ Build failed" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    }
    else {
        Write-Host "  ✓ Build completed successfully" -ForegroundColor Green
        $binaryPath = Join-Path $outputDir $moduleName
        if (Test-Path $binaryPath) {
            $fileInfo = Get-Item $binaryPath
            $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
            Write-Host "  Binary size: $sizeKB KB" -ForegroundColor Gray
            Write-Host "  Note: Docker builds Linux binary (not Windows .exe)" -ForegroundColor Gray
        }
    }
}
else {
    # Determine OS-specific binary extension
    $binaryExt = ""
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
        $binaryExt = ".exe"
    }

    $outputFileName = "$moduleName$binaryExt"
    $outputPath = Join-Path $outputDir $outputFileName

    Push-Location $goPath
    try {
        Write-Host "  Building binary: $outputPath" -ForegroundColor Gray
        & $goCmd build -o $outputPath ./...

        if ($LASTEXITCODE -ne 0) {
            $buildSuccess = $false
            Write-Host "  ✗ Build failed" -ForegroundColor Red
        }
        else {
            Write-Host "  ✓ Build completed successfully" -ForegroundColor Green
            if (Test-Path $outputPath) {
                $fileInfo = Get-Item $outputPath
                $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
                Write-Host "  Binary size: $sizeKB KB" -ForegroundColor Gray
            }
        }
    }
    finally { Pop-Location }
}

Write-Host ""

if (-not $buildSuccess) {
    Write-Host "✗ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Go application built successfully!" -ForegroundColor Green
exit 0
