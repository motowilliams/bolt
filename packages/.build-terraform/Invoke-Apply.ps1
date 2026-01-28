# TASK: apply, deploy
# DESCRIPTION: Applies Terraform changes (WARNING: modifies infrastructure)
# DEPENDS: format, validate, plan

Write-Host "⚠ WARNING: This will apply Terraform changes and modify infrastructure" -ForegroundColor Yellow
Write-Host "  Press Ctrl+C to cancel, or wait 5 seconds to continue..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Applying Terraform changes..." -ForegroundColor Cyan

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
if ($BoltConfig.TerraformPath) {
    # Use configured path (relative to project root)
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TerraformPath
}
elseif ($BoltConfig.IacPath) {
    # Backward compatibility - use IacPath if TerraformPath not specified
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

# ===== Apply Changes =====
$applySuccess = $true

# Group files by directory (each directory is a potential Terraform module)
$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Applying module: $relativePath" -ForegroundColor Gray
    
    # Initialize and apply
    Push-Location $dir
    try {
        # Check if plan file exists
        $planFile = "terraform.tfplan"
        $hasPlanFile = Test-Path -Path $planFile
        
        if ($useDocker) {
            # Use Docker with volume mount
            $absolutePath = [System.IO.Path]::GetFullPath($dir)
            
            # Initialize
            Write-Host "    Initializing..." -ForegroundColor Gray
            & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest init -backend=false -upgrade 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ✗ Initialization failed" -ForegroundColor Red
                $applySuccess = $false
                continue
            }
            
            # Apply (with or without plan file)
            if ($hasPlanFile) {
                Write-Host "    Applying from plan file..." -ForegroundColor Gray
                $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest apply -auto-approve terraform.tfplan -no-color 2>&1
            }
            else {
                Write-Host "    Generating and applying plan..." -ForegroundColor Gray
                $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest apply -auto-approve -no-color 2>&1
            }
        }
        else {
            # Use local terraform CLI (configured path or PATH search)
            Write-Host "    Initializing..." -ForegroundColor Gray
            & $terraformCmd init -backend=false 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ✗ Initialization failed" -ForegroundColor Red
                $applySuccess = $false
                continue
            }
            
            # Apply (with or without plan file)
            if ($hasPlanFile) {
                Write-Host "    Applying from plan file..." -ForegroundColor Gray
                $output = & $terraformCmd apply -auto-approve "terraform.tfplan" -no-color 2>&1
            }
            else {
                Write-Host "    Generating and applying plan..." -ForegroundColor Gray
                $output = & $terraformCmd apply -auto-approve -no-color 2>&1
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Apply completed successfully" -ForegroundColor Green
            
            # Display apply summary
            $summaryLines = $output | Where-Object { $_ -match 'Apply complete!' }
            if ($summaryLines) {
                foreach ($line in $summaryLines) {
                    Write-Host "      $line" -ForegroundColor Cyan
                }
            }
        }
        else {
            Write-Host "    ✗ Apply failed" -ForegroundColor Red
            $applySuccess = $false
            
            # Display errors
            $errorLines = $output | Where-Object { $_ -match 'Error:' }
            if ($errorLines) {
                foreach ($line in $errorLines) {
                    Write-Host "      $line" -ForegroundColor Red
                }
            }
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
}

# ===== Report Results =====
if (-not $applySuccess) {
    Write-Host "✗ Terraform apply failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Terraform changes applied successfully!" -ForegroundColor Green
exit 0
