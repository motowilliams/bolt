#Requires -Version 7.0

# TASK: lint
# DESCRIPTION: Validates TypeScript files using ESLint
# DEPENDS: format

Write-Host "Linting TypeScript files..." -ForegroundColor Cyan

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

# ===== Lint Files =====
$lintSuccess = $true

Push-Location $projectDir
try {
    if ($useDocker) {
        # Use Docker with volume mount
        $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
        
        Write-Host "  Installing dependencies in Docker..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project node:22-alpine npm install 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Failed to install dependencies" -ForegroundColor Red
            $lintSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    ✓ Dependencies installed" -ForegroundColor Green
            
            # Run ESLint via npm
            Write-Host "  Running ESLint..." -ForegroundColor Gray
            $output = & docker run --rm -v "${absolutePath}:/project" -w /project node:22-alpine npm run lint 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Linting passed" -ForegroundColor Green
            }
            else {
                Write-Host "    ✗ Linting failed" -ForegroundColor Red
                $lintSuccess = $false
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
            $lintSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    ✓ Dependencies installed" -ForegroundColor Green
            
            # Run ESLint via npm script
            Write-Host "  Running ESLint..." -ForegroundColor Gray
            $output = & npm run lint 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Linting passed" -ForegroundColor Green
            }
            else {
                Write-Host "    ✗ Linting failed" -ForegroundColor Red
                $lintSuccess = $false
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
if (-not $lintSuccess) {
    Write-Host "✗ TypeScript linting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All TypeScript files passed linting!" -ForegroundColor Green
exit 0
