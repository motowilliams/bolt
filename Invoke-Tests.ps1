#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Runs all tests in the Bolt project, including tests in starter packages.

.DESCRIPTION
    This script configures Pester to discover and run tests from multiple
    locations in the project:
    
    - tests/ - Core Bolt orchestration tests
    - packages/.build-bicep/tests/ - Bicep starter package tests
    - packages/.build-golang/tests/ - Golang starter package tests
    - packages/.build-terraform/tests/ - Terraform starter package tests
    - packages/.build-dotnet/tests/ - .NET starter package tests
    - packages/.build-typescript/tests/ - TypeScript starter package tests
    - packages/.build-python/tests/ - Python starter package tests

    This allows developers to run all tests with a single command while
    maintaining test decoupling for future starter package separation.

.PARAMETER Tag
    Run only tests with the specified tag(s). Available tags:
    - Core: Fast core orchestration tests (no external dependencies)
    - Security: Security validation tests (includes all security-related tests)
    - Bicep-Tasks: Bicep starter package tests (requires Bicep CLI)
    - Golang-Tasks: Golang starter package tests (requires Go CLI)
    - Terraform-Tasks: Terraform starter package tests (requires Terraform CLI or Docker)
    - DotNet-Tasks: .NET starter package tests (requires .NET SDK or Docker)
    - TypeScript-Tasks: TypeScript starter package tests (requires Node.js/npm or Docker)
    - Python-Tasks: Python starter package tests (requires Python 3.8+ or Docker)
    - SecurityLogging: Security event logging tests
    - SecurityTxt: RFC 9116 compliance tests
    - OutputValidation: Output sanitization tests
    - Variables: Variable system tests
    - Perf: Performance baseline tests
    - Release: Release packaging tests

.PARAMETER ExcludeTag
    Exclude tests with the specified tag(s). Same tag values as Tag parameter.

.PARAMETER Output
    Output verbosity level: None, Normal, Detailed, or Diagnostic.
    Default: Normal

.PARAMETER PassThru
    Return the Pester result object to the pipeline.

.EXAMPLE
    .\Invoke-Tests.ps1
    Runs all tests with normal output.

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Core
    Runs only core tests (fast, no Bicep CLI required).

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Bicep-Tasks -Output Detailed
    Runs only Bicep starter package tests with detailed output.

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Golang-Tasks
    Runs only Golang starter package tests (requires Go CLI).

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Terraform-Tasks
    Runs only Terraform starter package tests (requires Terraform CLI or Docker).

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag DotNet-Tasks
    Runs only .NET starter package tests (requires .NET SDK or Docker).

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag TypeScript-Tasks
    Runs only TypeScript starter package tests (requires Node.js/npm or Docker).

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Python-Tasks
    Runs only Python starter package tests (requires Python 3.8+ or Docker).

.EXAMPLE
    .\Invoke-Tests.ps1 -PassThru
    Runs all tests and returns the result object.

.NOTES
    This script is the recommended way to run tests locally and in CI.
    It ensures all tests (including those in starter packages) are discovered.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Core', 'Security', 'Bicep-Tasks', 'Golang-Tasks', 'Terraform-Tasks', 'DotNet-Tasks', 'TypeScript-Tasks', 'Python-Tasks', 'SecurityLogging', 'SecurityTxt', 'OutputValidation', 'Variables', 'Perf', 'Release')]
    [string[]]$Tag,

    [Parameter()]
    [ValidateSet('Core', 'Security', 'Bicep-Tasks', 'Golang-Tasks', 'Terraform-Tasks', 'DotNet-Tasks', 'TypeScript-Tasks', 'Python-Tasks', 'SecurityLogging', 'SecurityTxt', 'OutputValidation', 'Variables', 'Perf', 'Release')]
    [string[]]$ExcludeTag,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Normal',

    [Parameter()]
    [switch]$PassThru
)

# Configure Pester to discover tests in multiple locations
$config = New-PesterConfiguration

# Set test discovery paths
$config.Run.Path = @(
    'tests'                            # Core Bolt tests
    'packages/.build-bicep/tests'      # Bicep starter package tests
    'packages/.build-golang/tests'     # Golang starter package tests
    'packages/.build-terraform/tests'  # Terraform starter package tests
    'packages/.build-dotnet/tests'     # .NET starter package tests
    'packages/.build-typescript/tests' # TypeScript starter package tests
    'packages/.build-python/tests'     # Python starter package tests
)

# Apply tag filters if specified
if ($Tag) {
    $config.Filter.Tag = $Tag
}

if ($ExcludeTag) {
    $config.Filter.ExcludeTag = $ExcludeTag
}

# Set output verbosity
$config.Output.Verbosity = $Output

# Always enable PassThru to capture results for summary
$config.Run.PassThru = $true

# Run tests
Write-Host "Discovering tests in:" -ForegroundColor Cyan
Write-Host "  - tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-bicep/tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-golang/tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-terraform/tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-dotnet/tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-typescript/tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-python/tests/" -ForegroundColor Gray
Write-Host ""

$result = Invoke-Pester -Configuration $config

# Display custom summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Overall stats
$totalTests = $result.TotalCount
$passedTests = $result.PassedCount
$failedTests = $result.FailedCount
$skippedTests = $result.SkippedCount

Write-Host "Total:   $totalTests tests" -ForegroundColor Gray
Write-Host "Passed:  $passedTests tests" -ForegroundColor Green
if ($skippedTests -gt 0) {
    Write-Host "Skipped: $skippedTests tests" -ForegroundColor Yellow
}
if ($failedTests -gt 0) {
    Write-Host "Failed:  $failedTests tests" -ForegroundColor Red
}

# Show skipped test details if any
if ($skippedTests -gt 0) {
    Write-Host ""
    Write-Host "───────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "Skipped Tests" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host ""

    $skipCount = 1
    foreach ($test in $result.Skipped) {
        Write-Host "[$skipCount] " -ForegroundColor Yellow -NoNewline
        Write-Host $test.ExpandedName -ForegroundColor White

        # Show tags if available
        if ($test.Tag -and $test.Tag.Count -gt 0) {
            Write-Host "    Tags: " -ForegroundColor Cyan -NoNewline
            Write-Host ($test.Tag -join ', ') -ForegroundColor Gray
        }

        # Show location
        if ($test.ScriptBlock.File) {
            $relativePath = [System.IO.Path]::GetRelativePath((Get-Location), $test.ScriptBlock.File)
            Write-Host "    Location: $relativePath" -ForegroundColor Gray -NoNewline
            if ($test.ScriptBlock.StartPosition.StartLine) {
                Write-Host ":$($test.ScriptBlock.StartPosition.StartLine)" -ForegroundColor Gray
            } else {
                Write-Host ""
            }
        }

        # Show skip reason if available
        if ($test.ErrorRecord.Exception.Message) {
            $skipReason = $test.ErrorRecord.Exception.Message
            Write-Host "    Reason: " -ForegroundColor Yellow -NoNewline
            Write-Host $skipReason -ForegroundColor Gray
        }

        Write-Host ""
        $skipCount++
    }
}

# Show failed test details if any
if ($failedTests -gt 0) {
    Write-Host ""
    Write-Host "───────────────────────────────────────────────────────────────────" -ForegroundColor Red
    Write-Host "Failed Tests" -ForegroundColor Red
    Write-Host "───────────────────────────────────────────────────────────────────" -ForegroundColor Red
    Write-Host ""

    $failureCount = 1
    foreach ($test in $result.Failed) {
        Write-Host "[$failureCount] " -ForegroundColor Red -NoNewline
        Write-Host $test.ExpandedName -ForegroundColor White

        # Show tags if available
        if ($test.Tag -and $test.Tag.Count -gt 0) {
            Write-Host "    Tags: " -ForegroundColor Cyan -NoNewline
            Write-Host ($test.Tag -join ', ') -ForegroundColor Gray
        }

        # Show location
        if ($test.ScriptBlock.File) {
            $relativePath = [System.IO.Path]::GetRelativePath((Get-Location), $test.ScriptBlock.File)
            Write-Host "    Location: $relativePath" -ForegroundColor Gray -NoNewline
            if ($test.ScriptBlock.StartPosition.StartLine) {
                Write-Host ":$($test.ScriptBlock.StartPosition.StartLine)" -ForegroundColor Gray
            } else {
                Write-Host ""
            }
        }

        # Show error message
        if ($test.ErrorRecord) {
            $errorMessage = $test.ErrorRecord.Exception.Message
            # Truncate long error messages
            if ($errorMessage.Length -gt 200) {
                $errorMessage = $errorMessage.Substring(0, 200) + "..."
            }
            Write-Host "    Error: " -ForegroundColor Red -NoNewline
            Write-Host $errorMessage -ForegroundColor Gray
        }

        Write-Host ""
        $failureCount++
    }
}

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Return result if PassThru was requested
if ($PassThru) {
    return $result
}

# Exit with appropriate code
if ($failedTests -gt 0) {
    exit 1
} else {
    exit 0
}
