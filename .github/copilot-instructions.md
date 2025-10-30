# Gosh! - AI Agent Instructions

> **Go** + **powerShell** = **Gosh!** 🎉

## How to Use These Instructions

**⚠️ CRITICAL: Always Think Deeply and Ask Questions**

Before implementing any changes or answering requests:

1. **Think deeply about the problem** - Use your thinking process to:
   - Analyze the user's request thoroughly
   - Consider multiple approaches and their tradeoffs
   - Identify edge cases and potential issues
   - Evaluate impact on existing functionality
   - Plan the implementation strategy

2. **Ask clarifying questions when needed** - Don't make assumptions:
   - If requirements are ambiguous, ask for clarification
   - If multiple approaches exist, present options and ask for preference
   - If design decisions need to be made, discuss them with the user
   - If you're unsure about constraints, verify them

3. **Present your thinking** - Share your analysis before implementing:
   - Explain your understanding of the problem
   - Outline your proposed approach
   - Discuss alternatives you considered
   - Get user confirmation before proceeding with complex changes

**Example questions to ask:**
- "Should this feature work with `-Only` flag?"
- "Do you prefer option A (tree format) or option B (list format)?"
- "Should we handle this edge case: [scenario]?"
- "What should happen when [situation]?"

**When to think deeply:**
- Adding new features or parameters
- Modifying core orchestration logic
- Changing task discovery behavior
- Updating cross-platform code
- Refactoring existing functionality

**Remember**: It's better to ask and understand fully than to implement incorrectly.

---

## Project Overview

This is **Gosh**, a self-contained PowerShell build system (`gosh.ps1`) designed for Azure Bicep infrastructure projects. It provides extensible task orchestration with automatic dependency resolution, similar to Make or Rake, but pure PowerShell with no external dependencies.

**Architecture Pattern**: Monolithic orchestrator (`gosh.ps1`) + modular task scripts (`.build/*.ps1`)

**Last Updated**: October 2025

### Current Project Status

The project is a **working example** that includes:
- ✅ Complete build orchestration system (`gosh.ps1`)
- ✅ Three project tasks: `format`, `lint`, `build`
- ✅ Pester test suite with comprehensive coverage (267 tests)
- ✅ Example Azure infrastructure (App Service + SQL)
- ✅ Multi-task execution with dependency resolution
- ✅ Tab completion and help system (script and module mode)
- ✅ Parameterized task directory (`-TaskDirectory`)
- ✅ Task outline visualization (`-Outline`)
- ✅ Module installation (`-AsModule`) with upward directory search
- ✅ Test tags for fast/slow test separation
- ✅ Cross-platform support (Windows, Linux, macOS)
- ✅ Security validation suite (path traversal, command injection protection)
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
# ===== Script Mode =====
# Single task with dependencies
.\gosh.ps1 build              # Runs: format → lint → build

# Preview execution plan without running
.\gosh.ps1 build -Outline     # Shows dependency tree and execution order

# Multiple tasks in sequence
.\gosh.ps1 lint format        # Runs: lint, then format
.\gosh.ps1 format,lint,build  # Comma-separated also works

# Skip dependencies (faster iteration)
.\gosh.ps1 build -Only        # Runs: build only (no format/lint)

# Preview what -Only would do
.\gosh.ps1 build -Only -Outline

# Multiple tasks without dependencies
.\gosh.ps1 format lint build -Only  # Runs all three, skipping build's deps

# Custom task directory
.\gosh.ps1 -TaskDirectory "infra-tasks" -ListTasks
.\gosh.ps1 deploy -TaskDirectory "deployment-tasks"

# Individual steps
.\gosh.ps1 format            # Format all .bicep files
.\gosh.ps1 lint              # Validate all .bicep files

# ===== Module Mode =====
# Install as module first (one-time setup)
.\gosh.ps1 -AsModule

# Then use globally with 'gosh' command
gosh build                   # Runs from any subdirectory
gosh -ListTasks              # Lists all tasks
gosh build -Outline          # Preview execution plan
gosh format lint build -Only # Multiple tasks without dependencies

# Module finds .build/ directory by searching upward
cd tests/iac
gosh build                   # Works from subdirectories (searches up)
```

**Important**: 
- Use `-Only` switch to skip dependencies for all tasks in the sequence
- Use `-Outline` to preview dependency trees and execution order without running tasks
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
- **Use platform-specific paths for module installation** - Windows uses `MyDocuments`, Linux/macOS use `LocalApplicationData`

Example cross-platform path handling:
```powershell
# ✅ GOOD - Cross-platform
$iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "*.bicep" -Recurse -File -Force

# ❌ BAD - Windows-only
$bicepFiles = Get-ChildItem -Path "tests\iac" -Filter "*.bicep" -Recurse
```

Module installation paths (cross-platform):
```powershell
# ✅ GOOD - Cross-platform module path detection
if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
    # Windows: ~/Documents/PowerShell/Modules/
    $modulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell" "Modules" $moduleName
}
else {
    # Linux/macOS: ~/.local/share/powershell/Modules/
    $modulePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "powershell" "Modules" $moduleName
}

# ❌ BAD - Windows-only
$modulePath = Join-Path $HOME "Documents" "PowerShell" "Modules" $moduleName
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

## Task Outline Feature

The `-Outline` flag provides task visualization without execution:

**Purpose**: Preview dependency trees and execution order before running tasks.

**Implementation**:
- `Show-TaskOutline` function (152 lines) in `gosh.ps1`
- Displays ASCII tree structure (├── └──)
- Shows task descriptions inline
- Calculates deduplicated execution order
- Respects `-Only` flag (shows what would actually execute)
- Handles missing dependencies (shown in red)

**Example Usage**:
```powershell
# Preview build dependencies
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

# Preview with -Only flag
.\gosh.ps1 build -Only -Outline
# Shows: build only (dependencies skipped)

# Multiple tasks
.\gosh.ps1 format lint build -Outline
# Shows combined execution plan with deduplication
```

**Use Cases**:
- **Debugging**: Understand complex dependency chains
- **Documentation**: Show team members task relationships
- **Planning**: Verify execution order before critical operations
- **Testing**: Preview `-Only` behavior without side effects

## CI/CD Philosophy

**Local-First Principle (90/10 Rule)**: Tasks should run identically locally and in CI pipelines.

- **Same commands**: `.\gosh.ps1 build` works the same locally and in CI
- **No special CI flags**: Avoid `if ($env:CI)` branches unless absolutely necessary
- **Consistent tooling**: Use same Bicep CLI version, same PowerShell modules
- **Deterministic behavior**: Tasks produce same results regardless of environment

**Pipeline-agnostic design**: Tasks work with GitHub Actions, Azure DevOps, GitLab CI, etc.

### GitHub Actions CI

This project includes a CI workflow at `.github/workflows/ci.yml`:

**Configuration**:
- **Platforms**: Ubuntu (Linux) and Windows (matrix strategy)
- **Triggers**: All branch pushes, pull requests to `main`, manual dispatch via `workflow_dispatch`
  - Push builds run on all branches (including topic branches)
  - Duplicate builds prevented when PR is open (only PR build runs)
- **Branch Protection**: Main branch should be protected (requires GitHub settings configuration)

**Pipeline Steps**:
1. **Setup**: Checkout code, verify PowerShell 7.0+
2. **Dependencies**: Install Pester 5.0+ and Bicep CLI
   - Ubuntu: Azure CLI (includes Bicep) via `curl -sL https://aka.ms/InstallAzureCLIDeb`
   - Windows: Bicep via `winget install Microsoft.Bicep`
3. **Core Tests**: Fast tests (~1s, no Bicep required) - `Invoke-Pester -Tag Core`
4. **Bicep Tasks Tests**: Bicep-dependent tests (~22s) - `Invoke-Pester -Tag Bicep-Tasks`
5. **Test Report**: Generate NUnit XML - `Invoke-Pester -Configuration $config`
6. **Build Pipeline**: Run full pipeline - `pwsh -File gosh.ps1 build`
7. **Verify Artifacts**: Check compiled ARM JSON templates exist

**Artifacts**:
- Test results uploaded as `test-results-ubuntu-latest.xml` and `test-results-windows-latest.xml`
- Retention: 30 days
- Available even if tests fail (`if: always()`)

**Status Badge**:
```markdown
[![CI](https://github.com/motowilliams/gosh/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/gosh/actions/workflows/ci.yml)
```

**Example for other CI platforms**:
```yaml
# Azure DevOps, GitLab CI, etc.
- name: Build
  run: pwsh -File gosh.ps1 build
  
- name: Test
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Output Detailed
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

## Troubleshooting Common Issues

### Task Not Found or Tab Completion Not Working

**Problem**: New task not appearing in `-ListTasks` or tab completion not working.

**Solutions**:
1. **Verify task metadata format**:
   ```powershell
   # First 30 lines must contain properly formatted metadata
   # TASK: taskname
   # DESCRIPTION: Task description
   # DEPENDS: dependency1, dependency2
   ```

2. **Restart PowerShell** - Tab completion caches task list at shell startup
   ```powershell
   # After adding tasks to .build/, restart PowerShell session
   exit
   # Then reopen PowerShell
   ```

3. **Check file naming** - Must follow `Invoke-*.ps1` pattern
   ```powershell
   # ✅ CORRECT
   .build/Invoke-Deploy.ps1
   
   # ❌ INCORRECT
   .build/deploy.ps1
   ```

### Bicep CLI Not Found

**Problem**: Tasks fail with "Bicep CLI not found" error.

**Solution**: Install Bicep CLI
```powershell
# Windows
winget install Microsoft.Bicep

# Linux/macOS
# See: https://aka.ms/bicep-install
```

### Tests Failing with Pester Errors

**Problem**: Pester tests fail or Pester module not found.

**Solution**: Install Pester 5.0+
```powershell
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
```

### Task Execution Fails with Exit Code Error

**Problem**: Task completes but shows failure or wrong exit code.

**Solution**: Ensure explicit exit codes in task scripts
```powershell
# Always end task scripts with explicit exit
exit 0  # Success
exit 1  # Failure
```

### Cross-Platform Path Issues

**Problem**: Tasks work on Windows but fail on Linux/macOS.

**Solution**: Use `Join-Path` for all path construction
```powershell
# ✅ CORRECT - Cross-platform
$path = Join-Path $PSScriptRoot "subfolder" "file.txt"

# ❌ INCORRECT - Windows-only
$path = "$PSScriptRoot\subfolder\file.txt"
```

### Dependency Loop or Circular Dependency

**Problem**: Task execution fails with circular dependency error.

**Solution**: Review task dependencies in `.build/` files
```powershell
# Check dependency chain with -Outline
.\gosh.ps1 taskname -Outline

# Verify no task depends on itself directly or indirectly
# Example: build → lint → format → build (CIRCULAR!)
```

## Testing & Validation

### Pester Testing Framework

This project uses **Pester** for PowerShell testing. The test suite is organized with separate locations for core and module-specific tests:

**Test Structure**:
- **`tests/gosh.Tests.ps1`** (28 tests) - Core Gosh orchestration using mock fixtures
- **`tests/security/Security.Tests.ps1`** (87 tests) - Core security validation tests (P0 fixes)
- **`tests/security/SecurityTxt.Tests.ps1`** (20 tests) - RFC 9116 compliance tests
- **`tests/security/SecurityLogging.Tests.ps1`** (26 tests) - Security event logging tests
- **`tests/security/OutputValidation.Tests.ps1`** (44 tests) - Terminal injection protection tests
- **`packages/.build-bicep/tests/Tasks.Tests.ps1`** (12 tests) - Bicep task validation tests
- **`packages/.build-bicep/tests/Integration.Tests.ps1`** (4 tests) - End-to-end Bicep integration tests
- **`tests/fixtures/`** - Mock tasks for testing Gosh orchestration without external dependencies

**Running tests**:
```powershell
Invoke-Pester                      # Run all tests (auto-discovers *.Tests.ps1)
Invoke-Pester -Output Detailed     # With detailed output
Invoke-Pester -Path tests/gosh.Tests.ps1  # Run specific test file

# Use tags for targeted testing
Invoke-Pester -Tag Core            # Only core orchestration tests (28 tests, ~1s)
Invoke-Pester -Tag Security        # Only security validation tests (29 tests, ~1s)
Invoke-Pester -Tag Bicep-Tasks     # Only Bicep task tests (16 tests, ~22s)
```

**Test Tags**:
- **`Core`** (28 tests) - Tests gosh.ps1 orchestration, fast, no external dependencies
- **`Security`** (205 tests) - Tests all security features (validation, RFC 9116, logging, output sanitization)
- **`Bicep-Tasks`** (16 tests) - Tests Bicep task implementation, slower, requires Bicep CLI

**Test Coverage**:

1. **Core Orchestration Tests** (`tests/gosh.Tests.ps1`):
   - Script validation (syntax, PowerShell version)
   - Task listing (`-ListTasks`, `-Help`)
   - Task discovery from `.build/` and test fixtures
   - Filename fallback for tasks without metadata (handles Invoke-Verb-Noun.ps1 patterns)
   - Task execution (single, multiple, with dependencies)
   - Dependency resolution and `-Only` flag
   - New task creation (`-NewTask`)
   - Error handling for invalid tasks
   - Parameter validation (comma/space-separated)
   - Documentation consistency
   - **Uses `-TaskDirectory 'tests/fixtures'` to test with mock tasks**

2. **Security Validation Tests** (`tests/security/Security.Tests.ps1`):
   - Path traversal protection (absolute paths, parent directory references)
   - Command injection prevention (semicolons, pipes, backticks)
   - PowerShell injection prevention (special characters, variables, command substitution)
   - Input sanitization and validation
   - Error handling security (secure failure modes)

3. **Bicep Task Tests** (`packages/.build-bicep/tests/Tasks.Tests.ps1`):
   - Format task: structure, metadata, aliases
   - Lint task: structure, metadata, dependencies
   - Build task: structure, metadata, dependency chain

4. **Bicep Integration Tests** (`packages/.build-bicep/tests/Integration.Tests.ps1`):
   - Format Bicep files (requires Bicep CLI)
   - Lint Bicep files (requires Bicep CLI)
   - Build Bicep files (requires Bicep CLI)
   - Full build pipeline with dependencies

5. **Test Fixtures** (`tests/fixtures/`):
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
Tests Passed: 267
Tests Failed: 0
Skipped: 0
Total Time: ~15 seconds
```

### Validation Strategy

- **Exit codes**: CI/CD integration via `$LASTEXITCODE` (0=success, 1=failure)
- **Pester tests**: Comprehensive unit and integration tests for all functionality
- **NUnit XML output**: `TestResults.xml` for CI/CD pipeline integration
- **Bicep validation**: lint task catches syntax errors
- **Local-first principle**: Tasks run identically locally and in CI (90/10 rule)
- **Direct testing**: Use `Invoke-Pester` to test the Gosh orchestrator itself
- **PSScriptAnalyzer**: Always use project settings when running analysis
  ```powershell
  Invoke-ScriptAnalyzer -Path "gosh.ps1" -Settings ".vscode/PSScriptAnalyzerSettings.psd1"
  ```

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

## Changelog Maintenance

This project follows [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/) format for documenting changes.

**When to update CHANGELOG.md**:
- Adding new features or functionality
- Making breaking changes
- Fixing bugs
- Deprecating features
- Removing features
- Addressing security vulnerabilities
- Making significant documentation changes

**Do NOT update CHANGELOG.md for**:
- Typo fixes in comments or minor documentation tweaks
- Refactoring that doesn't change behavior
- Internal code reorganization
- Test-only changes (unless adding new test categories)

### Changelog Format

**Structure**:
```markdown
## [Unreleased]

### Added
- New features and capabilities

### Changed
- Changes to existing functionality

### Deprecated
- Features marked for removal in future versions

### Removed
- Features removed in this version

### Fixed
- Bug fixes

### Security
- Security vulnerability fixes
```

### Adding Entries

**Always add to `[Unreleased]` section** under the appropriate category:

```markdown
## [Unreleased]

### Added
- **Feature Name**: Brief description of the feature
  - Sub-bullet for important details
  - Cross-reference with `-Parameter` names or function names
  - Mention platform-specific behavior if applicable
```

**Writing good changelog entries**:
- Start with a brief, descriptive summary in **bold**
- Include enough context for users to understand the change
- Reference specific parameters, functions, or files when relevant
- Use present tense ("Add" not "Added")
- Be consistent with existing entry style
- Group related changes together with sub-bullets

**Examples**:
```markdown
### Added
- **Module Installation**: `-AsModule` parameter to install Gosh as a PowerShell module
  - Enables global `gosh` command accessible from any directory
  - Cross-platform support (Windows, Linux, macOS)
  - Automatic upward directory search for `.build/` folders

### Changed
- Updated task discovery to support both script and module modes
- Modified `Get-AllTasks` to accept `$ScriptRoot` parameter

### Fixed
- Cross-platform compatibility for module installation paths
```

### Release Process

When creating a new release:

1. **Move `[Unreleased]` content** to a new version section:
   ```markdown
   ## [1.1.0] - 2025-10-30
   
   ### Added
   - Content from Unreleased section
   ```

2. **Use Semantic Versioning**:
   - **Major (X.0.0)**: Breaking changes to core functionality or task metadata format
   - **Minor (1.X.0)**: New features, new parameters, backward-compatible enhancements
   - **Patch (1.0.X)**: Bug fixes, documentation updates, minor improvements

3. **Add version comparison links** at bottom:
   ```markdown
   [Unreleased]: https://github.com/motowilliams/gosh/compare/v1.1.0...HEAD
   [1.1.0]: https://github.com/motowilliams/gosh/compare/v1.0.0...v1.1.0
   [1.0.0]: https://github.com/motowilliams/gosh/releases/tag/v1.0.0
   ```

4. **Create empty `[Unreleased]` section** for next changes

### Common Patterns

**New Parameters**:
```markdown
### Added
- **Parameter Name**: `-ParameterName` to enable specific behavior
  - Description of what it does
  - Usage example if helpful
```

**Breaking Changes**:
```markdown
### Changed
- **BREAKING**: Old behavior replaced with new behavior
  - Migration path: how to update existing usage
  - Affected functionality: what will break
```

**Bug Fixes**:
```markdown
### Fixed
- Task execution now correctly handles edge case X
- Cross-platform path resolution in module installation
```

**Security Issues**:
```markdown
### Security
- Fixed command injection vulnerability in task parameter handling
- Added input sanitization for user-provided task names
```

### Documenting Failed Approaches

**CRITICAL**: Document approaches that didn't work to avoid wasting time repeating them.

Add a **`### Technical Notes`** subsection within relevant changelog entries to capture:
- Implementation attempts that failed
- Why they didn't work
- What was learned
- The solution that ultimately worked

**Format**:
```markdown
## [Unreleased]

### Added
- **Module Installation**: `-AsModule` parameter to install Gosh as a PowerShell module
  - Enables global `gosh` command accessible from any directory
  - Cross-platform support (Windows, Linux, macOS)
  - Automatic upward directory search for `.build/` folders
  
  **Technical Notes**:
  - ❌ **Failed**: Attempted to fake `$PSScriptRoot` in module mode using `Set-Variable -Scope Script`
    - PowerShell doesn't allow overriding automatic variables
    - Module execution always uses module's location, not project root
  - ❌ **Failed**: Tried passing project root as function parameter to every function
    - Required massive refactoring of all functions
    - Made function signatures inconsistent and hard to maintain
  - ✅ **Solution**: Used environment variable `$env:GOSH_PROJECT_ROOT` to pass context
    - Module sets variable before invoking gosh-core.ps1
    - Core script checks variable and sets `$script:EffectiveScriptRoot`
    - All functions use `$script:EffectiveScriptRoot` instead of `$PSScriptRoot`
```

**Benefits**:
- Prevents future developers from trying the same failed approaches
- Documents the reasoning behind current implementation
- Provides learning context for similar problems
- Shows evolution of the solution

**When to add Technical Notes**:
- Complex features with multiple attempted solutions
- Non-obvious implementation decisions
- Cross-platform compatibility issues
- Performance optimizations
- Security fixes with multiple iterations
- Breaking changes requiring careful migration

**Example patterns**:
```markdown
### Changed
- **BREAKING**: Updated task discovery to use upward directory search
  
  **Technical Notes**:
  - ❌ **Failed**: Tried using Git repository root detection
    - Not all projects use Git
    - Breaks in subdirectories without `.git/` folder
  - ❌ **Failed**: Used current working directory
    - Doesn't work when invoked from arbitrary locations
    - Breaks when calling from VS Code tasks
  - ✅ **Solution**: Search upward for `.build/` directory (like Git searches for `.git/`)
    - Works from any subdirectory
    - No external dependencies (Git, etc.)
    - Consistent with developer mental model

### Fixed
- Cross-platform module installation paths
  
  **Technical Notes**:
  - ❌ **Failed**: Used `$HOME/Documents/PowerShell/Modules` directly
    - Hardcoded path separator breaks on Linux
    - `Documents` folder doesn't exist on Linux/macOS
  - ❌ **Failed**: Used `[Environment]::GetFolderPath('MyDocuments')` for all platforms
    - Linux/macOS returns empty or unexpected paths
    - PowerShell module path differs by platform
  - ✅ **Solution**: Platform detection with appropriate folder paths
    - Windows: `GetFolderPath('MyDocuments')` + `PowerShell/Modules`
    - Linux/macOS: `GetFolderPath('LocalApplicationData')` + `powershell/Modules`
    - Uses `$IsWindows`, `$IsLinux`, `$IsMacOS` automatic variables
```

## Quick Reference

```powershell
# Common tasks
.\gosh.ps1 -ListTasks              # List all available tasks
.\gosh.ps1 -Help                   # Same as -ListTasks
.\gosh.ps1 build                   # Full pipeline (format → lint → build)
.\gosh.ps1 build -Outline          # Preview execution plan (no execution)
.\gosh.ps1 build -Only             # Build only (skip format/lint)
.\gosh.ps1 build -Only -Outline    # Preview what -Only would do
.\gosh.ps1 format lint             # Multiple tasks (space-separated)
.\gosh.ps1 format,lint             # Multiple tasks (comma-separated)
.\gosh.ps1 format lint build -Only # Multiple tasks without deps

# Testing with Pester
Invoke-Pester                      # Run all tests (267 tests, ~15s)
Invoke-Pester -Tag Core            # Only orchestration tests (28 tests, ~1s)
Invoke-Pester -Tag Security        # Only security tests (205 tests, ~10s)
Invoke-Pester -Tag Bicep-Tasks     # Only Bicep task tests (16 tests, ~22s)
Invoke-Pester -Output Detailed     # With detailed output

# Creating new tasks
.\gosh.ps1 -NewTask deploy         # Create new task file in .build/
.\gosh.ps1 -NewTask validate -TaskDirectory "custom" # Create in custom dir

# Task discovery
Get-ChildItem .build               # See all project tasks
Select-String "# TASK:" .build/*.ps1  # See task names

# Module installation
.\gosh.ps1 -AsModule               # Install as PowerShell module for current user
gosh build                         # Use globally after installation
gosh -ListTasks                    # Works from any subdirectory (upward search)

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
- `.build/Invoke-*.ps1` - User-customizable task templates (placeholders)
- `packages/.build-bicep/Invoke-*.ps1` - Bicep task implementations (format, lint, build)

### Testing
- `tests/gosh.Tests.ps1` - Core Gosh orchestration tests (28 tests, uses mock fixtures, tag: `Core`)
- `tests/security/Security.Tests.ps1` - Security validation tests (87 tests, P0 fixes, tag: `Security`)
- `tests/security/SecurityTxt.Tests.ps1` - RFC 9116 compliance tests (20 tests, tag: `SecurityTxt`, `Operational`)
- `tests/security/SecurityLogging.Tests.ps1` - Security event logging tests (26 tests, tag: `SecurityLogging`, `Operational`)
- `tests/security/OutputValidation.Tests.ps1` - Output sanitization tests (44 tests, tag: `OutputValidation`, `Security`)
- `packages/.build-bicep/tests/Tasks.Tests.ps1` - Bicep task validation tests (12 tests, tag: `Bicep-Tasks`)
- `packages/.build-bicep/tests/Integration.Tests.ps1` - End-to-end Bicep integration tests (4 tests, tag: `Bicep-Tasks`)
- `tests/fixtures/Invoke-Mock*.ps1` - Mock tasks for testing Gosh without external dependencies

### Infrastructure
- `packages/.build-bicep/tests/iac/main.bicep` - Example infrastructure template for testing
- `packages/.build-bicep/tests/iac/modules/*.bicep` - Example infrastructure modules (App Service, SQL)
- `packages/.build-bicep/tests/iac/*.parameters.json` - Example parameter files

### Configuration
- `.vscode/tasks.json` - VS Code task definitions
- `.editorconfig` - Editor formatting rules
- `.vscode/extensions.json` - Recommended VS Code extensions
- `.vscode/settings.json` - Workspace settings
