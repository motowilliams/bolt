# TASK: build
# DESCRIPTION: Builds Go application
# DEPENDS: format, lint, test

Write-Host "Building Go application..." -ForegroundColor Cyan

# ===== Go Command Detection =====
# Check for configured tool path first
if ($BoltConfig.GoToolPath) {
    $goToolPath = $BoltConfig.GoToolPath
    if (-not (Test-Path -Path $goToolPath -PathType Leaf)) {
        Write-Error "Go CLI not found at configured path: $goToolPath. Please check GoToolPath in bolt.config.json or install Go: https://go.dev/doc/install"
        exit 1
    }
    $goCmd = $goToolPath
}
else {
    # Fall back to PATH search
    $goCmdObj = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmdObj) {
        Write-Error "Go CLI not found. Please install: https://go.dev/doc/install or configure GoToolPath in bolt.config.json"
        exit 1
    }
    $goCmd = "go"
}

# ===== Find Go Module Path =====
# Find Go module path (using configured path)
if ($BoltConfig.GoPath) {
    # Use configured path (relative to project root)
    $goPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.GoPath
}
else {
    Write-Error "GoPath not configured in bolt.config.json. Please add 'GoPath' property pointing to your Go source files."
    exit 1
}

# Check if path exists
if (-not (Test-Path -Path $goPath)) {
    Write-Host "No Go project found at path: $goPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Building project in: $goPath" -ForegroundColor Gray
Write-Host ""

$buildSuccess = $true

# Build the Go application
Push-Location $goPath
try {
    # Determine output binary name from go.mod module name
    $moduleName = "app"
    if (Test-Path "go.mod") {
        $modContent = Get-Content "go.mod" -Raw
        if ($modContent -match 'module\s+([^\s]+)') {
            $fullModuleName = $matches[1]
            # Get last segment of module path
            $moduleName = $fullModuleName -replace '.*/([^/]+)$', '$1'
        }
    }
    
    # Set output directory
    $outputDir = "bin"
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    # Determine OS-specific binary extension
    $binaryExt = ""
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
        $binaryExt = ".exe"
    }
    
    $outputPath = Join-Path $outputDir "$moduleName$binaryExt"
    
    Write-Host "  Building binary: $outputPath" -ForegroundColor Gray
    
    # Build the application
    & $goCmd build -o $outputPath ./...
    
    if ($LASTEXITCODE -ne 0) {
        $buildSuccess = $false
        Write-Host "  ✗ Build failed" -ForegroundColor Red
    }
    else {
        Write-Host "  ✓ Build completed successfully" -ForegroundColor Green
        
        # Show binary info
        if (Test-Path $outputPath) {
            $fileInfo = Get-Item $outputPath
            $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
            Write-Host "  Binary size: $sizeKB KB" -ForegroundColor Gray
        }
    }
}
finally {
    Pop-Location
}

Write-Host ""

if (-not $buildSuccess) {
    Write-Host "✗ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Go application built successfully!" -ForegroundColor Green
exit 0
