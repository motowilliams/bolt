#Requires -Version 7.0

# TASK: test
# DESCRIPTION: Runs Python tests using pytest
# DEPENDS: format, lint

Write-Host "Running Python tests..." -ForegroundColor Cyan

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

# Check for test files
$testFiles = Get-ChildItem -Path $pythonPath -Recurse -Filter "test_*.py" -File -Force |
             Where-Object { $_.FullName -notmatch '__pycache__|\.venv|venv|\.eggs|\.tox|build|dist' }

if ($testFiles.Count -eq 0) {
    Write-Host "No test files found in $pythonPath" -ForegroundColor Yellow
    Write-Host "  (Looking for test_*.py or *_test.py files)" -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($testFiles.Count) test file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Run Tests =====
$testSuccess = $true

if ($useDocker) {
    # Use Docker with volume mount
    $absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

    Write-Host "  Installing pytest in Docker..." -ForegroundColor Gray
    $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim pip install pytest 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Failed to install pytest" -ForegroundColor Red
        $testSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "    ✓ pytest installed" -ForegroundColor Green

        # Install project dependencies if requirements.txt exists
        $requirementsPath = Join-Path $pythonPath "requirements.txt"
        if (Test-Path -Path $requirementsPath) {
            Write-Host "  Installing dependencies from requirements.txt..." -ForegroundColor Gray
            $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim pip install -r requirements.txt 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Dependencies installed" -ForegroundColor Green
            }
            else {
                Write-Host "    ⚠ Failed to install some dependencies" -ForegroundColor Yellow
            }
        }

        # Run pytest
        Write-Host "  Running pytest..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim python -m pytest -v 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ All tests passed" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Some tests failed" -ForegroundColor Red
            $testSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
}
else {
    # Use local Python CLI
    Write-Host "  Installing pytest..." -ForegroundColor Gray
    $output = & $pythonCmd -m pip install pytest --quiet 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Failed to install pytest" -ForegroundColor Red
        $testSuccess = $false
        $output | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "    ✓ pytest installed" -ForegroundColor Green

        # Install project dependencies if requirements.txt exists
        $requirementsPath = Join-Path $pythonPath "requirements.txt"
        if (Test-Path -Path $requirementsPath) {
            Write-Host "  Installing dependencies from requirements.txt..." -ForegroundColor Gray
            $output = & $pythonCmd -m pip install -r $requirementsPath --quiet 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Dependencies installed" -ForegroundColor Green
            }
            else {
                Write-Host "    ⚠ Failed to install some dependencies" -ForegroundColor Yellow
            }
        }

        # Run pytest
        Write-Host "  Running pytest..." -ForegroundColor Gray
        Push-Location $pythonPath
        try {
            $output = & $pythonCmd -m pytest -v 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ All tests passed" -ForegroundColor Green
            }
            else {
                Write-Host "    ✗ Some tests failed" -ForegroundColor Red
                $testSuccess = $false
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
if (-not $testSuccess) {
    Write-Host "✗ Python tests failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All Python tests passed successfully!" -ForegroundColor Green
exit 0
