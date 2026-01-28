# TASK: restore
# DESCRIPTION: Restores NuGet packages for .NET projects
# DEPENDS:

Write-Host "Restoring NuGet packages..." -ForegroundColor Cyan

# ===== .NET Command Detection =====
# Check for configured tool path first
if ($BoltConfig.DotNetToolPath) {
    $dotnetToolPath = $BoltConfig.DotNetToolPath
    if (-not (Test-Path -Path $dotnetToolPath -PathType Leaf)) {
        Write-Error ".NET SDK not found at configured path: $dotnetToolPath. Please check DotNetToolPath in bolt.config.json or install .NET SDK: https://dotnet.microsoft.com/download"
        exit 1
    }
    $dotnetCmd = $dotnetToolPath
    $useDocker = $false
}
else {
    # Fall back to PATH search
    $dotnetCmdObj = Get-Command dotnet -ErrorAction SilentlyContinue
    
    # If dotnet not found, check for Docker
    if (-not $dotnetCmdObj) {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            Write-Error ".NET SDK not found and Docker is not available. Please install .NET SDK: https://dotnet.microsoft.com/download, Docker: https://docs.docker.com/get-docker/, or configure DotNetToolPath in bolt.config.json"
            exit 1
        }
        
        Write-Host "  Using Docker container for .NET SDK (local CLI not found)" -ForegroundColor Gray
        $useDocker = $true
    }
    else {
        $dotnetCmd = "dotnet"
        $useDocker = $false
    }
}

# ===== Find .NET Projects =====
# Find directories containing .csproj files (using configured path)
if ($BoltConfig -and $BoltConfig.DotNetPath) {
    # Use configured path (relative to project root)
    $dotnetPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.DotNetPath
}
else {
    # Fallback to default location (for direct script execution)
    $dotnetPath = Join-Path $PSScriptRoot "tests"
}

$projectFiles = Get-ChildItem -Path $dotnetPath -Filter "*.csproj" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($projectFiles.Count -eq 0) {
    Write-Host "No .NET projects found to restore." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($projectFiles.Count) .NET project(s)" -ForegroundColor Gray
Write-Host ""

# ===== Restore Projects =====
$restoreSuccess = $true

foreach ($project in $projectFiles) {
    $projectDir = Split-Path -Path $project.FullName -Parent
    $relativePath = Resolve-Path -Relative $project.FullName
    
    Write-Host "  Restoring: $relativePath" -ForegroundColor Gray
    
    Push-Location $projectDir
    try {
        if ($useDocker) {
            # Use Docker with volume mount
            $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
            
            # Run dotnet restore in Docker container
            $output = & docker run --rm -v "${absolutePath}:/project" -w /project mcr.microsoft.com/dotnet/sdk:10.0 dotnet restore 2>&1
        }
        else {
            # Use local dotnet CLI (configured path or PATH search)
            $output = & $dotnetCmd restore 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Packages restored successfully" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Restore failed" -ForegroundColor Red
            $restoreSuccess = $false
            
            # Display restore errors
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
if (-not $restoreSuccess) {
    Write-Host "✗ NuGet package restoration failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All packages restored successfully!" -ForegroundColor Green
exit 0
