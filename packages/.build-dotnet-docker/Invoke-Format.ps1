# TASK: format, fmt
# DESCRIPTION: Formats C# source files using dotnet format
# DEPENDS:

Write-Host "Formatting C# files..." -ForegroundColor Cyan

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

# ===== Find .NET Projects =====
if ($BoltConfig -and $BoltConfig.DotNetPath) {
    $dotnetPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.DotNetPath
}
else {
    Write-Error "DotNetPath not configured in bolt.config.json. Please add 'DotNetPath' property pointing to your .NET source files."
    exit 1
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

    $absolutePath = [System.IO.Path]::GetFullPath($projectDir)

    # First check if formatting is needed
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $imageName format --verify-no-changes 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Formatting needed, applying changes..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project $imageName format 2>&1

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

    Write-Host ""
}

# ===== Report Results =====
if (-not $formatSuccess) {
    Write-Host "✗ C# formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All C# projects formatted successfully!" -ForegroundColor Green
exit 0
