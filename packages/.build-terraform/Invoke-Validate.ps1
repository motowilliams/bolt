# TASK: validate
# DESCRIPTION: Validates Terraform configuration syntax

Write-Host "Validating Terraform configuration..." -ForegroundColor Cyan

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

# ===== Find Terraform Root Modules =====
# Find directories containing .tf files (using configured path)
if ($BoltConfig -and $BoltConfig.TerraformPath) {
    # Use configured path (relative to project root)
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TerraformPath
}
elseif ($BoltConfig -and $BoltConfig.IacPath) {
    # Backward compatibility - use IacPath if TerraformPath not specified
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
}
else {
    Write-Error "TerraformPath not configured in bolt.config.json. Please add 'TerraformPath' property pointing to your Terraform source files."
    exit 1
}

$tfFiles = Get-ChildItem -Path $tfPath -Filter "*.tf" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($tfFiles.Count -eq 0) {
    Write-Host "No Terraform files found to validate." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tfFiles.Count) Terraform file(s) to validate" -ForegroundColor Gray
Write-Host ""

# ===== Validate Configuration =====
$validateSuccess = $true

# Group files by directory (each directory is a potential Terraform module)
$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Validating module: $relativePath" -ForegroundColor Gray
    
    # Initialize Terraform (required before validate)
    Push-Location $dir
    try {
        if ($useDocker) {
            # Use Docker with volume mount
            $absolutePath = [System.IO.Path]::GetFullPath($dir)
            
            # Initialize without downloading providers (faster validation)
            Write-Host "    Initializing..." -ForegroundColor Gray
            $initOutput = & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest init -backend=false -upgrade 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ✗ Initialization failed" -ForegroundColor Red
                Write-Host "      $initOutput" -ForegroundColor Red
                $validateSuccess = $false
                continue
            }
            
            # Run validate
            $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest validate -no-color 2>&1
        }
        else {
            # Use local terraform CLI (configured path or PATH search)
            Write-Host "    Initializing..." -ForegroundColor Gray
            & $terraformCmd init -backend=false 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ✗ Initialization failed" -ForegroundColor Red
                $validateSuccess = $false
                continue
            }
            
            # Run validate
            $output = & $terraformCmd validate -no-color 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Configuration is valid" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Validation failed" -ForegroundColor Red
            $validateSuccess = $false
            
            # Display validation errors
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
}

# ===== Report Results =====
if (-not $validateSuccess) {
    Write-Host "✗ Terraform validation failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Terraform configurations are valid!" -ForegroundColor Green
exit 0
