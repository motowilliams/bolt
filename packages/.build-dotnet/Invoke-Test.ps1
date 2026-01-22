# TASK: test
# DESCRIPTION: Runs .NET tests using dotnet test
# DEPENDS:

Write-Host "Running .NET tests..." -ForegroundColor Cyan

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

# ===== Find .NET Test Projects =====
# Find directories containing .csproj files (using config or fallback to default path)
if ($BoltConfig.DotNetPath) {
    # Use configured path (relative to project root)
    $dotnetPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.DotNetPath
}
else {
    # Fallback to default location for backward compatibility
    $dotnetPath = Join-Path $PSScriptRoot "tests" "app"
}

# Look for test projects (typically named *.Tests.csproj or in Tests directory)
$allProjects = Get-ChildItem -Path $dotnetPath -Filter "*.csproj" -Recurse -File -Force -ErrorAction SilentlyContinue
$testProjects = $allProjects | Where-Object { 
    $_.Name -match '\.Tests\.csproj$' -or $_.Directory.Name -eq 'Tests' -or $_.Directory.Name -eq 'tests'
}

# If no explicit test projects, use all projects (dotnet test will skip non-test projects)
if ($testProjects.Count -eq 0) {
    $testProjects = $allProjects
}

if ($testProjects.Count -eq 0) {
    Write-Host "No .NET test projects found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($testProjects.Count) test project(s)" -ForegroundColor Gray
Write-Host ""

# ===== Run Tests =====
$testSuccess = $true

foreach ($project in $testProjects) {
    $projectDir = Split-Path -Path $project.FullName -Parent
    $relativePath = Resolve-Path -Relative $project.FullName
    
    Write-Host "  Testing: $relativePath" -ForegroundColor Gray
    
    Push-Location $projectDir
    try {
        if ($useDocker) {
            # Use Docker with volume mount
            $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
            
            # Run dotnet test in Docker container
            Write-Host ""
            & docker run --rm -v "${absolutePath}:/project" -w /project mcr.microsoft.com/dotnet/sdk:8.0 dotnet test --nologo --verbosity normal
            Write-Host ""
        }
        else {
            # Use local dotnet CLI
            Write-Host ""
            & dotnet test --nologo --verbosity normal
            Write-Host ""
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Tests passed" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Tests failed" -ForegroundColor Red
            $testSuccess = $false
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
}

# ===== Report Results =====
if (-not $testSuccess) {
    Write-Host "✗ .NET tests failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All tests passed!" -ForegroundColor Green
exit 0
