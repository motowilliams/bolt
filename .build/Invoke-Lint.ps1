# TASK: lint
# DESCRIPTION: Validates Bicep syntax and runs linter

Write-Host "Linting Bicep files..." -ForegroundColor Cyan

# Check if bicep CLI is available
$bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
if (-not $bicepCmd) {
    Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install"
    exit 1
}

# Find all .bicep files (cross-platform path handling)
$iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "*.bicep" -Recurse -File -Force -ErrorAction SilentlyContinue

if ($bicepFiles.Count -eq 0) {
    Write-Host "No Bicep files found to lint." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($bicepFiles.Count) Bicep file(s) to validate" -ForegroundColor Gray
Write-Host ""

$errorCount = 0
$warningCount = 0
$lintSuccess = $true

foreach ($file in $bicepFiles) {
    $relativePath = Resolve-Path -Relative $file.FullName
    Write-Host "  Linting: $relativePath" -ForegroundColor Gray

    # Run bicep lint to check for issues (capture both stdout and stderr)
    $output = & bicep lint $file.FullName 2>&1

    # bicep lint outputs diagnostics in format: "path(line,col) : Level rule-name: message"
    # Example: "main.bicep(4,7) : Warning no-unused-params: Parameter "foo" is declared but never used."

    # Filter for actual diagnostic lines (contain line/column numbers)
    $diagnostics = $output | Where-Object { $_ -match '^\S+\(\d+,\d+\)\s*:\s*(Error|Warning)' }

    if ($diagnostics) {
        foreach ($diag in $diagnostics) {
            if ($diag -match ':\s*Error\s') {
                Write-Host "    $diag" -ForegroundColor Red
                $errorCount++
                $lintSuccess = $false
            }
            elseif ($diag -match ':\s*Warning\s') {
                Write-Host "    $diag" -ForegroundColor Yellow
                $warningCount++
            }
        }
    }
    else {
        Write-Host "    ✓ No issues found" -ForegroundColor Green
    }

    Write-Host ""
}

# Summary
Write-Host "Lint Summary:" -ForegroundColor Cyan
Write-Host "  Files checked: $($bicepFiles.Count)" -ForegroundColor Gray

if ($errorCount -gt 0) {
    Write-Host "  Errors: $errorCount" -ForegroundColor Red
}
if ($warningCount -gt 0) {
    Write-Host "  Warnings: $warningCount" -ForegroundColor Yellow
}

Write-Host ""

if (-not $lintSuccess) {
    Write-Host "✗ Linting failed with $errorCount error(s)" -ForegroundColor Red
    exit 1
}

if ($warningCount -gt 0) {
    Write-Host "⚠ Linting passed with $warningCount warning(s)" -ForegroundColor Yellow
    exit 0
}

Write-Host "✓ All Bicep files passed linting with no issues!" -ForegroundColor Green
exit 0
