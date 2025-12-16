# CI Workflow Documentation

This document explains the Continuous Integration (CI) workflow for Bolt, a PowerShell build orchestration system.

## Overview

The CI pipeline validates code quality, runs tests across multiple platforms, and verifies build artifacts. It's designed to catch issues early and ensure cross-platform compatibility.

## Triggers

The CI workflow runs automatically on:

- **All branch pushes** - Every commit to any branch triggers a build
- **Pull requests to `main`** - PRs targeting the main branch run CI checks
- **Manual dispatch** - Can be triggered manually via GitHub Actions UI (`workflow_dispatch`)

### Branch Protection

When a PR is open, GitHub automatically prevents duplicate builds:
- Push builds run on all branches (including feature branches)
- PR builds run only when targeting `main`
- Only one build runs per push when both conditions apply

## Platform Strategy

The workflow uses a **matrix strategy** to test on multiple platforms:

- **Ubuntu (Linux)** - `ubuntu-latest`
- **Windows** - `windows-latest`

**Fail-fast**: Disabled - all platforms complete testing even if one fails, providing complete coverage results.

## Workflow Steps

### 1. Setup and Preparation

#### Checkout Code
```yaml
- uses: actions/checkout@v4
```
Retrieves the repository code at the commit being tested.

#### PowerShell Version Check
```powershell
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "OS: $($PSVersionTable.OS)"
```
Displays environment information for debugging. Bolt requires PowerShell 7.0+.

### 2. Dependency Installation

#### PowerShell Modules Cache
Caches Pester modules to speed up builds:
- **Linux**: `~/.local/share/powershell/Modules`
- **Windows**: `~/Documents/PowerShell/Modules`
- **Cache key**: Based on OS + `ci.yml` hash

#### Pester Installation
```powershell
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
```
Installs the Pester testing framework (v5.0+) if not cached.

#### Bicep CLI Cache
Platform-specific caching for Bicep CLI:
- **Linux**: `~/.azure/bin`
- **Windows**: `C:\Program Files\Bicep CLI`

**Note**: Bicep is only required for testing the Bicep starter package (`packages/.build-bicep`), not for Bolt's core orchestration.

#### Bicep CLI Installation

**Ubuntu (Linux)**:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```
Installs Azure CLI (which includes Bicep CLI).

**Windows**:
```powershell
winget install Microsoft.Bicep --silent
```
Installs Bicep CLI via Windows Package Manager.

### 3. Test Execution

Tests run in stages with different dependencies:

#### Stage 1: Core Tests (Fast)
```powershell
Invoke-Pester -Tag Core -Output Detailed
```
- **Duration**: ~1 second
- **Dependencies**: None (no Bicep required)
- **Coverage**: Bolt orchestration, task discovery, dependency resolution
- **Files**: `tests/bolt.Tests.ps1`, `tests/security/*.Tests.ps1`

#### Stage 2: Bicep Tasks Tests
```powershell
Invoke-Pester -Tag Bicep-Tasks -Output Detailed
```
- **Duration**: ~22 seconds
- **Dependencies**: Requires Bicep CLI
- **Coverage**: Bicep starter package tasks (format, lint, build)
- **Files**: `packages/.build-bicep/tests/*.Tests.ps1`

#### Stage 3: Full Test Suite with Report
```powershell
$config = New-PesterConfiguration
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = 'TestResults-${{ matrix.os }}.xml'
Invoke-Pester -Configuration $config
```
- Runs all tests and generates NUnit XML report
- **Report location**: `TestResults-{os}.xml`
- **Exit code**: Non-zero if any tests fail

### 4. Test Results

#### Upload Test Artifacts
```yaml
- uses: actions/upload-artifact@v4
  if: always()
```
- **Artifact names**: `test-results-ubuntu-latest`, `test-results-windows-latest`
- **Retention**: 30 days
- **Always runs**: Even if tests fail, results are uploaded for analysis

### 5. Build Verification

#### Run Build Pipeline
```powershell
pwsh -File bolt.ps1 build
```
Executes the full build pipeline: `format → lint → build`

**What this does**:
- **Format**: Formats all `.bicep` files using Bicep CLI
- **Lint**: Validates `.bicep` files for errors/warnings
- **Build**: Compiles `.bicep` files to ARM JSON templates

**Exit behavior**: Pipeline exits with code 1 if any task fails.

#### Verify Build Artifacts
```powershell
Get-ChildItem -Path packages/.build-bicep/tests/iac -Filter "*.json" -Recurse
```
- Checks that compiled ARM templates (`.json` files) were created
- Lists all generated templates for verification
- Fails if no `.json` files found (indicates build failure)

### 6. Manifest Generation Tests

#### Test Module Creation
```powershell
pwsh -File infra/New-BoltModule.ps1 -Install -NoImport -ModuleOutputPath ".\test-module"
```
Creates a test module for manifest generation validation.

#### Test Manifest Generation
```powershell
pwsh -File infra/generate-manifest.ps1 -ModulePath "test-module/Bolt/Bolt.psm1" -ModuleVersion "0.0.1"
```
Tests the PowerShell manifest generator script.

#### Validate Manifest
```powershell
Test-ModuleManifest -Path $manifestPath
```
Verifies the generated `.psd1` manifest is valid PowerShell.

## Exit Codes and Failure Handling

- **0**: Success - all tests passed, build completed
- **1**: Failure - tests failed, build failed, or artifacts missing

**Behavior on failure**:
- Workflow immediately exits with error
- Test results still uploaded (due to `if: always()`)
- Build status badge shows failure
- GitHub prevents PR merge (if branch protection enabled)

## Test Organization

### Test Tags

Tests use tags for targeted execution:
- **`Core`** - Fast tests (~1s), no external dependencies
- **`Bicep-Tasks`** - Slower tests (~22s), requires Bicep CLI
- **`Security`** - Security validation tests

### Test Files

| Location | Purpose | Dependencies |
|----------|---------|--------------|
| `tests/bolt.Tests.ps1` | Core Bolt orchestration | None |
| `tests/security/*.Tests.ps1` | Security validation | None |
| `packages/.build-bicep/tests/Tasks.Tests.ps1` | Bicep task validation | Bicep CLI |
| `packages/.build-bicep/tests/Integration.Tests.ps1` | End-to-end integration | Bicep CLI |
| `tests/fixtures/*.ps1` | Mock tasks for testing | None |

## Build Artifacts

### Generated Files

After a successful build, the following artifacts are created:

- **ARM Templates**: `packages/.build-bicep/tests/iac/*.json`
  - Compiled from `.bicep` source files
  - Used for Azure infrastructure deployment
  - Gitignored (not committed)

- **Test Reports**: `TestResults-{os}.xml`
  - NUnit format XML
  - Uploaded as GitHub Actions artifacts
  - 30-day retention

### Artifact Locations

```
bolt/
├── packages/.build-bicep/tests/iac/
│   ├── main.json              # Compiled from main.bicep
│   └── modules/*.json         # Compiled module templates
└── TestResults-*.xml          # Test reports
```

## Local Development Workflow

To run the same checks locally before pushing:

```powershell
# 1. Install dependencies
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
winget install Microsoft.Bicep  # Windows
# or: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash  # Linux

# 2. Run fast core tests
Invoke-Pester -Tag Core -Output Detailed

# 3. Run Bicep tasks tests
Invoke-Pester -Tag Bicep-Tasks -Output Detailed

# 4. Run full test suite
Invoke-Pester -Output Detailed

# 5. Run build pipeline
.\bolt.ps1 build

# 6. Verify artifacts
Get-ChildItem packages/.build-bicep/tests/iac -Filter "*.json"
```

## Performance

**Typical build times** (approximate):

| Platform | Setup | Core Tests | Bicep Tests | Full Report | Build | Total |
|----------|-------|------------|-------------|-------------|-------|-------|
| Ubuntu   | ~2m   | ~1s        | ~22s        | ~25s        | ~15s  | ~3m   |
| Windows  | ~3m   | ~1s        | ~22s        | ~25s        | ~15s  | ~4m   |

**Caching benefits**:
- First run: Full installation time
- Subsequent runs: ~50% faster due to module/CLI caching

## Troubleshooting

### Common Issues

**Tests fail with "Pester module not found"**
- Cache may be corrupted
- Solution: Re-run workflow (will reinstall)

**Bicep tests fail with "Bicep CLI not found"**
- Installation step may have failed
- Check platform-specific installation logs
- Verify winget/curl commands succeeded

**Build pipeline fails but tests pass**
- Check for syntax errors in `.bicep` files
- Review `lint` task output for warnings
- Ensure all `.bicep` files are valid

**Artifacts not uploaded**
- Check that test step completed (even with failures)
- Verify `if: always()` condition on upload step
- Review artifact retention settings (30 days)

## Security Considerations

- **No secrets required** - Public repository, no deployment steps
- **Read-only operations** - CI only validates, doesn't modify repository
- **Artifact retention** - 30 days, contains no sensitive data
- **PowerShell execution** - Runs in isolated GitHub Actions runner

## Status Badge

Add this badge to `README.md`:

```markdown
[![CI](https://github.com/motowilliams/bolt/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/bolt/actions/workflows/ci.yml)
```

## Related Documentation

- [IMPLEMENTATION.md](../../IMPLEMENTATION.md) - Feature documentation and task system
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution guidelines and development workflow
- [README.md](../../README.md) - Project overview and quick start
- [tests/](../../tests/) - Test files and fixtures

## Maintenance

### Updating Dependencies

To update Pester or Bicep versions:
1. Modify version in installation steps
2. Update cache key in `ci.yml` (forces cache refresh)
3. Test locally before committing

### Adding New Test Tags

When adding new test categories:
1. Tag tests appropriately in `.Tests.ps1` files
2. Add new test stage in `ci.yml`
3. Update this documentation with timing/dependencies
4. Consider impact on total build time

### Platform Support

Current platforms: Ubuntu, Windows

To add macOS support:
1. Add `macos-latest` to matrix
2. Test Bicep CLI installation method for macOS
3. Update module cache paths
4. Verify all tests pass on new platform
