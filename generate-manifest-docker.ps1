# Docker wrapper for generate-manifest.ps1
# This script runs the manifest generation inside a PowerShell container

param(
    [Parameter(Mandatory = $true)]
    [string]$ModulePath,
    [Parameter(Mandatory = $true)]
    [string]$ModuleVersion,
    [Parameter(Mandatory = $true)]
    [string]$Tags,
    [string]$ProjectUri = "",
    [string]$LicenseUri = "",
    [string]$ReleaseNotes = ""
)

Write-Host "🐳 Starting Docker-based manifest generation..." -ForegroundColor Cyan

# Check if Docker is available
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "❌ Docker not found in PATH. Please install Docker Desktop or Docker Engine."
    exit 1
}

# Check if the generate-manifest.ps1 script exists
$generateScriptPath = Join-Path $PSScriptRoot "generate-manifest.ps1"
if (-not (Test-Path $generateScriptPath)) {
    Write-Error "❌ generate-manifest.ps1 not found at $generateScriptPath"
    exit 1
}

# Prepare arguments for the container script
$containerArgs = @()

$containerArgs += "-WorkspacePath"
$containerArgs += "/workspace"

$containerArgs += "-ModulePath"
$containerArgs += $ModulePath

$containerArgs += "-ModuleVersion"
$containerArgs += $ModuleVersion

$containerArgs += "-Tags"
# Tags is already a string, so pass it directly
$containerArgs += $Tags

if (-not [string]::IsNullOrWhiteSpace($ProjectUri)) {
    $containerArgs += "-ProjectUri"
    $containerArgs += $ProjectUri
}

if (-not [string]::IsNullOrWhiteSpace($LicenseUri)) {
    $containerArgs += "-LicenseUri"
    $containerArgs += $LicenseUri
}

if (-not [string]::IsNullOrWhiteSpace($ReleaseNotes)) {
    $containerArgs += "-ReleaseNotes"
    $containerArgs += $ReleaseNotes
}

Write-Host "📋 Container arguments: $($containerArgs -join ' ')" -ForegroundColor Gray

# Build the Docker command
$dockerArgs = @(
    "run"
    "--rm"
    "-v"
    "${PWD}:/workspace"
    "mcr.microsoft.com/powershell:latest"
    "pwsh"
    "-File"
    "/workspace/generate-manifest.ps1"
)

# Add the arguments
$dockerArgs += $containerArgs

Write-Host "🚀 Running manifest generation in PowerShell container..." -ForegroundColor Yellow

try {
    # Execute the Docker command
    & docker @dockerArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Manifest generation completed successfully!" -ForegroundColor Green

        # Check if the manifest was created
        # Extract module name and determine expected manifest location
        if ($ModulePath.EndsWith('.psm1')) {
            $moduleDirectory = Split-Path $ModulePath -Parent
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)
        }
        else {
            $moduleDirectory = $ModulePath
            $moduleName = Split-Path $ModulePath -Leaf
        }

        $manifestPath = Join-Path $PWD $moduleDirectory "$moduleName.psd1"
        if (Test-Path $manifestPath) {
            Write-Host "📄 Generated manifest: $manifestPath" -ForegroundColor Cyan

            # Display the generated file size and modification time
            $manifestFile = Get-Item $manifestPath
            Write-Host "   Size: $($manifestFile.Length) bytes" -ForegroundColor Gray
            Write-Host "   Modified: $($manifestFile.LastWriteTime)" -ForegroundColor Gray
        }
        else {
            Write-Host "⚠️  Warning: Expected manifest file not found at $manifestPath" -ForegroundColor Yellow
            # Also check the old location (workspace root) as fallback
            $fallbackPath = Join-Path $PWD "$moduleName.psd1"
            if (Test-Path $fallbackPath) {
                Write-Host "📄 Found manifest at: $fallbackPath" -ForegroundColor Cyan
            }
        }
    }
    else {
        Write-Error "❌ Docker command failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
catch {
    Write-Error "❌ Error executing Docker command: $_"
    exit 1
}

Write-Host "`n🎉 Docker manifest generation completed!" -ForegroundColor Green
