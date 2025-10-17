# PowerShell Build System - AI Agent Instructions

## Project Overview

This is a **self-contained PowerShell build system** (`go.ps1`) designed for Azure Bicep infrastructure projects. It provides extensible task orchestration with automatic dependency resolution, similar to Make or Rake, but pure PowerShell with no external dependencies.

**Architecture Pattern**: Monolithic orchestrator (`go.ps1`) + modular task scripts (`.build/*.ps1`)

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
- **Project tasks override core tasks** - allows customization without modifying `go.ps1`

### Task Discovery Flow

1. `Get-CoreTasks()` - returns hashtable of built-in tasks (check-index, check)
2. `Get-ProjectTasks()` - scans `.build/*.ps1`, parses metadata using regex on first 30 lines
3. `Get-AllTasks()` - merges both, project tasks win conflicts
4. Tab completion (`Register-ArgumentCompleter`) queries same discovery logic

## Critical Developer Workflows

### Building & Testing

```powershell
# Full pipeline with dependencies
.\go.ps1 build              # Runs: format → lint → build

# Skip dependencies (faster iteration)
.\go.ps1 build -Only        # Runs: build only (no format/lint)

# Individual steps
.\go.ps1 format            # Format all .bicep files
.\go.ps1 lint              # Validate all .bicep files
```

**Important**: Use `-Only` switch (not `-NoDeps`) to skip dependencies - recently renamed for clarity.

### Creating New Tasks

Add a script to `.build/` with metadata header:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploys infrastructure to Azure
# DEPENDS: build

param()  # Always include param() even if empty

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

**Critical**: Always use explicit `exit 0` or `exit 1` - go.ps1 checks `$LASTEXITCODE` for orchestration.

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

- `.\go.ps1 format` - formats in-place (modifies files)
- `.\go.ps1 format -Check` - validates only (planned feature, not yet implemented in go.ps1 parameter forwarding)

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

- **Same commands**: `.\go.ps1 build` works the same locally and in CI
- **No special CI flags**: Avoid `if ($env:CI)` branches unless absolutely necessary
- **Consistent tooling**: Use same Bicep CLI version, same PowerShell modules
- **Deterministic behavior**: Tasks produce same results regardless of environment

**Pipeline-agnostic design**: Tasks work with GitHub Actions, Azure DevOps, GitLab CI, etc.

```yaml
# Example CI job (any platform)
- name: Build
  run: pwsh -File go.ps1 build
  
- name: Test
  run: pwsh -File go.ps1 test
```

## Known Limitations & Quirks

1. **`-ListTasks` flag shows header but no tasks** - hashtable iteration issue, but tasks execute correctly when called directly
2. **No parameter forwarding yet** - `.\go.ps1 format -Check` doesn't pass `-Check` to task script (planned enhancement)
3. **PowerShell 7.0+ required** - uses `#Requires -Version 7.0` and `using namespace` syntax
4. **Tab completion requires shell restart** - after adding new tasks, restart PowerShell for completions to update

## Testing & Validation

### Pester Testing Framework

This project uses **Pester** for PowerShell testing. Test files follow the pattern `*.Tests.ps1`:

```powershell
# Example: .build/Invoke-Build.Tests.ps1
Describe "Build Task" {
    It "Should find main.bicep files" {
        $files = Get-ChildItem -Path "iac" -Filter "main*.bicep" -File
        $files.Count | Should -BeGreaterThan 0
    }
}
```

**Running tests**:
```powershell
.\go.ps1 test              # Run all Pester tests (task to be created)
Invoke-Pester              # Direct Pester invocation
```

**Creating a test task** (`.build/Invoke-Test.ps1`):
```powershell
# TASK: test
# DESCRIPTION: Run Pester tests

param()

$config = New-PesterConfiguration
$config.Run.Path = @('.')
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config

exit ($result.FailedCount -eq 0 ? 0 : 1)
```

### Validation Strategy

- **Exit codes**: CI/CD integration via `$LASTEXITCODE` (0=success, 1=failure)
- **Pester tests**: Unit tests for task logic and validation
- **Bicep validation**: lint task catches syntax errors
- **Local-first principle**: Tasks run identically locally and in CI (90/10 rule)

## Quick Reference

```powershell
# Common tasks
.\go.ps1 -ListTasks         # List all available tasks
.\go.ps1 build              # Full pipeline
.\go.ps1 build -Only        # Build only (skip format/lint)
.\go.ps1 format             # Format all bicep files
.\go.ps1 lint               # Validate all bicep files

# Task discovery
Get-ChildItem .build        # See all project tasks
Select-String "# TASK:" .build/*.ps1  # See task names
```

## Related Files

- `IMPLEMENTATION.md` - Feature documentation and examples
- `.build/Invoke-*.ps1` - Project task implementations
- `iac/main.bicep` - Main infrastructure template
- `iac/modules/*.bicep` - Reusable infrastructure modules
