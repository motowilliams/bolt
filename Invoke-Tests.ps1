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
    
    This allows developers to run all tests with a single command while
    maintaining test decoupling for future starter package separation.

.PARAMETER Tag
    Run only tests with the specified tag(s). Available tags:
    - Core: Fast core orchestration tests (no external dependencies)
    - Security: Security validation tests (includes all security-related tests)
    - Bicep-Tasks: Bicep starter package tests (requires Bicep CLI)
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
    .\Invoke-Tests.ps1 -PassThru
    Runs all tests and returns the result object.

.NOTES
    This script is the recommended way to run tests locally and in CI.
    It ensures all tests (including those in starter packages) are discovered.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Core', 'Security', 'Bicep-Tasks', 'SecurityLogging', 'SecurityTxt', 'OutputValidation', 'Variables', 'Perf', 'Release')]
    [string[]]$Tag,

    [Parameter()]
    [ValidateSet('Core', 'Security', 'Bicep-Tasks', 'SecurityLogging', 'SecurityTxt', 'OutputValidation', 'Variables', 'Perf', 'Release')]
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
    'tests'                        # Core Bolt tests
    'packages/.build-bicep/tests'  # Bicep starter package tests
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

# Enable PassThru if requested
if ($PassThru) {
    $config.Run.PassThru = $true
}

# Run tests
Write-Host "Discovering tests in:" -ForegroundColor Cyan
Write-Host "  - tests/" -ForegroundColor Gray
Write-Host "  - packages/.build-bicep/tests/" -ForegroundColor Gray
Write-Host ""

$result = Invoke-Pester -Configuration $config

if ($PassThru) {
    return $result
}
