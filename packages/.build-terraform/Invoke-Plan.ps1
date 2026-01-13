# TASK: plan
# DESCRIPTION: Generates Terraform execution plan
# DEPENDS: format, validate

Write-Host "Generating Terraform execution plan..." -ForegroundColor Cyan

# ===== Terraform Command Detection =====
# Check for local terraform installation first
$terraformCmd = Get-Command terraform -ErrorAction SilentlyContinue

# If terraform not found, check for Docker
if (-not $terraformCmd) {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Error "Terraform CLI not found and Docker is not available. Please install Terraform: https://developer.hashicorp.com/terraform/downloads or Docker: https://docs.docker.com/get-docker/"
        exit 1
    }
    
    Write-Host "  Using Docker container for Terraform (local CLI not found)" -ForegroundColor Gray
    $useDocker = $true
}
else {
    $useDocker = $false
}

# ===== Find Terraform Root Modules =====
# Find directories containing .tf files (using config or fallback to default path)
if ($BoltConfig.IacPath) {
    # Use configured path (relative to project root)
    $tfPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
}
else {
    # Fallback to default location for backward compatibility
    $tfPath = Join-Path $PSScriptRoot "tests" "tf"
}

$tfFiles = Get-ChildItem -Path $tfPath -Filter "*.tf" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($tfFiles.Count -eq 0) {
    Write-Host "No Terraform files found to plan." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tfFiles.Count) Terraform file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Generate Plan =====
$planSuccess = $true

# Group files by directory (each directory is a potential Terraform module)
$directories = $tfFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent } | Select-Object -Unique

foreach ($dir in $directories) {
    $relativePath = Resolve-Path -Relative $dir
    Write-Host "  Planning module: $relativePath" -ForegroundColor Gray
    
    # Initialize and plan
    Push-Location $dir
    try {
        if ($useDocker) {
            # Use Docker with volume mount
            $absolutePath = [System.IO.Path]::GetFullPath($dir)
            
            # Initialize
            Write-Host "    Initializing..." -ForegroundColor Gray
            & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest init -backend=false -upgrade 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ✗ Initialization failed" -ForegroundColor Red
                $planSuccess = $false
                continue
            }
            
            # Generate plan (use quoted parameter for PowerShell compatibility)
            $output = & docker run --rm -v "${absolutePath}:/tf" -w /tf hashicorp/terraform:latest plan "-out=terraform.tfplan" -no-color 2>&1
        }
        else {
            # Use local terraform CLI
            Write-Host "    Initializing..." -ForegroundColor Gray
            & terraform init -backend=false 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ✗ Initialization failed" -ForegroundColor Red
                $planSuccess = $false
                continue
            }
            
            # Generate plan
            $output = & terraform plan "-out=terraform.tfplan" -no-color 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Plan generated successfully" -ForegroundColor Green
            
            # Display plan summary (look for resource changes in output)
            $changeLines = $output | Where-Object { $_ -match 'Plan:' }
            if ($changeLines) {
                foreach ($line in $changeLines) {
                    Write-Host "      $line" -ForegroundColor Cyan
                }
            }
        }
        else {
            Write-Host "    ✗ Plan generation failed" -ForegroundColor Red
            $planSuccess = $false
            
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
if (-not $planSuccess) {
    Write-Host "✗ Terraform plan generation failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Terraform execution plan generated successfully!" -ForegroundColor Green
Write-Host "  Note: Plan files (*.tfplan) are not applied automatically" -ForegroundColor Gray
exit 0
