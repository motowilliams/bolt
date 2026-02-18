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

Write-Host "Python project path: $pythonPath" -ForegroundColor Gray
Write-Host ""

# ===== Build Project =====
$buildSuccess = $true

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
            $buildExitCode = $LASTEXITCODE

            # Check if build artifacts exist (primary success indicator)
            $distPath = Join-Path $pythonPath "dist"
            $hasArtifacts = $false
            if (Test-Path -Path $distPath) {
                $artifacts = Get-ChildItem -Path $distPath -File -Filter "*.whl" -ErrorAction SilentlyContinue
                $hasArtifacts = $artifacts.Count -gt 0
            }

            # Build succeeds if exit code is 0 OR artifacts exist (handles Windows cleanup issues)
            if ($buildExitCode -eq 0 -or $hasArtifacts) {
                Write-Host "    ✓ Package built successfully" -ForegroundColor Green

                if (Test-Path -Path $distPath) {
                    $allArtifacts = Get-ChildItem -Path $distPath -File
                    Write-Host "    Generated $($allArtifacts.Count) artifact(s) in dist/" -ForegroundColor Gray
                }

                # Show warning if cleanup failed but build succeeded
                if ($buildExitCode -ne 0 -and $hasArtifacts) {
                    Write-Host "    ⚠ Build succeeded but cleanup failed (common on Windows + Dropbox)" -ForegroundColor Yellow
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

Write-Host ""

# ===== Report Results =====
if (-not $buildSuccess) {
    Write-Host "✗ Python build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Python build completed successfully!" -ForegroundColor Green
exit 0
