# TASK: build
# DESCRIPTION: Builds .NET projects
# DEPENDS: format, restore, test

Write-Host "Building .NET projects..." -ForegroundColor Cyan

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
    Write-Host "No .NET projects found to build." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($projectFiles.Count) .NET project(s)" -ForegroundColor Gray
Write-Host ""

# ===== Build Projects =====
$buildSuccess = $true
$absoluteDotnetPath = [System.IO.Path]::GetFullPath($dotnetPath)

foreach ($project in $projectFiles) {
    $projectDir = Split-Path -Path $project.FullName -Parent
    $relativePath = Resolve-Path -Relative $project.FullName

    Write-Host "  Building: $relativePath" -ForegroundColor Gray

    $relativeProjectDir = [System.IO.Path]::GetRelativePath($absoluteDotnetPath, $projectDir)
    $workDir = "/project/$($relativeProjectDir -replace '\\', '/')"
    $output = & docker run --rm -v "${absoluteDotnetPath}:/project" -w $workDir $imageName build --nologo --verbosity quiet 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Build succeeded" -ForegroundColor Green

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
            if ($_ -match 'error|Error|ERROR') {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
}

# ===== Report Results =====
if (-not $buildSuccess) {
    Write-Host "✗ .NET build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All .NET projects built successfully!" -ForegroundColor Green
exit 0
