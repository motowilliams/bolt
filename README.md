# Gosh! 🎉

> **Go** + **Shell** = **Gosh!**  
> Build orchestration for PowerShell

A self-contained PowerShell build system with extensible task orchestration and automatic dependency resolution. Inspired by Make and Rake, but pure PowerShell with no external dependencies—just PowerShell 7.0+.

**Perfect for Azure Bicep infrastructure projects**, but flexible enough for any PowerShell workflow.

## ✨ Features

- **🔍 Automatic Task Discovery**: Drop `.ps1` files in `.build/` with comment-based metadata
- **🔗 Dependency Resolution**: Tasks declare dependencies via `# DEPENDS:` header
- **🚫 Circular Dependency Prevention**: Tracks executed tasks to prevent infinite loops
- **✅ Exit Code Propagation**: Proper CI/CD integration via `$LASTEXITCODE`
- **📋 Multiple Task Support**: Run tasks in sequence (space or comma-separated)
- **⏩ Skip Dependencies**: Use `-Only` flag for faster iteration
- **🎯 Tab Completion**: Task names auto-complete in PowerShell
- **🎨 Colorized Output**: Consistent, readable task output

## 🚀 Quick Start

### Installation

1. Clone or download this repository
2. Ensure PowerShell 7.0+ is installed
3. Install Azure Bicep CLI: `winget install Microsoft.Bicep`
4. Navigate to the project directory

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

```powershell
# List available tasks
.\gosh.ps1 -Help

# Run a single task (with dependencies)
.\gosh.ps1 build

# Run multiple tasks in sequence
.\gosh.ps1 format lint build

# Skip dependencies for faster iteration
.\gosh.ps1 build -Only

# Run multiple tasks without dependencies
.\gosh.ps1 format lint build -Only
```

## 📁 Project Structure

```
.
├── gosh.ps1                    # Main orchestrator
├── .build/                     # Task scripts
│   ├── Invoke-Build.ps1        # Compile Bicep to ARM JSON
│   ├── Invoke-Format.ps1       # Format Bicep files
│   └── Invoke-Lint.ps1         # Validate Bicep syntax
├── iac/                        # Infrastructure as Code
│   ├── main.bicep              # Main infrastructure template
│   ├── main.parameters.json    # Production parameters
│   ├── main.dev.parameters.json # Development parameters
│   └── modules/                # Reusable Bicep modules
│       ├── app-service-plan.bicep
│       ├── web-app.bicep
│       └── sql-server.bicep
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

Create a PowerShell script in `.build/` with metadata:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploys infrastructure to Azure
# DEPENDS: build

param()

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
  - Runs in-place formatting on all `.bicep` files in `iac/`
  - Use `-Check` flag to validate without modifying files
  - Reports which files need formatting
  
- **`lint`**: Validates Bicep syntax using `bicep lint`
  - Captures and displays errors and warnings with line numbers
  - Parses diagnostics in format: `path(line,col) : Level rule-name: message`
  - Fails if any errors are found
  
- **`build`**: Compiles Bicep to ARM JSON templates
  - Only compiles `main*.bicep` files (e.g., `main.bicep`, `main.dev.bicep`)
  - Module files in `iac/modules/` are referenced, not compiled directly
  - Output `.json` files placed alongside source `.bicep` files
  - Depends on: `format`, `lint` (runs automatically)

### Usage Examples

```powershell
# Full pipeline: format → lint → build
.\gosh.ps1 build

# Check formatting without making changes
.\gosh.ps1 format -Check

# Individual steps
.\gosh.ps1 format      # Format all files
.\gosh.ps1 lint        # Validate syntax
.\gosh.ps1 build -Only # Compile only (skip format/lint)
```

### Bicep CLI Integration

All tasks use the official Azure Bicep CLI:
- `bicep format` - Code formatting
- `bicep lint` - Syntax validation  
- `bicep build` - ARM template compilation

Install: `winget install Microsoft.Bicep` or https://aka.ms/bicep-install

## 🏗️ Example Workflows

### Full Build Pipeline

```powershell
# Format, lint, and compile in one command
.\gosh.ps1 build

# Run with dependency chain: format → lint → build
```

### Development Iteration

```powershell
# Quick format check (no file modifications)
.\gosh.ps1 format -Check

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
# Check formatting in CI (fail if not pre-formatted)
.\gosh.ps1 format -Check

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

Uses **Pester** for PowerShell testing. Test files follow `*.Tests.ps1` pattern.

```powershell
# Run all tests (coming soon!)
.\gosh.ps1 test

# Or run Pester directly
Invoke-Pester
```

### Creating Tests

```powershell
# .build/Invoke-Build.Tests.ps1
Describe "Build Task" {
    It "Should find main.bicep files" {
        $files = Get-ChildItem -Path "iac" -Filter "main*.bicep" -File
        $files.Count | Should -BeGreaterThan 0
    }
}
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

## 🐛 Troubleshooting

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

### Customizing for Your Project

1. **Keep `gosh.ps1`**: The orchestrator rarely needs modification
2. **Modify tasks in `.build/`**: Edit existing tasks or add new ones
3. **Update infrastructure in `iac/`**: Replace with your own Bicep modules
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
az deployment group create --resource-group "rg-$Environment" --template-file "iac/main.json"

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
- Include `param()` block even if no parameters
- Add metadata comments: `# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`

## 💡 Why "Gosh"?

**Go** (the entry point) + **Shell** (PowerShell) = **Gosh!**

It's also a natural exclamation when your builds succeed! 🎉

### Design Goals

- **Zero external dependencies**: Just PowerShell 7.0+ and your tools (Bicep, Git, etc.)
- **Self-contained**: Single `gosh.ps1` file orchestrates everything
- **Convention over configuration**: Drop tasks in `.build/`, they're discovered automatically
- **Developer-friendly**: Tab completion, colorized output, helpful error messages
- **CI/CD ready**: Exit codes, deterministic behavior, no special flags

---

**Gosh, that was easy!** ✨
