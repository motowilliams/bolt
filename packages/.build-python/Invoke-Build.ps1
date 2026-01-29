#Requires -Version 7.0

# TASK: build
# DESCRIPTION: Installs Python dependencies and validates package structure
# DEPENDS: format, lint, test

Write-Host "Building Python project..." -ForegroundColor Cyan

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

Write-Host "Python project path: $pythonPath" -ForegroundColor Gray
Write-Host ""

# ===== Build Project =====
$buildSuccess = $true

if ($useDocker) {
    # Use Docker with volume mount
    $absolutePath = [System.IO.Path]::GetFullPath($pythonPath)

    # Check for setup.py, pyproject.toml, or requirements.txt
    $hasSetupPy = Test-Path -Path (Join-Path $pythonPath "setup.py")
    $hasPyprojectToml = Test-Path -Path (Join-Path $pythonPath "pyproject.toml")
    $hasRequirements = Test-Path -Path (Join-Path $pythonPath "requirements.txt")

    if ($hasPyprojectToml -or $hasSetupPy) {
        Write-Host "  Building Python package in Docker (installing build tools and building)..." -ForegroundColor Gray
        # Combine install and execution in single container to preserve installed packages
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim sh -c "pip install build --quiet && python -m build" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Package built successfully" -ForegroundColor Green

            # Check dist directory
            $distPath = Join-Path $pythonPath "dist"
            if (Test-Path -Path $distPath) {
                $artifacts = Get-ChildItem -Path $distPath -File
                Write-Host "    Generated $($artifacts.Count) artifact(s) in dist/" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "    ✗ Package build failed" -ForegroundColor Red
            $buildSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
    elseif ($hasRequirements) {
        Write-Host "  Installing dependencies from requirements.txt in Docker..." -ForegroundColor Gray
        $output = & docker run --rm -v "${absolutePath}:/project" -w /project python:3.12-slim pip install -r requirements.txt 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Dependencies installed successfully" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Dependency installation failed" -ForegroundColor Red
            $buildSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "  No setup.py, pyproject.toml, or requirements.txt found" -ForegroundColor Yellow
        Write-Host "  Skipping dependency installation" -ForegroundColor Gray
    }
}
else {
    # Use local Python CLI
    # Check for setup.py, pyproject.toml, or requirements.txt
    $hasSetupPy = Test-Path -Path (Join-Path $pythonPath "setup.py")
    $hasPyprojectToml = Test-Path -Path (Join-Path $pythonPath "pyproject.toml")
    $hasRequirements = Test-Path -Path (Join-Path $pythonPath "requirements.txt")

    if ($hasPyprojectToml -or $hasSetupPy) {
        Write-Host "  Installing build dependencies..." -ForegroundColor Gray
        $output = & $pythonCmd -m pip install build --quiet 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Failed to install build dependencies" -ForegroundColor Red
            $buildSuccess = $false
        }
        else {
            Write-Host "    ✓ Build dependencies installed" -ForegroundColor Green

            # Build package
            Write-Host "  Building Python package..." -ForegroundColor Gray
            Push-Location $pythonPath
            try {
                $output = & $pythonCmd -m build 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ Package built successfully" -ForegroundColor Green

                    # Check dist directory
                    $distPath = Join-Path $pythonPath "dist"
                    if (Test-Path -Path $distPath) {
                        $artifacts = Get-ChildItem -Path $distPath -File
                        Write-Host "    Generated $($artifacts.Count) artifact(s) in dist/" -ForegroundColor Gray
                    }
                }
                else {
                    Write-Host "    ✗ Package build failed" -ForegroundColor Red
                    $buildSuccess = $false
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
    elseif ($hasRequirements) {
        Write-Host "  Installing dependencies from requirements.txt..." -ForegroundColor Gray
        $requirementsPath = Join-Path $pythonPath "requirements.txt"
        $output = & $pythonCmd -m pip install -r $requirementsPath --quiet 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Dependencies installed successfully" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ Dependency installation failed" -ForegroundColor Red
            $buildSuccess = $false
            $output | ForEach-Object {
                Write-Host "      $_" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "  No setup.py, pyproject.toml, or requirements.txt found" -ForegroundColor Yellow
        Write-Host "  Skipping dependency installation" -ForegroundColor Gray
    }
}

Write-Host ""

# ===== Report Results =====
if (-not $buildSuccess) {
    Write-Host "✗ Python build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Python build completed successfully!" -ForegroundColor Green
exit 0
