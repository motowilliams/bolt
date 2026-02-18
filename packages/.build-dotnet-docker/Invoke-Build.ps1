#Requires -Version 7.0

# TASK: build
# DESCRIPTION: Builds .NET projects (Docker)
# DEPENDS: format, restore, test

Write-Host "Building .NET projects (Docker)..." -ForegroundColor Cyan

# ===== Docker Requirement Check =====
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. This package requires Docker with Linux containers. Install Docker: https://docs.docker.com/get-docker/"
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
    Write-Host "No .NET projects found to build." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($projectFiles.Count) .NET project(s)" -ForegroundColor Gray
Write-Host ""

# ===== Docker Image Selection =====
$dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
$imageName = "bolt-dotnet:latest"

# Build args with optional cache invalidation
$buildArgs = @("-t", $imageName, "-f", $dockerfilePath, $PSScriptRoot)
if ($env:BOLT_DOTNET_DOCKER_REBUILD -eq "1" -or $env:BOLT_DOTNET_DOCKER_REBUILD -eq "true") {
    Write-Host "  Building Docker image with --no-cache (BOLT_DOTNET_DOCKER_REBUILD=1)..." -ForegroundColor Gray
    $buildArgs = @("--no-cache") + $buildArgs
}
else {
    Write-Host "  Building Docker image (using cache)..." -ForegroundColor Gray
}

$buildOutput = & docker build @buildArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Docker image. Output: $buildOutput"
    exit 1
}

Write-Host "    ✓ Docker image ready: $imageName" -ForegroundColor Green
$dockerImage = $imageName

# ===== Build Projects =====
$buildSuccess = $true

# Mount the parent directory (dotnetPath) so project references work
$absolutePath = [System.IO.Path]::GetFullPath($dotnetPath)

foreach ($project in $projectFiles) {
    $relativePath = $project.FullName.Substring($dotnetPath.Length).TrimStart('\', '/')
    $containerPath = "/project/$relativePath" -replace '\\', '/'

    Write-Host "  Building: $relativePath" -ForegroundColor Gray

    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $dockerImage dotnet build $containerPath --nologo --verbosity quiet 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Build succeeded" -ForegroundColor Green

        $projectDir = Split-Path -Path $project.FullName -Parent
        $binPath = Join-Path $projectDir "bin"
        if (Test-Path $binPath) {
            $assemblies = Get-ChildItem -Path $binPath -Filter "*.dll" -Recurse -File -ErrorAction SilentlyContinue |
                          Where-Object { $_.FullName -notmatch '\\ref\\' } |
                          Sort-Object LastWriteTime -Descending |
                          Select-Object -First 1

            if ($assemblies) {
                $sizeKB = [math]::Round($assemblies.Length / 1KB, 2)
                Write-Host "      Output: $($assemblies.Name) ($sizeKB KB)" -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Host "    ✗ Build failed" -ForegroundColor Red
        $buildSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
}

Write-Host ""

if (-not $buildSuccess) {
    Write-Host "✗ Build task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All .NET projects built successfully" -ForegroundColor Green
exit 0
