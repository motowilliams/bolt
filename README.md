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
- **🎯 Tab Completion**: Task names auto-complete in PowerShell (script and module mode)
- **🎨 Colorized Output**: Consistent, readable task output
- **🆕 Task Generator**: Create new task stubs with `-NewTask` parameter
- **📊 Task Outline**: Preview dependency trees with `-Outline` flag (no execution)
- **📦 Module Installation**: Install as PowerShell module with `-AsModule` for global access
- **📝 Manifest Generation**: Dedicated tooling for creating PowerShell module manifests (`.psd1`)
- **🐳 Docker Integration**: Containerized manifest generation with Docker wrapper scripts
- **⬆️ Upward Directory Search**: Module mode finds `.build/` by searching parent directories
- **🔧 Parameter Sets**: PowerShell parameter sets prevent invalid combinations and improve UX
- **🌍 Cross-Platform**: Runs on Windows, Linux, and macOS with PowerShell Core

## 🚀 Quick Start

### Installation

**Option 1: Script Mode (Standalone)**

1. Clone or download this repository
2. Ensure PowerShell 7.0+ is installed
3. Install Azure Bicep CLI: `winget install Microsoft.Bicep`
4. Navigate to the project directory and run `.\gosh.ps1`

**Option 2: Module Mode (Global Command)**

Install Gosh as a PowerShell module for global access:

```powershell
# From the Gosh repository directory
.\gosh.ps1 -AsModule

# Restart PowerShell or force import
Import-Module Gosh -Force

# Now use 'gosh' from anywhere
cd ~/projects/myproject
gosh build
```

**Module Benefits:**
- 🌍 Run `gosh` from any directory (no need for `.\gosh.ps1`)
- 🔍 Automatic upward search for `.build/` folders (like git)
- ⚡ Use from subdirectories within your projects
- 🔄 Easy updates: re-run `.\gosh.ps1 -AsModule` to update

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

**Script Mode:**
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

# Install as a module
.\gosh.ps1 -AsModule
```

**Module Mode** (after running `.\gosh.ps1 -AsModule`):
```powershell
# All the same commands work, but simpler syntax
gosh -Help
gosh build
gosh build -Outline
gosh format lint build
gosh build -Only
gosh -NewTask deploy
gosh -TaskDirectory "infra-tasks" -ListTasks

# Works from any subdirectory in your project
cd ~/projects/myproject/src/components
gosh build  # Automatically finds .build/ in parent directories

# Update the module after modifying gosh.ps1
cd ~/projects/gosh
.\gosh.ps1 -AsModule  # Overwrites existing installation
```

## ⚙️ Parameter Sets

Gosh uses PowerShell parameter sets to provide a clean, validated interface with better user experience:

### Available Parameter Sets

1. **Help** (default) - Shows usage when no parameters provided:
   ```powershell
   .\gosh.ps1  # Shows help automatically (no hanging!)
   ```

2. **TaskExecution** - For running tasks:
   ```powershell
   .\gosh.ps1 build                    # Run task with dependencies
   .\gosh.ps1 build -Only              # Skip dependencies
   .\gosh.ps1 build -Outline           # Preview execution plan
   .\gosh.ps1 format lint build        # Multiple tasks
   .\gosh.ps1 build -TaskDirectory "custom"  # Custom task directory
   ```

3. **ListTasks** - For listing available tasks:
   ```powershell
   .\gosh.ps1 -ListTasks               # List all tasks
   .\gosh.ps1 -Help                    # Alias for -ListTasks
   .\gosh.ps1 -ListTasks -TaskDirectory "custom"  # Custom directory
   ```

4. **CreateTask** - For creating new tasks:
   ```powershell
   .\gosh.ps1 -NewTask deploy          # Create new task
   .\gosh.ps1 -NewTask validate -TaskDirectory "custom"  # Custom directory
   ```

5. **InstallModule** - For module installation:
   ```powershell
   .\gosh.ps1 -AsModule                # Install as PowerShell module
   ```

### Benefits

- **No Invalid Combinations**: PowerShell prevents mixing incompatible parameters like `-ListTasks -NewTask`
- **Better IntelliSense**: IDEs show only relevant parameters for each mode
- **Clear Help**: `Get-Help .\gosh.ps1` shows all parameter sets distinctly
- **No Hanging**: Running with no parameters automatically shows help instead of prompting

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
│   │   ├── Security.Tests.ps1  # Security validation tests (87 tests)
│   │   ├── SecurityTxt.Tests.ps1 # RFC 9116 compliance tests (20 tests)
│   │   ├── SecurityLogging.Tests.ps1 # Audit logging tests (26 tests)
│   │   └── OutputValidation.Tests.ps1 # Output sanitization tests (44 tests)
│   └── Invoke-Test.ps1         # Test helper
├── .well-known/
│   └── security.txt            # RFC 9116 security policy
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

- **`tests/security/Security.Tests.ps1`** (87 tests) - Security validation tests
  - Input validation, path sanitization, injection prevention
  - Validates TaskDirectory, task names, and script paths
  - Tag: `Security`, `P0`

- **`tests/security/SecurityTxt.Tests.ps1`** (20 tests) - RFC 9116 compliance
  - Validates .well-known/security.txt file format and content
  - Verifies required and recommended fields
  - Tag: `SecurityTxt`, `Operational`

- **`tests/security/SecurityLogging.Tests.ps1`** (26 tests) - Security event logging
  - Tests opt-in audit logging functionality
  - Validates log format, file management, and GitIgnore integration
  - Tag: `SecurityLogging`, `Operational`

- **`tests/security/OutputValidation.Tests.ps1`** (44 tests) - Output sanitization
  - Tests ANSI escape sequence removal and control character filtering
  - Validates length/line limits and malicious input handling
  - Tag: `OutputValidation`, `Security`

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
Invoke-Pester                         # 267 tests total

# Run with detailed output
Invoke-Pester -Output Detailed

# Run specific test file
Invoke-Pester -Path tests/gosh.Tests.ps1
Invoke-Pester -Path packages/.build-bicep/tests/

# Run tests by tag
Invoke-Pester -Tag Core               # Core orchestration only (28 tests, ~1s)
Invoke-Pester -Tag Security           # Security validation only (205 tests, ~10s)
Invoke-Pester -Tag Bicep-Tasks        # Bicep tasks only (16 tests, ~22s)
```

### Test Tags

Tests are organized with tags for flexible execution:

- **`Core`** (28 tests) - Tests gosh.ps1 orchestration itself
  - Fast execution (~1 second)
  - No external tool dependencies
  - Uses mock fixtures from `tests/fixtures/`

- **`Security`** (205 tests) - Tests security validations and features
  - Moderate execution (~10 seconds)
  - Includes Security.Tests.ps1, SecurityTxt.Tests.ps1, SecurityLogging.Tests.ps1, OutputValidation.Tests.ps1
  - Validates input sanitization, RFC 9116 compliance, audit logging, and output validation
  - Tests P0 security fixes for TaskDirectory, path sanitization, task name validation, and terminal injection protection
  
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

**Security Tests** (`tests/security/` - 205 tests total):

1. **Security.Tests.ps1** (87 tests) - Core security validation:
   - Path traversal protection (absolute paths, parent directory references)
   - Command injection prevention (semicolons, pipes, backticks)
   - PowerShell injection prevention (special characters, variables, command substitution)
   - Input sanitization and validation
   - Error handling security (secure failure modes)

2. **SecurityTxt.Tests.ps1** (20 tests) - RFC 9116 compliance:
   - File existence and location (.well-known/security.txt)
   - Required fields (Contact, Expires)
   - Recommended fields (Preferred-Languages, Canonical, Policy)
   - Contact information validity (GitHub Security Advisories)
   - File format and structure (UTF-8 encoding, field names)
   - Security policy content (vulnerability reporting guidance)
   - Repository integration (GitHub references, git tracking)

3. **SecurityLogging.Tests.ps1** (26 tests) - Audit logging:
   - Logging disabled by default (no overhead when not enabled)
   - Opt-in via `$env:GOSH_AUDIT_LOG` environment variable
   - Log entry format (timestamp, severity, user, machine, event, details)
   - TaskDirectory usage logging (custom directories only)
   - File creation logging (via -NewTask)
   - Task execution logging (start, completion, success/failure)
   - External command logging (git operations)
   - Log file management (append mode, sequential writes)
   - GitIgnore integration (.gosh/ excluded from version control)
   - Error handling (silent failures, directory conflicts)

4. **OutputValidation.Tests.ps1** (44 tests) - Terminal injection protection:
   - Normal output pass-through (no modification of safe content)
   - ANSI escape sequence removal (colors, cursor control)
   - Control character filtering (null bytes, bell, backspace, etc.)
   - Length validation and truncation (100KB default limit)
   - Line count validation and truncation (1000 lines default)
   - Malicious input handling (command injection attempts)
   - Real-world git scenarios (status output, branch names)
   - Pipeline support (accepts input from pipeline)
   - Verbose output (detailed logging of sanitization)
   - Integration tests (check-index task output validation)

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
Tests Passed: 267
Tests Failed: 0
Skipped: 0
Total Time: ~15 seconds
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

## 📦 Module Installation

Gosh can be installed as a PowerShell module for global access, allowing you to use the `gosh` command from anywhere without referencing the script path.

### Installing the Module

```powershell
# From the Gosh repository directory
.\gosh.ps1 -AsModule
```

This creates a module in the user module path:
- **Windows**: `~/Documents/PowerShell/Modules/Gosh/`
- **Linux/macOS**: `~/.local/share/powershell/Modules/Gosh/`

The module includes:
- **Module manifest** (`Gosh.psd1`) - Metadata and exports
- **Module script** (`Gosh.psm1`) - Wrapper with upward directory search
- **Core script** (`gosh-core.ps1`) - Copy of gosh.ps1

### Using the Module

After installation, restart PowerShell or run:
```powershell
Import-Module Gosh -Force
```

Now use `gosh` from anywhere:
```powershell
# Navigate to any project with a .build/ folder
cd ~/projects/myproject/src/components

# Run tasks - automatically finds .build/ in parent directories
gosh build
gosh -ListTasks
gosh format lint build
gosh build -Only
```

### Updating the Module

The installation is **idempotent** - you can re-run it to update:

```powershell
# After modifying gosh.ps1 locally
cd ~/projects/gosh
.\gosh.ps1 -AsModule  # Overwrites existing module

# Reload in current session
Import-Module Gosh -Force
```

### How It Works

**Upward Directory Search** (like git):
1. Module searches current directory for `.build/`
2. If not found, checks parent directory
3. Continues upward until `.build/` is found or root is reached
4. Sets project root context for task execution

This allows you to run `gosh` from any subdirectory within your project.

**Example directory structure:**
```
~/projects/myproject/
├── .build/              # Found by upward search
│   ├── Invoke-Build.ps1
│   └── Invoke-Deploy.ps1
└── src/
    └── components/      # You can run 'gosh' here
        └── app.bicep
```

### Module vs Script Mode

| Feature | Script Mode | Module Mode |
|---------|-------------|-------------|
| **Command** | `.\gosh.ps1` | `gosh` |
| **Location** | Must be in project root | Run from any project subdirectory |
| **Discovery** | Uses `$PSScriptRoot` | Searches upward for `.build/` |
| **Tab Completion** | ✅ Yes | ✅ Yes |
| **Updates** | Edit file | Re-run `.\gosh.ps1 -AsModule` |
| **Portability** | Single file | Module in user profile |

Both modes support all features: `-Only`, `-Outline`, `-TaskDirectory`, `-NewTask`, etc.

### Uninstalling

To remove the module:
```powershell
Remove-Item -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules\Gosh" -Recurse -Force
Remove-Module Gosh -ErrorAction SilentlyContinue
```

## 📦 Module Manifest Generation

Gosh includes dedicated tooling for generating PowerShell module manifests (`.psd1` files) from existing modules. This is useful for publishing modules to PowerShell Gallery or creating distribution packages.

### Generate Manifest Script

The `generate-manifest.ps1` script analyzes existing PowerShell modules and creates properly formatted manifest files:

```powershell
# Generate manifest for a module file
.\generate-manifest.ps1 -ModulePath "MyModule.psm1" -ModuleVersion "1.0.0" -Tags "Build,DevOps"

# Generate manifest for a module directory
.\generate-manifest.ps1 -ModulePath "MyModule/" -ModuleVersion "2.1.0" -Tags "Infrastructure,Azure"

# With additional metadata
.\generate-manifest.ps1 -ModulePath "Gosh/Gosh.psm1" -ModuleVersion "3.0.0" -Tags "Build,Task,Orchestration" -ProjectUri "https://github.com/owner/repo" -LicenseUri "https://github.com/owner/repo/blob/main/LICENSE"
```

**Features:**
- **Automatic Analysis**: Imports module to discover exported functions, cmdlets, and aliases
- **Git Integration**: Automatically infers ProjectUri from git remote origin URL
- **Cross-Platform**: Works on Windows, Linux, and macOS
- **Validation**: Tests generated manifests for correctness
- **Flexible Input**: Accepts both `.psm1` files and module directories

### Docker-Based Generation

For isolated execution, use the Docker wrapper:

```powershell
# Generate manifest in PowerShell container (no host pollution)
.\generate-manifest-docker.ps1 -ModulePath "Gosh/Gosh.psm1" -ModuleVersion "3.0.0" -Tags "Build,DevOps,Docker"
```

**Docker Benefits:**
- **Clean Environment**: No module pollution on host system
- **Consistent Results**: Same PowerShell version and environment every time
- **CI/CD Integration**: Perfect for automated build pipelines
- **Cross-Platform**: Works wherever Docker is available

### Usage Examples

**Local Development:**
```powershell
# Quick manifest generation for testing
.\generate-manifest.ps1 -ModulePath ".\MyModule.psm1" -ModuleVersion "1.0.0" -Tags "Development"
```

**Build Pipeline:**
```powershell
# Generate module in custom location (CI/CD)
.\gosh.ps1 -AsModule -ModuleOutputPath "C:\BuildOutput" -NoImport

# Generate manifest for distribution
.\generate-manifest.ps1 -ModulePath "C:\BuildOutput\Gosh\Gosh.psm1" -ModuleVersion "1.5.0" -Tags "Build,Release"
```

**Publishing Workflow:**
```powershell
# 1. Install module to temporary location
.\gosh.ps1 -AsModule -ModuleOutputPath ".\dist" -NoImport

# 2. Generate manifest
.\generate-manifest.ps1 -ModulePath ".\dist\Gosh\Gosh.psm1" -ModuleVersion "2.0.0" -Tags "Build,PowerShell,Bicep"

# 3. Publish to PowerShell Gallery
Publish-Module -Path ".\dist\Gosh" -NuGetApiKey $apiKey
```

### Parameters

**Required:**
- `-ModulePath`: Path to `.psm1` file or module directory
- `-ModuleVersion`: Semantic version (e.g., "1.0.0", "2.1.3-beta")
- `-Tags`: Comma-separated tags for PowerShell Gallery

**Optional:**
- `-ProjectUri`: Project homepage URL (auto-detected from git)
- `-LicenseUri`: License URL (auto-inferred from ProjectUri)
- `-ReleaseNotes`: Release notes for this version
- `-WorkspacePath`: Base path for module resolution (Docker: "/workspace", Local: ".")

### Output

The scripts generate:
- **Manifest file** (`.psd1`) in the same directory as the module
- **Validation results** confirming manifest correctness
- **Module metadata** summary (functions, aliases, version, GUID)

**Example output:**
```
✅ Found module file: ./Gosh/Gosh.psm1
✅ Successfully imported module: Gosh
Exported Functions (1): Invoke-Gosh
Exported Aliases (1): gosh
✅ Inferred ProjectUri from git: https://github.com/motowilliams/gosh
✅ Module manifest created: ./Gosh/Gosh.psd1
✅ Manifest is valid!
  Module Name: Gosh
  Version: 3.0.0
  GUID: 5ed0dd69-db75-4ee7-b0d3-e93922605317
```

## 🐛 Troubleshooting

### Module: Tab completion not working

```powershell
# Restart PowerShell to activate tab completion
exit
# Then reopen PowerShell

# Or force reload the module
Import-Module Gosh -Force
```

### Module: Can't find .build directory

```powershell
# Ensure you're in a project directory or subdirectory with .build/
Get-ChildItem -Path . -Filter .build -Directory -Force -Recurse

# Use -Verbose to see the search path
gosh -ListTasks -Verbose
# Output shows: "Searching for '.build' in: C:\projects\myproject"
```

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

**Before contributing**: Please read our [No Hallucinations Policy](.github/NO-HALLUCINATIONS-POLICY.md) to ensure all documentation and references are accurate and verified.

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

- **Triggers**: All branch pushes, pull requests to `main`, manual dispatch
  - Push builds run on all branches (including topic branches)
  - Duplicate builds prevented when PR is open (only PR build runs)
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

## 🔒 Security

Gosh implements comprehensive security measures including:

- **Input Validation**: Task names, paths, and parameters are validated
- **Path Sanitization**: Protection against directory traversal attacks
- **Execution Policy Awareness**: Runtime checks for PowerShell security settings
- **Atomic File Operations**: Race condition prevention in file creation
- **Git Output Sanitization**: Safe handling of external command output
- **Output Validation**: ANSI escape sequence removal and control character filtering
- **Security Event Logging**: Opt-in audit logging for security-relevant operations

### Security Event Logging

Gosh can optionally log security-relevant events for audit and compliance purposes. Logging is **disabled by default** to minimize performance impact and respect privacy.

**Enable logging:**
```powershell
# Windows (PowerShell)
$env:GOSH_AUDIT_LOG = '1'
.\gosh.ps1 build

# Linux/macOS (Bash)
export GOSH_AUDIT_LOG=1
pwsh -File gosh.ps1 build
```

**Logs are written to:** `.gosh/audit.log` (automatically created, excluded from git)

**What gets logged:**
- Task executions (name, script path, user, timestamp)
- File creations (via `-NewTask`)
- Custom `TaskDirectory` usage
- External command executions (e.g., `git status`)
- Task completion status (success/failure with exit codes)

**Log format:**
```
2025-10-26 14:30:45 | Info | username@machine | TaskExecution | Task: build, Script: .build/Invoke-Build.ps1
2025-10-26 14:30:46 | Info | username@machine | TaskCompletion | Task 'build' succeeded
```

**View logs:**
```powershell
Get-Content .gosh/audit.log
```

For security best practices and vulnerability reporting, see:
- **[SECURITY.md](SECURITY.md)** - Complete security documentation and analysis
- **[.well-known/security.txt](.well-known/security.txt)** - RFC 9116 compliant security policy

**Report security vulnerabilities** via [GitHub Security Advisories](https://github.com/motowilliams/gosh/security/advisories/new). Do not report vulnerabilities through public issues.

## 💡 Why "Gosh"?

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
