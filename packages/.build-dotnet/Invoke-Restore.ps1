# TASK: restore
# DESCRIPTION: Restores NuGet packages for .NET projects
# DEPENDS:

Write-Host "Restoring NuGet packages..." -ForegroundColor Cyan

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
            $output = & docker run --rm -v "${absolutePath}:/project" -w /project mcr.microsoft.com/dotnet/sdk:8.0 dotnet restore 2>&1
        }
        else {
            # Use local dotnet CLI
            $output = & dotnet restore 2>&1
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
