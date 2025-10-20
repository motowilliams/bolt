# Gosh! 🎉

[![CI](https://github.com/motowilliams/gosh/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/gosh/actions/workflows/ci.yml)

> **Go** + **powerShell** = **Gosh!**  
> Build orchestration for PowerShell

A self-contained, cross-platform PowerShell build system with extensible task orchestration and automatic dependency resolution. Inspired by Make and Rake, but pure PowerShell with no external dependencies—just PowerShell 7.0+.

**Perfect for Azure Bicep infrastructure projects**, but flexible enough for any PowerShell workflow. Runs on Windows, Linux, and macOS.

## ✨ Features

- **🔍 Automatic Task Discovery**: Drop `.ps1` files in `.build/` with comment-based metadata
- **🔗 Dependency Resolution**: Tasks declare dependencies via `# DEPENDS:` header
- **🚫 Circular Dependency Prevention**: Prevents infinite loops by tracking executed tasks
- **✅ Exit Code Propagation**: Proper CI/CD integration via `$LASTEXITCODE`
- **📋 Multiple Task Support**: Run tasks in sequence (space or comma-separated)
- **⏩ Skip Dependencies**: Use `-Only` flag for faster iteration
- **🎯 Tab Completion**: Task names auto-complete in PowerShell
- **🎨 Colorized Output**: Consistent, readable task output
- **🆕 Task Generator**: Create new task stubs with `-NewTask` parameter
- **📊 Task Outline**: Preview dependency trees with `-Outline` flag (no execution)
- **🌍 Cross-Platform**: Runs on Windows, Linux, and macOS with PowerShell Core

## 🚀 Quick Start

### Installation

1. Clone or download this repository
2. Ensure PowerShell 7.0+ is installed
3. Install Azure Bicep CLI: `winget install Microsoft.Bicep`
4. Navigate to the project directory

### First Run

```powershell
# List available tasks
.\gosh.ps1 -Help

# Output:
# Available tasks:
#   build      - Compiles Bicep files to ARM JSON templates
#   format     - Formats Bicep files using bicep format
#   lint       - Validates Bicep files using bicep lint
```

### Run Your First Build

```powershell
# Run the full build pipeline
.\gosh.ps1 build

# This executes: format → lint → build
```

### Common Commands

```powershell
# List available tasks
.\gosh.ps1 -Help

# Run a single task (with dependencies)
.\gosh.ps1 build

# Preview task execution plan without running
.\gosh.ps1 build -Outline

# Run multiple tasks in sequence
.\gosh.ps1 format lint build

# Skip dependencies for faster iteration
.\gosh.ps1 build -Only

# Preview what -Only would execute
.\gosh.ps1 build -Only -Outline

# Run multiple tasks without dependencies
.\gosh.ps1 format lint build -Only

# Create a new task
.\gosh.ps1 -NewTask deploy

# Use a custom task directory
.\gosh.ps1 -TaskDirectory "infra-tasks" -ListTasks
```

## 📁 Project Structure

```
.
├── gosh.ps1                    # Main orchestrator
├── .build/                     # User-customizable task templates
│   ├── Invoke-Build.ps1        # Build task template
│   ├── Invoke-Format.ps1       # Format task template
│   └── Invoke-Lint.ps1         # Lint task template
├── packages/                   # External task packages
│   └── .build-bicep/           # Bicep task implementation (separate package)
│       ├── Invoke-Build.ps1    # Compiles Bicep to ARM JSON
│       ├── Invoke-Format.ps1   # Formats Bicep files
│       ├── Invoke-Lint.ps1     # Validates Bicep syntax
│       └── tests/              # Bicep-specific tests
│           ├── Tasks.Tests.ps1 # Task validation tests (12 tests)
│           ├── Integration.Tests.ps1 # End-to-end tests (4 tests)
│           └── iac/            # Test infrastructure
├── tests/                      # Core Gosh tests
│   ├── fixtures/               # Mock tasks for testing
│   ├── gosh.Tests.ps1          # Core orchestration tests (28 tests)
│   ├── security/
│   │   └── Security.Tests.ps1  # Security validation tests (29 tests)
│   └── Invoke-Test.ps1         # Test helper
└── .github/
    └── copilot-instructions.md # AI agent guidance
```

### Example Infrastructure

The project includes a complete Azure infrastructure example:

- **App Service Plan**: Hosting environment with configurable SKU
- **Web App**: Azure App Service with managed identity
- **SQL Server**: Azure SQL Server with firewall rules
- **SQL Database**: Database with configurable DTU/storage

All modules are parameterized and support multiple environments (dev, staging, prod).

## 🛠️ Creating Tasks

### Task Directory Flexibility

By default, Gosh discovers tasks from the `.build/` directory. You can customize this location using the `-TaskDirectory` parameter:

```powershell
# Use a different directory for tasks
.\gosh.ps1 -TaskDirectory "custom-tasks" -ListTasks

# Execute tasks from custom directory
.\gosh.ps1 deploy -TaskDirectory "infra-tasks"

# Create new tasks in custom directory
.\gosh.ps1 -NewTask validate -TaskDirectory "validation-tasks"
```

This is useful for:
- **Organizing tasks by category** (build, deploy, test, etc.)
- **Separating concerns** (infrastructure vs. application tasks)
- **Testing task behavior** (using fixture directories)
- **Multi-project workflows** (different task sets per project)

### Quick Method

Use the built-in task generator to create a new task with proper structure:

```powershell
.\gosh.ps1 -NewTask deploy
# Creates: .build/Invoke-Deploy.ps1 with metadata template
```

This automatically creates a properly formatted task file with:
- Correct naming convention (`Invoke-TaskName.ps1`)
- Metadata headers (`TASK`, `DESCRIPTION`, `DEPENDS`)
- Parameter block
- Color-coded output statements
- TODO comments for implementation
- Proper exit codes

### Manual Method

Or create a PowerShell script in `.build/` manually with metadata:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploys infrastructure to Azure
# DEPENDS: build

Write-Host "Deploying..." -ForegroundColor Cyan
# Your deployment logic here
exit 0  # Explicit exit code required
```

**Task discovery is automatic**—no registration needed!

### Task Metadata

- `# TASK:` - Task name(s), comma-separated for aliases
- `# DESCRIPTION:` - Human-readable description
- `# DEPENDS:` - Dependency list, comma-separated

## 🎯 Built for Azure Bicep

While Gosh works with any PowerShell workflow, it's optimized for Azure Bicep infrastructure projects:

### Available Tasks

- **`format`**: Formats all Bicep files using `bicep format`
  - Runs in-place formatting on all `.bicep` files in `tests/iac/`
  - Reports which files were formatted
  
- **`lint`**: Validates Bicep syntax using `bicep lint`
  - Captures and displays errors and warnings with line numbers
  - Parses diagnostics in format: `path(line,col) : Level rule-name: message`
  - Fails if any errors are found
  
- **`build`**: Compiles Bicep to ARM JSON templates
  - Only compiles `main*.bicep` files (e.g., `main.bicep`, `main.dev.bicep`)
  - Module files in `tests/iac/modules/` are referenced, not compiled directly
  - Output `.json` files placed alongside source `.bicep` files
  - Depends on: `format`, `lint` (runs automatically)

### Usage Examples

```powershell
# Full pipeline: format → lint → build
.\gosh.ps1 build

# Preview execution plan before running
.\gosh.ps1 build -Outline

# Individual steps
.\gosh.ps1 format      # Format all files
.\gosh.ps1 lint        # Validate syntax
.\gosh.ps1 build -Only # Compile only (skip format/lint)

# Preview what -Only would do
.\gosh.ps1 build -Only -Outline
```

### Bicep CLI Integration

All tasks use the official Azure Bicep CLI:
- `bicep format` - Code formatting
- `bicep lint` - Syntax validation  
- `bicep build` - ARM template compilation

Install: `winget install Microsoft.Bicep` or https://aka.ms/bicep-install

## 📊 Task Visualization with `-Outline`

The `-Outline` flag displays the task dependency tree and execution order **without executing** any tasks:

```powershell
# Preview build task dependencies
.\gosh.ps1 build -Outline

# Output:
# Task execution plan for: build
#
# build (Compiles Bicep files to ARM JSON templates)
# ├── format (Formats Bicep files using bicep format)
# └── lint (Validates Bicep syntax and runs linter)
#
# Execution order:
#   1. format
#   2. lint
#   3. build
```

**Key Benefits:**
- **🔍 Debug dependencies** - Understand why certain tasks run
- **📋 Document workflows** - Show team members task relationships  
- **🎯 Plan execution** - Preview before running critical operations
- **⚡ Test `-Only` flag** - See what would execute with dependencies skipped

**Examples:**

```powershell
# Preview what -Only would do
.\gosh.ps1 build -Only -Outline
# Output: Execution order: 1. build (dependencies skipped)

# Preview multiple tasks
.\gosh.ps1 format lint build -Outline

# Preview with custom task directory
.\gosh.ps1 -TaskDirectory "infra-tasks" deploy -Outline
```

## 🏗️ Example Workflows

### Full Build Pipeline

```powershell
# Format, lint, and compile in one command
.\gosh.ps1 build

# Run with dependency chain: format → lint → build
```

### Development Iteration

```powershell
# Fix formatting issues
.\gosh.ps1 format

# Validate syntax
.\gosh.ps1 lint

# Compile without re-running format/lint
.\gosh.ps1 build -Only
```

### Multiple Tasks

```powershell
# Run tasks in sequence (space-separated)
.\gosh.ps1 format lint

# Or comma-separated
.\gosh.ps1 format,lint,build

# Skip all dependencies with -Only
.\gosh.ps1 format lint build -Only
```

### CI/CD Integration

```powershell
# Full validation and build
.\gosh.ps1 build
```

## 📖 Philosophy

### Local-First Principle (90/10 Rule)

Tasks should run **identically** locally and in CI pipelines:

- ✅ **Same commands**: `.\gosh.ps1 build` works the same everywhere
- ✅ **No special CI flags**: Avoid `if ($env:CI)` branches unless absolutely necessary
- ✅ **Consistent tooling**: Use same Bicep CLI version, same PowerShell modules
- ✅ **Deterministic behavior**: Tasks produce same results regardless of environment
- ✅ **Pipeline-agnostic**: Works with GitHub Actions, Azure DevOps, GitLab CI, etc.

### CI/CD Example

```yaml
# GitHub Actions
name: Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Infrastructure
        run: pwsh -File gosh.ps1 build
        
# Azure DevOps
steps:
  - task: PowerShell@2
    inputs:
      filePath: 'gosh.ps1'
      arguments: 'build'
      pwsh: true
```

## 🧪 Testing

The project includes comprehensive **Pester** tests to ensure correct behavior when refactoring or adding new features. Tests are organized for clarity with separate locations for core and module-specific tests.

### Test Structure

**Core Tests** (`tests/` directory):
- **`tests/gosh.Tests.ps1`** (28 tests) - Core orchestration tests
  - Script validation, task discovery, execution, dependency resolution
  - Uses mock fixtures from `tests/fixtures/` to test Gosh itself
  - Tag: `Core`

- **`tests/security/Security.Tests.ps1`** (29 tests) - Security validation tests
  - Input validation, path sanitization, injection prevention
  - Validates TaskDirectory, task names, and script paths
  - Tag: `Security`, `P0`

**Bicep Module Tests** (`packages/.build-bicep/tests/` directory):
- **`packages/.build-bicep/tests/Tasks.Tests.ps1`** (12 tests) - Task validation
  - Validates structure and metadata of Bicep tasks
  - Tag: `Bicep-Tasks`
  
- **`packages/.build-bicep/tests/Integration.Tests.ps1`** (4 tests) - Integration tests
  - Executes actual Bicep operations against real infrastructure files
  - Requires Bicep CLI to be installed
  - Tag: `Bicep-Tasks`

### Running Tests

```powershell
# Run all tests (auto-discovers test files)
Invoke-Pester                         # 73 tests total

# Run with detailed output
Invoke-Pester -Output Detailed

# Run specific test file
Invoke-Pester -Path tests/gosh.Tests.ps1
Invoke-Pester -Path packages/.build-bicep/tests/

# Run tests by tag
Invoke-Pester -Tag Core               # Core orchestration only (28 tests, ~1s)
Invoke-Pester -Tag Security           # Security validation only (29 tests, ~1s)
Invoke-Pester -Tag Bicep-Tasks        # Bicep tasks only (16 tests, ~22s)
```

### Test Tags

Tests are organized with tags for flexible execution:

- **`Core`** (28 tests) - Tests gosh.ps1 orchestration itself
  - Fast execution (~1 second)
  - No external tool dependencies
  - Uses mock fixtures from `tests/fixtures/`

- **`Security`** (29 tests) - Tests security validations
  - Fast execution (~1 second)
  - Validates input sanitization and injection prevention
  - Tests P0 security fixes for TaskDirectory, path sanitization, and task name validation
  
- **`Bicep-Tasks`** (16 tests) - Tests Bicep task implementation
  - Slower execution (~22 seconds)
  - Requires Bicep CLI for integration tests
  - Tests live with implementation in `packages/.build-bicep/tests/`
  - Validates task structure, metadata, and actual Bicep operations

**Common workflows:**
```powershell
# Quick validation during development
Invoke-Pester -Tag Core

# Security validation
Invoke-Pester -Tag Security

# Full task testing before commit
Invoke-Pester -Tag Bicep-Tasks

# Complete test suite
Invoke-Pester
```

### Test Coverage

**Core Orchestration** (`tests/gosh.Tests.ps1` - 28 tests):
- Script validation and PowerShell version requirements
- Task listing with `-ListTasks` and `-Help` parameters
- Task discovery from `.build/` directory and test fixtures
- Filename fallback for tasks without metadata (handles Invoke-Verb-Noun.ps1 patterns)
- Task execution (single, multiple, with dependencies)
- Dependency resolution and `-Only` flag behavior
- New task creation with `-NewTask` parameter
- Error handling for invalid tasks
- Parameter validation (comma/space-separated)
- Documentation consistency

**Security Validation** (`tests/security/Security.Tests.ps1` - 29 tests):
- Path traversal protection (absolute paths, parent directory references)
- Command injection prevention (semicolons, pipes, backticks)
- PowerShell injection prevention (special characters, variables, command substitution)
- Input sanitization and validation
- Error handling security (secure failure modes)

**Bicep Tasks** (`packages/.build-bicep/tests/Tasks.Tests.ps1` - 12 tests):
- Format task: existence, syntax, metadata, aliases
- Lint task: existence, syntax, metadata, dependencies
- Build task: existence, syntax, metadata, dependencies

**Bicep Integration** (`packages/.build-bicep/tests/Integration.Tests.ps1` - 4 tests):
- Format Bicep files integration
- Lint Bicep files integration
- Build Bicep files integration
- Full build pipeline with dependencies

### Test Fixtures

Mock tasks in `tests/fixtures/` are used to test Gosh orchestration without external dependencies:

- `Invoke-MockSimple.ps1` - Simple task with no dependencies
- `Invoke-MockWithDep.ps1` - Task with single dependency
- `Invoke-MockComplex.ps1` - Task with multiple dependencies
- `Invoke-MockFail.ps1` - Task that intentionally fails

These fixtures enable testing with the `-TaskDirectory` parameter:

```powershell
# Tests explicitly specify the fixture directory
.\gosh.ps1 mock-simple -TaskDirectory 'tests/fixtures'

# This allows clean separation between production tasks and test mocks
```

The fixtures allow testing of:
- Dependency resolution chains
- Error handling
- Task execution order
- Gosh orchestration without relying on real project tasks

### Test Requirements

- **Pester 5.0+**: Install with `Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser`
- **Bicep CLI** (optional): Required only for integration tests, other tests run without it
- Tests run in isolated contexts with proper setup/teardown
- Test results output to `TestResults.xml` (NUnit format for CI/CD)

### CI/CD Integration

Use Pester directly in CI pipelines:

```yaml
# GitHub Actions
- name: Run Tests
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Output Detailed -CI
  shell: pwsh

# Run only fast core tests for quick PR validation
- name: Quick Validation
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Tag Core -Output Detailed -CI
  shell: pwsh
  
- name: Publish Test Results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: TestResults.xml
```

### Test Results

```
Tests Passed: 43
Tests Failed: 0
Skipped: 0
Total Time: ~27 seconds
```

## 🔧 Requirements

- **PowerShell 7.0+** (uses `#Requires -Version 7.0` and modern syntax)
- **Azure Bicep CLI** (for infrastructure tasks) - [Installation Guide](https://aka.ms/bicep-install)
- **Git** (for `check-index` task)

### Installation

```powershell
# Install Bicep CLI (Windows)
winget install Microsoft.Bicep

# Or via Azure CLI
az bicep install

# Verify installation
bicep --version
```

## 🎨 Output Formatting

All tasks use consistent color coding:

- **Cyan**: Task headers
- **Gray**: Progress/details
- **Green**: Success (✓)
- **Yellow**: Warnings (⚠)
- **Red**: Errors (✗)

## 🐛 Troubleshooting

### Task not found

```powershell
# Restart PowerShell to refresh tab completion
exit
# Then reopen and try again
```

### Bicep CLI not found

```powershell
# Install Bicep
winget install Microsoft.Bicep

# Verify installation
bicep --version
```

### Task fails silently

- Check that task script includes explicit `exit 0` or `exit 1`
- Verify `$LASTEXITCODE` is checked after external commands
- Use `-ErrorAction Stop` on PowerShell cmdlets that should fail the task

### Tab completion not working

- Ensure you're using PowerShell 7.0+ (not Windows PowerShell 5.1)
- Restart your PowerShell session after adding new tasks
- Check that task scripts have proper `# TASK:` metadata

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions welcome! This is a self-contained build system—keep it simple and dependency-free.

### Customizing for Your Project

1. **Keep `gosh.ps1`**: The orchestrator rarely needs modification
2. **Modify tasks in `.build/`**: Edit existing tasks or add new ones
3. **Update infrastructure in `tests/iac/`**: Replace with your own Bicep modules
4. **Adjust parameters**: Edit `*.parameters.json` files for your environment

### Adding a New Task

Create a new file in `.build/` with the task metadata pattern:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy, publish
# DESCRIPTION: Deploy infrastructure to Azure
# DEPENDS: build

param(
    [string]$Environment = "dev"
)

Write-Host "Deploying to $Environment..." -ForegroundColor Cyan

# Your deployment logic here
az deployment group create --resource-group "rg-$Environment" --template-file "tests/iac/main.json"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Deployment succeeded" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Deployment failed" -ForegroundColor Red
    exit 1
}
```

Task is automatically discovered—no registration needed! Restart your shell to get tab completion.

### Guidelines

- Use explicit exit codes: `exit 0` (success) or `exit 1` (failure)
- Follow color conventions: Cyan (headers), Gray (progress), Green (success), Yellow (warnings), Red (errors)
- Add metadata comments: `# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`
- Only include `param()` if your task accepts parameters

## 🔄 Continuous Integration

Gosh includes a GitHub Actions workflow that runs on Ubuntu and Windows:

- **Triggers**: Pull requests to `main`, push to `main` branch, manual dispatch
- **Platforms**: Ubuntu (Linux) and Windows
- **Pipeline**: Core tests → Tasks tests → Full build (format → lint → build)
- **Dependencies**: Automatically installs PowerShell 7.0+ and Bicep CLI
- **Test Reports**: NUnit XML artifacts uploaded for each platform
- **Status**: [![CI](https://github.com/motowilliams/gosh/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/gosh/actions/workflows/ci.yml)

See `.github/workflows/ci.yml` for the complete workflow configuration.

### Running CI Locally

The CI pipeline runs the same commands you use locally:

```powershell
# Install dependencies
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run tests (same as CI)
Invoke-Pester -Tag Core    # Fast tests (~1s)
Invoke-Pester -Tag Tasks   # Bicep tests (~22s)
Invoke-Pester             # All tests

# Run build pipeline (same as CI)
.\gosh.ps1 build
```

This follows the **90/10 principle**: 90% of the workflow should be identical locally and in CI.

## �💡 Why "Gosh"?

**Go** (the entry point) + **powerShell** (PowerShell) = **Gosh!**

It's also a natural exclamation when your builds succeed! 🎉

### Design Goals

- **Zero external dependencies**: Just PowerShell 7.0+ and your tools (Bicep, Git, etc.)
- **Self-contained**: Single `gosh.ps1` file orchestrates everything
- **Convention over configuration**: Drop tasks in `.build/`, they're discovered automatically
- **Developer-friendly**: Tab completion, colorized output, helpful error messages
- **CI/CD ready**: Exit codes, deterministic behavior, no special flags

---

**Gosh, that was easy!** ✨
