# Gosh! - Implementation Summary

> **Go** + **powerShell** = **Gosh!** 🎉

## ✅ Fully Implemented Features

### 1. Core Build System (`gosh.ps1`)
- **Task Discovery**: Automatically finds tasks in `.build/` directory (or custom directory via `-TaskDirectory`)
- **Dependency Resolution**: Executes dependencies before main tasks
- **Tab Completion**: Task names auto-complete in PowerShell (respects `-TaskDirectory`, works in script and module mode)
- **Metadata Support**: Tasks defined via comment-based metadata
- **Circular Dependency Prevention**: Tracks executed tasks
- **Exit Code Handling**: Properly propagates errors
- **Parameterized Task Directory**: Use `-TaskDirectory` to specify custom task locations
- **Task Outline**: Preview dependency trees with `-Outline` flag (no execution)
- **Module Installation**: Install as PowerShell module via `New-GoshModule.ps1` for global `gosh` command
  - `-ModuleOutputPath`: Custom installation path for build/release scenarios
  - `-NoImport`: Skip automatic importing for CI/CD pipelines
- **Upward Directory Search**: Module mode finds `.build/` by searching parent directories (like git)
- **Parameter Sets**: PowerShell parameter sets provide validated operation modes (Help, TaskExecution, ListTasks, CreateTask)

### 2. Build Tasks

#### **Format Task** (`.\gosh.ps1 format` or `.\gosh.ps1 fmt`)
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

#### **Lint Task** (`.\gosh.ps1 lint`)
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

#### **Build Task** (`.\gosh.ps1 build`)
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
- Comprehensive Pester test suite for Gosh build system
- Located in `tests/gosh.Tests.ps1`
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
Running tests from 'C:\...\gosh.Tests.ps1'
Describing Gosh Core Functionality
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
.\generate-manifest.ps1 -ModulePath "Gosh/Gosh.psm1" -ModuleVersion "3.0.0" -Tags "Build,Task" -ProjectUri "https://github.com/owner/repo"
```

**Architecture:**
- **Separation of Concerns**: Manifest generation is separate from core module installation
- **Build Integration**: Works with `New-GoshModule.ps1 -Install -NoImport -ModuleOutputPath` options
- **CI/CD Ready**: Docker wrapper provides consistent containerized execution
- **Validation**: Multiple validation layers ensure manifest correctness

## Usage Examples

```powershell
# List all available tasks
.\gosh.ps1 -ListTasks
.\gosh.ps1 -Help

# Preview task execution plan (no execution)
.\gosh.ps1 build -Outline

# Format all Bicep files
.\gosh.ps1 format

# Lint/validate Bicep files
.\gosh.ps1 lint

# Full build (format → lint → compile)
.\gosh.ps1 build

# Install Gosh as a PowerShell module (enables 'gosh' command globally)
.\New-GoshModule.ps1 -Install

# Install to custom location (for build/release)
.\New-GoshModule.ps1 -Install -ModuleOutputPath "C:\Custom\Path" -NoImport

# Use global 'gosh' command (after module installation)
gosh build
gosh -ListTasks
gosh format lint build -Only

# Uninstall Gosh module from all locations
.\New-GoshModule.ps1 -Uninstall

# Run test suite directly with Pester
Invoke-Pester

# With detailed output
Invoke-Pester -Output Detailed

# Skip dependencies
.\gosh.ps1 build -Only

# Preview what -Only would do
.\gosh.ps1 build -Only -Outline

# Use task aliases
.\gosh.ps1 fmt           # Same as format
.\gosh.ps1 check         # Check git index

# Use custom task directory
.\gosh.ps1 -TaskDirectory "infra-tasks" -ListTasks
.\gosh.ps1 deploy -TaskDirectory "deployment"

# Create new task in custom directory
.\gosh.ps1 -NewTask validate -TaskDirectory "validation"
```

## Task Outline Feature

The `-Outline` flag visualizes task dependency trees without execution:

**Example Output:**
```
PS> .\gosh.ps1 build -Outline

Task execution plan for: build

build (Compiles Bicep files to ARM JSON templates)
├── format (Formats Bicep files using bicep format)
└── lint (Validates Bicep syntax and runs linter)

Execution order:
  1. format
  2. lint
  3. build
```

**With `-Only` flag:**
```
PS> .\gosh.ps1 build -Only -Outline

Task execution plan for: build
(Dependencies will be skipped with -Only flag)

build (Compiles Bicep files to ARM JSON templates)
(Dependencies skipped: format, lint)

Execution order:
  1. build
```

**Multiple tasks:**
```
PS> .\gosh.ps1 format lint build -Outline

Task execution plan for: format, lint, build

format (Formats Bicep files using bicep format)

lint (Validates Bicep syntax and runs linter)

build (Compiles Bicep files to ARM JSON templates)
├── format (Formats Bicep files using bicep format)
└── lint (Validates Bicep syntax and runs linter)

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

## Task Dependency Chain

```
build
├── format  (auto-executed first)
└── lint    (auto-executed second)
```

When you run `.\gosh.ps1 build`, it automatically:
1. Formats all Bicep files
2. Validates all Bicep files
3. Compiles main Bicep files to JSON

If any step fails, the build stops and returns an error code.

## Module Management

### Installation

Gosh can be installed as a PowerShell module for global command-line usage:

**Basic Installation:**
```powershell
# Install to default user module location
.\New-GoshModule.ps1 -Install

# Output:
# Installing Gosh as a PowerShell module...
# Using default module path: C:\Users\username\Documents\PowerShell\Modules\Gosh
# ✓ Gosh module installed successfully!
# You can now use 'gosh' command from any directory.
```

**Advanced Installation Options:**
```powershell
# Install to custom location
.\New-GoshModule.ps1 -Install -ModuleOutputPath "C:\Custom\Modules\Path"

# Install without auto-importing (for CI/CD pipelines)
.\New-GoshModule.ps1 -Install -NoImport

# Both options combined
.\New-GoshModule.ps1 -Install -ModuleOutputPath ".\dist" -NoImport
```

**After Installation:**
```powershell
# Use global 'gosh' command from any directory
gosh build
gosh -ListTasks
gosh format lint build -Only

# The module automatically searches upward for .build/ directories
# Just like 'git' searches for '.git/' when using git commands
```

**Cross-Platform Support:**
- Windows: `~\Documents\PowerShell\Modules\Gosh\`
- Linux/macOS: `~/.local/share/powershell/Modules/Gosh/`

### Uninstallation

Remove Gosh from all module installation locations:

**From Script Mode:**
```powershell
# Uninstall from all known locations
.\New-GoshModule.ps1 -Uninstall

# Output:
# Gosh Module Uninstallation
#
# Found 1 Gosh installation(s):
#
#   - C:\Users\username\Documents\PowerShell\Modules\Gosh
#
# Uninstall Gosh from all locations? (y/n): y
#
# Uninstalling Gosh...
# Removing: C:\Users\username\Documents\PowerShell\Modules\Gosh
#   ✓ Successfully removed
#
# ✓ Gosh module uninstalled successfully!
```

**Skip Confirmation:**
```powershell
# Use -Force to skip confirmation prompt
.\New-GoshModule.ps1 -Uninstall -Force
```

**Uninstallation Features:**
- ✅ **Auto-Detection**: Finds all Gosh installations on current platform
- ✅ **Confirmation**: Prompts before removing (safe by default)
- ✅ **Clean Removal**: Removes module from memory and disk
- ✅ **Recovery Instructions**: If automatic removal fails, creates a recovery file with manual cleanup steps
- ✅ **Exit Codes**: Returns 0 on success, 1 on failure for CI/CD integration

**Behavior:**
- Detects all installations (default path + custom paths)
- Removes module from current PowerShell session
- Deletes module directory recursively
- Creates recovery file at `$env:TEMP\Gosh-Uninstall-Manual.txt` if manual cleanup needed
- Works across Windows, Linux, and macOS

**After Uninstallation:**
```powershell
# The 'gosh' command will no longer be available
gosh build
# PowerShell: The term 'gosh' is not recognized...

# You may need to restart PowerShell for changes to take effect
```

## Testing

The project includes a comprehensive Pester test suite organized into three files for separation of concerns:

### Test Structure

**Core Orchestration** (`tests/gosh.Tests.ps1` - 28 tests):
- Tests Gosh's task discovery, execution, and dependency resolution
- Uses mock tasks from `tests/fixtures/` to avoid external dependencies
- Validates script syntax, parameter handling, error handling
- Tests filename fallback for tasks without metadata (handles Invoke-Verb-Noun.ps1 patterns)
- Ensures documentation consistency

**Security Validation** (`tests/security/Security.Tests.ps1` - 29 tests):
- Validates P0 security fixes for path traversal and command injection
- Tests input sanitization and validation
- Ensures secure error handling

**Bicep Tasks** (`packages/.build-bicep/tests/Tasks.Tests.ps1` - 12 tests):
- Validates structure and metadata of Bicep tasks
- Checks task existence, syntax, and proper metadata headers
- Verifies dependency declarations

**Bicep Integration** (`packages/.build-bicep/tests/Integration.Tests.ps1` - 4 tests):
- End-to-end tests executing actual Bicep operations
- Requires Bicep CLI to be installed
- Tests format, lint, build, and full pipeline

### Test Fixtures

Mock tasks in `tests/fixtures/` allow testing Gosh orchestration without external tool dependencies:

- `Invoke-MockSimple.ps1` - Simple task with no dependencies
- `Invoke-MockWithDep.ps1` - Task with single dependency (depends on mock-simple)
- `Invoke-MockComplex.ps1` - Task with multiple dependencies
- `Invoke-MockFail.ps1` - Task that intentionally fails for error handling tests

These fixtures are used by tests via the `-TaskDirectory` parameter to achieve clean separation between test infrastructure and production tasks:

```powershell
# Tests explicitly specify the fixture directory
.\gosh.ps1 mock-simple -TaskDirectory 'tests/fixtures'

# This parameterization removes hardcoded test paths from gosh.ps1
# allowing it to focus solely on task orchestration
```

**Architecture Benefits:**
- ✅ No test-specific code in `gosh.ps1` (clean production code)
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
Invoke-Pester -Path tests/gosh.Tests.ps1
Invoke-Pester -Path packages/.build-bicep/tests/

# Run tests by tag
Invoke-Pester -Tag Core           # Only core orchestration tests (28 tests, ~1s)
Invoke-Pester -Tag Security       # Only security validation tests (29 tests, ~1s)
Invoke-Pester -Tag Bicep-Tasks    # Only Bicep task tests (16 tests, ~22s)
```

### Test Tags

The test suite uses Pester tags for flexible test execution:

**`Core` Tag** (28 tests, ~1 second)
- Tests gosh.ps1 orchestration functionality
- Includes `gosh.Tests.ps1` and `Documentation Consistency` tests
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
- Tests Bicep task implementation in `packages/.build-bicep/` directory
- Includes `Tasks.Tests.ps1` (structure validation)
- Includes `Integration.Tests.ps1` (actual Bicep execution)
- Requires Bicep CLI to be installed
- Runs slower due to actual tool invocation

**Use Cases:**
```powershell
# Quick feedback loop during core development
Invoke-Pester -Tag Core

# Validate Bicep tasks before committing changes
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

## Next Steps / Enhancements

Potential future improvements:
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
    run: pwsh -File gosh.ps1 build
    
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

**Gosh, that was easy!** 🎉

