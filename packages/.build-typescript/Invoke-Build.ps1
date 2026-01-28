#Requires -Version 7.0

# TASK: build
# DESCRIPTION: Compiles TypeScript files to JavaScript
# DEPENDS: format, lint, test

Write-Host "Building TypeScript project..." -ForegroundColor Cyan

# ===== Node.js Command Detection =====
# Check for configured tool path first
if ($BoltConfig.NodeToolPath) {
    $nodeToolPath = $BoltConfig.NodeToolPath
    if (-not (Test-Path -Path $nodeToolPath -PathType Leaf)) {
        Write-Error "Node.js not found at configured path: $nodeToolPath. Please check NodeToolPath in bolt.config.json or install Node.js: https://nodejs.org/"
        exit 1
    }
    # When using custom node path, derive npm path
    $nodeDir = Split-Path -Path $nodeToolPath -Parent
    $npmCmd = Join-Path $nodeDir "npm"
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
        $npmCmd += ".cmd"
    }
    if (-not (Test-Path -Path $npmCmd -PathType Leaf)) {
        Write-Error "npm not found at expected path: $npmCmd. Please ensure npm is installed alongside Node.js"
        exit 1
    }
    $useDocker = $false
}
else {
    # Fall back to PATH search
    $npmCmdObj = Get-Command npm -ErrorAction SilentlyContinue
    
    # If npm not found, check for Docker
    if (-not $npmCmdObj) {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            Write-Error "Node.js/npm not found and Docker is not available. Please install Node.js: https://nodejs.org/, Docker: https://docs.docker.com/get-docker/, or configure NodeToolPath in bolt.config.json"
            exit 1
        }
        
        Write-Host "  Using Docker container for Node.js (local CLI not found)" -ForegroundColor Gray
        $useDocker = $true
    }
    else {
        $npmCmd = "npm"
        $useDocker = $false
    }
}

# ===== Find TypeScript Projects =====
# Find directories containing package.json files (using configured path)
if ($BoltConfig.TypeScriptPath) {
    # Use configured path (relative to project root)
    $tsPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.TypeScriptPath
}
else {
    Write-Error "TypeScriptPath not configured in bolt.config.json. Please add 'TypeScriptPath' property pointing to your TypeScript source files."
    exit 1
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
        # Use local npm CLI (configured path or PATH search)
        Write-Host "  Installing dependencies..." -ForegroundColor Gray
        $output = & $npmCmd install 2>&1
        
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
            $output = & $npmCmd run build 2>&1
            
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
