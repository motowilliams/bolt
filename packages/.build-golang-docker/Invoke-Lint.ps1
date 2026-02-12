#Requires -Version 7.0

# TASK: lint
# DESCRIPTION: Validates Go code using go vet (Docker)
# DEPENDS: format

Write-Host "Linting Go code (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
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

Write-Host "Linting Go files in: $goPath" -ForegroundColor Gray
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

# ===== Lint Files =====
$lintSuccess = $true

$absolutePath = [System.IO.Path]::GetFullPath($goPath)
Write-Host "  Running go vet in Docker..." -ForegroundColor Gray
$output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage go vet ./... 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ No linting errors found" -ForegroundColor Green
}
else {
    Write-Host "    ✗ Linting errors found" -ForegroundColor Red
    $lintSuccess = $false
    $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
}

Write-Host ""

if (-not $lintSuccess) {
    Write-Host "✗ Go linting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Go lint checks passed!" -ForegroundColor Green
exit 0
