#Requires -Version 7.0

# TASK: plan
# DESCRIPTION: Generates Terraform execution plan (Docker)
# DEPENDS: format, validate

Write-Host "Generating Terraform execution plan (Docker)..." -ForegroundColor Cyan

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
    Write-Host "No Terraform files found to plan." -ForegroundColor Yellow
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

# ===== Generate Plan =====
$planSuccess = $true

$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Planning module: $relativePath" -ForegroundColor Gray

    Push-Location $dir
    try {
        $absolutePath = [System.IO.Path]::GetFullPath($dir)

        Write-Host "    Initializing..." -ForegroundColor Gray
        & docker run --rm -v "${absolutePath}:/tf" -w /tf $dockerImage init -backend=false -upgrade 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Initialization failed" -ForegroundColor Red
            $planSuccess = $false
            continue
        }

        $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf $dockerImage plan "-out=terraform.tfplan" -no-color 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Plan generated successfully" -ForegroundColor Green

            $planFilePath = Join-Path $dir "terraform.tfplan"
            if (Test-Path $planFilePath) {
                $sizeKB = [math]::Round((Get-Item $planFilePath).Length / 1KB, 2)
                Write-Host "      Plan file: terraform.tfplan ($sizeKB KB)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "    ✗ Plan generation failed" -ForegroundColor Red
            $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
            $planSuccess = $false
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""

if (-not $planSuccess) {
    Write-Host "✗ Plan task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Terraform plans generated successfully" -ForegroundColor Green
exit 0
