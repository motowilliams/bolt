#Requires -Version 7.0

# TASK: format, fmt
# DESCRIPTION: Formats Terraform files using terraform fmt (Docker)
# DEPENDS:

Write-Host "Formatting Terraform files (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
}

# ===== Find Terraform Files =====
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
    Write-Host "No Terraform files found to format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tfFiles.Count) Terraform file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerImage = "hashicorp/terraform:latest"

$rebuildEnvVar = $env:BOLT_TERRAFORM_DOCKER_REBUILD
if ($rebuildEnvVar -eq "1" -or $rebuildEnvVar -eq "true") {
    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
    if (Test-Path -Path $dockerfilePath) {
        Write-Host "  Building custom Docker image (BOLT_TERRAFORM_DOCKER_REBUILD=1)..." -ForegroundColor Gray
        $imageName = "bolt-terraform:latest"
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

# ===== Format Files =====
$formatIssues = 0
$formattedCount = 0

$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Formatting directory: $relativePath" -ForegroundColor Gray

    $absolutePath = [System.IO.Path]::GetFullPath($dir)
    & docker run --rm -v "${absolutePath}:/tf" -w /tf $dockerImage fmt -recursive | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $filesInDir = ($tfFiles | Where-Object { (Split-Path -Path $_.FullName -Parent) -eq $dir }).Count
        Write-Host "    ✓ Formatted $filesInDir file(s)" -ForegroundColor Green
        $formattedCount += $filesInDir
    }
    else {
        Write-Host "    ✗ Format failed" -ForegroundColor Red
        $formatIssues++
    }
}

Write-Host ""

if ($formatIssues -gt 0) {
    Write-Host "✗ Format task completed with $formatIssues error(s)" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Terraform files formatted successfully ($formattedCount file(s))" -ForegroundColor Green
exit 0
