#Requires -Version 7.0

# TASK: lint
# DESCRIPTION: Validates Python code using ruff
# DEPENDS: format

Write-Host "Linting Python files..." -ForegroundColor Cyan

# ===== Python Command Detection =====
# Check for configured tool path first
if ($BoltConfig.PythonToolPath) {
    $pythonToolPath = $BoltConfig.PythonToolPath
    if (-not (Test-Path -Path $pythonToolPath -PathType Leaf)) {
        Write-Error "Python not found at configured path: $pythonToolPath. Please check PythonToolPath in bolt.config.json or install Python: https://www.python.org/downloads/"
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

# ===== Lint Files =====
$lintSuccess = $true

if ($useDocker) {
    # Use Docker with volume mount
    $absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

    Write-Host "  Installing ruff in Docker..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim pip install ruff 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Failed to install ruff" -ForegroundColor Red
        $lintSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "    ✓ ruff installed" -ForegroundColor Green

        # Run ruff
        Write-Host "  Running ruff..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim python -m ruff check . 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ No linting errors found" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Linting errors found" -ForegroundColor Red
            $lintSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
}
else {
    # Use local Python CLI
    Write-Host "  Installing ruff..." -ForegroundColor Gray
    $output = & $pythonCmd -m pip install ruff --quiet 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Failed to install ruff" -ForegroundColor Red
        $lintSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "    ✓ ruff installed" -ForegroundColor Green

        # Run ruff
        Write-Host "  Running ruff..." -ForegroundColor Gray
        Push-Location $pythonPath
        try {
            $output = & $pythonCmd -m ruff check . 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ No linting errors found" -ForegroundColor Green
            }
            else {
                Write-Host "    ✗ Linting errors found" -ForegroundColor Red
                $lintSuccess = $false
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
if (-not $lintSuccess) {
    Write-Host "✗ Python linting failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Python files validated successfully!" -ForegroundColor Green
exit 0
