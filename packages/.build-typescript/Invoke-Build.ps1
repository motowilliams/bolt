#Requires -Version 7.0

# TASK: build
# DESCRIPTION: Compiles TypeScript files to JavaScript
# DEPENDS: format, lint, test

Write-Host "Building TypeScript project..." -ForegroundColor Cyan

# ===== Tool Command Detection =====
# Check for local npm installation first
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue

# If npm not found, check for Docker
if (-not $npmCmd) {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Error "Node.js/npm not found and Docker is not available. Please install Node.js: https://nodejs.org/ or Docker: https://docs.docker.com/get-docker/"
        exit 1
    }
    
    Write-Host "  Using Docker container for Node.js (local CLI not found)" -ForegroundColor Gray
    $useDocker = $true
}
else {
    $useDocker = $false
}

# ===== Find TypeScript Projects =====
# Find directories containing package.json files (using config or fallback to default path)
if ($BoltConfig.TypeScriptPath) {
    # Use configured path (relative to project root)
    $tsPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TypeScriptPath
}
else {
    # Fallback to default location for backward compatibility
    $tsPath = Join-Path $PSScriptRoot "tests" "app"
}

# Check if path exists
if (-not (Test-Path -Path $tsPath)) {
    Write-Host "TypeScript project path not found: $tsPath" -ForegroundColor Yellow
    exit 0
}

# Look for package.json to determine project root
$packageJson = Get-ChildItem -Path $tsPath -Filter "package.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $packageJson) {
    Write-Host "No package.json found in $tsPath" -ForegroundColor Yellow
    exit 0
}

$projectDir = Split-Path -Path $packageJson.FullName -Parent
Write-Host "Found TypeScript project in: $projectDir" -ForegroundColor Gray
Write-Host ""

# ===== Build Project =====
$buildSuccess = $true

Push-Location $projectDir
try {
    if ($useDocker) {
        # Use Docker with volume mount
        $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
        
        Write-Host "  Installing dependencies in Docker..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project node:22-alpine npm install 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Failed to install dependencies" -ForegroundColor Red
            $buildSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    ✓ Dependencies installed" -ForegroundColor Green
            
            # Run build via npm
            Write-Host "  Compiling TypeScript..." -ForegroundColor Gray
            $output = & docker run --rm -v "${absolutePath}:/project" -w /project node:22-alpine npm run build 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Build completed successfully" -ForegroundColor Green
                
                # Check if dist directory was created
                $distPath = Join-Path $projectDir "dist"
                if (Test-Path -Path $distPath) {
                    $jsFiles = Get-ChildItem -Path $distPath -Filter "*.js" -Recurse -File
                    Write-Host "    Generated $($jsFiles.Count) JavaScript file(s) in dist/" -ForegroundColor Gray
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
    }
    else {
        # Use local npm CLI
        Write-Host "  Installing dependencies..." -ForegroundColor Gray
        $output = & npm install 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Failed to install dependencies" -ForegroundColor Red
            $buildSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    ✓ Dependencies installed" -ForegroundColor Green
            
            # Run build via npm script
            Write-Host "  Compiling TypeScript..." -ForegroundColor Gray
            $output = & npm run build 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Build completed successfully" -ForegroundColor Green
                
                # Check if dist directory was created
                $distPath = Join-Path $projectDir "dist"
                if (Test-Path -Path $distPath) {
                    $jsFiles = Get-ChildItem -Path $distPath -Filter "*.js" -Recurse -File
                    Write-Host "    Generated $($jsFiles.Count) JavaScript file(s) in dist/" -ForegroundColor Gray
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
    }
}
finally {
    Pop-Location
}

Write-Host ""

# ===== Report Results =====
if (-not $buildSuccess) {
    Write-Host "✗ TypeScript build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ TypeScript build completed successfully!" -ForegroundColor Green
exit 0
