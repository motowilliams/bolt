#Requires -Version 7.0

# TASK: test
# DESCRIPTION: Runs .NET tests (Docker)
# DEPENDS: restore

Write-Host "Running .NET tests (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
}

# ===== Find .NET Test Projects =====
if ($BoltConfig -and $BoltConfig.DotNetPath) {
    $dotnetPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.DotNetPath
}
else {
    Write-Error "DotNetPath not configured in bolt.config.json. Please add 'DotNetPath' property pointing to your .NET source files."
    exit 1
}

$testProjects = Get-ChildItem -Path $dotnetPath -Filter "*.csproj" -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'Test' -or $_.Name -match 'Tests' }

if ($testProjects.Count -eq 0) {
    Write-Host "No test projects found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($testProjects.Count) test project(s)" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerImage = "mcr.microsoft.com/dotnet/sdk:10.0"

$rebuildEnvVar = $env:BOLT_DOTNET_DOCKER_REBUILD
if ($rebuildEnvVar -eq "1" -or $rebuildEnvVar -eq "true") {
    $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
    if (Test-Path -Path $dockerfilePath) {
        Write-Host "  Building custom Docker image (BOLT_DOTNET_DOCKER_REBUILD=1)..." -ForegroundColor Gray
        $imageName = "bolt-dotnet:latest"
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

# ===== Run Tests =====
$testSuccess = $true

foreach ($project in $testProjects) {
    $projectDir = Split-Path -Path $project.FullName -Parent
    $relativePath = Resolve-Path -Relative $project.FullName

    Write-Host "  Running tests: $relativePath" -ForegroundColor Gray

    Push-Location $projectDir
    try {
        $absolutePath = [System.IO.Path]::GetFullPath($projectDir)

        $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage dotnet test --nologo --verbosity quiet 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ All tests passed" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Some tests failed" -ForegroundColor Red
            $testSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""

if (-not $testSuccess) {
    Write-Host "✗ Test task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All .NET tests passed" -ForegroundColor Green
exit 0
