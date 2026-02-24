# TASK: restore
# DESCRIPTION: Restores NuGet packages for .NET projects
# DEPENDS:

Write-Host "Restoring NuGet packages..." -ForegroundColor Cyan

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

    $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project $imageName restore 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Packages restored successfully" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ Restore failed" -ForegroundColor Red
        $restoreSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
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
