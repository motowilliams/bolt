#Requires -Version 7.0

# TASK: format, fmt
# DESCRIPTION: Formats Python files using black
# DEPENDS:

Write-Host "Formatting Python files..." -ForegroundColor Cyan

# ===== Python Command Detection =====
# Check for configured tool path first
if ($BoltConfig.PythonToolPath) {
    $pythonToolPath = $BoltConfig.PythonToolPath
    if (-not (Test-Path -Path $pythonToolPath -PathType Leaf)) {
        Write-Error "Python not found at configured path: $pythonToolPath. Please check PythonToolPath in bolt.config.json or install Python: https://www.python.org/downloads/"
        exit 1
    }
    $pythonCmd = $pythonToolPath
}
else {
    # Fall back to PATH search
    $pythonCmdObj = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmdObj) {
        # Try python3 on Unix systems
        $pythonCmdObj = Get-Command python3 -ErrorAction SilentlyContinue
    }

    if (-not $pythonCmdObj) {
        Write-Error "Python not found. Please install Python: https://www.python.org/downloads/ or configure PythonToolPath in bolt.config.json"
        exit 1
    }

    $pythonCmd = $pythonCmdObj.Source
}

# ===== Find Python Source Files =====
# Use configured path or default to current directory
if ($BoltConfig -and $BoltConfig.PythonPath) {
    # Use configured path (relative to project root)
    $pythonPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.PythonPath
}
else {
    Write-Error "PythonPath not configured in bolt.config.json. Please add 'PythonPath' property pointing to your Python source files."
    exit 1
}

# Check if path exists
if (-not (Test-Path -Path $pythonPath)) {
    Write-Host "Python project path not found: $pythonPath" -ForegroundColor Yellow
    exit 0
}

# Find Python files
$pythonFiles = Get-ChildItem -Path $pythonPath -Recurse -Filter "*.py" -File -Force |
               Where-Object { $_.FullName -notmatch '__pycache__|\.venv|venv|\.eggs|\.tox|build|dist' }

if ($pythonFiles.Count -eq 0) {
    Write-Host "No Python files found in $pythonPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($pythonFiles.Count) Python file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Format Files =====
$formatSuccess = $true

# Use local Python CLI
Write-Host "  Installing black..." -ForegroundColor Gray
$output = & $pythonCmd -m pip install black --quiet 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "    ✗ Failed to install black" -ForegroundColor Red
    $formatSuccess = $false
    $output | ForEach-Object {
        Write-Host "      $_" -ForegroundColor Red
    }
}
else {
    Write-Host "    ✓ black installed" -ForegroundColor Green

    # Run black
    Write-Host "  Running black..." -ForegroundColor Gray
    Push-Location $pythonPath
    try {
        $output = & $pythonCmd -m black . 2>&1

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
    finally {
        Pop-Location
    }
}

Write-Host ""

# ===== Report Results =====
if (-not $formatSuccess) {
    Write-Host "✗ Python formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Python files formatted successfully!" -ForegroundColor Green
exit 0
