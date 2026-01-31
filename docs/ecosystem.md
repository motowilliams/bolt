# Bolt Ecosystem

This document describes Bolt's package starter system, module installation, and manifest generation tools.

## 📦 Package Starters

**Package starters** are pre-built task collections for specific toolchains and workflows. They provide ready-to-use task templates that you can install into your project's `.build/` directory.

### Available Package Starters

#### Python Starter Package

Python application development tasks for formatting, linting, testing, and building with Docker fallback support.

**Included Tasks:** `format` (alias `fmt`), `lint`, `test`, `build`

**Requirements:** Python 3.8+ ([Installation](https://www.python.org/downloads/)) or Docker ([Installation](https://docs.docker.com/get-docker/))

See [packages/.build-python/README.md](../packages/.build-python/README.md) for detailed documentation, installation instructions, and usage examples.

#### Golang Starter Package

Go application development tasks for building, testing, and formatting Go code with Docker fallback support.

**Included Tasks:** `format` (alias `fmt`), `lint`, `test`, `build`

**Requirements:** Go 1.21+ CLI ([Installation](https://go.dev/doc/install)) or Docker ([Installation](https://docs.docker.com/get-docker/))

See [packages/.build-golang/README.md](../packages/.build-golang/README.md) for detailed documentation, installation instructions, and usage examples.

#### TypeScript Starter Package

TypeScript/JavaScript application development tasks with automatic Docker fallback.

**Included Tasks:** `format` (alias `fmt`), `lint`, `test`, `build`

**Requirements:** Node.js 18+ with npm ([Installation](https://nodejs.org/)) or Docker ([Installation](https://docs.docker.com/get-docker/))

See [packages/.build-typescript/README.md](../packages/.build-typescript/README.md) for detailed documentation, installation instructions, and usage examples.

#### .NET (C#) Starter Package

.NET/C# application development tasks with automatic Docker fallback.

**Included Tasks:** `format` (alias `fmt`), `restore`, `test`, `build`

**Requirements:** .NET SDK 6.0+ ([Installation](https://dotnet.microsoft.com/download)) or Docker ([Installation](https://docs.docker.com/get-docker/))

See [packages/.build-dotnet/README.md](../packages/.build-dotnet/README.md) for detailed documentation, installation instructions, and usage examples.

#### Terraform Starter Package

Infrastructure-as-Code tasks for Terraform workflows with automatic Docker fallback.

**Included Tasks:** `format` (alias `fmt`), `validate`, `plan`, `apply` (alias `deploy`)

**Requirements:** Terraform CLI ([Installation](https://developer.hashicorp.com/terraform/downloads)) or Docker ([Installation](https://docs.docker.com/get-docker/))

See [packages/.build-terraform/README.md](../packages/.build-terraform/README.md) for detailed documentation, installation instructions, and usage examples.

#### Bicep Starter Package

Infrastructure-as-Code tasks for Azure Bicep workflows.

**Included Tasks:** `format`, `lint`, `build`

**Requirements:** Azure Bicep CLI ([Installation](https://aka.ms/bicep-install))

See [packages/.build-bicep/README.md](../packages/.build-bicep/README.md) for detailed documentation, installation instructions, and usage examples.

See [`packages/README.md`](../packages/README.md) for details on available package starters.

**Want to create your own package starter?** See the comprehensive guides:
- **For AI-assisted development**: [`.github/prompts/create-package-starter.prompt.md`](../.github/prompts/create-package-starter.prompt.md)
- **For developer guidelines**: [`.github/instructions/package-starter-development.instructions.md`](../.github/instructions/package-starter-development.instructions.md)
- **Package details**: [`packages/README.md`](../packages/README.md#creating-your-own-package-starter)

### Using Multiple Package Starters (Multi-Namespace)

**New in v0.6.0**: You can now use multiple package starters simultaneously in the same project by organizing them in namespace subdirectories under `.build/`.

**Directory Structure:**
```
.build/
  ├── bicep/              # Bicep tasks
  │   ├── Invoke-Lint.ps1
  │   ├── Invoke-Format.ps1
  │   └── Invoke-Build.ps1
  └── golang/             # Golang tasks
      ├── Invoke-Lint.ps1
      ├── Invoke-Test.ps1
      └── Invoke-Build.ps1
```

**Installation:**
```powershell
# Create namespace subdirectories
New-Item -ItemType Directory -Path ".build/bicep" -Force
New-Item -ItemType Directory -Path ".build/golang" -Force

# Install Bicep tasks
Copy-Item -Path "packages/.build-bicep/Invoke-*.ps1" -Destination ".build/bicep/" -Force

# Install Golang tasks  
Copy-Item -Path "packages/.build-golang/Invoke-*.ps1" -Destination ".build/golang/" -Force
```

**Task Naming:**
Tasks are automatically prefixed with their namespace to prevent conflicts:
```powershell
# List all tasks - shows namespace prefixes
.\bolt.ps1 -ListTasks

# Output:
#   bicep-build [project:bicep]
#     Compiles Bicep to ARM JSON
#   bicep-format [project:bicep]
#     Formats Bicep files
#   bicep-lint [project:bicep]
#     Lints Bicep files
#   golang-build [project:golang]
#     Builds Go application
#   golang-lint [project:golang]
#     Lints Go code
#   golang-test [project:golang]
#     Runs Go tests
```

**Usage:**
```powershell
# Run Bicep tasks
.\bolt.ps1 bicep-lint
.\bolt.ps1 bicep-build

# Run Golang tasks
.\bolt.ps1 golang-test
.\bolt.ps1 golang-build

# Create new namespaced tasks (auto-detects namespace)
.\bolt.ps1 -NewTask bicep-deploy      # Creates .build/bicep/Invoke-Deploy.ps1
.\bolt.ps1 -NewTask golang-benchmark  # Creates .build/golang/Invoke-Benchmark.ps1
```

**Benefits:**
- ✅ Use Bicep for infrastructure AND Golang for application code in the same repo
- ✅ No task name conflicts between packages (automatic prefixing)
- ✅ Clear separation of concerns by namespace
- ✅ Works with tab completion and all Bolt features

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
- **Core script** (`bolt.ps1`) - Copy of bolt.ps1

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

---

[← Back to README](../README.md)
