# Gosh! - AI Agent Instructions

> **Go** + **powerShell** = **Gosh!** 🎉

## Project Overview

This is **Gosh**, a self-contained PowerShell build system (`gosh.ps1`) designed for Azure Bicep infrastructure projects. It provides extensible task orchestration with automatic dependency resolution, similar to Make or Rake, but pure PowerShell with no external dependencies.

**Architecture Pattern**: Monolithic orchestrator (`gosh.ps1`) + modular task scripts (`.build/*.ps1`)

**Last Updated**: October 2025

### Current Project Status

The project is a **working example** that includes:
- ✅ Complete build orchestration system (`gosh.ps1`)
- ✅ Four core tasks: `format`, `lint`, `build`, `test`
- ✅ Pester test suite with comprehensive coverage
- ✅ Example Azure infrastructure (App Service + SQL)
- ✅ Multi-task execution with dependency resolution
- ✅ Tab completion and help system
- ✅ MIT License
- ✅ Comprehensive documentation (README.md, IMPLEMENTATION.md, copilot-instructions.md)

**Ready to use**: The system is functional and can be adapted for any Azure Bicep project.

## Core Architecture

### Task System Design

Tasks are discovered via **comment-based metadata** in `.build/*.ps1` files:

```powershell
# TASK: build, compile          # Task names (comma-separated for aliases)
# DESCRIPTION: Compiles Bicep   # Human-readable description
# DEPENDS: format, lint          # Dependencies (executed automatically)
```

**Key architectural decisions:**
- **No task registration required** - tasks auto-discovered via filesystem scan
- **Dependency resolution happens at runtime** - `Invoke-Task` recursively executes deps with circular dependency prevention via `$ExecutedTasks` hashtable
- **Exit codes propagate correctly** - `$LASTEXITCODE` checked after script execution, returns boolean for orchestration
- **Project tasks override core tasks** - allows customization without modifying `gosh.ps1`

### Task Discovery Flow

1. `Get-CoreTasks()` - returns hashtable of built-in tasks (check-index, check)
2. `Get-ProjectTasks()` - scans `.build/*.ps1`, parses metadata using regex on first 30 lines
3. `Get-AllTasks()` - merges both, project tasks win conflicts
4. Tab completion (`Register-ArgumentCompleter`) queries same discovery logic

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

# Individual steps
.\gosh.ps1 format            # Format all .bicep files
.\gosh.ps1 lint              # Validate all .bicep files
```

**Important**: 
- Use `-Only` switch to skip dependencies for all tasks in the sequence
- Tasks execute in the order specified
- If any task fails, execution stops
- The `$ExecutedTasks` hashtable prevents duplicate task execution across the sequence

### Creating New Tasks

**Quick method** - Use the built-in task generator:

```powershell
.\gosh.ps1 -NewTask deploy
# Creates .build/Invoke-Deploy.ps1 with proper metadata structure
```

**Manual method** - Add a script to `.build/` with metadata header:

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

### Bicep File Conventions

- **Only `main*.bicep` files are compiled** (e.g., `main.bicep`, `main.dev.bicep`) - see `Invoke-Build.ps1`
- **Module files in `iac/modules/` are not compiled directly** - they're referenced by main files
- **Compiled `.json` files live alongside `.bicep` sources** - gitignored via `iac/.gitignore`

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
    Invoke-Pester -Path ./tests/gosh.Tests.ps1 -Output Detailed -CI
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

This project uses **Pester** for PowerShell testing. The comprehensive test suite (`tests/gosh.Tests.ps1`) includes 24 tests covering all major functionality.

**Running tests**:
```powershell
Invoke-Pester                      # Run all tests
Invoke-Pester -Output Detailed     # With detailed output
```

**Test Coverage** (`tests/gosh.Tests.ps1` - 419 lines):
- **Script Validation**: Verifies `gosh.ps1` syntax, PowerShell version requirements
- **Task Listing**: Tests `-ListTasks` and `-Help` parameters
- **Task Discovery**: Validates automatic discovery from `.build/` and `tests/` directories
- **Task Execution**: Single tasks, multiple tasks, comma/space-separated lists
- **Dependency Resolution**: Tests `-Only` flag and automatic dependency execution
- **New Task Creation**: Validates `-NewTask` parameter functionality
- **Error Handling**: Ensures proper error messages for invalid tasks
- **Integration Tests**: Tests Bicep CLI integration (format, lint, build)
- **Parameter Validation**: Tests various task argument formats
- **Documentation Consistency**: Validates README and help text

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

```json
// Available tasks (Ctrl+Shift+B for default build)
{
  "label": "Gosh: Build",      // Default build task (Ctrl+Shift+B)
  "label": "Gosh: Format",     // Format Bicep files
  "label": "Gosh: Lint",       // Validate Bicep files
  "label": "Gosh: List Tasks"  // Show available tasks
}
```

**Usage**: Press `Ctrl+Shift+B` to run the default build task, or `Ctrl+Shift+P` → "Tasks: Run Task" to select any task.

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
.\gosh.ps1 build                   # Full pipeline
.\gosh.ps1 build -Only             # Build only (skip format/lint)
.\gosh.ps1 test                    # Run Pester test suite
.\gosh.ps1 format lint             # Multiple tasks (space-separated)
.\gosh.ps1 format,lint             # Multiple tasks (comma-separated)
.\gosh.ps1 format lint build -Only # Multiple tasks without deps

# Testing
Invoke-Pester                      # Run all tests
Invoke-Pester -Output Detailed     # With detailed output

# Creating new tasks
.\gosh.ps1 -NewTask deploy         # Create new task file

# Task discovery
Get-ChildItem .build               # See all project tasks
Select-String "# TASK:" .build/*.ps1  # See task names

# VS Code shortcuts
Ctrl+Shift+B                       # Run default build task
Ctrl+Shift+P > Tasks: Run Task     # Select any task
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
- `tests/gosh.Tests.ps1` - Comprehensive Pester test suite (24 tests, 419 lines)
- `tests/Invoke-Test.ps1` - Test runner task with auto-install

### Infrastructure
- `iac/main.bicep` - Main infrastructure template
- `iac/modules/*.bicep` - Reusable infrastructure modules (App Service, SQL)
- `iac/*.parameters.json` - Environment-specific parameter files

### Configuration
- `.vscode/tasks.json` - VS Code task definitions
- `.editorconfig` - Editor formatting rules
- `.vscode/extensions.json` - Recommended VS Code extensions
- `.vscode/settings.json` - Workspace settings
