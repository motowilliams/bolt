# Bolt! ⚡

[![CI](https://github.com/motowilliams/bolt/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/bolt/actions/workflows/ci.yml)

> **Bolt** - Lightning-fast Build orchestration for PowerShell!

A self-contained, cross-platform PowerShell build system with extensible task orchestration and automatic dependency resolution. Inspired by PSake, Make and Rake. Just PowerShell with no external dependencies - just PowerShell Core 7.0+.

**Perfect for any build workflow** - infrastructure-as-code, application builds, testing pipelines, deployment automation, and more. Runs on Windows, Linux, and macOS.

## 📑 Table of Contents

- [✨ Features](#-features)
- [🚀 Quick Start](#-quick-start)
- [📦 Package Starters](#-package-starters)
- [⚙️ Parameter Sets](#️-parameter-sets)
- [📁 Project Structure](#-project-structure)
- [🛠️ Creating Tasks](#️-creating-tasks)
- [⚠️ Important: Task Execution Behaviors](#️-important-task-execution-behaviors)
- [📊 Task Visualization with `-Outline`](#-task-visualization-with--outline)
- [🏗️ Example Workflows](#️-example-workflows)
- [📖 Philosophy](#-philosophy)
- [🧪 Testing](#-testing)

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
- **📦 Module Installation**: Install as PowerShell module via `New-BoltModule.ps1` for global access
- **Module Uninstallation**: Remove Bolt from all installations via `New-BoltModule.ps1`
- **Manifest Generation**: Dedicated tooling for creating PowerShell module manifests (`.psd1`)
- **🐳 Docker Integration**: Containerized manifest generation with Docker wrapper scripts
- **⬆️ Upward Directory Search**: Module mode finds `.build/` by searching parent directories
- **🔧 Parameter Sets**: PowerShell parameter sets prevent invalid combinations and improve UX
- **📝 Configuration Variables**: Project-level variables via `bolt.config.json` auto-injected as `$BoltConfig`
- **🔧 Variable Management**: CLI commands to list, add, and remove variables (`-ListVariables`, `-AddVariable`, `-RemoveVariable`)
- **⚡ Config Caching**: Configuration cached per-invocation for fast multi-task execution
- **🌍 Cross-Platform**: Runs on Windows, Linux, and macOS with PowerShell Core

[back to top](#-bolt!)

## 🚀 Quick Start

### Installation

**Option 1: Script Mode (Standalone)**

1. Clone or download this repository
2. Ensure PowerShell 7.0+ is installed
3. Navigate to the project directory and run `.\bolt.ps1`

**Option 2: Module Mode (Global Command)**

Install Bolt as a PowerShell module for global access:

```powershell
# From the Bolt repository directory
.\New-BoltModule.ps1 -Install

# Restart PowerShell or force import
Import-Module Bolt -Force

# Now use 'bolt' from anywhere
cd ~/projects/myproject
bolt build
```

**Module Benefits:**
- 🌍 Run `bolt` from any directory (no need for `.\bolt.ps1`)
- 🔍 Automatic upward search for `.build/` folders (like git)
- ⚡ Use from subdirectories within your projects
- 🔄 Easy updates: re-run `.\New-BoltModule.ps1 -Install` to update

### First Run

```powershell
# List available tasks
.\bolt.ps1 -Help

# Output:
# Available tasks:
#   build      - Compiles source files
#   format     - Formats source files
#   lint       - Validates source files
```

### Run Your First Build

```powershell
# Run the full build pipeline
.\bolt.ps1 build

# This executes: format → lint → build
```

### Common Commands

**Script Mode:**
```powershell
# List available tasks
.\bolt.ps1 -Help

# Run a single task (with dependencies)
.\bolt.ps1 build

# Preview task execution plan without running
.\bolt.ps1 build -Outline

# Run multiple tasks in sequence
.\bolt.ps1 format lint build

# Skip dependencies for faster iteration
.\bolt.ps1 build -Only

# Preview what -Only would execute
.\bolt.ps1 build -Only -Outline

# Run multiple tasks without dependencies
.\bolt.ps1 format lint build -Only

# Create a new task
.\bolt.ps1 -NewTask deploy

# Use a custom task directory
.\bolt.ps1 -TaskDirectory "infra-tasks" -ListTasks

# Manage configuration variables
.\bolt.ps1 -ListVariables
.\bolt.ps1 -AddVariable -Name "SourcePath" -Value "src"
.\bolt.ps1 -RemoveVariable -VariableName "OldSetting"

# Install as a module
.\New-BoltModule.ps1 -Install

# Uninstall module from all locations
.\New-BoltModule.ps1 -Uninstall
```

**Module Mode** (after running `.\New-BoltModule.ps1 -Install`):
```powershell
# All the same commands work, but simpler syntax
bolt -Help
bolt build
bolt build -Outline
bolt format lint build
bolt build -Only
bolt -NewTask deploy
bolt -TaskDirectory "infra-tasks" -ListTasks

# Works from any subdirectory in your project
cd ~/projects/myproject/src/components
bolt build  # Automatically finds .build/ in parent directories

# Update the module after modifying bolt.ps1
cd ~/projects/bolt
.\New-BoltModule.ps1 -Install  # Overwrites existing installation

# Uninstall the module
.\New-BoltModule.ps1 -Uninstall
```

## 📦 Package Starters

**Package starters** are pre-built task collections for specific toolchains and workflows. They provide ready-to-use task templates that you can install into your project's `.build/` directory.

### Available Package Starters

#### Bicep Starter Package (`packages/.build-bicep`)

Infrastructure-as-Code tasks for Azure Bicep workflows.

**Included Tasks:**
- **`format`** - Formats Bicep files using `bicep format`
- **`lint`** - Validates Bicep syntax using `bicep lint`
- **`build`** - Compiles Bicep files to ARM JSON templates

**Requirements:** Azure Bicep CLI - `winget install Microsoft.Bicep` (Windows) or https://aka.ms/bicep-install

**Installation:**
```powershell
# Copy tasks from package starter to your project
Copy-Item -Path "packages/.build-bicep/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
.\bolt.ps1 format  # Format Bicep files
.\bolt.ps1 lint    # Validate syntax
.\bolt.ps1 build   # Full pipeline: format → lint → build
```

### More Package Starters Coming Soon

We're working on additional package starters for popular toolchains:
- **TypeScript** - Build, lint, and test TypeScript projects
- **Python** - Format (black/ruff), lint (pylint/flake8), test (pytest)
- **Node.js** - Build, lint (ESLint), test (Jest/Mocha)
- **Docker** - Build, tag, push container images
- **Terraform** - Format, validate, plan infrastructure

See [`packages/README.md`](packages/README.md) for details on available package starters and how to create your own.

[back to top](#-bolt!)

## ⚙️ Parameter Sets

Bolt uses PowerShell parameter sets to provide a clean, validated interface with better user experience:

### Available Parameter Sets

1. **Help** (default) - Shows usage when no parameters provided:
   ```powershell
   .\bolt.ps1  # Shows help automatically (no hanging!)
   ```

2. **TaskExecution** - For running tasks:
   ```powershell
   .\bolt.ps1 build                    # Run task with dependencies
   .\bolt.ps1 build -Only              # Skip dependencies
   .\bolt.ps1 build -Outline           # Preview execution plan
   .\bolt.ps1 format lint build        # Multiple tasks
   .\bolt.ps1 build -TaskDirectory "custom"  # Custom task directory
   ```

3. **ListTasks** - For listing available tasks:
   ```powershell
   .\bolt.ps1 -ListTasks               # List all tasks
   .\bolt.ps1 -Help                    # Alias for -ListTasks
   .\bolt.ps1 -ListTasks -TaskDirectory "custom"  # Custom directory
   ```

4. **CreateTask** - For creating new tasks:
   ```powershell
   .\bolt.ps1 -NewTask deploy          # Create new task
   .\bolt.ps1 -NewTask validate -TaskDirectory "custom"  # Custom directory
   ```

5. **ListVariables** - For viewing configuration variables:
   ```powershell
   .\bolt.ps1 -ListVariables           # Show all variables (built-in + user-defined)
   ```

6. **AddVariable** - For adding/updating configuration variables:
   ```powershell
   .\bolt.ps1 -AddVariable -Name "Environment" -Value "dev"
   .\bolt.ps1 -AddVariable -Name "Azure.SubscriptionId" -Value "abc-123"
   ```

7. **RemoveVariable** - For removing configuration variables:
   ```powershell
   .\bolt.ps1 -RemoveVariable -VariableName "Environment"
   ```

**For module installation and uninstallation, use the separate `New-BoltModule.ps1` script:**

```powershell
# Install as PowerShell module
.\New-BoltModule.ps1 -Install
.\New-BoltModule.ps1 -Install -NoImport      # Install without auto-importing
.\New-BoltModule.ps1 -Install -ModuleOutputPath "C:\Custom\Path"  # Custom path

# Remove all installations
.\New-BoltModule.ps1 -Uninstall
.\New-BoltModule.ps1 -Uninstall -Force       # Skip confirmation
```

### Benefits
- **No Invalid Combinations**: PowerShell prevents mixing incompatible parameters like `-ListTasks -NewTask`
- **Better IntelliSense**: IDEs show only relevant parameters for each mode
- **Clear Help**: `Get-Help .\bolt.ps1` shows all parameter sets distinctly
- **No Hanging**: Running with no parameters automatically shows help instead of prompting

[back to top](#-bolt!)

## 📁 Project Structure

```
.
├── bolt.ps1                    # Main orchestrator
├── .build/                     # User-customizable task templates (placeholders)
│   ├── Invoke-Build.ps1        # Build task template
│   ├── Invoke-Format.ps1       # Format task template
│   └── Invoke-Lint.ps1         # Lint task template
├── packages/                   # Package starters (pre-built task collections)
│   ├── README.md               # Package starter documentation
│   └── .build-bicep/           # Bicep starter package (IaC tasks)
│       ├── Invoke-Build.ps1    # Compiles Bicep to ARM JSON
│       ├── Invoke-Format.ps1   # Formats Bicep files
│       ├── Invoke-Lint.ps1     # Validates Bicep syntax
│       └── tests/              # Bicep starter package tests
│           ├── Tasks.Tests.ps1 # Task validation tests
│           ├── Integration.Tests.ps1 # End-to-end tests
│           └── iac/            # Test infrastructure
├── tests/                      # Core Bolt tests
│   ├── fixtures/               # Mock tasks for testing
│   ├── bolt.Tests.ps1          # Core orchestration tests
│   ├── security/
│   │   ├── Security.Tests.ps1  # Security validation tests
│   │   ├── SecurityTxt.Tests.ps1 # RFC 9116 compliance tests
│   │   ├── SecurityLogging.Tests.ps1 # Audit logging tests
│   │   └── OutputValidation.Tests.ps1 # Output sanitization tests
│   └── Invoke-Test.ps1         # Test helper
├── .well-known/
│   └── security.txt            # RFC 9116 security policy
└── .github/
    └── copilot-instructions.md # AI agent guidance
```

### Package Starters vs. Project Tasks

- **`.build/`** - Your project-specific tasks (starts with placeholder templates)
- **`packages/`** - Pre-built task collections for specific toolchains
  - Install by copying starter package tasks to `.build/`
  - Each starter is self-contained with tests and documentation
  - See [`packages/README.md`](packages/README.md) for details

### Example Infrastructure

The Bicep starter package (`packages/.build-bicep`) includes a complete Azure infrastructure example for testing:

- **App Service Plan**: Hosting environment with configurable SKU
- **Web App**: Azure App Service with managed identity
- **SQL Server**: Azure SQL Server with firewall rules
- **SQL Database**: Database with configurable DTU/storage

All modules are parameterized and support multiple environments (dev, staging, prod). These are example templates used for testing the Bicep starter package tasks.

[back to top](#-bolt!)

## 🛠️ Creating Tasks

### Task Directory Flexibility

By default, Bolt discovers tasks from the `.build/` directory. You can customize this location using the `-TaskDirectory` parameter:

```powershell
# Use a different directory for tasks
.\bolt.ps1 -TaskDirectory "custom-tasks" -ListTasks

# Execute tasks from custom directory
.\bolt.ps1 deploy -TaskDirectory "infra-tasks"

# Create new tasks in custom directory
.\bolt.ps1 -NewTask validate -TaskDirectory "validation-tasks"
```

This is useful for:
- **Organizing tasks by category** (build, deploy, test, etc.)
- **Separating concerns** (infrastructure vs. application tasks)
- **Testing task behavior** (using fixture directories)
- **Multi-project workflows** (different task sets per project)

### Quick Method

Use the built-in task generator to create a new task with proper structure:

```powershell
.\bolt.ps1 -NewTask deploy
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

**Task discovery is automatic** - no registration needed!

### Task Metadata

- `# TASK:` - Task name(s), comma-separated for aliases
- `# DESCRIPTION:` - Human-readable description
- `# DEPENDS:` - Dependency list, comma-separated

### Filename Fallback (Convenience Feature)

If a task file has no `# TASK:` metadata, Bolt derives the task name from the filename:

```powershell
# Invoke-Deploy.ps1          -> task name: deploy
# Invoke-My-Task.ps1         -> task name: my-task
# Invoke-Clean-All.ps1       -> task name: clean-all
```

**Warning**: When using filename fallback, Bolt displays a warning to encourage explicit metadata:

```
WARNING: Task file 'Invoke-MyTask.ps1' does not have a # TASK: metadata tag. 
Using filename fallback to derive task name 'mytask'. To disable this warning, 
set: $env:BOLT_NO_FALLBACK_WARNINGS = 1
```

This warning helps avoid confusion during task discovery, especially if you rename files. To suppress the warning:

```powershell
# Disable fallback warnings
$env:BOLT_NO_FALLBACK_WARNINGS = 1

# Or in a script/profile
[System.Environment]::SetEnvironmentVariable('BOLT_NO_FALLBACK_WARNINGS', '1', 'User')
```

**Best Practice**: Always include explicit `# TASK:` metadata for clarity and to avoid file-rename surprises.

[back to top](#-bolt!)

## ⚠️ Important: Task Execution Behaviors

Understanding how Bolt executes tasks is critical for writing reliable, predictable task scripts.

### Exit Codes Are Required

**Tasks without explicit `exit` statements will succeed or fail based on `$LASTEXITCODE`:**

```powershell
# ❌ DANGEROUS - Implicit behavior, unpredictable results
Write-Host "Task complete"
# If last external command succeeded (exit 0) → task succeeds
# If last external command failed (exit non-zero) → task fails
# If no external commands run → task succeeds ($LASTEXITCODE is null, condition fails, task returns true)

# ✅ CORRECT - Always use explicit exit
Write-Host "✓ Task complete" -ForegroundColor Green
exit 0  # Explicit success
```

**Why this matters:**
- Without explicit `exit`, bolt.ps1 checks `$LASTEXITCODE` from the last external command
- If `$LASTEXITCODE` is 0 or null → task succeeds
- If `$LASTEXITCODE` is non-zero → task fails
- This creates **fragile, unpredictable behavior** where task success depends on side effects

**Example of the problem:**
```powershell
# Your deployment logic (all succeeds)
Copy-Item "app.zip" "\\server\share\"
Write-Host "✓ Deployed successfully" -ForegroundColor Green

# Oops! Developer checks something at the end
Test-Path "\\server\share\optional-file.txt"  # Test-Path returns $false (PowerShell cmdlet - doesn't affect $LASTEXITCODE)
# No explicit exit

# Task succeeds because $LASTEXITCODE is still 0 from Copy-Item
# BUT if Copy-Item had failed, task would fail even though we didn't check it!
```

**Best practice**: **Always end tasks with explicit `exit 0` or `exit 1`.**

### Output Behavior

**Tasks execute inside a script block with injected utility functions.** Use `Write-Host` for output:

```powershell
# ❌ BAD - Pipeline output won't display
$result = "Hello, World!"
$result  # This won't appear in terminal

# ✅ GOOD - Use Write-Host for display output
Write-Host "Hello, World!" -ForegroundColor Cyan
```

**Why**: When bolt.ps1 executes tasks, it creates a script block that dot-sources your task script, then executes that block with the call operator (`&`). Pipeline output from the script block is discarded unless you use `Write-Host` or `Write-Output`. Bare variables or expressions sent to the pipeline will not appear in the terminal.

### Pipeline Between Tasks

Tasks in a dependency chain do **NOT** pass pipeline objects to each other:

```powershell
# Given: build depends on lint, lint depends on format
# When you run: .\bolt.ps1 build

# Execution order:
# 1. format executes → output goes to terminal
# 2. lint executes → does NOT receive format's output
# 3. build executes → does NOT receive lint's output

# Only success/failure status propagates between tasks
```

**Why**: Dependencies execute for orchestration purposes (ensuring prerequisites run first), not for data flow. This is the correct design for a build orchestrator - similar to Make, Rake, Gradle, etc.

**If you need data sharing between tasks**:
- Use files (write/read from disk)
- Use environment variables (`$env:VARIABLE_NAME`)
- Design tasks as independent operations

### Configuration Management with `bolt.config.json`

**The recommended way to manage project-level settings** is through `bolt.config.json`:

```powershell
# Create a configuration file (manually or via -AddVariable)
echo '{ "SourcePath": "src", "Environment": "dev" }' > bolt.config.json

# Or use the CLI
.\bolt.ps1 -AddVariable -Name "SourcePath" -Value "src"
.\bolt.ps1 -AddVariable -Name "Environment" -Value "dev"

# View all variables
.\bolt.ps1 -ListVariables
```

**All tasks automatically receive a `$BoltConfig` variable** with your settings:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploy infrastructure

# Access configuration values
$sourcePath = $BoltConfig.SourcePath
$environment = $BoltConfig.Environment

Write-Host "Deploying from: $sourcePath" -ForegroundColor Cyan
Write-Host "Environment: $environment" -ForegroundColor Gray

exit 0
```

**Built-in variables** (always available in `$BoltConfig`):
- `ProjectRoot` - Absolute path to project root directory
- `TaskDirectory` - Name of task directory (e.g., ".build")
- `TaskDirectoryPath` - Absolute path to task directory
- `TaskName` - Current task name being executed
- `TaskScriptRoot` - Directory containing the current task script
- `GitRoot` - Git repository root (if in a git repo)
- `GitBranch` - Current git branch (if in a git repo)
- `Colors` - Hashtable with color theme (e.g., `$BoltConfig.Colors.Header`)

**User-defined variables** (from `bolt.config.json`):
- Any variables you add via `-AddVariable` or by editing the JSON file
- Accessed via `$BoltConfig.YourVariableName`
- Supports nested values with dot notation (e.g., `$BoltConfig.Azure.SubscriptionId`)

**Configuration file location**:
- Searches upward from current directory to find `bolt.config.json`
- Same search behavior as `.build/` directory discovery
- Create in your project root for project-wide settings

**CLI Commands**:

```powershell
# List all variables (built-in and user-defined)
.\bolt.ps1 -ListVariables

# Add or update a variable
.\bolt.ps1 -AddVariable -Name "VariableName" -Value "value"
.\bolt.ps1 -AddVariable -Name "Nested.Value" -Value "123"  # Creates nested structure

# Remove a variable
.\bolt.ps1 -RemoveVariable -VariableName "VariableName"
.\bolt.ps1 -RemoveVariable -VariableName "Nested.Value"  # Removes nested property
```

**Example `bolt.config.json`**:

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

**Performance**: Configuration is cached per bolt.ps1 invocation and automatically invalidated when you add/remove variables, so multi-task executions are fast.

### Task Parameter Limitations

Task scripts CAN use `param()` blocks, but with limitations:

```powershell
# ✅ This works - Default parameters only
param(
    [string]$Name = "World"
)
# Usage: .\bolt.ps1 yourtask
```

**❌ Named parameter passing is NOT currently supported:**
```powershell
# This does NOT work:
.\bolt.ps1 yourtask -Name "Bolt"
# Arguments are passed as an array using @Arguments splatting, which only supports positional parameters
```

**Recommended patterns for dynamic behavior**:
1. **Use `bolt.config.json` (preferred)** - Type-safe, validated, auto-injected as `$BoltConfig`
2. **Use environment variables** - For CI/CD or system-level settings: `$env:VARIABLE_NAME`
3. **Use configuration files** - Load from JSON/YAML/XML in your task as needed

[back to top](#-bolt!)

## 📊 Task Visualization with `-Outline`

The `-Outline` flag displays the task dependency tree and execution order **without executing** any tasks:

```powershell
# Preview build task dependencies
.\bolt.ps1 build -Outline

# Output:
# Task execution plan for: build
#
# build (Compiles source files)
# ├── format (Formats source files)
# └── lint (Validates source files)
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
.\bolt.ps1 build -Only -Outline
# Output: Execution order: 1. build (dependencies skipped)

# Preview multiple tasks
.\bolt.ps1 format lint build -Outline

# Preview with custom task directory
.\bolt.ps1 -TaskDirectory "infra-tasks" deploy -Outline
```

[back to top](#-bolt!)

## 🏗️ Example Workflows

### Full Build Pipeline

```powershell
# Format, lint, and compile in one command
.\bolt.ps1 build

# Run with dependency chain: format → lint → build
```

### Development Iteration

```powershell
# Fix formatting issues
.\bolt.ps1 format

# Validate syntax
.\bolt.ps1 lint

# Compile without re-running format/lint
.\bolt.ps1 build -Only
```

### Multiple Tasks

```powershell
# Run tasks in sequence (space-separated)
.\bolt.ps1 format lint

# Or comma-separated
.\bolt.ps1 format,lint,build

# Skip all dependencies with -Only
.\bolt.ps1 format lint build -Only
```

### CI/CD Integration

```powershell
# Full validation and build
.\bolt.ps1 build
```

[back to top](#-bolt!)

## 📖 Philosophy

### Local-First Principle (90/10 Rule)

Tasks should run **identically** locally and in CI pipelines:

- ✅ **Same commands**: `.\bolt.ps1 build` works the same everywhere
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
        run: pwsh -File bolt.ps1 build
        
# Azure DevOps
steps:
  - task: PowerShell@2
    inputs:
      filePath: 'bolt.ps1'
      arguments: 'build'
      pwsh: true
```

[back to top](#-bolt!)

## 🧪 Testing

The project includes comprehensive **Pester** tests to ensure correct behavior when refactoring or adding new features. Tests are organized for clarity with separate locations for core and module-specific tests.

### Test Structure

**Core Tests** (`tests/` directory):
- **`tests/bolt.Tests.ps1`** - Core orchestration tests
  - Script validation, task discovery, execution, dependency resolution
  - Uses mock fixtures from `tests/fixtures/` to test Bolt itself
  - Tag: `Core`

- **`tests/security/Security.Tests.ps1`** - Security validation tests
  - Input validation, path sanitization, injection prevention
  - Validates TaskDirectory, task names, and script paths
  - Tag: `Security`, `P0`

- **`tests/security/SecurityTxt.Tests.ps1`** - RFC 9116 compliance
  - Validates .well-known/security.txt file format and content
  - Verifies required and recommended fields
  - Tag: `SecurityTxt`, `Operational`

- **`tests/security/SecurityLogging.Tests.ps1`** - Security event logging
  - Tests opt-in audit logging functionality
  - Validates log format, file management, and GitIgnore integration
  - Tag: `SecurityLogging`, `Operational`

- **`tests/security/OutputValidation.Tests.ps1`** - Output sanitization
  - Tests ANSI escape sequence removal and control character filtering
  - Validates length/line limits and malicious input handling
  - Tag: `OutputValidation`, `Security`

**Bicep Module Tests** (`packages/.build-bicep/tests/` directory):
- **`packages/.build-bicep/tests/Tasks.Tests.ps1`** - Task validation
  - Validates structure and metadata of Bicep tasks
  - Tag: `Bicep-Tasks`
  
- **`packages/.build-bicep/tests/Integration.Tests.ps1`** - Integration tests
  - Executes actual Bicep operations against real infrastructure files
  - Requires Bicep CLI to be installed
  - Tag: `Bicep-Tasks`

### Running Tests

```powershell
# Run all tests (auto-discovers test files)
Invoke-Pester

# Run with detailed output
Invoke-Pester -Output Detailed

# Run specific test file
Invoke-Pester -Path tests/bolt.Tests.ps1
Invoke-Pester -Path packages/.build-bicep/tests/

# Run tests by tag
Invoke-Pester -Tag Core
Invoke-Pester -Tag Security
Invoke-Pester -Tag Bicep-Tasks
```

### Test Tags

Tests are organized with tags for flexible execution:

- **`Core`** - Tests bolt.ps1 orchestration itself
  - Fast execution (~1 second)
  - No external tool dependencies
  - Uses mock fixtures from `tests/fixtures/`

- **`Security`** - Tests security validations and features
  - Moderate execution (~10 seconds)
  - Includes Security.Tests.ps1, SecurityTxt.Tests.ps1, SecurityLogging.Tests.ps1, OutputValidation.Tests.ps1
  - Validates input sanitization, RFC 9116 compliance, audit logging, and output validation
  - Tests P0 security fixes for TaskDirectory, path sanitization, task name validation, and terminal injection protection
  
- **`Bicep-Tasks`** - Tests Bicep task implementation
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

**Core Orchestration** (`tests/bolt.Tests.ps1`):
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

**Security Tests** (`tests/security/`):

1. **Security.Tests.ps1** - Core security validation:
   - Path traversal protection (absolute paths, parent directory references)
   - Command injection prevention (semicolons, pipes, backticks)
   - PowerShell injection prevention (special characters, variables, command substitution)
   - Input sanitization and validation
   - Error handling security (secure failure modes)

2. **SecurityTxt.Tests.ps1** - RFC 9116 compliance:
   - File existence and location (.well-known/security.txt)
   - Required fields (Contact, Expires)
   - Recommended fields (Preferred-Languages, Canonical, Policy)
   - Contact information validity (GitHub Security Advisories)
   - File format and structure (UTF-8 encoding, field names)
   - Security policy content (vulnerability reporting guidance)
   - Repository integration (GitHub references, git tracking)

3. **SecurityLogging.Tests.ps1** - Audit logging:
   - Logging disabled by default (no overhead when not enabled)
   - Opt-in via `$env:BOLT_AUDIT_LOG` environment variable
   - Log entry format (timestamp, severity, user, machine, event, details)
   - TaskDirectory usage logging (custom directories only)
   - File creation logging (via -NewTask)
   - Task execution logging (start, completion, success/failure)
   - External command logging (git operations)
   - Log file management (append mode, sequential writes)
   - GitIgnore integration (.bolt/ excluded from version control)
   - Error handling (silent failures, directory conflicts)

4. **OutputValidation.Tests.ps1** - Terminal injection protection:
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

**Bicep Tasks** (`packages/.build-bicep/tests/Tasks.Tests.ps1`):
- Format task: existence, syntax, metadata, aliases
- Lint task: existence, syntax, metadata, dependencies
- Build task: existence, syntax, metadata, dependencies

**Bicep Integration** (`packages/.build-bicep/tests/Integration.Tests.ps1`):
- Format Bicep files integration
- Lint Bicep files integration
- Build Bicep files integration
- Full build pipeline with dependencies

### Test Fixtures

Mock tasks in `tests/fixtures/` are used to test Bolt orchestration without external dependencies:

- `Invoke-MockSimple.ps1` - Simple task with no dependencies
- `Invoke-MockWithDep.ps1` - Task with single dependency
- `Invoke-MockComplex.ps1` - Task with multiple dependencies
- `Invoke-MockFail.ps1` - Task that intentionally fails

These fixtures enable testing with the `-TaskDirectory` parameter:

```powershell
# Tests explicitly specify the fixture directory
.\bolt.ps1 mock-simple -TaskDirectory 'tests/fixtures'

# This allows clean separation between production tasks and test mocks
```

The fixtures allow testing of:
- Dependency resolution chains
- Error handling
- Task execution order
- Bolt orchestration without relying on real project tasks

### Test Requirements

- **Pester 5.0+**: Install with `Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser`
- **Bicep CLI** (optional): Required only for integration tests, other tests run without it
- Tests run in isolated contexts with proper setup/teardown
- Test results output to `TestResults.xml` (NUnit format for CI/CD)
- All tests pass consistently across platforms (Windows, Linux, macOS)

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

All tests pass consistently. Run `Invoke-Pester` to see current results.

[back to top](#-bolt!)

## 🔧 Requirements

- **PowerShell 7.0+** (uses `#Requires -Version 7.0` and modern syntax)
- **Git** (for `check-index` task)

[back to top](#-bolt!)

## 🎨 Output Formatting

All tasks use consistent color coding:

- **Cyan**: Task headers
- **Gray**: Progress/details
- **Green**: Success (✓)
- **Yellow**: Warnings (⚠)
- **Red**: Errors (✗)

[back to top](#-bolt!)

## 📦 Module Installation

Bolt can be installed as a PowerShell module for global access, allowing you to use the `bolt` command from anywhere without referencing the script path.

### Installing the Module

```powershell
# From the Bolt repository directory
.\New-BoltModule.ps1 -Install
```

This creates a module in the user module path:
- **Windows**: `~/Documents/PowerShell/Modules/Bolt/`
- **Linux/macOS**: `~/.local/share/powershell/Modules/Bolt/`

The module includes:
- **Module manifest** (`Bolt.psd1`) - Metadata and exports
- **Module script** (`Bolt.psm1`) - Wrapper with upward directory search
- **Core script** (`bolt-core.ps1`) - Copy of bolt.ps1

### Using the Module

After installation, restart PowerShell or run:
```powershell
Import-Module Bolt -Force
```

Now use `bolt` from anywhere:
```powershell
# Navigate to any project with a .build/ folder
cd ~/projects/myproject/src/components

# Run tasks - automatically finds .build/ in parent directories
bolt build
bolt -ListTasks
bolt format lint build
bolt build -Only
```

### Updating the Module

The installation is **idempotent** - you can re-run it to update:

```powershell
# After modifying bolt.ps1 locally
cd ~/projects/bolt
.\New-BoltModule.ps1 -Install  # Overwrites existing module

# Reload in current session
Import-Module Bolt -Force
```

### How It Works

**Upward Directory Search** (like git):
1. Module searches current directory for `.build/`
2. If not found, checks parent directory
3. Continues upward until `.build/` is found or root is reached
4. Sets project root context for task execution

This allows you to run `bolt` from any subdirectory within your project.

**Example directory structure:**
```
~/projects/myproject/
├── .build/              # Found by upward search
│   ├── Invoke-Build.ps1
│   └── Invoke-Deploy.ps1
└── src/
    └── components/      # You can run 'bolt' here
        └── app.bicep
```

### Module vs Script Mode

| Feature | Script Mode | Module Mode |
|---------|-------------|-------------|
| **Command** | `.\bolt.ps1` | `bolt` |
| **Location** | Must be in project root | Run from any project subdirectory |
| **Discovery** | Uses `$PSScriptRoot` | Searches upward for `.build/` |
| **Tab Completion** | ✅ Yes | ✅ Yes |
| **Updates** | Edit file | Re-run `.\New-BoltModule.ps1 -Install` |
| **Portability** | Single file | Module in user profile |

Both modes support all features: `-Only`, `-Outline`, `-TaskDirectory`, `-NewTask`, etc.

### Uninstalling

Remove Bolt from all module installation locations:

**From script mode:**
```powershell
cd ~/projects/bolt
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

**From module mode (after installation):**
```powershell
# The bolt command cannot uninstall itself, use the script directly
cd ~/projects/bolt
.\New-BoltModule.ps1 -Uninstall
```

**Skip confirmation prompt:**
```powershell
.\New-BoltModule.ps1 -Uninstall -Force
```

**Features:**
- ✅ Auto-detects all Bolt installations (default + custom paths)
- ✅ Prompts for confirmation (safe by default, use `-Force` to skip)
- ✅ Removes module from current session and disk
- ✅ Creates recovery instructions if manual cleanup needed
- ✅ Works across Windows, Linux, and macOS
- ✅ Proper exit codes for CI/CD integration (0=success, 1=failure)

[back to top](#-bolt!)

## 📦 Module Manifest Generation

Bolt includes dedicated tooling for generating PowerShell module manifests (`.psd1` files) from existing modules. This is useful for publishing modules to PowerShell Gallery or creating distribution packages.

### Generate Manifest Script

The `generate-manifest.ps1` script analyzes existing PowerShell modules and creates properly formatted manifest files:

```powershell
# Generate manifest for a module file
.\generate-manifest.ps1 -ModulePath "MyModule.psm1" -ModuleVersion "1.0.0" -Tags "Build,DevOps"

# Generate manifest for a module directory
.\generate-manifest.ps1 -ModulePath "MyModule/" -ModuleVersion "2.1.0" -Tags "Infrastructure,Azure"

# With additional metadata
.\generate-manifest.ps1 -ModulePath "Bolt/Bolt.psm1" -ModuleVersion "3.0.0" -Tags "Build,Task,Orchestration" -ProjectUri "https://github.com/owner/repo" -LicenseUri "https://github.com/owner/repo/blob/main/LICENSE"
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
.\generate-manifest-docker.ps1 -ModulePath "Bolt/Bolt.psm1" -ModuleVersion "3.0.0" -Tags "Build,DevOps,Docker"
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
.\bolt.ps1 -AsModule -ModuleOutputPath "C:\BuildOutput" -NoImport

# Generate manifest for distribution
.\generate-manifest.ps1 -ModulePath "C:\BuildOutput\Bolt\Bolt.psm1" -ModuleVersion "1.5.0" -Tags "Build,Release"
```

**Publishing Workflow:**
```powershell
# 1. Install module to temporary location
.\bolt.ps1 -AsModule -ModuleOutputPath ".\dist" -NoImport

# 2. Generate manifest
.\generate-manifest.ps1 -ModulePath ".\dist\Bolt\Bolt.psm1" -ModuleVersion "2.0.0" -Tags "Build,PowerShell,Bicep"

# 3. Publish to PowerShell Gallery
Publish-Module -Path ".\dist\Bolt" -NuGetApiKey $apiKey
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
✅ Found module file: ./Bolt/Bolt.psm1
✅ Successfully imported module: Bolt
Exported Functions (1): Invoke-Bolt
Exported Aliases (1): bolt
✅ Inferred ProjectUri from git: https://github.com/motowilliams/bolt
✅ Module manifest created: ./Bolt/Bolt.psd1
✅ Manifest is valid!
  Module Name: Bolt
  Version: 3.0.0
  GUID: 5ed0dd69-db75-4ee7-b0d3-e93922605317
```

[back to top](#-bolt!)

## 🐛 Troubleshooting

### Module: Tab completion not working

```powershell
# Restart PowerShell to activate tab completion
exit
# Then reopen PowerShell

# Or force reload the module
Import-Module Bolt -Force
```

### Module: Can't find .build directory

```powershell
# Ensure you're in a project directory or subdirectory with .build/
Get-ChildItem -Path . -Filter .build -Directory -Force -Recurse

# Use -Verbose to see the search path
bolt -ListTasks -Verbose
# Output shows: "Searching for '.build' in: C:\projects\myproject"
```

### Task not found

```powershell
# Restart PowerShell to refresh tab completion
exit
# Then reopen and try again
```

### External tool not found

```powershell
# Install the required tool for your tasks
# Example for Bicep (if using Bicep starter package):
winget install Microsoft.Bicep

# Verify installation
bicep --version

# For other tools, see package starter documentation
```

### Task fails silently

- Check that task script includes explicit `exit 0` or `exit 1`
- Verify `$LASTEXITCODE` is checked after external commands
- Use `-ErrorAction Stop` on PowerShell cmdlets that should fail the task

### Tab completion not working

- Ensure you're using PowerShell 7.0+ (not Windows PowerShell 5.1)
- Restart your PowerShell session after adding new tasks
- Check that task scripts have proper `# TASK:` metadata

[back to top](#-bolt!)

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

[back to top](#-bolt!)

## 🤝 Contributing

Contributions welcome! This is a self-contained build system - keep it simple and dependency-free.

**Before contributing**: Please read our [No Hallucinations Policy](.github/NO-HALLUCINATIONS-POLICY.md) to ensure all documentation and references are accurate and verified.

### Customizing for Your Project

1. **Keep `bolt.ps1`**: The orchestrator rarely needs modification
2. **Modify tasks in `.build/`**: Edit existing tasks or add new ones
3. **Install package starters**: Use pre-built task collections for your toolchain (see `packages/README.md`)
4. **Update configuration**: Edit `bolt.config.json` for project-specific settings

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

Task is automatically discovered - no registration needed! Restart your shell to get tab completion.

### Guidelines

- Use explicit exit codes: `exit 0` (success) or `exit 1` (failure)
- Follow color conventions: Cyan (headers), Gray (progress), Green (success), Yellow (warnings), Red (errors)
- Add metadata comments: `# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`
- Only include `param()` if your task accepts parameters

[back to top](#-bolt!)

## 🔄 Continuous Integration

Bolt includes a GitHub Actions workflow that runs on Ubuntu and Windows:

- **Triggers**: All branch pushes, pull requests to `main`, manual dispatch
  - Push builds run on all branches (including topic branches)
  - Duplicate builds prevented when PR is open (only PR build runs)
- **Platforms**: Ubuntu (Linux) and Windows
- **Pipeline**: Core tests → Starter package tests → Full build (format → lint → build)
- **Dependencies**: Automatically installs PowerShell 7.0+ and tools required by starter packages (e.g., Bicep CLI for testing Bicep starter)
- **Test Reports**: NUnit XML artifacts uploaded for each platform
- **Status**: [![CI](https://github.com/motowilliams/bolt/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/bolt/actions/workflows/ci.yml)

See `.github/workflows/ci.yml` for the complete workflow configuration.

### Running CI Locally

The CI pipeline runs the same commands you use locally:

```powershell
# Install dependencies
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run tests (same as CI)
Invoke-Pester -Tag Core    # Fast tests (~1s)
Invoke-Pester -Tag Bicep-Tasks   # Bicep starter package tests (~22s)
Invoke-Pester             # All tests

# Run build pipeline (same as CI)
.\bolt.ps1 build
```

This follows the **90/10 principle**: 90% of the workflow should be identical locally and in CI.

[back to top](#-bolt!)

## 🔒 Security

Bolt implements comprehensive security measures including:

- **Input Validation**: Task names, paths, and parameters are validated
- **Path Sanitization**: Protection against directory traversal attacks
- **Execution Policy Awareness**: Runtime checks for PowerShell security settings
- **Atomic File Operations**: Race condition prevention in file creation
- **Git Output Sanitization**: Safe handling of external command output
- **Output Validation**: ANSI escape sequence removal and control character filtering
- **Security Event Logging**: Opt-in audit logging for security-relevant operations

### Security Event Logging

Bolt can optionally log security-relevant events for audit and compliance purposes. Logging is **disabled by default** to minimize performance impact and respect privacy.

**Enable logging:**
```powershell
# Windows (PowerShell)
$env:BOLT_AUDIT_LOG = '1'
.\bolt.ps1 build

# Linux/macOS (Bash)
export BOLT_AUDIT_LOG=1
pwsh -File bolt.ps1 build
```

**Logs are written to:** `.bolt/audit.log` (automatically created, excluded from git)

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
Get-Content .bolt/audit.log
```

For security best practices and vulnerability reporting, see:
- **[SECURITY.md](SECURITY.md)** - Complete security documentation and analysis
- **[.well-known/security.txt](.well-known/security.txt)** - RFC 9116 compliant security policy

**Report security vulnerabilities** via [GitHub Security Advisories](https://github.com/motowilliams/bolt/security/advisories/new). Do not report vulnerabilities through public issues.

## 💡 Why "Bolt"?

**Bolt** represents lightning-fast task execution ⚡ - a quick, powerful strike that gets things done!

It's the perfect name for a build orchestration tool that runs fast and efficiently! 🚀

### Design Goals

- **Zero external dependencies**: Just PowerShell 7.0+ (tools like Bicep, Git, etc. are optional via package starters)
- **Self-contained**: Single `bolt.ps1` file orchestrates everything
- **Convention over configuration**: Drop tasks in `.build/`, they're discovered automatically
- **Developer-friendly**: Tab completion, colorized output, helpful error messages
- **CI/CD ready**: Exit codes, deterministic behavior, no special flags

---

**Lightning fast builds with Bolt!** ⚡
