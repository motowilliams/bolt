# Bolt Usage Guide

This document provides detailed information on using Bolt's features, creating tasks, and understanding task execution behaviors.

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

8. **ValidateTasks** - For validating task file metadata and structure:
   ```powershell
   .\bolt.ps1 -ValidateTasks                  # Validate all tasks in .build
   .\bolt.ps1 -ValidateTasks -TaskDirectory "custom"  # Validate custom directory
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

## ✔️ Task Validation with `-ValidateTasks`

The `-ValidateTasks` flag checks all task files for required metadata and proper structure **without executing** any tasks:

```powershell
# Validate all tasks in .build directory
.\bolt.ps1 -ValidateTasks

# Validate tasks in custom directory
.\bolt.ps1 -ValidateTasks -TaskDirectory "custom-tasks"
```

**What It Validates:**
- **TASK metadata** - Checks if `# TASK:` header exists and task name is valid
- **DESCRIPTION metadata** - Checks if `# DESCRIPTION:` header exists and is not a placeholder
- **DEPENDS metadata** - Checks if `# DEPENDS:` header exists (even if empty)
- **Exit code** - Verifies task has explicit `exit 0` or `exit 1` statement
- **Task name format** - Ensures task names follow lowercase alphanumeric + hyphens pattern

**Example Output:**

```
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

================================================================================
Summary: 2 task file(s) validated
  ✓ Pass: 1  ⚠ Warnings: 1  ✗ Failures: 0
```

**Status Indicators:**
- **✓ PASS** - Task file meets all requirements
- **⚠ WARN** - Task file has minor issues (placeholder descriptions, missing non-critical metadata)
- **✗ FAIL** - Task file has critical issues (invalid task name format)

**Use Cases:**
- **Development** - Check task quality before committing
- **Code Review** - Verify new tasks follow conventions
- **CI/CD** - Add validation step to ensure task metadata compliance
- **Onboarding** - Help new contributors understand task requirements

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
  - See [`packages/README.md`](../packages/README.md) for details

---

[← Back to README](../README.md)
