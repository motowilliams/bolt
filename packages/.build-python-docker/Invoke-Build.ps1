#Requires -Version 7.0

# TASK: build
# DESCRIPTION: Installs Python dependencies and validates package structure (Docker)
# DEPENDS: format, lint, test

Write-Host "Building Python project (Docker)..." -ForegroundColor Cyan

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

Write-Host "Python project path: $pythonPath" -ForegroundColor Gray
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

# ===== Build Project =====
$buildSuccess = $true

$absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

$hasSetupPy = Test-Path -Path (Join-Path $pythonPath "setup.py")
$hasPyprojectToml = Test-Path -Path (Join-Path $pythonPath "pyproject.toml")
$hasRequirements = Test-Path -Path (Join-Path $pythonPath "requirements.txt")

if ($hasPyprojectToml -or $hasSetupPy) {
    Write-Host "  Building Python package in Docker (installing build tools and building)..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage sh -c "pip install build --quiet && python -m build" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Package built successfully" -ForegroundColor Green

        $distPath = Join-Path $pythonPath "dist"
        if (Test-Path -Path $distPath) {
            $artifacts = Get-ChildItem -Path $distPath -File
            Write-Host "    Generated $($artifacts.Count) artifact(s) in dist/" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "    ✗ Package build failed" -ForegroundColor Red
        $buildSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
}
elseif ($hasRequirements) {
    Write-Host "  Installing dependencies from requirements.txt in Docker..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage sh -c "pip install -r requirements.txt --quiet" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Dependencies installed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ Dependency installation failed" -ForegroundColor Red
        $buildSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "  No build configuration found (setup.py, pyproject.toml, or requirements.txt)" -ForegroundColor Yellow
    Write-Host "  Skipping build step" -ForegroundColor Gray
}

if (-not $buildSuccess) {
    Write-Host "✗ Build task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Build task completed successfully" -ForegroundColor Green
exit 0
