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
    # When using custom python path, derive pip path
    $pythonDir = Split-Path -Path $pythonToolPath -Parent
    $pipCmd = Join-Path $pythonDir "pip"
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
        $pipCmd += ".exe"
    }
    if (-not (Test-Path -Path $pipCmd -PathType Leaf)) {
        Write-Error "pip not found at expected path: $pipCmd. Please ensure pip is installed alongside Python"
        exit 1
    }
    $pythonCmd = $pythonToolPath
    $useDocker = $false
}
else {
    # Fall back to PATH search
    $pythonCmdObj = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmdObj) {
        # Try python3 on Unix systems
        $pythonCmdObj = Get-Command python3 -ErrorAction SilentlyContinue
    }

    # If python not found, check for Docker
    if (-not $pythonCmdObj) {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            Write-Error "Python not found and Docker is not available. Please install Python: https://www.python.org/downloads/, Docker: https://docs.docker.com/get-docker/, or configure PythonToolPath in bolt.config.json"
            exit 1
        }

        Write-Host "  Using Docker container for Python (local CLI not found)" -ForegroundColor Gray
        $useDocker = $true
    }
    else {
        $pythonCmd = $pythonCmdObj.Source
        $useDocker = $false
    }
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

if ($useDocker) {
    # Use Docker with volume mount
    $absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

    Write-Host "  Installing black in Docker..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim pip install black 2>&1

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
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim python -m black . 2>&1

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
else {
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
}

Write-Host ""

# ===== Report Results =====
if (-not $formatSuccess) {
    Write-Host "✗ Python formatting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Python files formatted successfully!" -ForegroundColor Green
exit 0
