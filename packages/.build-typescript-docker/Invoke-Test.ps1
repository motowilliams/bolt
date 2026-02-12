#Requires -Version 7.0

# TASK: test
# DESCRIPTION: Runs TypeScript tests using Jest (Docker)
# DEPENDS: format, lint

Write-Host "Running TypeScript tests (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
}

# ===== Find TypeScript Projects =====
if ($BoltConfig -and $BoltConfig.TypeScriptPath) {
    $tsPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TypeScriptPath
}
else {
    Write-Error "TypeScriptPath not configured in bolt.config.json. Please add 'TypeScriptPath' property pointing to your TypeScript source files."
    exit 1
}

if (-not (Test-Path -Path $tsPath)) {
    Write-Host "TypeScript project path not found: $tsPath" -ForegroundColor Yellow
    exit 0
}

$packageJson = Get-ChildItem -Path $tsPath -Filter "package.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $packageJson) {
    Write-Host "No package.json found in $tsPath" -ForegroundColor Yellow
    exit 0
}

$projectDir = Split-Path -Path $packageJson.FullName -Parent
Write-Host "Found TypeScript project in: $projectDir" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerImage = "node:22-alpine"

$rebuildEnvVar = $env:BOLT_TYPESCRIPT_DOCKER_REBUILD
if ($rebuildEnvVar -eq "1" -or $rebuildEnvVar -eq "true") {
    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
    if (Test-Path -Path $dockerfilePath) {
        Write-Host "  Building custom Docker image (BOLT_TYPESCRIPT_DOCKER_REBUILD=1)..." -ForegroundColor Gray
        $imageName = "bolt-typescript:latest"
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

Push-Location $projectDir
try {
    $absolutePath = [System.IO.Path]::GetFullPath($projectDir)

    Write-Host "  Installing dependencies in Docker..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage npm install 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Failed to install dependencies" -ForegroundColor Red
        $testSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "    ✓ Dependencies installed" -ForegroundColor Green

        Write-Host "  Running Jest tests..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage npm test 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ All tests passed" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Tests failed" -ForegroundColor Red
            $testSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
}
finally {
    Pop-Location
}

if (-not $testSuccess) {
    Write-Host "✗ Test task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Test task completed successfully" -ForegroundColor Green
exit 0
