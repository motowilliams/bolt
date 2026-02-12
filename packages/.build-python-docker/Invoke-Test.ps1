#Requires -Version 7.0

# TASK: test
# DESCRIPTION: Runs Python tests using pytest (Docker)
# DEPENDS: format, lint

Write-Host "Running Python tests (Docker)..." -ForegroundColor Cyan

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

$testFiles = Get-ChildItem -Path $pythonPath -Recurse -Filter "test_*.py" -File -Force |
             Where-Object { $_.FullName -notmatch '__pycache__|\.venv|venv|\.eggs|\.tox|build|dist' }

if ($testFiles.Count -eq 0) {
    Write-Host "No test files found in $pythonPath" -ForegroundColor Yellow
    Write-Host "  (Looking for test_*.py or *_test.py files)" -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($testFiles.Count) test file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerImage = "python:3.12-slim"

$rebuildEnvVar = $env:BOLT_PYTHON_DOCKER_REBUILD
if ($rebuildEnvVar -eq "1" -or $rebuildEnvVar -eq "true") {
    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
    if (Test-Path -Path $dockerfilePath) {
        Write-Host "  Building custom Docker image (BOLT_PYTHON_DOCKER_REBUILD=1)..." -ForegroundColor Gray
        $imageName = "bolt-python:latest"
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

# ===== Run Tests =====
$testSuccess = $true

$absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

$requirementsPath = Join-Path $pythonPath "requirements.txt"
if (Test-Path -Path $requirementsPath) {
    Write-Host "  Running pytest in Docker (installing pytest, dependencies, and testing)..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage sh -c "pip install pytest --quiet && pip install -r requirements.txt --quiet && python -m pytest -v" 2>&1
}
else {
    Write-Host "  Running pytest in Docker (installing and testing)..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage sh -c "pip install pytest --quiet && python -m pytest -v" 2>&1
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ All tests passed" -ForegroundColor Green
}
else {
    Write-Host "    ✗ Some tests failed" -ForegroundColor Red
    $testSuccess = $false
    $output | ForEach-Object {
        Write-Host "      $_" -ForegroundColor Red
    }
}

if (-not $testSuccess) {
    Write-Host "✗ Test task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Test task completed successfully" -ForegroundColor Green
exit 0
