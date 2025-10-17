# Invoke-Format.ps1
# TASK: format, fmt
# DESCRIPTION: Formats Bicep files using bicep format

param(
    [switch]$Check
)

Write-Host "Formatting Bicep files..." -ForegroundColor Cyan

# Check if bicep CLI is available
$bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
if (-not $bicepCmd) {
    Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install"
    exit 1
}

# Find all .bicep files
$bicepFiles = Get-ChildItem -Path "iac" -Filter "*.bicep" -Recurse -File -ErrorAction SilentlyContinue

if ($bicepFiles.Count -eq 0) {
    Write-Host "No Bicep files found to format." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($bicepFiles.Count) Bicep file(s)" -ForegroundColor Gray
Write-Host ""

$formatIssues = 0
$formattedCount = 0

foreach ($file in $bicepFiles) {
    $relativePath = Resolve-Path -Relative $file.FullName
    
    if ($Check) {
        # Check if file needs formatting without making changes
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # Format to temp file
        bicep format $file.FullName --outfile $tempFile 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            # Compare original with formatted
            $original = Get-Content $file.FullName -Raw
            $formatted = Get-Content $tempFile -Raw
            
            if ($original -ne $formatted) {
                Write-Host "  ✗ $relativePath needs formatting" -ForegroundColor Yellow
                $formatIssues++
            }
            else {
                Write-Host "  ✓ $relativePath" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  ✗ $relativePath (format check failed)" -ForegroundColor Red
            $formatIssues++
        }
        
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
    else {
        # Format the file in place
        Write-Host "  Formatting: $relativePath" -ForegroundColor Gray
        
        bicep format $file.FullName --outfile $file.FullName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $relativePath formatted" -ForegroundColor Green
            $formattedCount++
        }
        else {
            Write-Host "  ✗ $relativePath (format failed)" -ForegroundColor Red
            $formatIssues++
        }
    }
}

Write-Host ""

if ($Check) {
    if ($formatIssues -eq 0) {
        Write-Host "✓ All $($bicepFiles.Count) Bicep file(s) are properly formatted" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "✗ $formatIssues file(s) need formatting. Run '.\go.ps1 format' to fix." -ForegroundColor Red
        exit 1
    }
}
else {
    if ($formatIssues -eq 0) {
        Write-Host "✓ Successfully formatted $formattedCount Bicep file(s)" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "✗ Failed to format $formatIssues file(s)" -ForegroundColor Red
        exit 1
    }
}
