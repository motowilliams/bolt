# Bolt! - Implementation Summary

> **Bolt** - Lightning-fast PowerShell! ⚡

## ✅ Fully Implemented Features

### 1. Core Build System (`bolt.ps1`)
- **Task Discovery**: Automatically finds tasks in `.build/` directory (or custom directory via `-TaskDirectory`)
- **Dependency Resolution**: Executes dependencies before main tasks
- **Tab Completion**: Task names auto-complete in PowerShell (respects `-TaskDirectory`, works in script and module mode)
- **Metadata Support**: Tasks defined via comment-based metadata
- **Circular Dependency Prevention**: Tracks executed tasks
- **Exit Code Handling**: Properly propagates errors
- **Parameterized Task Directory**: Use `-TaskDirectory` to specify custom task locations
- **Task Outline**: Preview dependency trees with `-Outline` flag (no execution)
- **Module Installation**: Install as PowerShell module via `New-BoltModule.ps1` for global `bolt` command
  - `-ModuleOutputPath`: Custom installation path for build/release scenarios
  - `-NoImport`: Skip automatic importing for CI/CD pipelines
- **Upward Directory Search**: Module mode finds `.build/` by searching parent directories (like git)
- **Parameter Sets**: PowerShell parameter sets provide validated operation modes (Help, TaskExecution, ListTasks, CreateTask, ListVariables, AddVariable, RemoveVariable)
- **Configuration Variables**: Project-level variables via `bolt.config.json` auto-injected as `$BoltConfig` into all tasks
- **Variable Management**: CLI commands to list, add, and remove variables:
  - `-ListVariables`: Display all built-in and user-defined variables
  - `-AddVariable <Name> <Value>`: Add or update a configuration variable
  - `-RemoveVariable <Name>`: Remove a configuration variable
- **Config Caching**: Configuration cached per-invocation and invalidated on add/remove for fast multi-task execution
- **Upward Config Search**: `bolt.config.json` discovered via upward directory search (same as `.build/`)

### 2. Bicep Starter Package Tasks

The Bicep starter package (`packages/.build-bicep`) provides infrastructure-as-code tasks:

#### **Format Task** (`.\bolt.ps1 format` or `.\bolt.ps1 fmt`)
- Formats all Bicep files using `bicep format`
- Recursively finds all `.bicep` files in `tests/iac/` directory
- Shows per-file formatting status
- Returns exit code 1 if formatting fails

**Example Output:**
```
Formatting Bicep files...
Found 4 Bicep file(s)

  Formatting: .\iac\main.bicep
  ✓ .\iac\main.bicep formatted
  ...
✓ Successfully formatted 4 Bicep file(s)
```

#### **Lint Task** (`.\bolt.ps1 lint`)
- Validates all Bicep files for syntax errors
- Runs Bicep linter using `bicep lint`
- Detects and reports errors and warnings
- Shows detailed error messages with file locations
- Returns exit code 1 if linting fails

**Example Output:**
```
Linting Bicep files...
Found 4 Bicep file(s) to validate

  Linting: .\iac\main.bicep
    ✓ No issues found
  ...

Lint Summary:
  Files checked: 4
✓ All Bicep files passed linting with no issues!
```

#### **Build Task** (`.\bolt.ps1 build`)
- **Dependencies**: `format`, `lint` (auto-executed first)
- Compiles Bicep files to ARM JSON templates
- Only compiles `main*.bicep` files (not modules)
- Outputs `.json` files next to `.bicep` files
- Returns exit code 1 if compilation fails

**Example Output:**
```
Dependencies for 'build': format, lint

Executing dependency: format
[... format output ...]

Executing dependency: lint
[... lint output ...]

Building Bicep templates...
  Compiling: main.bicep -> main.json
  ✓ main.bicep compiled successfully

✓ All Bicep files compiled successfully!
```

#### **Test Suite** (`Invoke-Pester`)
- Comprehensive Pester test suite for Bolt build system
- Located in `tests/bolt.Tests.ps1`
- Requires Pester 5.0+: `Install-Module -Name Pester -MinimumVersion 5.0.0`
- Tests task discovery, execution, dependencies, and error handling
- Generates NUnit XML test results for CI/CD integration
- Returns exit code 1 if any tests fail

**Test Coverage:**
- Script validation (syntax, PowerShell version)
- Task listing and help functionality
- Task discovery from `.build/` and `tests/` directories
- Single and multiple task execution
- Dependency resolution and `-Only` flag
- Parameter validation (comma/space-separated)
- New task creation with `-NewTask`
- Error handling for invalid tasks
- Bicep CLI integration (format, lint, build)

**Example Output:**
```
Running Pester tests...

Pester v5.7.1
Running tests from 'C:\...\bolt.Tests.ps1'
Describing Bolt Core Functionality
 Context Script Validation
   [+] Should exist 3ms
   [+] Should have valid PowerShell syntax 4ms
   ...

Test Summary:
  Total:  24
  Passed: 15
  Failed: 0
  Skipped: 3

✓ All tests passed!
```

### 3. Azure Infrastructure (Bicep)

Created a complete Azure infrastructure setup for testing:

**Files:**
- `tests/iac/main.bicep` - Main deployment template
- `tests/iac/modules/app-service-plan.bicep` - App Service Plan
- `tests/iac/modules/web-app.bicep` - ASP.NET Core 8.0 Web App
- `tests/iac/modules/sql-server.bicep` - SQL Server + Database
- `tests/iac/main.parameters.json` - Production parameters
- `tests/iac/main.dev.parameters.json` - Development parameters

**What Gets Deployed:**
- Linux App Service Plan
- ASP.NET Core 8.0 Web App (HTTPS only, TLS 1.2+)
- Azure SQL Server with Basic tier database
- Firewall rules for Azure services
- Secure connection strings

### 4. Error Detection

The system properly detects and reports errors:

✅ **Syntax Errors**: Invalid Bicep syntax caught by linter
✅ **Format Issues**: Unformatted files detected in check mode
✅ **Compilation Errors**: Failed builds return non-zero exit codes
✅ **Dependency Failures**: Build stops if lint/format fails

### 5. Module Manifest Generation

Dedicated tooling for creating PowerShell module manifests from existing modules:

#### **Generate Manifest Script** (`generate-manifest.ps1`)
- Analyzes existing PowerShell modules (`.psm1` files or directories)
- Automatically discovers exported functions, cmdlets, and aliases
- Generates properly formatted `.psd1` manifest files
- Includes Git repository integration for automatic URI inference
- Cross-platform support (Windows, Linux, macOS)
- Robust validation with fallback error handling

**Features:**
- **Input Flexibility**: Accepts both `.psm1` files and module directories
- **Automatic Discovery**: Imports module to analyze exports
- **Git Integration**: Infers ProjectUri from `git config --get remote.origin.url`
- **Validation**: Tests generated manifests using `Test-ModuleManifest`
- **Metadata Creation**: Generates GUID, copyright, description, and tags

#### **Docker Wrapper** (`generate-manifest-docker.ps1`)
- Containerized manifest generation using `mcr.microsoft.com/powershell:latest`
- Isolated execution prevents host system pollution
- Perfect for CI/CD pipelines and automated builds
- Consistent cross-platform results
- Volume mounting for workspace access

**Usage Examples:**
```powershell
# Local manifest generation
.\generate-manifest.ps1 -ModulePath "MyModule.psm1" -ModuleVersion "1.0.0" -Tags "Build,DevOps"

# Docker-based generation
.\generate-manifest-docker.ps1 -ModulePath "MyModule.psm1" -ModuleVersion "1.0.0" -Tags "Build,DevOps"

# With additional metadata
.\generate-manifest.ps1 -ModulePath "Bolt/Bolt.psm1" -ModuleVersion "3.0.0" -Tags "Build,Task" -ProjectUri "https://github.com/owner/repo"
```

**Architecture:**
- **Separation of Concerns**: Manifest generation is separate from core module installation
- **Build Integration**: Works with `New-BoltModule.ps1 -Install -NoImport -ModuleOutputPath` options
- **CI/CD Ready**: Docker wrapper provides consistent containerized execution
- **Validation**: Multiple validation layers ensure manifest correctness

### 6. Configuration Variable System

Project-level configuration management with automatic injection into task contexts:

#### **Configuration File** (`bolt.config.json`)
- JSON-based configuration file in project root
- Discovered via upward directory search (same as `.build/` folder)
- Supports nested values with dot notation (e.g., `Azure.SubscriptionId`)
- Auto-created when using `-AddVariable` if it doesn't exist
- Schema available in `bolt.config.schema.json` for IDE validation
- Example configuration in `bolt.config.example.json`

**Example `bolt.config.json`:**
```json
{
  "SourcePath": "src",
  "Environment": "dev",
  "Azure": {
    "SubscriptionId": "00000000-0000-0000-0000-000000000000",
    "ResourceGroup": "rg-myapp-dev"
  }
}
```

#### **Variable Management CLI**
Three dedicated parameter sets for managing configuration:

**List Variables:**
```powershell
.\bolt.ps1 -ListVariables

# Output:
# Bolt Configuration Variables
#
# Built-in Variables:
#   ProjectRoot = C:\projects\myapp
#   TaskDirectory = .build
#   TaskDirectoryPath = C:\projects\myapp\.build
#   TaskName =
#   TaskScriptRoot =
#   GitRoot = C:/projects/myapp
#   GitBranch = main
#   Colors = @{ Header = Blue }
#
# User-Defined Variables:
#   SourcePath = src
#   Environment = dev
#   Azure.SubscriptionId = 00000000-0000-0000-0000-000000000000
#   Azure.ResourceGroup = rg-myapp-dev
```

**Add/Update Variables:**
```powershell
# Add a simple variable
.\bolt.ps1 -AddVariable -Name "SourcePath" -Value "src"

# Add a nested variable (creates nested structure)
.\bolt.ps1 -AddVariable -Name "Azure.SubscriptionId" -Value "00000000-0000-0000-0000-000000000000"

# Update existing variable (same command)
.\bolt.ps1 -AddVariable -Name "Environment" -Value "staging"

# Output:
# Adding variable: SourcePath = src
# Variable 'SourcePath' set to 'src'
# ✓ Variable 'SourcePath' added successfully
#   Run '.\bolt.ps1 -ListVariables' to see all variables
```

**Remove Variables:**
```powershell
# Remove a variable
.\bolt.ps1 -RemoveVariable -VariableName "OldSetting"

# Remove a nested variable
.\bolt.ps1 -RemoveVariable -VariableName "Azure.OldProperty"

# Output:
# Removing variable: OldSetting
# Variable 'OldSetting' removed
# ✓ Variable 'OldSetting' removed successfully
#   Run '.\bolt.ps1 -ListVariables' to see remaining variables
```

#### **Automatic Config Injection**

All tasks automatically receive a `$BoltConfig` variable containing:

**Built-in Variables** (always available):
- `ProjectRoot`: Absolute path to project root directory
- `TaskDirectory`: Name of task directory (e.g., ".build")
- `TaskDirectoryPath`: Absolute path to task directory
- `TaskName`: Current task name being executed
- `TaskScriptRoot`: Directory containing the current task script
- `GitRoot`: Git repository root (if in a git repo)
- `GitBranch`: Current git branch (if in a git repo)
- `Colors`: Hashtable with color theme (e.g., `$BoltConfig.Colors.Header`)

**User-Defined Variables** (from `bolt.config.json`):
- All variables from configuration file
- Accessed via property access: `$BoltConfig.YourVariable`
- Nested values via dot notation: `$BoltConfig.Azure.SubscriptionId`

**Task Usage Example:**
```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploy infrastructure to Azure

# Access built-in variables
Write-Host "Project Root: $($BoltConfig.ProjectRoot)" -ForegroundColor Cyan
Write-Host "Task Directory: $($BoltConfig.TaskDirectory)" -ForegroundColor Gray

# Access user-defined variables
$sourcePath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.SourcePath
$subscriptionId = $BoltConfig.Azure.SubscriptionId
$resourceGroup = $BoltConfig.Azure.ResourceGroup

Write-Host "Deploying from: $sourcePath" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray

# Your deployment logic here

exit 0
```

#### **Configuration Caching**

- Configuration is cached per bolt.ps1 invocation for performance
- Cache automatically invalidated when using `-AddVariable` or `-RemoveVariable`
- Multi-task executions in a single run share the cached config
- Each new bolt.ps1 invocation starts with a fresh cache

**Performance Benefits:**
- Avoids repeated file I/O and JSON parsing
- Enables fast multi-task execution (e.g., `.\bolt.ps1 format lint build`)
- No performance penalty for tasks that don't use config

**Cache Invalidation:**
```powershell
# Cache is automatically cleared after these operations:
.\bolt.ps1 -AddVariable -Name "Setting" -Value "value"      # Cache invalidated
.\bolt.ps1 -RemoveVariable -VariableName "Setting"           # Cache invalidated

# Fresh cache on each invocation:
.\bolt.ps1 build                               # Loads config, caches it
.\bolt.ps1 format lint                         # New invocation, fresh cache
```

#### **Bicep Starter Package Integration**

All Bicep starter package tasks (`format`, `lint`, `build`) have been refactored to use `$BoltConfig`:

```powershell
# Before: Hardcoded paths
$iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"

# After: Configuration-driven
$iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath

# Fallback to default if not configured
if (-not $BoltConfig.IacPath) {
    $iacPath = Join-Path $BoltConfig.ProjectRoot "tests" "iac"
}
```

This makes the tasks portable and reusable across different projects by simply changing `bolt.config.json`.

## Usage Examples

```powershell
# List all available tasks
.\bolt.ps1 -ListTasks
.\bolt.ps1 -Help

# Manage configuration variables
.\bolt.ps1 -ListVariables
.\bolt.ps1 -AddVariable -Name "SourcePath" -Value "src"
.\bolt.ps1 -AddVariable -Name "Azure.SubscriptionId" -Value "00000000-0000-0000-0000-000000000000"
.\bolt.ps1 -RemoveVariable -VariableName "OldSetting"

# Preview task execution plan (no execution)
.\bolt.ps1 build -Outline

# Format source files
.\bolt.ps1 format

# Lint/validate source files
.\bolt.ps1 lint

# Full build (format → lint → compile)
.\bolt.ps1 build

# Install Bolt as a PowerShell module (enables 'bolt' command globally)
.\New-BoltModule.ps1 -Install

# Install to custom location (for build/release)
.\New-BoltModule.ps1 -Install -ModuleOutputPath "C:\Custom\Path" -NoImport

# Use global 'bolt' command (after module installation)
bolt build
bolt -ListTasks
bolt -ListVariables
bolt format lint build -Only

# Uninstall Bolt module from all locations
.\New-BoltModule.ps1 -Uninstall

# Run test suite directly with Pester
Invoke-Pester

# With detailed output
Invoke-Pester -Output Detailed

# Skip dependencies
.\bolt.ps1 build -Only

# Preview what -Only would do
.\bolt.ps1 build -Only -Outline

# Use task aliases
.\bolt.ps1 fmt           # Same as format
.\bolt.ps1 check         # Check git index

# Use custom task directory
.\bolt.ps1 -TaskDirectory "infra-tasks" -ListTasks
.\bolt.ps1 deploy -TaskDirectory "deployment"

# Create new task in custom directory
.\bolt.ps1 -NewTask validate -TaskDirectory "validation"
```

## Task Outline Feature

The `-Outline` flag visualizes task dependency trees without execution:

**Example Output:**
```
PS> .\bolt.ps1 build -Outline

Task execution plan for: build

build (Compiles source files)
├── format (Formats source files)
└── lint (Validates source files)

Execution order:
  1. format
  2. lint
  3. build
```

**With `-Only` flag:**
```
PS> .\bolt.ps1 build -Only -Outline

Task execution plan for: build
(Dependencies will be skipped with -Only flag)

build (Compiles source files)
(Dependencies skipped: format, lint)

Execution order:
  1. build
```

**Multiple tasks:**
```
PS> .\bolt.ps1 format lint build -Outline

Task execution plan for: format, lint, build

format (Formats source files)

lint (Validates source files)

build (Compiles source files)
├── format (Formats source files)
└── lint (Validates source files)

Execution order:
  1. format
  2. lint
  3. build
```

**Benefits:**
- Debug complex dependency chains
- Document task relationships for team members
- Verify execution order before running
- Test `-Only` flag behavior without side effects

## Task Validation Feature

The `-Validation` flag checks all task files for metadata compliance and proper structure without executing them.

### What It Validates

1. **TASK Metadata**
   - Checks if `# TASK:` header exists
   - Validates task name format (lowercase alphanumeric + hyphens only)
   - Enforces 50 character limit for task names
   - Detects filename fallback usage

2. **DESCRIPTION Metadata**
   - Checks if `# DESCRIPTION:` header exists
   - Flags placeholder descriptions ("TODO", "Add description")
   - Warns about empty descriptions

3. **DEPENDS Metadata**
   - Checks if `# DEPENDS:` header exists
   - Header can be empty (no dependencies) but must be present

4. **Exit Codes**
   - Verifies task has explicit `exit 0` or `exit 1` statement
   - Prevents implicit success/failure behavior

### Example Output

**Validating default .build directory:**
```powershell
PS> .\bolt.ps1 -Validation

Task Validation Report
================================================================================

File: Invoke-Build.ps1 | Task: build | ✓ PASS
  TASK: ✓
  DESCRIPTION: ✓ (Compiles Bicep files to ARM JSON templates...)
  DEPENDS: ✓ (format, lint)
  Exit Code: ✓

File: Invoke-Format.ps1 | Task: format | ⚠ WARN
  TASK: ✓
  DESCRIPTION: ✓ (TODO: Add description for this task...)
  DEPENDS: ✓
  Exit Code: ✓
  Issue: Description is placeholder or empty

File: Invoke-Lint.ps1 | Task: lint | ⚠ WARN
  TASK: ✓
  DESCRIPTION: ✗
  DEPENDS: ✗
  Exit Code: ✓
  Issue: Missing DESCRIPTION metadata
  Issue: Missing DEPENDS metadata

================================================================================
Summary: 3 task file(s) validated
  ✓ Pass: 1  ⚠ Warnings: 2  ✗ Failures: 0
```

**Validating custom directory:**
```powershell
PS> .\bolt.ps1 -TaskDirectory "infra-tasks" -Validation

Task Validation Report
================================================================================

File: Invoke-Deploy.ps1 | Task: deploy | ✗ FAIL
  TASK: ✓
  DESCRIPTION: ✓ (Deploys infrastructure to Azure...)
  DEPENDS: ✓ (build)
  Exit Code: ✗
  Issue: Missing explicit exit code (exit 0 or exit 1)

================================================================================
Summary: 1 task file(s) validated
  ✓ Pass: 0  ⚠ Warnings: 0  ✗ Failures: 1
```

### Status Indicators

- **✓ PASS**: Task file meets all requirements
- **⚠ WARN**: Task file has minor issues (placeholder descriptions, missing non-critical metadata)
- **✗ FAIL**: Task file has critical issues (invalid task name format, etc.)

### Exit Codes

- **0**: All validations passed (or warnings only)
- **1**: One or more task files have failures

### Use Cases

**Development Workflow:**
```powershell
# Check tasks before committing
.\bolt.ps1 -Validation

# Fix issues, then validate again
.\bolt.ps1 -Validation
```

**Code Review:**
```powershell
# Validate new tasks in PR
.\bolt.ps1 -TaskDirectory "feature-branch-tasks" -Validation
```

**CI/CD Pipeline:**
```yaml
# GitHub Actions example
- name: Validate Tasks
  run: pwsh -File bolt.ps1 -Validation
  shell: pwsh
```

**Onboarding:**
```powershell
# Help new contributors understand task requirements
.\bolt.ps1 -Validation

# Shows what metadata is required and why
```

### Implementation Details

- **Test-TaskMetadata Function**: Core validation logic
  - Reads first 30 lines for metadata parsing
  - Scans entire file for exit code validation
  - Returns hashtable with validation results
  - Tracks issues and status (Pass/Warning/Fail)

- **Show-ValidationReport Function**: Formatted output
  - Color-coded status indicators
  - File-by-file detailed validation
  - Summary statistics
  - Returns exit code based on failure count

- **ValidateTasks Parameter Set**: Clean interface
  - Works with `-TaskDirectory` parameter
  - Discovers all tasks in specified directory
  - Excludes core tasks (only validates project tasks)

## Namespace-Aware Dependency Resolution

**Version 0.7.0+** introduces namespace-aware dependency resolution for better task isolation in multi-package projects.

### How It Works

When a namespaced task declares dependencies, Bolt now resolves them with **namespace priority**:

1. **First**: Look for `{namespace}-{dependency}` in the same namespace
2. **Fallback**: Use root-level `{dependency}` if not found

### Example Scenario

**Directory Structure:**
```
.build/
├── Invoke-Format.ps1       # Root-level format task
├── Invoke-Lint.ps1         # Root-level lint task
└── golang/
    ├── Invoke-Build.ps1    # DEPENDS: format, lint, test
    ├── Invoke-Format.ps1   # golang-format task
    ├── Invoke-Lint.ps1     # golang-lint task
    └── Invoke-Test.ps1     # golang-test task
```

**Before v0.7.0 (Incorrect):**
```powershell
PS> .\bolt.ps1 golang-build

Dependencies for 'golang-build': format, lint, test

Executing dependency: format        # ✗ Root task executed (wrong!)
Executing dependency: lint          # ✗ Root task executed (wrong!)
WARNING: Dependency 'test' not found, skipping  # ✗ Missing!
```

**After v0.7.0 (Correct):**
```powershell
PS> .\bolt.ps1 golang-build

Dependencies for 'golang-build': format, lint, test

Executing dependency: golang-format  # ✓ Namespace task (correct!)
Executing dependency: golang-lint    # ✓ Namespace task (correct!)
Executing dependency: golang-test    # ✓ Namespace task (correct!)
```

### Outline Mode

The `-Outline` flag also respects namespace-aware resolution:

**Before v0.7.0:**
```
golang-build (Builds Go application)
├── format (TODO: Add description)  ← Root task shown
├── lint (TODO: Add description)    ← Root task shown
└── test (NOT FOUND)                ← Missing!
```

**After v0.7.0:**
```
golang-build (Builds Go application)
├── golang-format (Formats Go files)   ← Namespace task shown
├── golang-lint (Lints Go files)       ← Namespace task shown
└── golang-test (Tests Go files)       ← Namespace task shown
```

### Benefits

- **Task Isolation**: Each starter package uses its own tasks
- **Correct Behavior**: Dependencies resolve to the right tasks
- **Accurate Previews**: `-Outline` shows what will actually execute
- **Fallback Support**: Can still use root-level tasks when needed

### Migration Guide

**Scenario 1: Namespace tasks exist**
- No changes needed - Bolt now correctly uses namespace tasks

**Scenario 2: Only root tasks exist**
- No changes needed - Bolt falls back to root tasks automatically

**Scenario 3: Mixed (root + namespace, different behavior desired)**
- If you want namespace task to use root task instead of its own:
  - Option A: Remove the namespace task (falls back to root)
  - Option B: Have namespace task call root task explicitly (future enhancement)

### Technical Details

**Resolution Algorithm:**
```powershell
function Resolve-Dependency($dep, $namespace, $allTasks) {
    if ($namespace) {
        # Try namespace-prefixed first
        $namespacedDep = "$namespace-$dep"
        if ($allTasks.ContainsKey($namespacedDep)) {
            return $namespacedDep  # Use golang-format
        }
    }
    
    # Fall back to non-namespaced
    if ($allTasks.ContainsKey($dep)) {
        return $dep  # Use format
    }
    
    # Not found
    return $null
}
```

**Applied in:**
- `Invoke-Task` - Task execution (commit 513da5f)
- `Show-TaskOutline` - `-Outline` mode (commit eed7e55)

## Task Dependency Chain

```
build
├── format  (auto-executed first)
└── lint    (auto-executed second)
```

When you run `.\bolt.ps1 build`, it automatically:
1. Formats all Bicep files
2. Validates all Bicep files
3. Compiles main Bicep files to JSON

If any step fails, the build stops and returns an error code.

## Module Management

### Installation

Bolt can be installed as a PowerShell module for global command-line usage:

**Basic Installation:**
```powershell
# Install to default user module location
.\New-BoltModule.ps1 -Install

# Output:
# Installing Bolt as a PowerShell module...
# Using default module path: C:\Users\username\Documents\PowerShell\Modules\Bolt
# ✓ Bolt module installed successfully!
# You can now use 'bolt' command from any directory.
```

**Advanced Installation Options:**
```powershell
# Install to custom location
.\New-BoltModule.ps1 -Install -ModuleOutputPath "C:\Custom\Modules\Path"

# Install without auto-importing (for CI/CD pipelines)
.\New-BoltModule.ps1 -Install -NoImport

# Both options combined
.\New-BoltModule.ps1 -Install -ModuleOutputPath ".\dist" -NoImport
```

**After Installation:**
```powershell
# Use global 'bolt' command from any directory
bolt build
bolt -ListTasks
bolt format lint build -Only

# The module automatically searches upward for .build/ directories
# Just like 'git' searches for '.git/' when using git commands
```

**Cross-Platform Support:**
- Windows: `~\Documents\PowerShell\Modules\Bolt\`
- Linux/macOS: `~/.local/share/powershell/Modules/Bolt/`

### Uninstallation

Remove Bolt from all module installation locations:

**From Script Mode:**
```powershell
# Uninstall from all known locations
.\New-BoltModule.ps1 -Uninstall

# Output:
# Bolt Module Uninstallation
#
# Found 1 Bolt installation(s):
#
#   - C:\Users\username\Documents\PowerShell\Modules\Bolt
#
# Uninstall Bolt from all locations? (y/n): y
#
# Uninstalling Bolt...
# Removing: C:\Users\username\Documents\PowerShell\Modules\Bolt
#   ✓ Successfully removed
#
# ✓ Bolt module uninstalled successfully!
```

**Skip Confirmation:**
```powershell
# Use -Force to skip confirmation prompt
.\New-BoltModule.ps1 -Uninstall -Force
```

**Uninstallation Features:**
- ✅ **Auto-Detection**: Finds all Bolt installations on current platform
- ✅ **Confirmation**: Prompts before removing (safe by default)
- ✅ **Clean Removal**: Removes module from memory and disk
- ✅ **Recovery Instructions**: If automatic removal fails, creates a recovery file with manual cleanup steps
- ✅ **Exit Codes**: Returns 0 on success, 1 on failure for CI/CD integration

**Behavior:**
- Detects all installations (default path + custom paths)
- Removes module from current PowerShell session
- Deletes module directory recursively
- Creates recovery file at `$env:TEMP\Bolt-Uninstall-Manual.txt` if manual cleanup needed
- Works across Windows, Linux, and macOS

**After Uninstallation:**
```powershell
# The 'bolt' command will no longer be available
bolt build
# PowerShell: The term 'bolt' is not recognized...

# You may need to restart PowerShell for changes to take effect
```

## Testing

The project includes a comprehensive Pester test suite organized into three files for separation of concerns:

### Test Structure

**Core Orchestration** (`tests/bolt.Tests.ps1` - 28 tests):
- Tests Bolt's task discovery, execution, and dependency resolution
- Uses mock tasks from `tests/fixtures/` to avoid external dependencies
- Validates script syntax, parameter handling, error handling
- Tests filename fallback for tasks without metadata (handles Invoke-Verb-Noun.ps1 patterns)
- Ensures documentation consistency

**Security Validation** (`tests/security/Security.Tests.ps1` - 29 tests):
- Validates P0 security fixes for path traversal and command injection
- Tests input sanitization and validation
- Ensures secure error handling

**Bicep Starter Package Tests** (`packages/.build-bicep/tests/Tasks.Tests.ps1` - 12 tests):
- Validates structure and metadata of Bicep starter package tasks
- Checks task existence, syntax, and proper metadata headers
- Verifies dependency declarations

**Bicep Starter Package Integration** (`packages/.build-bicep/tests/Integration.Tests.ps1` - 4 tests):
- End-to-end tests executing actual Bicep operations
- Requires Bicep CLI to be installed
- Tests format, lint, build, and full pipeline

### Test Fixtures

Mock tasks in `tests/fixtures/` allow testing Bolt orchestration without external tool dependencies:

- `Invoke-MockSimple.ps1` - Simple task with no dependencies
- `Invoke-MockWithDep.ps1` - Task with single dependency (depends on mock-simple)
- `Invoke-MockComplex.ps1` - Task with multiple dependencies
- `Invoke-MockFail.ps1` - Task that intentionally fails for error handling tests

These fixtures are used by tests via the `-TaskDirectory` parameter to achieve clean separation between test infrastructure and production tasks:

```powershell
# Tests explicitly specify the fixture directory
.\bolt.ps1 mock-simple -TaskDirectory 'tests/fixtures'

# This parameterization removes hardcoded test paths from bolt.ps1
# allowing it to focus solely on task orchestration
```

**Architecture Benefits:**
- ✅ No test-specific code in `bolt.ps1` (clean production code)
- ✅ Tests explicitly declare their fixture location
- ✅ Easy to add new test scenarios by creating new fixture tasks
- ✅ Fixtures can be reused across different test contexts

### Running Tests

```powershell
# Run all tests (auto-discovers *.Tests.ps1 files)
Invoke-Pester

# Run with detailed output
Invoke-Pester -Output Detailed

# Run specific test file
Invoke-Pester -Path tests/bolt.Tests.ps1
Invoke-Pester -Path packages/.build-bicep/tests/

# Run tests by tag
Invoke-Pester -Tag Core           # Only core orchestration tests (28 tests, ~1s)
Invoke-Pester -Tag Security       # Only security validation tests (29 tests, ~1s)
Invoke-Pester -Tag Bicep-Tasks    # Only Bicep task tests (16 tests, ~22s)
```

### Test Tags

The test suite uses Pester tags for flexible test execution:

**`Core` Tag** (28 tests, ~1 second)
- Tests bolt.ps1 orchestration functionality
- Includes `bolt.Tests.ps1` and `Documentation Consistency` tests
- Fast execution with no external dependencies
- Uses mock fixtures from `tests/fixtures/`
- Ideal for quick validation during development

**`Security` Tag** (29 tests, ~1 second)
- Tests security validation and P0 fixes
- Includes path traversal and command injection prevention
- Fast execution with no external dependencies
- Ensures secure input handling and error modes
- Critical for security compliance

**`Bicep-Tasks` Tag** (16 tests, ~22 seconds)
- Tests Bicep starter package implementation in `packages/.build-bicep/` directory
- Includes `Tasks.Tests.ps1` (structure validation)
- Includes `Integration.Tests.ps1` (actual Bicep execution)
- Requires Bicep CLI to be installed
- Runs slower due to actual tool invocation

**Use Cases:**
```powershell
# Quick feedback loop during core development
Invoke-Pester -Tag Core

# Validate Bicep starter package before committing changes
Invoke-Pester -Tag Bicep-Tasks

# Complete validation (default)
Invoke-Pester
```

### Test Results

```
Tests Passed: 43
Tests Failed: 0
Skipped: 0
Total Time: ~27 seconds
```

### CI/CD Integration

Tests can be run in CI pipelines with tag-based filtering:

```yaml
# GitHub Actions - Quick PR validation
- name: Quick Core Tests
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Tag Core -Output Detailed -CI
  shell: pwsh

# Full test suite on main branch
- name: Run All Tests
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Output Detailed -CI
  shell: pwsh

- name: Publish Test Results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: TestResults.xml
```

## Package Starter Development

Bolt includes a comprehensive framework for creating new package starters - reusable task collections for specific toolchains.

### Documentation Resources

**For AI-Assisted Development:**
- **Prompt**: `.github/prompts/create-package-starter.prompt.md`
  - Comprehensive specification for creating new package starters
  - Includes all requirements, patterns, and validation checklist
  - Designed for AI agents to generate complete package starters

**For Developer Guidelines:**
- **Instructions**: `.github/instructions/package-starter-development.instructions.md`
  - Detailed development guide with patterns and examples
  - Task structure requirements and cross-platform considerations
  - Testing requirements (structure and integration tests)
  - Release script conventions
  - Common patterns and troubleshooting

**For Package-Specific Details:**
- **Package README**: `packages/README.md`
  - Available package starters (Bicep, Golang)
  - Installation and usage instructions
  - Multi-namespace support
  - Quick pattern overview with links to comprehensive docs

### Package Starter Structure

Each package starter includes:
```
packages/.build-[toolchain]/
├── Invoke-Format.ps1           # Format task
├── Invoke-Lint.ps1             # Validation task
├── Invoke-Test.ps1             # Testing task (if applicable)
├── Invoke-Build.ps1            # Build task (main pipeline)
├── Create-Release.ps1          # Release packaging script
├── README.md                   # Package-specific documentation
└── tests/
    ├── Tasks.Tests.ps1         # Task structure validation
    ├── Integration.Tests.ps1   # End-to-end integration tests
    └── [example-project]/      # Sample files for testing
```

### Key Requirements

- **Naming**: Use `Invoke-<TaskName>.ps1` pattern
- **Metadata**: Include comment-based metadata (`# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`)
- **Tool Checks**: Validate external tool availability before execution
- **Error Handling**: Use explicit exit codes (0=success, 1=failure)
- **Output Formatting**: Follow Bolt color standards (Cyan/Gray/Green/Yellow/Red)
- **Cross-Platform**: Use PowerShell cmdlets, not Unix commands
- **Path Construction**: Always use `Join-Path` for paths
- **Testing**: Include both structure validation and integration tests
- **Documentation**: Provide package-specific README with installation and usage

### Creating New Package Starters

1. **Use the AI prompt** for automated creation:
   ```
   .github/prompts/create-package-starter.prompt.md
   ```

2. **Follow the development guide** for manual creation:
   ```
   .github/instructions/package-starter-development.instructions.md
   ```

3. **Reference existing implementations**:
   - `packages/.build-bicep/` - Bicep infrastructure tasks
   - `packages/.build-golang/` - Go application tasks

4. **Test comprehensively**:
   ```powershell
   # Run package-specific tests
   Invoke-Pester -Tag [Toolchain]-Tasks
   ```

5. **Update main documentation**:
   - Add entry to `packages/README.md`
   - Update `CHANGELOG.md` under `[Unreleased]`

### Multi-Namespace Support

Package starters can be installed in namespace subdirectories:

```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/golang" -Force

# Install tasks
Copy-Item -Path "packages/.build-golang/Invoke-*.ps1" -Destination ".build/golang/" -Force

# Tasks become namespace-prefixed
# golang-format, golang-lint, golang-test, golang-build
```

Dependencies within the same namespace are resolved with priority, providing proper task isolation.

### Reference Implementations

**Bicep Starter Package** (`packages/.build-bicep/`):
- Infrastructure-as-Code tasks for Azure Bicep
- Tasks: format, lint, build
- Includes comprehensive tests and example infrastructure
- See: `packages/.build-bicep/README.md`

**Golang Starter Package** (`packages/.build-golang/`):
- Go application development tasks
- Tasks: format, lint, test, build
- Includes comprehensive tests and example Go app
- See: `packages/.build-golang/README.md`

### Contributing Package Starters

We welcome new package starters! Follow the comprehensive guidelines and submit a pull request with:
- Complete package starter implementation
- Comprehensive tests (structure and integration)
- Package-specific documentation
- Entry in `packages/README.md`
- Changelog update

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md)

## Next Steps / Enhancements

Potential future improvements:
- [ ] Add more package starters
- [ ] Add `deploy` task for Azure deployment
- [ ] Add `clean` task to remove compiled JSON files
- [x] Add `test` task for infrastructure testing (✅ Completed with Pester)
- [ ] Add `watch` task for file change monitoring
- [ ] Add task timing/profiling
- [ ] Support for multiple IaC directories
- [ ] Integration with Azure deployment scripts

## CI/CD Integration

The build system is CI/CD ready with proper exit codes:

```yaml
# Example GitHub Actions
steps:
  - name: Run build
    run: pwsh -File bolt.ps1 build

  - name: Run tests
    run: |
      Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
      Invoke-Pester -Output Detailed -CI
    shell: pwsh

  - name: Publish Test Results
    uses: EnricoMi/publish-unit-test-result-action@v2
    if: always()
    with:
      files: TestResults.xml
```

**Exit Codes:**
- Exit code 0 = success
- Exit code 1 = failure (lint errors, format issues, build failures, test failures)

## Requirements

- PowerShell 7.0+
- Azure Bicep CLI (`bicep`)
- Git (for `check` task)

---

**Lightning fast builds with Bolt!** ⚡

