#Requires -Version 7.0

# TASK: format, fmt
# DESCRIPTION: Formats Python files using black (Docker)
# DEPENDS:

Write-Host "Formatting Python files (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
}

# ===== Find Python Source Files =====
if ($BoltConfig -and $BoltConfig.PythonPath) {
    $pythonPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.PythonPath
}
else {
    Write-Error "PythonPath not configured in bolt.config.json. Please add 'PythonPath' property pointing to your Python source files."
    exit 1
}

if (-not (Test-Path -Path $pythonPath)) {
    Write-Host "Python project path not found: $pythonPath" -ForegroundColor Yellow
    exit 0
}

$pythonFiles = Get-ChildItem -Path $pythonPath -Recurse -Filter "*.py" -File -Force |
               Where-Object { $_.FullName -notmatch '__pycache__|\.venv|venv|\.eggs|\.tox|build|dist' }

if ($pythonFiles.Count -eq 0) {
    Write-Host "No Python files found in $pythonPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($pythonFiles.Count) Python file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
$imageName = "bolt-python:latest"

# Build args with optional cache invalidation
$buildArgs = @("-t", $imageName, "-f", $dockerfilePath, $PSScriptRoot)
if ($env:BOLT_PYTHON_DOCKER_REBUILD -eq "1" -or $env:BOLT_PYTHON_DOCKER_REBUILD -eq "true") {
    Write-Host "  Building Docker image with --no-cache (BOLT_PYTHON_DOCKER_REBUILD=1)..." -ForegroundColor Gray
    $buildArgs = @("--no-cache") + $buildArgs
}
else {
    Write-Host "  Building Docker image (using cache)..." -ForegroundColor Gray
}

$buildOutput = & docker build @buildArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Docker image. Output: $buildOutput"
    exit 1
}

Write-Host "    ✓ Docker image ready: $imageName" -ForegroundColor Green
$dockerImage = $imageName

# ===== Format Files =====
$formatSuccess = $true

$absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

Write-Host "  Running black in Docker (installing and formatting)..." -ForegroundColor Gray
$output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage sh -c "pip install black --quiet && python -m black ." 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ Files formatted successfully" -ForegroundColor Green
}
else {
    Write-Host "    ✗ Format failed" -ForegroundColor Red
    $formatSuccess = $false
    $output | ForEach-Object {
        Write-Host "      $_" -ForegroundColor Red
    }
}

if (-not $formatSuccess) {
    Write-Host "✗ Format task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Format task completed successfully" -ForegroundColor Green
exit 0
