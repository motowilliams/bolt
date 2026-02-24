# TASK: test
# DESCRIPTION: Runs .NET tests using dotnet test
# DEPENDS:

Write-Host "Running .NET tests..." -ForegroundColor Cyan

# ===== Docker Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. Install from: https://www.docker.com/get-started"
    exit 1
}

# ===== Build Image from Dockerfile =====
$dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
$imageName = "bolt-dotnet:latest"
$buildContext = Split-Path -Path $dockerfilePath -Parent

$buildArgs = @("build", "-t", $imageName, "-f", $dockerfilePath, $buildContext)
if ($env:BOLT_DOTNET_DOCKER_REBUILD -eq "1" -or $env:BOLT_DOTNET_DOCKER_REBUILD -eq "true") {
    Write-Host "  Rebuilding Docker image from scratch (cache disabled)" -ForegroundColor Gray
    $buildArgs = @("build", "--no-cache", "-t", $imageName, "-f", $dockerfilePath, $buildContext)
}
else {
    Write-Host "  Building Docker image (using cache if available)" -ForegroundColor Gray
}

& docker @buildArgs 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed"
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

$allProjects = Get-ChildItem -Path $dotnetPath -Filter "*.csproj" -Recurse -File -Force -ErrorAction SilentlyContinue
$testProjects = $allProjects | Where-Object {
    $_.Name -match '\.Tests\.csproj$' -or $_.Directory.Name -eq 'Tests' -or $_.Directory.Name -eq 'tests'
}

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

    $absolutePath = [System.IO.Path]::GetFullPath($projectDir)

    Write-Host ""
    & docker run --rm -v "${absolutePath}:/project" -w /project $imageName test --nologo --verbosity normal
    Write-Host ""

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Tests passed" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ Tests failed" -ForegroundColor Red
        $testSuccess = $false
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
