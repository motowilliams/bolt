# TASK: format, fmt
# DESCRIPTION: Formats Terraform files using terraform fmt

Write-Host "Formatting Terraform files..." -ForegroundColor Cyan

# ===== Terraform Command Detection =====
# Check for configured tool path first
if ($BoltConfig.TerraformToolPath) {
    $terraformToolPath = $BoltConfig.TerraformToolPath
    if (-not (Test-Path -Path $terraformToolPath -PathType Leaf)) {
        Write-Error "Terraform CLI not found at configured path: $terraformToolPath. Please check TerraformToolPath in bolt.config.json or install Terraform: https://developer.hashicorp.com/terraform/downloads"
        exit 1
    }
    $terraformCmd = $terraformToolPath
    $useDocker = $false
}
else {
    # Fall back to PATH search
    $terraformCmdObj = Get-Command terraform -ErrorAction SilentlyContinue
    
    # If terraform not found, check for Docker
    if (-not $terraformCmdObj) {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            Write-Error "Terraform CLI not found and Docker is not available. Please install Terraform: https://developer.hashicorp.com/terraform/downloads, Docker: https://docs.docker.com/get-docker/, or configure TerraformToolPath in bolt.config.json"
            exit 1
        }
        
        Write-Host "  Using Docker container for Terraform (local CLI not found)" -ForegroundColor Gray
        $useDocker = $true
    }
    else {
        $terraformCmd = "terraform"
        $useDocker = $false
    }
}

# ===== Find Terraform Files =====
# Find all .tf files (using config or fallback to default path)
if ($BoltConfig.TerraformPath) {
    # Use configured path (relative to project root)
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TerraformPath
}
elseif ($BoltConfig.IacPath) {
    # Backward compatibility - use IacPath if TerraformPath not specified
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
}
else {
    # Fallback to default location for backward compatibility
    $tfPath = Join-Path $PSScriptRoot "tests" "tf"
}

$tfFiles = Get-ChildItem -Path $tfPath -Filter "*.tf" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($tfFiles.Count -eq 0) {
    Write-Host "No Terraform files found to format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tfFiles.Count) Terraform file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Format Files =====
$formatIssues = 0
$formattedCount = 0

# Group files by directory for efficient formatting
$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Formatting directory: $relativePath" -ForegroundColor Gray
    
    if ($useDocker) {
        # Use Docker with volume mount
        # Convert path to absolute and handle cross-platform paths
        $absolutePath = [System.IO.Path]::GetFullPath($dir)
        
        # Docker volume mount syntax: host_path:container_path
        # Use splatting for proper argument handling
        & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest fmt -recursive | Out-Null
    }
    else {
        # Use local terraform CLI (configured path or PATH search)
        & $terraformCmd fmt -recursive $dir | Out-Null
    }
    
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

# ===== Report Results =====
if ($formatIssues -eq 0) {
    Write-Host "✓ Successfully formatted $formattedCount Terraform file(s)" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Failed to format files in $formatIssues director(ies)" -ForegroundColor Red
    exit 1
}
