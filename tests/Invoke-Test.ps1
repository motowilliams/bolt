# TASK: test
# DESCRIPTION: Run Pester tests for the Bolt build system
# DEPENDS:

#Requires -Version 7.0

# Auto-install Pester if not available
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' } | Select-Object -First 1
if (-not $pesterModule) {
    Write-Host "Pester 5.0+ not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
    Import-Module Pester -MinimumVersion 5.0.0
} else {
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
}

Write-Host "Running Pester tests..." -ForegroundColor Cyan
Write-Host ""

# Configure Pester
$configuration = New-PesterConfiguration

# Determine test file path (same directory as this script)
$testFile = Join-Path $PSScriptRoot 'bolt.Tests.ps1'

# Verify test file exists
if (-not (Test-Path $testFile)) {
    Write-Host "✗ Test file not found: $testFile" -ForegroundColor Red
    exit 1
}

# Set configuration options
$configuration.Run.Path = $testFile
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$projectRoot = Split-Path -Parent $PSScriptRoot
$configuration.TestResult.OutputPath = Join-Path $projectRoot 'TestResults.xml'
$configuration.TestResult.OutputFormat = 'NUnitXml'

# Run tests
$result = Invoke-Pester -Configuration $configuration

# Display summary
Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "  Total:  $($result.TotalCount)" -ForegroundColor Gray
Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor $(if ($result.PassedCount -gt 0) { 'Green' } else { 'Gray' })
Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor $(if ($result.SkippedCount -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host ""

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host "✗ $($result.FailedCount) test(s) failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All tests passed!" -ForegroundColor Green
exit 0
