#Requires -Version 7.0

# TASK: format, fmt
# DESCRIPTION: Formats TypeScript files using Prettier
# DEPENDS:

Write-Host "Formatting TypeScript files..." -ForegroundColor Cyan

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
}
else {
    # Fall back to PATH search
    $npmCmdObj = Get-Command npm -ErrorAction SilentlyContinue

    if (-not $npmCmdObj) {
        Write-Error "Node.js/npm not found. Please install Node.js: https://nodejs.org/ or configure NodeToolPath in bolt.config.json"
        exit 1
    }

    $npmCmd = "npm"
}

# ===== Find TypeScript Projects =====
# Find directories containing package.json files (using configured path)
if ($BoltConfig -and $BoltConfig.TypeScriptPath) {
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

# ===== Format Files =====
$formatSuccess = $true

Push-Location $projectDir
try {
    # Use local npm CLI (configured path or PATH search)
    Write-Host "  Installing dependencies..." -ForegroundColor Gray
    $output = & $npmCmd install 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Failed to install dependencies" -ForegroundColor Red
        $formatSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "    ✓ Dependencies installed" -ForegroundColor Green

        # Run prettier via npm script
        Write-Host "  Running Prettier..." -ForegroundColor Gray
        $output = & $npmCmd run format 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Files formatted successfully" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Format failed" -ForegroundColor Red
            $formatSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
}
finally {
    Pop-Location
}

Write-Host ""

# ===== Report Results =====
if (-not $formatSuccess) {
    Write-Host "✗ TypeScript formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All TypeScript files formatted successfully!" -ForegroundColor Green
exit 0
