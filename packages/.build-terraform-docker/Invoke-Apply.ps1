#Requires -Version 7.0

# TASK: apply, deploy
# DESCRIPTION: Applies Terraform changes (WARNING: modifies infrastructure) (Docker)
# DEPENDS: format, validate, plan

Write-Host "⚠ WARNING: This will apply Terraform changes and modify infrastructure" -ForegroundColor Yellow
Write-Host "  Press Ctrl+C to cancel, or wait 5 seconds to continue..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Applying Terraform changes (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
}

# ===== Find Terraform Root Modules =====
if ($BoltConfig -and $BoltConfig.TerraformPath) {
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TerraformPath
}
elseif ($BoltConfig -and $BoltConfig.IacPath) {
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
}
else {
    Write-Error "TerraformPath not configured in bolt.config.json. Please add 'TerraformPath' property pointing to your Terraform source files."
    exit 1
}

$tfFiles = Get-ChildItem -Path $tfPath -Filter "*.tf" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($tfFiles.Count -eq 0) {
    Write-Host "No Terraform files found to apply." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tfFiles.Count) Terraform file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
$imageName = "bolt-terraform:latest"

# Build args with optional cache invalidation
$buildArgs = @("-t", $imageName, "-f", $dockerfilePath, $PSScriptRoot)
if ($env:BOLT_TERRAFORM_DOCKER_REBUILD -eq "1" -or $env:BOLT_TERRAFORM_DOCKER_REBUILD -eq "true") {
    Write-Host "  Building Docker image with --no-cache (BOLT_TERRAFORM_DOCKER_REBUILD=1)..." -ForegroundColor Gray
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

# ===== Apply Changes =====
$applySuccess = $true

$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Applying module: $relativePath" -ForegroundColor Gray

    Push-Location $dir
    try {
        $planFile = "terraform.tfplan"
        $hasPlanFile = Test-Path -Path $planFile

        $absolutePath = [System.IO.Path]::GetFullPath($dir)

        Write-Host "    Initializing..." -ForegroundColor Gray
        & docker run --rm -v "${absolutePath}:/tf" -w /tf $dockerImage init -backend=false -upgrade 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Initialization failed" -ForegroundColor Red
            $applySuccess = $false
            continue
        }

        if ($hasPlanFile) {
            Write-Host "    Using existing plan file: $planFile" -ForegroundColor Gray
            $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf $dockerImage apply -auto-approve $planFile 2>&1
        }
        else {
            Write-Host "    No plan file found, applying directly (not recommended)" -ForegroundColor Yellow
            $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf $dockerImage apply -auto-approve -no-color 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Apply completed successfully" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Apply failed" -ForegroundColor Red
            $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
            $applySuccess = $false
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""

if (-not $applySuccess) {
    Write-Host "✗ Apply task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Terraform changes applied successfully" -ForegroundColor Green
Write-Host "⚠ Infrastructure has been modified" -ForegroundColor Yellow
exit 0
