# Bolt Package Starters

This directory contains **package starters** - pre-built task collections for specific toolchains and workflows. Package starters provide ready-to-use task templates that you can install into your project's `.build/` directory.

## Available Package Starters

### `.build-bicep` - Bicep Starter Package

Infrastructure-as-Code tasks for Azure Bicep workflows.

**Included Tasks:**
- **`format`** - Formats Bicep files using `bicep format`
- **`lint`** - Validates Bicep syntax using `bicep lint`
- **`build`** - Compiles Bicep files to ARM JSON templates

**Requirements:**
- Azure Bicep CLI: `winget install Microsoft.Bicep` (Windows) or https://aka.ms/bicep-install

**Installation:**

**Option 1: Download from GitHub Releases (recommended)**
```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

**Option 2: Manual copy from source (for development)**
```powershell
# From your project root
Copy-Item -Path "packages/.build-bicep/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
# Format all Bicep files
.\bolt.ps1 format

# Validate Bicep syntax
.\bolt.ps1 lint

# Full build pipeline (format → lint → build)
.\bolt.ps1 build
```

**Testing:**
The Bicep starter package includes comprehensive tests:
- `packages/.build-bicep/tests/Tasks.Tests.ps1` - Task structure validation
- `packages/.build-bicep/tests/Integration.Tests.ps1` - End-to-end integration tests
- `packages/.build-bicep/tests/iac/` - Example infrastructure templates

Run tests with: `Invoke-Pester -Tag Bicep-Tasks`

### `.build-golang` - Golang Starter Package

Go application development tasks for building, testing, and formatting Go code.

**Included Tasks:**
- **`format`** - Formats Go files using `go fmt` (alias: `fmt`)
- **`lint`** - Validates Go code using `go vet`
- **`test`** - Runs Go tests using `go test`
- **`build`** - Builds Go application (depends on format, lint, test)

**Requirements:**
- Go 1.21+ CLI: https://go.dev/doc/install

**Installation:**

**Option 1: Download from GitHub Releases (recommended)**
```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

**Option 2: Manual copy from source (for development)**
```powershell
# From your project root
Copy-Item -Path "packages/.build-golang/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
# Format all Go files
.\bolt.ps1 format

# Lint Go code
.\bolt.ps1 lint

# Run tests
.\bolt.ps1 test

# Full build pipeline (format → lint → test → build)
.\bolt.ps1 build
```

**Testing:**
The Golang starter package includes comprehensive tests:
- `packages/.build-golang/tests/Tasks.Tests.ps1` - Task structure validation
- `packages/.build-golang/tests/Integration.Tests.ps1` - End-to-end integration tests
- `packages/.build-golang/tests/app/` - Example Go application

Run tests with: `Invoke-Pester -Tag Golang-Tasks`

### `.build-dotnet` - .NET (C#) Starter Package

.NET/C# application development tasks for building, testing, formatting, and restoring packages with Docker fallback support.

**Included Tasks:**
- **`format`** - Formats C# files using `dotnet format` (alias: `fmt`)
- **`restore`** - Restores NuGet packages using `dotnet restore`
- **`test`** - Runs .NET tests using `dotnet test`
- **`build`** - Builds .NET projects (depends on format, restore, test)

**Requirements:**
- .NET SDK 6.0+ (8.0+ recommended): https://dotnet.microsoft.com/download
  - **OR** Docker Engine: https://docs.docker.com/get-docker/ (automatic fallback)
- Tasks automatically use Docker if .NET SDK is not installed

**Installation:**

**Option 1: Download from GitHub Releases (recommended)**
```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

**Option 2: Manual copy from source (for development)**
```powershell
# From your project root
Copy-Item -Path "packages/.build-dotnet/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
# Format all C# files
.\bolt.ps1 format

# Restore NuGet packages
.\bolt.ps1 restore

# Run tests
.\bolt.ps1 test

# Full build pipeline (format → restore → test → build)
.\bolt.ps1 build
```

**Docker Fallback:**
If .NET SDK is not installed, tasks automatically use Docker:
```powershell
# No local .NET SDK? No problem!
.\bolt.ps1 format    # Uses Docker: mcr.microsoft.com/dotnet/sdk:10.0
.\bolt.ps1 build     # Automatically falls back to Docker
```

**Testing:**
The .NET starter package includes comprehensive tests:
- `packages/.build-dotnet/tests/Tasks.Tests.ps1` - Task structure validation
- `packages/.build-dotnet/tests/Integration.Tests.ps1` - End-to-end integration tests
- `packages/.build-dotnet/tests/app/` - Example .NET application with xUnit tests

Run tests with: `Invoke-Pester -Tag DotNet-Tasks`

### `.build-typescript` - TypeScript Starter Package

TypeScript/JavaScript application development tasks for building, testing, linting, and formatting with Docker fallback support.

**Included Tasks:**
- **`format`** - Formats TypeScript files using Prettier (alias: `fmt`)
- **`lint`** - Validates TypeScript code using ESLint
- **`test`** - Runs tests using Jest test runner
- **`build`** - Compiles TypeScript to JavaScript (depends on format, lint, test)

**Requirements:**
- Node.js 18+ with npm: https://nodejs.org/
  - **OR** Docker Engine: https://docs.docker.com/get-docker/ (automatic fallback)
- Tasks automatically use Docker if Node.js/npm is not installed

**Installation:**

**Option 1: Download from GitHub Releases (recommended)**
```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

**Option 2: Manual copy from source (for development)**
```powershell
# From your project root
Copy-Item -Path "packages/.build-typescript/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
# Format all TypeScript files
.\bolt.ps1 format

# Lint TypeScript code
.\bolt.ps1 lint

# Run tests
.\bolt.ps1 test

# Full build pipeline (format → lint → test → build)
.\bolt.ps1 build
```

**Docker Fallback:**
If Node.js/npm is not installed, tasks automatically use Docker:
```powershell
# No local Node.js? No problem!
.\bolt.ps1 format    # Uses Docker: node:22-alpine
.\bolt.ps1 build     # Automatically falls back to Docker
```

**Testing:**
The TypeScript starter package includes comprehensive tests:
- `packages/.build-typescript/tests/Tasks.Tests.ps1` - Task structure validation
- `packages/.build-typescript/tests/Integration.Tests.ps1` - End-to-end integration tests
- `packages/.build-typescript/tests/app/` - Example TypeScript application with Jest tests

Run tests with: `Invoke-Pester -Tag TypeScript-Tasks`

### `.build-python` - Python Starter Package

Python application development tasks for formatting, linting, testing, and building with Docker fallback support.

**Included Tasks:**
- **`format`** - Formats Python files using `black` (alias: `fmt`)
- **`lint`** - Validates Python code using `ruff`
- **`test`** - Runs tests using `pytest`
- **`build`** - Installs dependencies and validates package structure (depends on format, lint, test)

**Requirements:**
- Python 3.8+ (3.12 recommended): https://www.python.org/downloads/
  - **OR** Docker Engine: https://docs.docker.com/get-docker/ (automatic fallback)
- Tasks automatically use Docker if Python is not installed

**Installation:**

**Option 1: Download from GitHub Releases (recommended)**
```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

**Option 2: Manual copy from source (for development)**
```powershell
# From your project root
Copy-Item -Path "packages/.build-python/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
# Format all Python files
.\bolt.ps1 format

# Lint Python code
.\bolt.ps1 lint

# Run tests
.\bolt.ps1 test

# Full build pipeline (format → lint → test → build)
.\bolt.ps1 build
```

**Docker Fallback:**
If Python is not installed, tasks automatically use Docker:
```powershell
# No local Python? No problem!
.\bolt.ps1 format    # Uses Docker: python:3.12-slim
.\bolt.ps1 build     # Automatically falls back to Docker
```

**Testing:**
The Python starter package includes comprehensive tests:
- `packages/.build-python/tests/Tasks.Tests.ps1` - Task structure validation
- `packages/.build-python/tests/Integration.Tests.ps1` - End-to-end integration tests
- `packages/.build-python/tests/app/` - Example Python application with pytest tests

Run tests with: `Invoke-Pester -Tag Python-Tasks`

### `.build-terraform` - Terraform Starter Package

Infrastructure-as-Code tasks for Terraform workflows with Docker fallback support.

**Included Tasks:**
- **`format`** - Formats Terraform files using `terraform fmt` (alias: `fmt`)
- **`validate`** - Validates Terraform configuration syntax
- **`plan`** - Generates Terraform execution plan
- **`apply`** - Applies Terraform changes (alias: `deploy`)

**Requirements:**
- Terraform 1.0+ CLI: https://developer.hashicorp.com/terraform/downloads
  - **OR** Docker Engine: https://docs.docker.com/get-docker/ (automatic fallback)
- Tasks automatically use Docker if Terraform CLI is not installed

**Installation:**

**Option 1: Download from GitHub Releases (recommended)**
```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

**Option 2: Manual copy from source (for development)**
```powershell
# From your project root
Copy-Item -Path "packages/.build-terraform/Invoke-*.ps1" -Destination ".build/" -Force
```

**Usage:**
```powershell
# Format all Terraform files
.\bolt.ps1 format

# Validate Terraform configuration
.\bolt.ps1 validate

# Generate execution plan
.\bolt.ps1 plan

# Full apply pipeline (format → validate → plan → apply)
.\bolt.ps1 apply
```

**Docker Fallback:**
If Terraform CLI is not installed, tasks automatically use Docker:
```powershell
# No local Terraform? No problem!
.\bolt.ps1 format    # Uses Docker: hashicorp/terraform:latest
.\bolt.ps1 validate  # Automatically falls back to Docker
```

**Testing:**
The Terraform starter package includes comprehensive tests:
- `packages/.build-terraform/tests/Tasks.Tests.ps1` - Task structure validation
- `packages/.build-terraform/tests/Integration.Tests.ps1` - End-to-end integration tests
- `packages/.build-terraform/tests/tf/` - Example Terraform configuration

Run tests with: `Invoke-Pester -Tag Terraform-Tasks`

## Using Multiple Package Starters (Multi-Namespace)

**New in Bolt v0.6.0**: You can install multiple package starters simultaneously by organizing them as namespace subdirectories under `.build/`.

### Installation Pattern

Instead of copying tasks directly to `.build/`, create namespace subdirectories:

```powershell
# Create namespace subdirectories
New-Item -ItemType Directory -Path ".build/bicep" -Force
New-Item -ItemType Directory -Path ".build/golang" -Force

# Install Bicep package starter
Copy-Item -Path "packages/.build-bicep/Invoke-*.ps1" -Destination ".build/bicep/" -Force

# Install Golang package starter
Copy-Item -Path "packages/.build-golang/Invoke-*.ps1" -Destination ".build/golang/" -Force
```

### Task Naming with Namespaces

Tasks in namespace subdirectories are automatically prefixed:

**Directory structure:**
```
.build/
  ├── bicep/
  │   ├── Invoke-Lint.ps1     (TASK: lint)
  │   ├── Invoke-Format.ps1   (TASK: format)
  │   └── Invoke-Build.ps1    (TASK: build)
  └── golang/
      ├── Invoke-Lint.ps1     (TASK: lint)
      ├── Invoke-Test.ps1     (TASK: test)
      └── Invoke-Build.ps1    (TASK: build)
```

**Task names in Bolt:**
- `bicep-lint`, `bicep-format`, `bicep-build` (from `.build/bicep/`)
- `golang-lint`, `golang-test`, `golang-build` (from `.build/golang/`)

### Usage Example

```powershell
# List all tasks (shows both namespaces)
.\bolt.ps1 -ListTasks

# Run Bicep tasks
.\bolt.ps1 bicep-lint
.\bolt.ps1 bicep-build

# Run Golang tasks
.\bolt.ps1 golang-test
.\bolt.ps1 golang-build

# Create new namespaced tasks
.\bolt.ps1 -NewTask bicep-deploy      # Creates .build/bicep/Invoke-Deploy.ps1
.\bolt.ps1 -NewTask golang-benchmark  # Creates .build/golang/Invoke-Benchmark.ps1
```

### Benefits

- ✅ **No Conflicts**: Each namespace has its own tasks (no `lint` collision between Bicep and Golang)
- ✅ **Clear Organization**: Related tasks grouped by toolchain
- ✅ **Easy Management**: Add/remove toolchains by managing subdirectories
- ✅ **Smart Task Creation**: `-NewTask` automatically detects namespace from task name

### Backward Compatibility

Tasks in the root `.build/` directory (not in subdirectories) continue to work as before without namespace prefixes. This maintains full backward compatibility with existing projects.

## Creating Your Own Package Starter

Want to contribute a package starter? We provide comprehensive guidance:

### Quick Start

For AI-assisted development, use the package starter creation prompt:
```
See: .github/prompts/create-package-starter.prompt.md
```

### Detailed Development Guide

For complete developer guidelines, patterns, and requirements:
```
See: .github/instructions/package-starter-development.instructions.md
```

This comprehensive guide covers:
- Directory structure and file organization
- Task file requirements and metadata format
- Cross-platform compatibility requirements
- Testing patterns (structure and integration tests)
- Release script conventions
- Output formatting standards
- Common patterns and examples

### Quick Pattern Overview

1. **Create a directory**: `packages/.build-<toolchain>/`
2. **Add task files**: Follow the `Invoke-<TaskName>.ps1` naming convention
3. **Include metadata**: Add comment-based metadata (`# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`)
4. **Add tests**: Include `tests/` directory with Pester tests
5. **Document requirements**: Specify external tool dependencies
6. **Add examples**: Include sample files for testing
7. **Create release script**: Add `Create-Release.ps1` for automatic release packaging

### Reference Implementations

See existing package starters as examples:
- [`.build-bicep/`](.build-bicep/README.md) - Infrastructure-as-Code tasks for Azure Bicep
- [`.build-golang/`](.build-golang/README.md) - Go application development tasks

### Release Script Convention

To include your package starter in GitHub releases, add a `Create-Release.ps1` script:

```powershell
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

# Package task files into zip
# Generate SHA256 checksum
# Exit 0 on success, 1 on failure
```

**Requirements**:
- Accept `-Version` and `-OutputDirectory` parameters
- Create archive: `bolt-starter-{toolchain}-{version}.zip`
- Generate checksum: `bolt-starter-{toolchain}-{version}.zip.sha256`
- Exit with 0 on success, 1 on failure

**Example**: See `packages/.build-bicep/Create-Release.ps1`

When present, your package will be automatically built and included in GitHub releases with the same version as the main Bolt module.

## Package Starter vs. Project Tasks

- **Package Starters** (this directory): Reusable task collections for specific toolchains
  - Installed by copying to your project
  - Tested independently
  - Tool-specific (requires external CLI tools)
  
- **Project Tasks** (`.build/` in project root): Your custom tasks
  - Project-specific automation
  - Can use package starter tasks as dependencies
  - Can override package starter tasks

## External Tool Dependency Pattern

Package starters should check for required external tools before executing:

```powershell
# Example: Check for external CLI tool
$toolCmd = Get-Command <tool-name> -ErrorAction SilentlyContinue
if (-not $toolCmd) {
    Write-Error "<Tool> CLI not found. Please install: <installation-instructions>"
    exit 1
}
```

See `packages/.build-bicep/Invoke-Build.ps1` for a real-world example of this pattern.

## Contributing

We welcome contributions! If you've created a package starter for a popular toolchain:

1. Fork the repository
2. Create a new package starter directory under `packages/`
3. Follow the development guidelines: [.github/instructions/package-starter-development.instructions.md](../.github/instructions/package-starter-development.instructions.md)
4. Add comprehensive tests (structure and integration)
5. Update this README with your package starter
6. Submit a pull request

For general contribution guidelines, see [CONTRIBUTING.md](../CONTRIBUTING.md)

### Using the AI Prompt

For AI-assisted development, use: [.github/prompts/create-package-starter.prompt.md](../.github/prompts/create-package-starter.prompt.md)
