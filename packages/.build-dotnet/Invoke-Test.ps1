# TASK: test
# DESCRIPTION: Runs .NET tests using dotnet test
# DEPENDS:

Write-Host "Running .NET tests..." -ForegroundColor Cyan

# ===== .NET Command Detection =====
# Check for configured tool path first
if ($BoltConfig.DotNetToolPath) {
    $dotnetToolPath = $BoltConfig.DotNetToolPath
    if (-not (Test-Path -Path $dotnetToolPath -PathType Leaf)) {
        Write-Error ".NET SDK not found at configured path: $dotnetToolPath. Please check DotNetToolPath in bolt.config.json or install .NET SDK: https://dotnet.microsoft.com/download"
        exit 1
    }
    $dotnetCmd = $dotnetToolPath
}
else {
    # Fall back to PATH search
    $dotnetCmdObj = Get-Command dotnet -ErrorAction SilentlyContinue

    if (-not $dotnetCmdObj) {
        Write-Error ".NET SDK not found. Please install .NET SDK: https://dotnet.microsoft.com/download or configure DotNetToolPath in bolt.config.json"
        exit 1
    }

    $dotnetCmd = "dotnet"
}

# ===== Find .NET Test Projects =====
# Find directories containing .csproj files (using configured path)
if ($BoltConfig -and $BoltConfig.DotNetPath) {
    # Use configured path (relative to project root)
    $dotnetPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.DotNetPath
}
else {
    Write-Error "DotNetPath not configured in bolt.config.json. Please add 'DotNetPath' property pointing to your .NET source files."
    exit 1
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
        # Use dotnet CLI (configured path or PATH search)
        Write-Host ""
        & $dotnetCmd test --nologo --verbosity normal
        Write-Host ""

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
