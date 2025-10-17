# Gosh! 🎉

> **Go** + **Shell** = **Gosh!**  
> Build orchestration for PowerShell

A self-contained PowerShell build system with extensible task orchestration and automatic dependency resolution. No external dependencies required—just PowerShell 7.0+.

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
│   ├── Invoke-Build.ps1
│   ├── Invoke-Format.ps1
│   └── Invoke-Lint.ps1
└── iac/                        # Infrastructure as Code
    ├── main.bicep
    └── modules/
```

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

- **Format Task**: Runs `bicep format` on all `.bicep` files
- **Lint Task**: Validates with `bicep lint`, captures diagnostics
- **Build Task**: Compiles `main*.bicep` files to ARM JSON

### Bicep Integration

```powershell
.\gosh.ps1 build
# Runs: format → lint → compile
```

## 🏗️ Example: Full Build Pipeline

```powershell
# Format, lint, and compile in one command
.\gosh.ps1 build

# Or run steps individually
.\gosh.ps1 format
.\gosh.ps1 lint
.\gosh.ps1 build -Only  # Skip format/lint
```

## 📖 Philosophy

**Local-First Principle (90/10 Rule)**: Tasks run identically locally and in CI.

- Same commands work everywhere
- No special CI flags or branches
- Consistent tooling and deterministic behavior
- Pipeline-agnostic design (GitHub Actions, Azure DevOps, GitLab CI, etc.)

### CI/CD Example

```yaml
# Works with any CI platform
- name: Build
  run: pwsh -File gosh.ps1 build
  
- name: Test  
  run: pwsh -File gosh.ps1 test
```

## 🧪 Testing

Uses **Pester** for PowerShell testing. Test files follow `*.Tests.ps1` pattern.

```powershell
.\gosh.ps1 test  # Coming soon!
```

## 🔧 Requirements

- PowerShell 7.0+
- Azure Bicep CLI (for infrastructure tasks)
- Git (for `check-index` task)

## 🎨 Output Formatting

All tasks use consistent color coding:

- **Cyan**: Task headers
- **Gray**: Progress/details
- **Green**: Success (✓)
- **Yellow**: Warnings (⚠)
- **Red**: Errors (✗)

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions welcome! This is a self-contained build system—keep it simple and dependency-free.

## 💡 Why "Gosh"?

**Go** (the entry point) + **Shell** (PowerShell) = **Gosh!**

It's also a natural exclamation when your builds succeed! 🎉

---

**Gosh, that was easy!** ✨
