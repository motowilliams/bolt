# TASK: format, fmt
# DESCRIPTION: Formats C# source files using dotnet format
# DEPENDS:

Write-Host "Formatting C# files..." -ForegroundColor Cyan

# ===== .NET Command Detection =====
# Check for local dotnet installation first
$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue

# If dotnet not found, check for Docker
if (-not $dotnetCmd) {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Error ".NET SDK not found and Docker is not available. Please install .NET SDK: https://dotnet.microsoft.com/download or Docker: https://docs.docker.com/get-docker/"
        exit 1
    }
    
    Write-Host "  Using Docker container for .NET SDK (local CLI not found)" -ForegroundColor Gray
    $useDocker = $true
}
else {
    $useDocker = $false
}

# ===== Find .NET Projects =====
# Find directories containing .csproj files (using config or fallback to default path)
if ($BoltConfig.DotNetPath) {
    # Use configured path (relative to project root)
    $dotnetPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.DotNetPath
}
else {
    # Fallback to default location for backward compatibility
    $dotnetPath = Join-Path $PSScriptRoot "tests" "app"
}

$projectFiles = Get-ChildItem -Path $dotnetPath -Filter "*.csproj" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($projectFiles.Count -eq 0) {
    Write-Host "No .NET projects found to format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($projectFiles.Count) .NET project(s)" -ForegroundColor Gray
Write-Host ""

# ===== Format Projects =====
$formatSuccess = $true

foreach ($project in $projectFiles) {
    $projectDir = Split-Path -Path $project.FullName -Parent
    $relativePath = Resolve-Path -Relative $project.FullName
    
    Write-Host "  Formatting project: $relativePath" -ForegroundColor Gray
    
    Push-Location $projectDir
    try {
        if ($useDocker) {
            # Use Docker with volume mount
            $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
            
            # Run dotnet format in Docker container
            $output = & docker run --rm -v "${absolutePath}:/project" -w /project mcr.microsoft.com/dotnet/sdk:8.0 dotnet format --verify-no-changes 2>&1
            
            # If verify-no-changes returns non-zero, format is needed
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    Formatting needed, applying changes..." -ForegroundColor Gray
                $output = & docker run --rm -v "${absolutePath}:/project" -w /project mcr.microsoft.com/dotnet/sdk:8.0 dotnet format 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ Project formatted successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "    ✗ Format failed" -ForegroundColor Red
                    $formatSuccess = $false
                    $output | ForEach-Object {
                        Write-Host "      $_" -ForegroundColor Red
                    }
                }
            }
            else {
                Write-Host "    ✓ Project already formatted" -ForegroundColor Green
            }
        }
        else {
            # Use local dotnet CLI
            # First check if formatting is needed
            $output = & dotnet format --verify-no-changes 2>&1
            
            # If verify-no-changes returns non-zero, format is needed
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    Formatting needed, applying changes..." -ForegroundColor Gray
                $output = & dotnet format 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ Project formatted successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "    ✗ Format failed" -ForegroundColor Red
                    $formatSuccess = $false
                    $output | ForEach-Object {
                        Write-Host "      $_" -ForegroundColor Red
                    }
                }
            }
            else {
                Write-Host "    ✓ Project already formatted" -ForegroundColor Green
            }
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
}

# ===== Report Results =====
if (-not $formatSuccess) {
    Write-Host "✗ C# formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All C# projects formatted successfully!" -ForegroundColor Green
exit 0
