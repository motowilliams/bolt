#Requires -Version 7.0

# TASK: build
# DESCRIPTION: Builds Go application (Docker)
# DEPENDS: format, lint, test

Write-Host "Building Go application (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
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

# ===== Docker Image Selection =====
$dockerImage = "golang:1.22-alpine"

$rebuildEnvVar = $env:BOLT_GOLANG_DOCKER_REBUILD
if ($rebuildEnvVar -eq "1" -or $rebuildEnvVar -eq "true") {
    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
    if (Test-Path -Path $dockerfilePath) {
        Write-Host "  Building custom Docker image (BOLT_GOLANG_DOCKER_REBUILD=1)..." -ForegroundColor Gray
        $imageName = "bolt-golang:latest"
        $buildOutput = & docker build -t $imageName -f $dockerfilePath $PSScriptRoot 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Custom image built: $imageName" -ForegroundColor Green
            $dockerImage = $imageName
        }
        else {
            Write-Host "    ✗ Failed to build custom image, using default" -ForegroundColor Yellow
            $buildOutput | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
        }
    }
}

# ===== Build Application =====
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

$absolutePath = [System.IO.Path]::GetFullPath($goPath)
$dockerOutputPath = "bin/$moduleName"  # Linux binary (no .exe)

Write-Host "  Building binary in Docker: $dockerOutputPath" -ForegroundColor Gray
$output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage go build -o $dockerOutputPath ./... 2>&1

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

Write-Host ""

if (-not $buildSuccess) {
    Write-Host "✗ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Build completed successfully!" -ForegroundColor Green
exit 0
