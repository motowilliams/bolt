# Bolt! ⚡

[![CI](https://github.com/motowilliams/bolt/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/bolt/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Cross-Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)]()

> **Lightning-fast Build Orchestration for PowerShell!**

A self-contained, **cross-platform** PowerShell build system with automatic task discovery and dependency resolution. Inspired by PSake, Make, and Rake. **Zero external dependencies** - just PowerShell 7.0+ with no additional tools required!

**Runs seamlessly on Windows, Linux, and macOS** - perfect for infrastructure-as-code, application builds, testing pipelines, deployment automation, and more.

## ✨ Key Features

- **🌍 Cross-Platform**: Works identically on Windows, Linux, and macOS with PowerShell Core
- **🚫 Zero Dependencies**: Just PowerShell 7.0+ required - no external tools or frameworks
- **🔍 Automatic Task Discovery**: Drop `Invoke-*.ps1` files in `.build/` with comment-based metadata - no registration needed
- **🔗 Smart Dependency Resolution**: Tasks declare dependencies that execute automatically in the correct order
- **📦 Package Starter Ecosystem**: Pre-built task collections for Python, Golang, TypeScript, dotnet, Terraform, and Bicep
- **⚡ Fast Iteration**: Skip dependencies with `-Only` flag for quick development cycles
- **📊 Task Visualization**: Preview execution plans with `-Outline` before running tasks

## 🚀 Quick Start

### Option 1: Script Mode (Quick Start)

Download and run Bolt directly without module installation:

```bash
# Download from GitHub Releases
# Visit https://github.com/motowilliams/bolt/releases
# Download the latest Bolt-X.Y.Z.zip and extract

# Navigate to extracted directory
$ cd path/to/bolt

# List available tasks
$ pwsh bolt.ps1 -Help

# Run your first build
$ pwsh bolt.ps1 build
```

Or use the quick install script (Windows/PowerShell):
```bash
# From PowerShell - downloads and extracts latest release
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download.ps1 | iex

# Then use directly
.\bolt.ps1 build
```

### Option 2: Module Mode (Recommended for Regular Use)

Install Bolt as a PowerShell module for global access from any directory:

```bash
# After downloading and extracting (see Option 1), install as module
$ cd path/to/bolt
$ pwsh New-BoltModule.ps1 -Install

# Restart your shell or force import
$ pwsh -Command "Import-Module Bolt -Force"

# Use 'bolt' command from anywhere
$ cd ~/projects/myproject
$ bolt build
```

Or clone from source (for development):
```bash
$ git clone https://github.com/motowilliams/bolt.git
$ cd bolt
$ pwsh New-BoltModule.ps1 -Install
```

### First Build

```bash
# List available tasks
$ bolt -Help

# Run your first build
$ bolt build

# Preview execution plan (no execution)
$ bolt build -Outline

# Skip dependencies for faster iteration
$ bolt build -Only
```

### Common Commands

```bash
# Basic usage
$ bolt build                    # Run task with dependencies
$ bolt format lint build        # Multiple tasks in sequence
$ bolt build -Only              # Skip dependencies

# Task management
$ bolt -ListTasks               # Show all available tasks
$ bolt -NewTask deploy          # Create new task template
$ bolt build -Outline           # Preview execution plan

# Configuration
$ bolt -ListVariables           # Show all config variables
$ bolt -AddVariable -Name "Environment" -Value "prod"
$ bolt -RemoveVariable -VariableName "OldSetting"

# Module mode works from any subdirectory
$ cd src/components/
$ bolt build                    # Automatically finds .build/ upward
```

**Module Benefits:**
- 🌍 Run `bolt` from any directory
- 🔍 Automatic upward search for `.build/` folders (like git)
- ⚡ Works from subdirectories within your projects
- 🔄 Easy updates: re-run `pwsh New-BoltModule.ps1 -Install`

### For Linux/Unix Users

**Why PowerShell for builds?** The pain point isn't Bash - it's **cross-platform consistency**.

Standard Unix tools like `sed`, `awk`, and `grep` have different behavior between macOS (BSD) and Linux (GNU). This creates subtle bugs when your build scripts work locally but fail in CI, or work on Ubuntu but break on CentOS.

**PowerShell guarantees identical behavior** on Linux, macOS, and Windows. Write once, run everywhere.

**Side-by-side comparison:**

```bash
# Bash with jq (realistic approach)
$ jq -r '.version' config.json
# Requires jq installation on all systems
# Another dependency to manage across environments

# PowerShell/Bolt tasks - JSON parsing built-in
$version = (Get-Content config.json | ConvertFrom-Json).version
# No external dependencies, works everywhere

# Real cross-platform pain point - in-place file editing
$ sed -i 's/old/new/g' file.txt        # Works on Linux (GNU sed)
$ sed -i '' 's/old/new/g' file.txt     # Required on macOS (BSD sed)
# Different syntax breaks scripts across platforms

# PowerShell/Bolt tasks - identical syntax everywhere
(Get-Content file.txt) -replace 'old','new' | Set-Content file.txt
# Same command on Windows, Linux, and macOS
```

**What Bolt gives you:**
- **Cross-platform consistency** - same syntax, same behavior across all platforms
- **Structured data** - work with JSON, arrays, hashtables as objects, not text
- **Type safety** - catch errors at script time, not runtime
- **Modern tooling** - IDE support with IntelliSense and debugging

**Bottom line**: PowerShell is available on all Linux distributions via package managers (apt, yum, snap). If cross-platform builds matter to your team, Bolt eliminates "works on my machine" issues.

## 📚 Documentation

### Core Documentation

- **[Usage Guide](docs/usage.md)** - Parameter sets, creating tasks, task execution behaviors, configuration management
- **[Architecture](docs/architecture.md)** - Internal logic flows, design philosophy, and intentional limitations
- **[Testing](docs/testing.md)** - Running tests, test coverage, CI/CD integration
- **[Ecosystem](docs/ecosystem.md)** - Package starters, module installation, manifest generation
- **[Security](docs/security.md)** - Security features, event logging, vulnerability reporting

### Additional Resources

- **[IMPLEMENTATION.md](IMPLEMENTATION.md)** - Detailed feature documentation and examples
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines and development practices
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[SECURITY.md](SECURITY.md)** - Complete security documentation and vulnerability reporting

## 📦 Package Starters

Pre-built task collections for popular toolchains:

| Package | Included Tasks | Requirements |
|---------|---------------|-------------|
| **[Python](packages/.build-python/README.md)** | format, lint, test, build | Python 3.8+ or Docker |
| **[Golang](packages/.build-golang/README.md)** | format, lint, test, build | Go 1.21+ or Docker |
| **[TypeScript](packages/.build-typescript/README.md)** | format, lint, test, build | Node.js 18+ or Docker |
| **[dotnet](packages/.build-dotnet/README.md)** | format, restore, test, build | .NET SDK 6.0+ or Docker |
| **[Terraform](packages/.build-terraform/README.md)** | format, validate, plan, apply | Terraform CLI or Docker |
| **[Bicep](packages/.build-bicep/README.md)** | format, lint, build | Bicep CLI |

**Install package starters:**
```bash
# Interactive installer (Windows/PowerShell)
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex

# Manual installation (cross-platform)
$ pwsh -Command "Copy-Item -Path 'packages/.build-python/Invoke-*.ps1' -Destination '.build/' -Force"
```

See [packages/README.md](packages/README.md) for complete package starter documentation.

**Want to create your own?** See [Package Starter Development Guide](.github/instructions/package-starter-development.instructions.md)

## 🏗️ Example Workflows

### Full Build Pipeline

```bash
# Format, lint, and compile with automatic dependencies
$ bolt build

# Execution: format → lint → build
```

### Development Iteration

```bash
# Fix formatting
$ bolt format

# Validate syntax
$ bolt lint

# Quick rebuild without re-running format/lint
$ bolt build -Only
```

### CI/CD Integration

```bash
# Same command works locally and in CI
$ bolt build
```

**GitHub Actions example:**
```yaml
steps:
  - uses: actions/checkout@v4
  - name: Install PowerShell
    run: |
      # Ubuntu/Debian
      sudo apt-get update
      sudo apt-get install -y powershell
  - name: Build
    run: bolt build
```

**Alternative - Direct script invocation:**
```yaml
steps:
  - uses: actions/checkout@v4
  - name: Build
    run: pwsh -File bolt.ps1 build
```

See [docs/testing.md](docs/testing.md) for complete CI/CD integration examples.

## 🛠️ Creating Tasks

### Quick Method

```bash
# Generate task with proper structure
$ bolt -NewTask deploy
# Creates: .build/Invoke-Deploy.ps1 with metadata template
```

### Manual Method

Create a PowerShell script in `.build/` directory with task metadata:

```powershell
# .build/Invoke-Deploy.ps1
# TASK: deploy
# DESCRIPTION: Deploys infrastructure to Azure
# DEPENDS: build

Write-Host "Deploying..." -ForegroundColor Cyan
# Your deployment logic here
exit 0  # Explicit exit code required
```

**Task discovery is automatic** - no registration needed! Restart shell for tab completion.

See [docs/usage.md](docs/usage.md) for detailed task creation guide.

## 🔧 Requirements

- **PowerShell 7.0+** (cross-platform)
- **Git** (optional, for `check-index` task)
- **Package starter tools** (optional, e.g., Bicep CLI for Bicep tasks)

Install PowerShell 7: https://aka.ms/powershell

## 🎨 Output Formatting

All tasks use consistent color coding:

- **Cyan**: Task headers
- **Gray**: Progress/details
- **Green**: Success (✓)
- **Yellow**: Warnings (⚠)
- **Red**: Errors (✗)

## 🐛 Troubleshooting

### Module: Tab completion not working

**Solution**: Restart your shell after installing the module or manually import:
```bash
$ pwsh -Command "Import-Module Bolt -Force"
```

### Module: Can't find .build directory

**Solution**: Ensure you're within a project that has a `.build/` folder somewhere in the directory tree. Module searches upward from current directory.

### Task not found

**Solution**: Check task file exists in `.build/` with proper metadata:
```bash
$ bolt -ListTasks  # Verify task appears in list
```

### External tool not found (e.g., Python, Go)

**Solution**: Install the required tool for your package starter:
```bash
# Example for Python
$ sudo apt install python3 python3-pip  # Ubuntu/Debian
$ brew install python3                  # macOS

# Example for Go
$ sudo apt install golang-go            # Ubuntu/Debian
$ brew install go                       # macOS

# See package starter README for other platforms
```

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions welcome! This is a self-contained build system - keep it simple and dependency-free.

**Before contributing**: Please read our [No Hallucinations Policy](.github/NO-HALLUCINATIONS-POLICY.md) to ensure all documentation is accurate and verified.

### Quick Start for Contributors

1. **Keep `bolt.ps1`**: The orchestrator rarely needs modification
2. **Modify tasks in `.build/`**: Edit existing tasks or add new ones
3. **Install package starters**: Use pre-built collections for your toolchain
4. **Update configuration**: Edit `bolt.config.json` for project settings

See [CONTRIBUTING.md](CONTRIBUTING.md) for complete guidelines.

### Contributing Package Starters

Create package starters for popular toolchains:
- **AI-assisted creation**: [`.github/prompts/create-package-starter.prompt.md`](.github/prompts/create-package-starter.prompt.md)
- **Developer guidelines**: [`.github/instructions/package-starter-development.instructions.md`](.github/instructions/package-starter-development.instructions.md)
- **Package examples**: [`packages/README.md`](packages/README.md)

## 🔄 Continuous Integration

Bolt includes automated CI/CD with GitHub Actions:

- **Platforms**: Ubuntu (Linux) and Windows
- **Pipeline**: Core tests → Package tests → Full build
- **Status**: [![CI](https://github.com/motowilliams/bolt/actions/workflows/ci.yml/badge.svg)](https://github.com/motowilliams/bolt/actions/workflows/ci.yml)

See [docs/testing.md](docs/testing.md) for CI/CD integration details.

### Running CI Locally

```powershell
# Install dependencies
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run tests (same as CI)
Invoke-Pester -Tag Core           # Fast tests (~1s)
Invoke-Pester -Tag Security       # Security tests (~10s)
Invoke-Pester                     # All tests

# Run build pipeline (same as CI)
bolt build
```

## 📦 Releases

Automated releases via GitHub Actions when tags are pushed.

**Install from releases:**
1. Download from [GitHub Releases](https://github.com/motowilliams/bolt/releases)
2. Verify checksum (SHA256 file provided)
3. Extract and install as module: `pwsh New-BoltModule.ps1 -Install`

**Release types:**
- **Production**: `v1.0.0`, `v2.1.0` (stable, recommended)
- **Pre-release**: `v1.0.0-beta`, `v2.0.0-rc1` (early access)

See [docs/ecosystem.md](docs/ecosystem.md) for detailed release information.

## 🔒 Security

Bolt implements comprehensive security measures:

- **Input Validation**: Task names, paths, and parameters
- **Path Sanitization**: Directory traversal protection
- **Output Validation**: ANSI escape sequence and control character filtering
- **Audit Logging**: Opt-in security event logging

**Report vulnerabilities** via [GitHub Security Advisories](https://github.com/motowilliams/bolt/security/advisories/new).

See [docs/security.md](docs/security.md) and [SECURITY.md](SECURITY.md) for complete security documentation.

---

**Lightning fast builds with Bolt!** ⚡
