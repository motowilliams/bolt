# Contributing to Bolt

Thank you for considering contributing to Bolt! 🎉

## ⚠️ Important: No Hallucinations Policy

**Before contributing any documentation or code**: Please read our [No Hallucinations Policy](.github/NO-HALLUCINATIONS-POLICY.md). 

**Key requirement**: Never create fictional URLs, endpoints, or features. Always verify information exists before documenting it.

## Project Philosophy

**Keep it simple, keep it self-contained.** Bolt is designed to have zero external dependencies beyond PowerShell 7.0+ (tools like Bicep, Git, etc. are optional via package starters).

## Getting Started

1. **Fork and clone** the repository
2. **Install prerequisites**:
   - PowerShell 7.0+
   - Azure Bicep CLI (optional, for testing Bicep starter package): `winget install Microsoft.Bicep`
3. **Make your changes** following the guidelines below
4. **Test locally**: Run `.\bolt.ps1 build` to ensure everything works
5. **Submit a pull request**

## Development Guidelines

### Task Development

When creating or modifying tasks in `.build/`:

- ✅ **Use explicit exit codes**: `exit 0` (success) or `exit 1` (failure) - **ALWAYS include explicit exit**
- ✅ **Include metadata**: `# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`
- ✅ **Follow color conventions**:
  - Cyan: Task headers
  - Gray: Progress/details
  - Green: Success (✓)
  - Yellow: Warnings (⚠)
  - Red: Errors (✗)
- ✅ **Check $LASTEXITCODE**: After external commands
- ✅ **Use descriptive variable names**: Avoid `$Task` (collides with bolt.ps1)
- ✅ **Use `Write-Host` for output**: Pipeline output (bare variables) won't display - tasks execute inside script blocks

#### Critical: Exit Codes Are Required

**Tasks without explicit `exit` statements will succeed or fail based on `$LASTEXITCODE`:**

```powershell
# ❌ DANGEROUS - Implicit behavior, unpredictable results
Write-Host "Task complete"
# If last external command succeeded (exit 0) → task succeeds
# If last external command failed (exit non-zero) → task fails
# If no external commands run → task succeeds ($LASTEXITCODE is null)

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
# TASK: deploy
Write-Host "Deploying application..." -ForegroundColor Cyan

# Your deployment logic (all succeeds)
Copy-Item "app.zip" "\\server\share\"
Write-Host "✓ Deployed successfully" -ForegroundColor Green

# Oops! Developer checks something at the end
Test-Path "\\server\share\optional-file.txt"  # Returns $false (PowerShell cmdlet - doesn't affect $LASTEXITCODE)
# No explicit exit

# Task succeeds because $LASTEXITCODE is still 0 from Copy-Item
# BUT if Copy-Item had failed, task would fail even though we didn't check it!
```

**Best practice**: Always end tasks with explicit `exit 0` or `exit 1`.

#### Understanding Task Execution Context

**Tasks execute inside a script block with injected utility functions.** This has important implications:

**Output Behavior:**
```powershell
# ❌ BAD - Pipeline output won't display
$result = "Hello, World!"
$result  # This won't appear in terminal

# ✅ GOOD - Use Write-Host for display output
Write-Host "Hello, World!" -ForegroundColor Cyan

# ✅ GOOD - Use Write-Output for pipeline objects (if task returns data)
$data = Get-Something
Write-Output $data  # For pipeline consumption by other tools
```

**Why this matters**: When bolt.ps1 executes tasks, it creates a script block that dot-sources your task script, then executes that block with the call operator `&`, which discards pipeline output by default. Use `Write-Host` for user-facing output. You can use `Write-Output` if you need to emit pipeline objects (for example, if your task is being called in a pipeline context), but note that pipeline output will not propagate between tasks.

**Pipeline Between Tasks:**

Tasks in a dependency chain do **NOT** pass pipeline objects to each other. Each task executes independently:

```powershell
# Given: build depends on lint, lint depends on format
# When you run: .\bolt.ps1 build

# Execution order:
# 1. format executes → output goes to terminal (if using Write-Host)
# 2. lint executes → does NOT receive format's output
# 3. build executes → does NOT receive lint's output

# Only success/failure status propagates between tasks
```

**Why**: Bolt uses `Invoke-Task` recursively for dependencies. Each task's return value is boolean (success/failure), not pipeline objects. Dependencies execute for orchestration purposes (ensuring prerequisites run first), not for data flow.

**If you need data sharing between tasks**:
- **Use `bolt.config.json` (preferred)** - Type-safe, validated, auto-injected as `$BoltConfig`
- Use files (write/read from disk)
- Use environment variables (`$env:VARIABLE_NAME`)
- Design tasks as independent operations, not pipelines

**Configuration Variables:**

The recommended way to pass data to tasks is through `bolt.config.json`:

```powershell
# Add configuration variables
.\bolt.ps1 -AddVariable "SourcePath" "src"
.\bolt.ps1 -AddVariable "Azure.SubscriptionId" "00000000-0000-0000-0000-000000000000"

# Then access in any task via $BoltConfig
# .build/Invoke-YourTask.ps1
$iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
$subscriptionId = $BoltConfig.Azure.SubscriptionId
```

All tasks automatically receive a `$BoltConfig` variable with:
- **Built-in variables**: `ProjectRoot`, `TaskDirectory`, `TaskDirectoryPath`, `TaskName`, `TaskScriptRoot`, `GitRoot`, `GitBranch`, `Colors`
- **User-defined variables**: Any variables from `bolt.config.json`

See "Variable System" section below for full details.

**Parameter Limitations:**

Task scripts CAN use `param()` blocks and `[CmdletBinding()]`, but with limitations:

```powershell
# ✅ This works - Default parameters only
[CmdletBinding()]
param(
    [string]$Name = "World",
    [int]$Count = 1
)
# Usage: .\bolt.ps1 yourtask
# (Parameters use their defaults)
```

**❌ Named parameter passing is NOT currently supported:**
```powershell
# This does NOT work:
.\bolt.ps1 yourtask -Name "Bolt" -Count 3
# Arguments are passed as an array, not parsed as named parameters
```

**Current limitation**: Bolt collects remaining arguments as an array and splats them to your task script. PowerShell array splatting only works for positional parameters, not named ones (hashtable splatting is required for named parameters, which would require parsing the argument structure).

**Recommended patterns for dynamic behavior**:
1. **Use `bolt.config.json` (preferred)** - Type-safe, validated, auto-injected as `$BoltConfig`
2. **Use environment variables** - For CI/CD or system-level settings: `$env:VARIABLE_NAME`
3. **Use configuration files** - Load from JSON/YAML/XML in your task as needed

### Example Task Template

```powershell
# .build/Invoke-YourTask.ps1
# TASK: yourtask, alias
# DESCRIPTION: Brief description of what this task does
# DEPENDS: dependency1, dependency2

param(
    [string]$Parameter = "default"
)

Write-Host "Running your task..." -ForegroundColor Cyan

# Access configuration variables via $BoltConfig
$projectRoot = $BoltConfig.ProjectRoot
$customSetting = $BoltConfig.CustomSetting  # From bolt.config.json

# Your task logic here
$success = $true

# ... do work ...

if ($success) {
    Write-Host "✓ Task completed successfully" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Task failed" -ForegroundColor Red
    exit 1
}
```

### Variable System

Bolt provides a configuration variable system for managing project-level settings:

#### **Using `$BoltConfig` in Tasks**

All tasks automatically receive a `$BoltConfig` variable containing:

**Built-in Variables** (always available):
```powershell
$BoltConfig.ProjectRoot        # Absolute path to project root
$BoltConfig.TaskDirectory      # Name of task directory (e.g., ".build")
$BoltConfig.TaskDirectoryPath  # Absolute path to task directory
$BoltConfig.TaskName           # Current task name being executed
$BoltConfig.TaskScriptRoot     # Directory containing current task script
$BoltConfig.GitRoot            # Git repository root (if in a git repo)
$BoltConfig.GitBranch          # Current git branch (if in a git repo)
$BoltConfig.Colors             # Hashtable with color theme
```

**User-Defined Variables** (from `bolt.config.json`):
```powershell
# Simple values
$BoltConfig.SourcePath        # From: { "SourcePath": "src" }
$BoltConfig.Environment       # From: { "Environment": "dev" }

# Nested values (dot notation in JSON becomes object properties)
$BoltConfig.Azure.SubscriptionId   # From: { "Azure": { "SubscriptionId": "..." } }
$BoltConfig.Azure.ResourceGroup    # From: { "Azure": { "ResourceGroup": "..." } }
```

#### **Managing Configuration Variables**

**List all variables:**
```powershell
.\bolt.ps1 -ListVariables
```

**Add or update a variable:**
```powershell
# Simple variable
.\bolt.ps1 -AddVariable -Name "SourcePath" -Value "src"

# Nested variable (creates nested structure)
.\bolt.ps1 -AddVariable -Name "Azure.SubscriptionId" -Value "00000000-0000-0000-0000-000000000000"
```

**Remove a variable:**
```powershell
# Remove simple variable
.\bolt.ps1 -RemoveVariable -VariableName "OldSetting"

# Remove nested variable
.\bolt.ps1 -RemoveVariable -VariableName "Azure.OldProperty"
```

#### **Configuration File Format**

The `bolt.config.json` file uses standard JSON:

```json
{
  "SourcePath": "src",
  "Environment": "dev",
  "Azure": {
    "SubscriptionId": "00000000-0000-0000-0000-000000000000",
    "ResourceGroup": "rg-myapp-dev",
    "Location": "eastus"
  },
  "DeploymentSettings": {
    "RetryCount": 3,
    "Timeout": 300
  }
}
```

**File Location:**
- Placed in project root (same level as `.build/` directory)
- Discovered via upward directory search
- Created automatically when using `-AddVariable` if it doesn't exist

**Schema Validation:**
- Schema available in `bolt.config.schema.json` for IDE IntelliSense
- Example configuration in `bolt.config.example.json`

#### **Task Development Best Practices**

**Use configuration variables instead of hardcoded values:**

```powershell
# ❌ BAD - Hardcoded paths
$sourcePath = "C:\projects\myapp\src"
$resourceGroup = "rg-myapp-dev"

# ✅ GOOD - Configuration-driven
$iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
$resourceGroup = $BoltConfig.Azure.ResourceGroup

# ✅ BETTER - With fallback to sensible default
if ($BoltConfig.IacPath) {
    $iacPath = Join-Path $BoltConfig.ProjectRoot $BoltConfig.IacPath
} else {
    # Default for backward compatibility
    $sourcePath = Join-Path $BoltConfig.ProjectRoot "src"
}
```

**Access nested values safely:**

```powershell
# Check if nested property exists
if ($BoltConfig.Azure -and $BoltConfig.Azure.SubscriptionId) {
    $subscriptionId = $BoltConfig.Azure.SubscriptionId
} else {
    Write-Host "⚠ Azure.SubscriptionId not configured" -ForegroundColor Yellow
    Write-Host "  Run: .\bolt.ps1 -AddVariable 'Azure.SubscriptionId' '<your-subscription-id>'" -ForegroundColor Gray
    exit 1
}
```

**Combine with environment variables for flexibility:**

```powershell
# Allow environment variable override for CI/CD
$subscriptionId = if ($env:AZURE_SUBSCRIPTION_ID) {
    $env:AZURE_SUBSCRIPTION_ID  # CI/CD override
} elseif ($BoltConfig.Azure.SubscriptionId) {
    $BoltConfig.Azure.SubscriptionId  # Local config
} else {
    Write-Host "✗ Subscription ID not configured" -ForegroundColor Red
    exit 1
}
```

### Code Style

- **PowerShell**: 4-space indentation, OTBS style
- **Bicep**: 2-space indentation (enforced by bicep format)
- **Comments**: Use descriptive comments for complex logic
- **Naming**: Use PascalCase for functions, camelCase for variables

### Testing

**⚠️ MANDATORY: ALL code changes MUST include comprehensive tests. No exceptions.**

**For Package Starters:**
- **Minimum 15+ task structure tests** (syntax, metadata, aliases)
- **Minimum 5+ integration tests** (task execution, exit codes, artifacts)
- **Real example files** in `tests/[example-project]/` (not empty placeholders)
- **Tagged appropriately** (`[Toolchain]-Tasks` or `[Toolchain]-Docker-Tasks`)
- See `.github/instructions/package-starter-development.instructions.md` for full requirements

**For Core Changes:**
- Add tests to `tests/bolt.Tests.ps1` (orchestration) or `tests/security/Security.Tests.ps1` (security)
- Tag with `Core` or `Security` as appropriate
- Verify cross-platform compatibility

**Testing is not optional. If tests don't exist or don't pass, changes will not be merged.**

---

Before submitting changes:

- **Run the complete test suite**: Use `.\Invoke-Tests.ps1` to run all tests (includes starter packages)
  - Alternative: `Invoke-Pester` (discovers tests in `tests/` only, requires explicit paths for starter packages)
- **Use test tags for faster feedback**:
  - `.\Invoke-Tests.ps1 -Tag Core` - Quick orchestration tests (fast, ~1s)
  - `.\Invoke-Tests.ps1 -Tag Security` - Security validation tests (moderate, ~10s)
  - `.\Invoke-Tests.ps1 -Tag Package-Bicep-Tasks` - Bicep starter package validation tests (slower, ~22s)
- **Test tasks individually**: Verify your task works standalone
- **Test with dependencies**: Check dependency resolution and `-Only` flag
- **Test with custom directories**: Verify `-TaskDirectory` parameter works correctly
- **Verify exit codes**: Ensure tasks return 0 for success, 1 for failure
- **Test cross-platform**: All changes should work on Windows, Linux, and macOS with PowerShell Core
- **Add new tests**: Choose the appropriate test file:
  - **Core orchestration changes** → `tests/bolt.Tests.ps1` (uses mock fixtures, tag with `Core`)
  - **Security changes** → `tests/security/Security.Tests.ps1` (validates security fixes, tag with `Security`)
  - **New Bicep starter package tasks** → `packages/.build-bicep/tests/Tasks.Tests.ps1` (validates task structure, tag with `Package-Bicep-Tasks`)
  - **Bicep starter package integrations** → `packages/.build-bicep/tests/Integration.Tests.ps1` (requires Bicep CLI, tag with `Package-Bicep-Tasks`)

> **Note**: Tests for starter packages live within their package directories (e.g., `packages/.build-bicep/tests/`). This supports future separation of starter packages into their own repositories. The `Invoke-Tests.ps1` script automatically discovers tests in both `tests/` and `packages/` directories.

### Adding New Starter Packages

Want to contribute a starter package for a new toolchain? Bolt supports TWO types of package starters:

#### Package Starter Types

**1. Non-Docker Packages (Preferred)**

Use for toolchains with well-supported local CLIs (Go, Node.js, .NET SDK, Terraform, etc.):
- **Pattern**: `packages/.build-<toolchain>/`
- **Requires**: Local tool installation only
- **No Docker references**: Clean, simple task scripts
- **Better DX**: Faster execution, native debugging, IDE integration
- **Example**: `.build-bicep`, `.build-golang`, `.build-typescript`

**2. Docker-Only Packages (Alternative)**

Use for containerized workflows or when avoiding local tool installation:
- **Pattern**: `packages/.build-<toolchain>-docker/`
- **Requires**: Docker with Linux containers (important on Windows)
- **Includes**: Dockerfile for custom image builds
- **Env var**: Force rebuild (e.g., `BOLT_TYPESCRIPT_DOCKER_REBUILD=1`)
- **Docker-only**: All `docker run` execution, no local CLI detection
- **Example**: `.build-typescript-docker`, `.build-python-docker`

**Recommendation**: For popular toolchains, create BOTH variants (non-Docker for local dev, Docker for containerized workflows). For specialized tools, choose the variant that makes most sense.

#### 1. Create Package Directory Structure

Create a new directory under `packages/` following the appropriate naming convention:

**Non-Docker Package:**
```powershell
packages/.build-<toolchain>/
├── Invoke-Format.ps1          # Format source files
├── Invoke-Lint.ps1            # Validate/lint code
├── Invoke-Test.ps1            # Run tests (optional if toolchain supports testing)
├── Invoke-Build.ps1           # Build application (with dependencies)
├── Create-Release.ps1         # Release packaging script
├── bolt.config.json           # Configuration template (optional)
├── README.md                  # Package-specific documentation
└── tests/
    ├── Tasks.Tests.ps1        # Task validation tests
    ├── Integration.Tests.ps1  # End-to-end integration tests
    └── app/                   # Example application for testing
```

**Docker-Only Package:**
```powershell
packages/.build-<toolchain>-docker/
├── Invoke-Format.ps1          # Format source files (via Docker)
├── Invoke-Lint.ps1            # Validate/lint code (via Docker)
├── Invoke-Test.ps1            # Run tests (via Docker)
├── Invoke-Build.ps1           # Build application (via Docker)
├── Dockerfile                 # Custom image definition
├── Create-Release.ps1         # Release packaging script
├── bolt.config.json           # Configuration template (optional)
├── README.md                  # Package-specific documentation
└── tests/
    ├── Tasks.Tests.ps1        # Task validation tests
    ├── Integration.Tests.ps1  # End-to-end integration tests
    └── app/                   # Example application for testing
```

**Naming Convention**: 
- Non-Docker: `.build-<toolchain>` where `<toolchain>` is lowercase (e.g., `.build-python`, `.build-golang`, `.build-terraform`)
- Docker-Only: `.build-<toolchain>-docker` (e.g., `.build-python-docker`, `.build-golang-docker`)

#### 2. Implement Task Files

Each task file should follow this structure:

```powershell
#Requires -Version 7.0

# TASK: taskname, alias1, alias2
# DESCRIPTION: Clear description of what the task does
# DEPENDS: dependency1, dependency2

[CmdletBinding()]
param()

# Check for required external tool
$toolCmd = Get-Command <tool-name> -ErrorAction SilentlyContinue
if (-not $toolCmd) {
    Write-Error "<Tool> CLI not found. Please install: <installation-instructions>"
    exit 1
}

# Use $BoltConfig for configuration
$projectPath = if ($BoltConfig.<ToolchainPath>) {
    Join-Path -Path $BoltConfig.ProjectRoot -ChildPath $BoltConfig.<ToolchainPath>
} else {
    # Default path for backward compatibility
    Join-Path -Path $BoltConfig.ProjectRoot -ChildPath "tests/app"
}

# Task implementation
Write-Host "Task Name" -ForegroundColor Cyan
# ... your task logic ...

# Always use explicit exit codes
if ($success) {
    Write-Host "✓ Task completed successfully" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Task failed" -ForegroundColor Red
    exit 1
}
```

**Key Requirements:**
- Include comment-based metadata (`# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`)
- Check for external tool availability before execution
- Support configuration via `$BoltConfig.<ToolchainPath>` with sensible defaults
- Use color conventions (Cyan for headers, Green/Red for status)
- Always end with explicit `exit 0` or `exit 1`

#### 3. Create Release Packaging Script

Add `Create-Release.ps1` to enable automatic GitHub release packaging:

```powershell
#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = 'Stop'

Write-Host "Creating <Toolchain> starter package archive..." -ForegroundColor Cyan

# Resolve paths
$packageRoot = Split-Path -Path $PSScriptRoot -Parent
$packageName = Split-Path -Path $PSScriptRoot -Leaf
$toolchainName = $packageName -replace '^\.build-', ''

# Create output directory
if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

# Create staging directory
$stagingDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bolt-staging-$toolchainName-$(Get-Random)"
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

try {
    # Copy task files
    Write-Host "  Staging package contents..." -ForegroundColor Gray
    $taskFiles = Get-ChildItem -Path $PSScriptRoot -Filter "Invoke-*.ps1" -File
    foreach ($file in $taskFiles) {
        Copy-Item -Path $file.FullName -Destination $stagingDir -Force
        Write-Host "    Added: $($file.Name)" -ForegroundColor Gray
    }
    
    # Copy README if exists
    $readmePath = Join-Path -Path $PSScriptRoot -ChildPath "README.md"
    if (Test-Path -Path $readmePath) {
        Copy-Item -Path $readmePath -Destination $stagingDir -Force
        Write-Host "    Added: README.md" -ForegroundColor Gray
    }
    
    # Create archive
    $archiveName = "bolt-starter-$toolchainName-$Version.zip"
    $archivePath = Join-Path -Path $OutputDirectory -ChildPath $archiveName
    Write-Host "  Creating archive: $archiveName" -ForegroundColor Gray
    
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $archivePath -Force
    $archiveSize = (Get-Item -Path $archivePath).Length / 1KB
    Write-Host "✓ Created package archive: $archiveName ($([math]::Round($archiveSize, 2)) KB)" -ForegroundColor Green
    
    # Generate SHA256 checksum
    Write-Host "  Generating checksum..." -ForegroundColor Gray
    $hash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash
    $checksumPath = "$archivePath.sha256"
    Set-Content -Path $checksumPath -Value "$hash  $archiveName" -NoNewline
    Write-Host "✓ Generated checksum file: $([System.IO.Path]::GetFileName($checksumPath))" -ForegroundColor Green
    Write-Host "  SHA256: $hash" -ForegroundColor Gray
    
    Write-Host "`n✓ <Toolchain> starter package release completed successfully" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`n✗ Failed to create package archive" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up staging directory
    if (Test-Path -Path $stagingDir) {
        Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
```

**Archive Naming Convention**: `bolt-starter-{toolchain}-{version}.zip`

#### 4. Add Comprehensive Tests

**⚠️ CRITICAL: TESTING IS NOT OPTIONAL**

**Package starters without comprehensive tests will NOT be merged. Period.**

Every package starter MUST include:
- **Minimum 15+ task structure assertions** (file existence, syntax validation, metadata)
- **Minimum 5+ integration assertions** (task execution, exit codes, artifacts)
- **Real example application files** in `tests/[example-project]/` (not empty placeholders)
- **Proper test tags** (`[Toolchain]-Tasks` or `[Toolchain]-Docker-Tasks`)
- **Graceful tool detection** - Skip tests when tools not installed, don't fail

**See `.github/instructions/package-starter-development.instructions.md` for complete requirements.**

---

Create two test files in `tests/` subdirectory:

**`Tasks.Tests.ps1` - Task structure validation:**

```powershell
#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $moduleRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..")
}

Describe 'Task Validation' -Tag '<Toolchain>-Tasks' {
    Context 'Format Task' {
        It 'Should exist' {
            $taskPath = Join-Path -Path $moduleRoot -ChildPath "Invoke-Format.ps1"
            Test-Path -Path $taskPath | Should -Be $true
        }
        
        It 'Should have valid PowerShell syntax' {
            $taskPath = Join-Path -Path $moduleRoot -ChildPath "Invoke-Format.ps1"
            $content = Get-Content -Path $taskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }
        
        It 'Should have TASK metadata' {
            $taskPath = Join-Path -Path $moduleRoot -ChildPath "Invoke-Format.ps1"
            $content = Get-Content -Path $taskPath -Raw
            $content | Should -Match '# TASK:'
        }
        
        It 'Should have DESCRIPTION metadata' {
            $taskPath = Join-Path -Path $moduleRoot -ChildPath "Invoke-Format.ps1"
            $content = Get-Content -Path $taskPath -Raw
            $content | Should -Match '# DESCRIPTION:'
        }
    }
    
    # Add similar contexts for Lint, Test, Build tasks
}
```

**`Integration.Tests.ps1` - End-to-end execution:**

```powershell
#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $moduleRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..")
    $projectRoot = Resolve-Path -Path (Join-Path -Path $moduleRoot -ChildPath ".." | Join-Path -ChildPath "..")
    $boltScript = Join-Path -Path $projectRoot -ChildPath "bolt.ps1"
}

Describe 'Task Integration Tests' -Tag '<Toolchain>-Tasks' {
    It 'Should format files if <Tool> CLI is available' {
        $toolCmd = Get-Command <tool-name> -ErrorAction SilentlyContinue
        
        if (-not $toolCmd) {
            Set-ItResult -Skipped -Because "<Tool> CLI not installed"
        }
        
        Push-Location -Path $moduleRoot
        try {
            & $boltScript format -Only
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Pop-Location
        }
    }
    
    # Add similar tests for lint, test, build tasks
    # Add test for full pipeline with dependencies
}
```

**Tag Convention**: 
- Non-Docker packages: `<Toolchain>-Tasks` (e.g., `Package-Python-Tasks`, `Package-Golang-Tasks`)
- Docker-only packages: `<Toolchain>-Docker-Tasks` (e.g., `Package-Python-Tasks-Docker`, `Package-Golang-Tasks-Docker`)

#### 5. Create Package-Specific README

Document your starter package in `README.md`:

```markdown
# <Toolchain> Starter Package for Bolt

<Brief description of what the starter package provides>

## Tasks

- **`format`** - <Description>
- **`lint`** - <Description>
- **`test`** - <Description> (if applicable)
- **`build`** - <Description> (with dependencies: format → lint → test → build)

## Requirements

- <Tool> CLI: <Installation instructions>
- <Any other dependencies>

## Installation

### Option 1: Download from GitHub Releases (Recommended)

```powershell
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

### Option 2: Manual Copy (Development)

```powershell
Copy-Item -Path "packages/.build-<toolchain>/Invoke-*.ps1" -Destination ".build/" -Force
```

## Usage

```powershell
# Format files
.\bolt.ps1 format

# Lint/validate
.\bolt.ps1 lint

# Run tests
.\bolt.ps1 test

# Full build pipeline
.\bolt.ps1 build
```

## Configuration

Customize paths via `bolt.config.json`:

```json
{
  "<ToolchainPath>": "path/to/your/code"
}
```

Default: `tests/app/` (for backward compatibility with examples)

## Testing

Run package tests:

```powershell
.\Invoke-Tests.ps1 -Tag <Toolchain>-Tasks
```

## Example Application

See `tests/app/` for a working example.
```

#### 6. Update Test Infrastructure

Add your new tag to `Invoke-Tests.ps1`:

```powershell
# Update ValidateSet in both -Tag and -ExcludeTag parameters
[ValidateSet('Core', 'Security', 'Package-Bicep-Tasks', 'Package-Golang-Tasks', 'Package-Terraform-Tasks', '<Toolchain>-Tasks', ...)]

# Add to test discovery paths
$config.Run.Path = @(
    'tests'
    'packages/.build-bicep/tests'
    'packages/.build-golang/tests'
    'packages/.build-terraform/tests'
    'packages/.build-<toolchain>/tests'  # Add your package
)

# Update documentation comment
.PARAMETER Tag
    Run only tests with the specified tag(s). Available tags:
    - <Toolchain>-Tasks: <Toolchain> starter package tests (requires <Tool> CLI)

# Add discovery output
Write-Host "  - packages/.build-<toolchain>/tests/" -ForegroundColor Gray
```

#### 7. Update Documentation

**`packages/README.md`** - Add section for your starter:

```markdown
### `.build-<toolchain>` - <Toolchain> Starter Package

<Brief description>

**Included Tasks:**
- **`format`** - <Description>
- **`lint`** - <Description>
- **`build`** - <Description>

**Requirements:**
- <Tool> CLI: <Installation instructions>

**Installation:** (same as other packages)

**Usage:** (examples)

**Testing:**

**Non-Docker packages:**
```
Run tests with: `Invoke-Pester -Tag <Toolchain>-Tasks`
```

**Docker-only packages:**
```
Run tests with: `Invoke-Pester -Tag <Toolchain>-Docker-Tasks`
```


**Main `README.md`** - Add to "Available Package Starters" section (follow Bicep/Golang pattern)

**`CHANGELOG.md`** - Document in next release notes:

**For non-Docker package:**
```markdown
### Added
- **<Toolchain> Starter Package**: Complete workflow package (`packages/.build-<toolchain>`)
  - Tasks: format, lint, test, build
  - Configuration support via `bolt.config.json`
  - Cross-platform support
  - Test suite: XX tests tagged `<Toolchain>-Tasks`
```

**For Docker-only package:**
```markdown
### Added
- **<Toolchain> Docker Starter Package**: Containerized workflow package (`packages/.build-<toolchain>-docker`)
  - Tasks: format, lint, test, build (all via Docker)
  - Includes Dockerfile for custom image builds
  - Environment variable for image rebuild: `BOLT_<TOOLCHAIN>_DOCKER_REBUILD`
  - Cross-platform support (requires Docker with Linux containers)
  - Test suite: XX tests tagged `<Toolchain>-Docker-Tasks`
```

#### 8. Testing Checklist

Before submitting your PR:

- [ ] All task files have proper metadata (`# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`)
- [ ] External tool check implemented in each task
- [ ] Configuration support via `$BoltConfig.<ToolchainPath>`
- [ ] Explicit exit codes in all tasks (`exit 0` / `exit 1`)
- [ ] Color conventions followed (Cyan/Gray/Green/Red)
- [ ] Cross-platform path handling (use `Join-Path`)
- [ ] Release script creates proper archive and checksum
- [ ] Task validation tests pass (`Tasks.Tests.ps1`)
- [ ] Integration tests pass (`Integration.Tests.ps1`)
- [ ] Tests tagged with `<Toolchain>-Tasks`
- [ ] Package README documents all tasks and configuration
- [ ] Test infrastructure updated (`Invoke-Tests.ps1`)
- [ ] Main documentation updated (`README.md`, `packages/README.md`)
- [ ] Example application included in `tests/app/`
- [ ] All tests pass: `.\Invoke-Tests.ps1 -Tag <Toolchain>-Tasks`

#### 9. Reference Implementations

Study these existing packages as templates:

**Non-Docker Packages:**
- **Bicep Starter** (`packages/.build-bicep/`) - Infrastructure-as-Code toolchain (local CLI only, no Docker)
- **Golang Starter** (`packages/.build-golang/`) - Application development with testing (local CLI only)
- **TypeScript Starter** (`packages/.build-typescript/`) - Node.js/TypeScript development (local CLI only)

**Docker-Only Packages:**
- **TypeScript Docker Starter** (`packages/.build-typescript-docker/`) - Node.js/TypeScript via Docker containers
- **Python Docker Starter** (`packages/.build-python-docker/`) - Python development via Docker containers

All packages follow the same conventions and provide excellent examples of:
- Task structure and metadata
- External tool validation (local CLI for non-Docker, Docker for Docker-only)
- Configuration handling
- Test organization
- Documentation patterns

#### 10. Common Pitfalls to Avoid

- ❌ Forgetting explicit `exit` statements in tasks
- ❌ Hardcoding paths instead of using `$BoltConfig` and `Join-Path`
- ❌ Missing external tool availability checks
- ❌ Inconsistent color usage in output
- ❌ Not testing cross-platform (Windows, Linux, macOS)
- ❌ Forgetting to update `Invoke-Tests.ps1` validation sets
- ❌ Missing package-specific README
- ❌ Not providing example application in `tests/app/`
- ❌ Archive naming doesn't follow `bolt-starter-{toolchain}-{version}.zip` pattern
- ❌ **Non-Docker packages**: Including Docker references or fallback logic
- ❌ **Docker-only packages**: Missing Dockerfile or rebuild environment variable
- ❌ **Docker-only packages**: Not mentioning Linux containers requirement for Windows users

### Cross-Platform Guidelines

Bolt is **cross-platform by design**. Follow these patterns:

**Path Handling:**
```powershell
# ✅ GOOD - Use Join-Path
$iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
$mainFile = Join-Path $sourcePath "main.ext"

# ❌ BAD - Hardcoded path separators
$iacPath = "$PSScriptRoot\..\tests\iac"      # Windows-only
$iacPath = "$PSScriptRoot/../tests/iac"      # Works, but inconsistent
```

**File Discovery:**
```powershell
# ✅ GOOD - Use -Force for consistent behavior across platforms
$sourceFiles = Get-ChildItem -Path $sourcePath -Filter "*.ext" -Recurse -File -Force

# ❌ BAD - Missing -Force may behave differently on Linux
$sourceFiles = Get-ChildItem -Path $sourcePath -Filter "*.ext" -Recurse -File
```

**Key Principles:**
- Always use `Join-Path` for path construction
- Use `-Force` with `Get-ChildItem` when scanning directories
- Avoid platform-specific commands (e.g., `cmd.exe`, `bash` unless wrapped)
- Test on multiple platforms before submitting PRs

### Writing Tests

When adding new functionality, include Pester tests in the appropriate file:

**For core Bolt features** (use `-TaskDirectory` parameter with mock fixtures):
```powershell
# Add to tests/bolt.Tests.ps1
Describe "Your New Feature" -Tag 'Core' {
    It "Should do something correctly" {
        # Tests use -TaskDirectory to point to fixtures
        $result = Invoke-Bolt -Arguments @('mock-simple') `
                              -Parameters @{ TaskDirectory = 'tests/fixtures'; Only = $true }
        $result.ExitCode | Should -Be 0
    }
}
```

**Mock Fixtures Pattern:**
- Tests use `tests/fixtures/` directory containing mock tasks
- Tests explicitly pass `-TaskDirectory 'tests/fixtures'` parameter
- This achieves clean separation between production tasks and test infrastructure
- No need to copy fixtures - they're referenced directly

**For new tasks in Bicep starter package**:
```powershell
# Add to packages/.build-bicep/tests/Tasks.Tests.ps1
Describe "YourNewTask Task" -Tag 'Package-Bicep-Tasks' {
    It "Should exist" {
        $taskPath = Join-Path $moduleRoot "Invoke-YourNewTask.ps1"
        Test-Path $taskPath | Should -Be $true
    }
    
    It "Should have valid PowerShell syntax" {
        $content = Get-Content $taskPath -Raw -ErrorAction Stop
        { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
    }
}
```

Test your changes:
```powershell
# Via Bolt (tests the integration)
.\bolt.ps1 test

# Directly via Pester (tests bolt.ps1 itself)
Invoke-Pester

# Specific test file
Invoke-Pester -Path tests\bolt.Tests.ps1

# Quick core tests during development
Invoke-Pester -Tag Core
```

> **Important**: When modifying `bolt.ps1`, always test with `Invoke-Pester` directly to avoid circular dependency issues.

## Modifying Core Files

### bolt.ps1

The orchestrator rarely needs modification. If you think it does:

1. **Discuss first**: Open an issue to discuss the change
2. **Maintain backward compatibility**: Don't break existing task scripts
3. **Update documentation**: README.md, IMPLEMENTATION.md, copilot-instructions.md
4. **Test thoroughly**: Multi-task execution, dependency resolution, error handling

### Documentation

When updating documentation:

- **README.md**: User-facing quick start and usage guide
- **IMPLEMENTATION.md**: Technical details and feature documentation
- **.github/copilot-instructions.md**: AI agent context and architecture
- Keep all three in sync with code changes

## Pull Request Process

1. **Create a descriptive PR title**: "Add deploy task for Azure" not "Update files"
2. **Include context**: What problem does this solve? How did you test it?
3. **Update documentation**: If you add/change features
4. **Keep it focused**: One feature or fix per PR
5. **Follow conventions**: Match existing code style and patterns

## Questions?

- Open an issue for discussion
- Check existing issues and PRs first
- Be respectful and constructive

## Security

**Found a security vulnerability?**

Please **DO NOT** report security vulnerabilities through public GitHub issues.

Instead, report them via:
- **GitHub Security Advisories** (preferred): https://github.com/motowilliams/bolt/security/advisories/new
- **Security Policy**: See [SECURITY.md](SECURITY.md) for complete vulnerability disclosure process
- **RFC 9116 Policy**: See [.well-known/security.txt](.well-known/security.txt)

You should receive a response within 48 hours. For more details on our security process, response timelines, and coordinated disclosure policy, see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thanks for contributing to Bolt!** ⚡
