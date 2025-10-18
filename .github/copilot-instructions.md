# Gosh! - AI Agent Instructions

> **Go** + **powerShell** = **Gosh!** 🎉

## Project Overview

This is **Gosh**, a self-contained PowerShell build system (`gosh.ps1`) designed for Azure Bicep infrastructure projects. It provides extensible task orchestration with automatic dependency resolution, similar to Make or Rake, but pure PowerShell with no external dependencies.

**Architecture Pattern**: Monolithic orchestrator (`gosh.ps1`) + modular task scripts (`.build/*.ps1`)

**Last Updated**: October 2025

### Current Project Status

The project is a **working example** that includes:
- ✅ Complete build orchestration system (`gosh.ps1`)
- ✅ Three project tasks: `format`, `lint`, `build`
- ✅ Pester test suite with comprehensive coverage (43 tests)
- ✅ Example Azure infrastructure (App Service + SQL)
- ✅ Multi-task execution with dependency resolution
- ✅ Tab completion and help system
- ✅ Parameterized task directory (`-TaskDirectory`)
- ✅ Test tags for fast/slow test separation
- ✅ MIT License
- ✅ Comprehensive documentation (README.md, IMPLEMENTATION.md, CONTRIBUTING.md)

**Ready to use**: The system is functional and can be adapted for any Azure Bicep project.

## Core Architecture

### Task System Design

Tasks are discovered via **comment-based metadata** in `.build/*.ps1` files (or custom directory via `-TaskDirectory` parameter):

```powershell
# TASK: build, compile          # Task names (comma-separated for aliases)
# DESCRIPTION: Compiles Bicep   # Human-readable description
# DEPENDS: format, lint          # Dependencies (executed automatically)
```

**Key architectural decisions:**
- **No task registration required** - tasks auto-discovered via filesystem scan
- **Parameterized task directory** - use `-TaskDirectory` to specify custom locations (default: `.build`)
- **Dependency resolution happens at runtime** - `Invoke-Task` recursively executes deps with circular dependency prevention via `$ExecutedTasks` hashtable
- **Exit codes propagate correctly** - `$LASTEXITCODE` checked after script execution, returns boolean for orchestration
- **Project tasks override core tasks** - allows customization without modifying `gosh.ps1`

### Task Discovery Flow

1. `Get-CoreTasks()` - returns hashtable of built-in tasks (check-index, check)
2. `Get-ProjectTasks($BuildPath)` - scans specified directory, parses metadata using regex on first 30 lines
3. `Get-AllTasks($TaskDirectory)` - merges both, project tasks win conflicts, uses `$TaskDirectory` parameter (default: `.build`)
4. Tab completion (`Register-ArgumentCompleter`) queries same discovery logic, respects `-TaskDirectory` from command line

## Critical Developer Workflows

### Building & Testing

```powershell
# Single task with dependencies
.\gosh.ps1 build              # Runs: format → lint → build

# Multiple tasks in sequence
.\gosh.ps1 lint format        # Runs: lint, then format
.\gosh.ps1 format,lint,build  # Comma-separated also works

# Skip dependencies (faster iteration)
.\gosh.ps1 build -Only        # Runs: build only (no format/lint)

# Multiple tasks without dependencies
.\gosh.ps1 format lint build -Only  # Runs all three, skipping build's deps

# Custom task directory
.\gosh.ps1 -TaskDirectory "infra-tasks" -ListTasks
.\gosh.ps1 deploy -TaskDirectory "deployment-tasks"

# Individual steps
.\gosh.ps1 format            # Format all .bicep files
.\gosh.ps1 lint              # Validate all .bicep files
```

**Important**: 
- Use `-Only` switch to skip dependencies for all tasks in the sequence
- Use `-TaskDirectory` to specify custom task locations (default: `.build`)
- Tasks execute in the order specified
- If any task fails, execution stops
- The `$ExecutedTasks` hashtable prevents duplicate task execution across the sequence

### Creating New Tasks

**Quick method** - Use the built-in task generator:

```powershell
.\gosh.ps1 -NewTask deploy
# Creates .build/Invoke-Deploy.ps1 with proper metadata structure

# Or in a custom directory:
.\gosh.ps1 -NewTask validate -TaskDirectory "quality-tasks"
# Creates quality-tasks/Invoke-Validate.ps1
```

**Manual method** - Add a script to `.build/` (or custom directory) with metadata header:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploys infrastructure to Azure
# DEPENDS: build

# Task implementation
Write-Host "Deploying..." -ForegroundColor Cyan
# ... your code ...
exit 0  # Explicit exit code required
```

**Task discovery is automatic** - no registration needed, restart shell for tab completion update.

## Project-Specific Conventions

### Cross-Platform Compatibility

**Gosh is designed to run on Windows, Linux, and macOS with PowerShell Core 7.0+**

Key cross-platform patterns:
- **Use `Join-Path` for all path construction** - never hardcode path separators (`/` or `\`)
- **Use `-Force` with `Get-ChildItem`** - ensures consistent behavior with hidden files/directories (e.g., `.build`)
- **Avoid platform-specific commands** - stick to PowerShell Core cmdlets that work everywhere
- **Test on multiple platforms** - especially when modifying task discovery or file operations

Example cross-platform path handling:
```powershell
# ✅ GOOD - Cross-platform
$iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "*.bicep" -Recurse -File -Force

# ❌ BAD - Windows-only
$bicepFiles = Get-ChildItem -Path "tests\iac" -Filter "*.bicep" -Recurse
```

### Bicep File Conventions

- **Only `main*.bicep` files are compiled** (e.g., `main.bicep`, `main.dev.bicep`) - see `Invoke-Build.ps1`
- **Module files in `tests/iac/modules/` are not compiled directly** - they're referenced by main files
- **Compiled `.json` files live alongside `.bicep` sources** - gitignored via pattern in `.gitignore`
- **Infrastructure is in `tests/iac/`** - example Bicep files used for testing build tasks

### Error Handling Pattern

All task scripts follow this pattern:

```powershell
$success = $true
foreach ($item in $items) {
    # Process item
    if ($LASTEXITCODE -ne 0) {
        $success = $false
    }
}

if (-not $success) {
    Write-Host "✗ Task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Task succeeded" -ForegroundColor Green
exit 0
```

**Critical**: Always use explicit `exit 0` or `exit 1` - gosh.ps1 checks `$LASTEXITCODE` for orchestration.

### Output Formatting Standards

All tasks use consistent color coding:
- **Cyan**: Task headers (`Write-Host "Building..." -ForegroundColor Cyan`)
- **Gray**: Progress/details (`Write-Host "  Processing: $file" -ForegroundColor Gray`)
- **Green**: Success (`✓` checkmark with green)
- **Yellow**: Warnings (`⚠` with yellow)
- **Red**: Errors (`✗` with red)

## Bicep-Specific Integration

### Bicep CLI Commands

The lint task uses `bicep lint` (not `bicep build --stdout`):

```powershell
# Correct pattern for capturing diagnostics
$output = & bicep lint $file.FullName 2>&1

# Parse bicep lint format: "path(line,col) : Level rule-name: message"
$diagnostics = $output | Where-Object { $_ -match '^\S+\(\d+,\d+\)\s*:\s*(Error|Warning)' }
```

**Why this matters**: `bicep lint` outputs to stdout (not stderr), and format differs from `bicep build`. The `&` call operator is required for proper output capture.

### Format Task Behavior

The format task formats Bicep files in-place:

**In-place formatting**: `.\gosh.ps1 format`
- Modifies files directly using `bicep format --outfile`
- Reports which files were formatted
- Always succeeds if bicep format runs without errors
- Use this for fixing formatting issues

**Implementation details**:
```powershell
# In-place mode: format directly
bicep format $file.FullName --outfile $file.FullName
```

## Integration Points

### Git Integration

Core task `check-index` verifies clean git state:
- Checks for uncommitted changes
- Used as dependency for release/deploy tasks
- Fails if `git` not in PATH or not in a repository

### Azure PowerShell Integration

Deployment tasks use **Azure PowerShell (Core)** modules:
```powershell
# Check for Az module availability
$azModule = Get-Module -ListAvailable -Name Az.* | Select-Object -First 1
if (-not $azModule) {
    Write-Error "Azure PowerShell modules not found. Please install: Install-Module -Name Az"
    exit 1
}
```

Install: `Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force`

### Azure Bicep CLI Dependency

All infrastructure tasks require `bicep` CLI:
```powershell
$bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
if (-not $bicepCmd) {
    Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install"
    exit 1
}
```

Install: `winget install Microsoft.Bicep` or https://aka.ms/bicep-install

## CI/CD Philosophy

**Local-First Principle (90/10 Rule)**: Tasks should run identically locally and in CI pipelines.

- **Same commands**: `.\gosh.ps1 build` works the same locally and in CI
- **No special CI flags**: Avoid `if ($env:CI)` branches unless absolutely necessary
- **Consistent tooling**: Use same Bicep CLI version, same PowerShell modules
- **Deterministic behavior**: Tasks produce same results regardless of environment

**Pipeline-agnostic design**: Tasks work with GitHub Actions, Azure DevOps, GitLab CI, etc.

```yaml
# Example CI job (any platform)
- name: Build
  run: pwsh -File gosh.ps1 build
  
- name: Test
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Output Detailed -CI
  shell: pwsh
```

## Known Limitations & Quirks

1. **PowerShell 7.0+ required** - uses modern syntax features
   - `#Requires -Version 7.0` directive enforced
   - Uses `using namespace` syntax
   - Ternary operator `? :` in some expressions
   
2. **Tab completion requires shell restart** - after adding new tasks to `.build/`, restart PowerShell for completions to update
   - Task discovery happens at registration time
   - `Register-ArgumentCompleter` caches task list
   
3. **Variable naming in tasks** - avoid using `$Task` variable name in task scripts
   - Collides with gosh.ps1's `-Task` parameter in some contexts
   - Use descriptive names like `$currentTask`, `$taskName`, etc.

## Testing & Validation

### Pester Testing Framework

This project uses **Pester** for PowerShell testing. The test suite is organized into three separate files for clarity and separation of concerns:

**Test Structure**:
- **`tests/gosh.Tests.ps1`** (25 tests) - Core Gosh orchestration using mock fixtures
- **`tests/ProjectTasks.Tests.ps1`** (12 tests) - Project-specific Bicep task validation
- **`tests/Integration.Tests.ps1`** (4 tests) - End-to-end Bicep integration tests
- **`tests/fixtures/`** - Mock tasks for testing Gosh orchestration without external dependencies

**Running tests**:
```powershell
Invoke-Pester                      # Run all tests (auto-discovers *.Tests.ps1)
Invoke-Pester -Output Detailed     # With detailed output
Invoke-Pester -Path tests/gosh.Tests.ps1  # Run specific test file

# Use tags for targeted testing
Invoke-Pester -Tag Core            # Only core orchestration tests (27 tests, ~1s)
Invoke-Pester -Tag Tasks           # Only task validation tests (16 tests, ~22s)
```

**Test Tags**:
- **`Core`** (27 tests) - Tests gosh.ps1 orchestration, fast, no external dependencies
- **`Tasks`** (16 tests) - Tests project task scripts, slower, requires Bicep CLI

**Test Coverage**:

1. **Core Orchestration Tests** (`tests/gosh.Tests.ps1`):
   - Script validation (syntax, PowerShell version)
   - Task listing (`-ListTasks`, `-Help`)
   - Task discovery from `.build/` and test fixtures
   - Task execution (single, multiple, with dependencies)
   - Dependency resolution and `-Only` flag
   - New task creation (`-NewTask`)
   - Error handling for invalid tasks
   - Parameter validation (comma/space-separated)
   - Documentation consistency
   - **Uses `-TaskDirectory 'tests/fixtures'` to test with mock tasks**

2. **Project Task Tests** (`tests/ProjectTasks.Tests.ps1`):
   - Format task: structure, metadata, aliases
   - Lint task: structure, metadata, dependencies
   - Build task: structure, metadata, dependency chain

3. **Integration Tests** (`tests/Integration.Tests.ps1`):
   - Format Bicep files (requires Bicep CLI)
   - Lint Bicep files (requires Bicep CLI)
   - Build Bicep files (requires Bicep CLI)
   - Full build pipeline with dependencies

4. **Test Fixtures** (`tests/fixtures/`):
   - `Invoke-MockSimple.ps1` - No dependencies
   - `Invoke-MockWithDep.ps1` - Single dependency
   - `Invoke-MockComplex.ps1` - Multiple dependencies
   - `Invoke-MockFail.ps1` - Intentional failure

**Test Architecture Pattern:**
```powershell
# Tests use -TaskDirectory parameter to reference fixtures directly
$result = Invoke-Gosh -Arguments @('mock-simple') `
                      -Parameters @{ TaskDirectory = 'tests/fixtures'; Only = $true }

# This achieves clean separation:
# - No test-specific code in gosh.ps1
# - Tests explicitly declare fixture location
# - No file copying or temporary directories needed
```

**Test Results**:
```
Tests Passed: 43
Tests Failed: 0
Skipped: 0
Total Time: ~27 seconds
```

### Validation Strategy

- **Exit codes**: CI/CD integration via `$LASTEXITCODE` (0=success, 1=failure)
- **Pester tests**: Comprehensive unit and integration tests for all functionality
- **NUnit XML output**: `TestResults.xml` for CI/CD pipeline integration
- **Bicep validation**: lint task catches syntax errors
- **Local-first principle**: Tasks run identically locally and in CI (90/10 rule)
- **Direct testing**: Use `Invoke-Pester` to test the Gosh orchestrator itself

## VS Code Integration

### Tasks Integration

Pre-configured VS Code tasks in `.vscode/tasks.json`:

**Build Tasks:**
```json
{
  "label": "Gosh: Build",       // Default build task (Ctrl+Shift+B)
  "label": "Gosh: Format",      // Format Bicep files
  "label": "Gosh: Lint",        // Validate Bicep files
  "label": "Gosh: List Tasks"   // Show available tasks
}
```

**Test Tasks:**
```json
{
  "label": "Test: All",         // Default test task (Ctrl+Shift+P → Run Test Task)
  "label": "Test: Core (Fast)", // Only core orchestration tests (~1s)
  "label": "Test: Tasks"        // Only task validation tests (~22s)
}
```

**Usage**: 
- Press `Ctrl+Shift+B` to run the default build task
- Press `Ctrl+Shift+P` → "Tasks: Run Task" to select any task
- Press `Ctrl+Shift+P` → "Tasks: Run Test Task" to select test tasks

**Adding new tasks**: When creating tasks in `.build/`, add corresponding VS Code tasks for IDE integration:

```json
{
  "label": "Gosh: YourTask",
  "type": "shell",
  "command": "pwsh",
  "args": ["-File", "${workspaceFolder}/gosh.ps1", "yourtask"]
}
```

### EditorConfig

The project uses `.editorconfig` for consistent code formatting:

- **PowerShell (*.ps1)**: 4 spaces indentation
- **Bicep (*.bicep)**: 2 spaces indentation  
- **JSON (*.json)**: 2 spaces indentation
- **UTF-8 encoding**, LF line endings, trim trailing whitespace

**Applies automatically** with EditorConfig-compatible editors (VS Code, Visual Studio, etc.)

## Quick Reference

```powershell
# Common tasks
.\gosh.ps1 -ListTasks              # List all available tasks
.\gosh.ps1 -Help                   # Same as -ListTasks
.\gosh.ps1 build                   # Full pipeline (format → lint → build)
.\gosh.ps1 build -Only             # Build only (skip format/lint)
.\gosh.ps1 format lint             # Multiple tasks (space-separated)
.\gosh.ps1 format,lint             # Multiple tasks (comma-separated)
.\gosh.ps1 format lint build -Only # Multiple tasks without deps

# Testing with Pester
Invoke-Pester                      # Run all tests (43 tests, ~27s)
Invoke-Pester -Tag Core            # Only orchestration tests (27 tests, ~1s)
Invoke-Pester -Tag Tasks           # Only task tests (16 tests, ~22s)
Invoke-Pester -Output Detailed     # With detailed output

# Creating new tasks
.\gosh.ps1 -NewTask deploy         # Create new task file in .build/
.\gosh.ps1 -NewTask validate -TaskDirectory "custom" # Create in custom dir

# Task discovery
Get-ChildItem .build               # See all project tasks
Select-String "# TASK:" .build/*.ps1  # See task names

# VS Code shortcuts
Ctrl+Shift+B                       # Run default build task
Ctrl+Shift+P > Tasks: Run Task     # Select any task
Ctrl+Shift+P > Tasks: Run Test Task # Select test task
```

## Related Files

### Documentation
- `README.md` - Project overview and quick start guide
- `IMPLEMENTATION.md` - Feature documentation and examples
- `CONTRIBUTING.md` - Contribution guidelines and task development patterns
- `CHANGELOG.md` - Version history and release notes

### Source Code
- `gosh.ps1` - Main orchestrator (task discovery, dependency resolution, execution)
- `.build/Invoke-*.ps1` - Project task implementations (format, lint, build)

### Testing
- `tests/gosh.Tests.ps1` - Core Gosh orchestration tests (27 tests, uses mock fixtures, tag: `Core`)
- `tests/ProjectTasks.Tests.ps1` - Project-specific task validation tests (12 tests, tag: `Tasks`)
- `tests/Integration.Tests.ps1` - End-to-end Bicep integration tests (4 tests, tag: `Tasks`)
- `tests/fixtures/Invoke-Mock*.ps1` - Mock tasks for testing Gosh without external dependencies

### Infrastructure
- `tests/iac/main.bicep` - Example infrastructure template for testing
- `tests/iac/modules/*.bicep` - Example infrastructure modules (App Service, SQL)
- `tests/iac/*.parameters.json` - Example parameter files

### Configuration
- `.vscode/tasks.json` - VS Code task definitions
- `.editorconfig` - Editor formatting rules
- `.vscode/extensions.json` - Recommended VS Code extensions
- `.vscode/settings.json` - Workspace settings
