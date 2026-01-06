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

## More Package Starters Coming Soon

We're working on additional package starters for popular toolchains:

- **TypeScript** - Build, lint, and test TypeScript projects
- **Python** - Format (black/ruff), lint (pylint/flake8), test (pytest)
- **Node.js** - Build, lint (ESLint), test (Jest/Mocha)
- **Docker** - Build, tag, push container images
- **Terraform** - Format, validate, plan infrastructure

## Creating Your Own Package Starter

Want to contribute a package starter? Here's the pattern:

1. **Create a directory**: `packages/.build-<toolchain>/`
2. **Add task files**: Follow the `Invoke-<TaskName>.ps1` naming convention
3. **Include metadata**: Add comment-based metadata (`# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`)
4. **Add tests**: Include `tests/` directory with Pester tests
5. **Document requirements**: Specify external tool dependencies
6. **Add examples**: Include sample files for testing
7. **Create release script** (optional): Add `Create-Release.ps1` for automatic release packaging

See `.build-bicep/` as a reference implementation.

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
3. Add comprehensive tests
4. Update this README with your package starter
5. Submit a pull request

For guidelines, see [CONTRIBUTING.md](../CONTRIBUTING.md)
