---
applyTo: 'packages/.build-*/**'
name: package-starter-development
description: Guidelines for developing new package starters for Bolt. Use when creating or modifying package starter task collections for specific toolchains.
---

# Package Starter Development Guidelines

This guide provides comprehensive instructions for creating new package starters for the Bolt build system.

## What is a Package Starter?

A **package starter** is a pre-built collection of task scripts for a specific toolchain or workflow. Package starters:
- Provide ready-to-use task templates
- Follow consistent patterns and conventions
- Include comprehensive tests
- Support both single and multi-namespace installations
- Can be released independently of core Bolt

## When to Create a Package Starter

Create a package starter when:
- The toolchain is widely used (TypeScript, Python, Docker, etc.)
- Common workflows benefit from standardization (format → lint → test → build)
- External CLI tools provide the functionality (bicep, go, tsc, etc.)
- The tasks would be reused across multiple projects

## Directory Structure

Each package starter follows this structure:

```
packages/.build-[toolchain]/
├── Invoke-Format.ps1           # Format task
├── Invoke-Lint.ps1             # Validation task
├── Invoke-Test.ps1             # Testing task (if applicable)
├── Invoke-Build.ps1            # Build task (main pipeline)
├── Create-Release.ps1          # Release packaging script
├── README.md                   # Package-specific documentation
└── tests/
    ├── Tasks.Tests.ps1         # Task structure validation
    ├── Integration.Tests.ps1   # End-to-end integration tests
    └── [example-project]/      # Sample files for testing
        ├── source files
        └── test fixtures
```

## Task File Requirements

### Naming Convention

Use `Invoke-<TaskName>.ps1` pattern where TaskName is PascalCase:
- `Invoke-Format.ps1` - Format source files
- `Invoke-Lint.ps1` - Validate source files
- `Invoke-Test.ps1` - Run tests
- `Invoke-Build.ps1` - Build artifacts

### Comment-Based Metadata

Every task must include metadata in the first 30 lines:

```powershell
# TASK: taskname, alias1, alias2
# DESCRIPTION: Clear, concise description of what the task does
# DEPENDS: dependency1, dependency2
```

**Examples:**

```powershell
# TASK: format, fmt
# DESCRIPTION: Formats Go files using go fmt
# DEPENDS:

# TASK: build
# DESCRIPTION: Compiles Go application
# DEPENDS: format, lint, test
```

### External Tool Validation

Always check for required external tools:

```powershell
#Requires -Version 7.0

# Check for required CLI tool
$toolCmd = Get-Command [tool-name] -ErrorAction SilentlyContinue
if (-not $toolCmd) {
    Write-Error "[Tool] CLI not found. Please install: [installation-url]"
    exit 1
}
```

**Real-world example from Bicep starter:**

```powershell
$bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
if (-not $bicepCmd) {
    Write-Error "Bicep CLI not found. Please install: https://aka.ms/bicep-install"
    exit 1
}
```

### Task Structure Pattern

Follow this structure for consistency:

```powershell
#Requires -Version 7.0

# TASK: taskname, alias
# DESCRIPTION: What this task does
# DEPENDS: dependency1, dependency2

# ===== External Tool Check =====
$toolCmd = Get-Command [tool] -ErrorAction SilentlyContinue
if (-not $toolCmd) {
    Write-Error "[Tool] not found. Install: [url]"
    exit 1
}

# ===== Task Header =====
Write-Host "[Action] files..." -ForegroundColor Cyan

# ===== Discover Files =====
$files = Get-ChildItem -Path $PSScriptRoot/.. -Recurse -Filter "*.[ext]" -File -Force

if ($files.Count -eq 0) {
    Write-Host "No files found to process" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($files.Count) file(s)" -ForegroundColor Gray
Write-Host ""

# ===== Process Files =====
$success = $true
foreach ($file in $files) {
    Write-Host "  Processing: $($file.Name)" -ForegroundColor Gray
    
    # Execute tool command
    & [tool] [args] $file.FullName 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ $($file.Name) processed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ $($file.Name) failed" -ForegroundColor Red
        $success = $false
    }
}

# ===== Report Results =====
Write-Host ""
if (-not $success) {
    Write-Host "✗ Task completed with errors" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All files processed successfully!" -ForegroundColor Green
exit 0
```

### Error Handling

Always use explicit exit codes:
- `exit 0` - Success
- `exit 1` - Failure

Track overall success and fail fast when appropriate:

```powershell
$success = $true
foreach ($file in $files) {
    # Process file
    if ($LASTEXITCODE -ne 0) {
        $success = $false
    }
}

if (-not $success) {
    Write-Host "✗ Task failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Task succeeded" -ForegroundColor Green
exit 0
```

### Output Formatting

Use consistent color coding:
- **Cyan** - Task headers
- **Gray** - Progress/details
- **Green** - Success (with ✓)
- **Yellow** - Warnings (with ⚠)
- **Red** - Errors (with ✗)

**Example:**

```powershell
Write-Host "Building application..." -ForegroundColor Cyan
Write-Host "  Compiling: main.go" -ForegroundColor Gray
Write-Host "    ✓ Compilation successful" -ForegroundColor Green
Write-Host "    ⚠ Warning: unused variable" -ForegroundColor Yellow
Write-Host "    ✗ Error: syntax error" -ForegroundColor Red
```

### Cross-Platform Compatibility

**CRITICAL**: Package starters must work on Windows, Linux, and macOS.

**Use PowerShell cmdlets, not Unix commands:**

```powershell
# ✅ CORRECT - Cross-platform
$files = Get-ChildItem -Path $path -Filter "*.go" -Recurse -File -Force
$content = Get-Content -Path $file -First 10

# ❌ WRONG - Unix-only
$files = Get-ChildItem $path | grep "*.go"
$content = cat $file | head -10
```

**Use Join-Path for all path construction:**

```powershell
# ✅ CORRECT - Cross-platform
$sourcePath = Join-Path $PSScriptRoot ".." "src"
$testPath = Join-Path $sourcePath "tests"

# ❌ WRONG - Windows-only
$sourcePath = "$PSScriptRoot\..\src"
$testPath = "$sourcePath\tests"
```

## Testing Requirements

### Task Structure Tests

Create `tests/Tasks.Tests.ps1` to validate task structure:

```powershell
#Requires -Version 7.0

Describe "[Toolchain] Package Starter - Task Validation" -Tag "[Toolchain]-Tasks" {
    BeforeAll {
        $packagePath = Join-Path $PSScriptRoot ".."
        $taskFiles = Get-ChildItem -Path $packagePath -Filter "Invoke-*.ps1" -File -Force
    }

    Context "Task Files Exist" {
        It "format task should exist" {
            $formatTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Format.ps1" }
            $formatTask | Should -Not -BeNullOrEmpty
        }

        It "lint task should exist" {
            $lintTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Lint.ps1" }
            $lintTask | Should -Not -BeNullOrEmpty
        }

        It "build task should exist" {
            $buildTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Build.ps1" }
            $buildTask | Should -Not -BeNullOrEmpty
        }
    }

    Context "Task Metadata" {
        It "format task should have TASK metadata" {
            $content = Get-Content -Path "$packagePath/Invoke-Format.ps1" -First 30 -Raw
            $content | Should -Match "# TASK:"
        }

        It "build task should declare dependencies" {
            $content = Get-Content -Path "$packagePath/Invoke-Build.ps1" -First 30 -Raw
            $content | Should -Match "# DEPENDS:"
        }
    }
}
```

### Integration Tests

Create `tests/Integration.Tests.ps1` for end-to-end testing:

```powershell
#Requires -Version 7.0

Describe "[Toolchain] Package Starter - Integration Tests" -Tag "[Toolchain]-Tasks" {
    BeforeAll {
        # Check for tool availability
        $toolCmd = Get-Command [tool-name] -ErrorAction SilentlyContinue
        if (-not $toolCmd) {
            Set-ItResult -Skipped -Because "[Tool] CLI not installed"
        }

        $packagePath = Join-Path $PSScriptRoot ".."
        $testProjectPath = Join-Path $PSScriptRoot "[example-project]"
    }

    Context "Format Task" {
        It "should format files successfully" {
            $formatScript = Join-Path $packagePath "Invoke-Format.ps1"
            & $formatScript
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Lint Task" {
        It "should validate files successfully" {
            $lintScript = Join-Path $packagePath "Invoke-Lint.ps1"
            & $lintScript
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Build Task" {
        It "should complete build pipeline" {
            $buildScript = Join-Path $packagePath "Invoke-Build.ps1"
            & $buildScript
            $LASTEXITCODE | Should -Be 0
        }
    }
}
```

### Test Tags

Use consistent tags for test filtering:
- `[Toolchain]-Tasks` - For package-specific tests
- Examples: `Bicep-Tasks`, `Golang-Tasks`, `TypeScript-Tasks`

This allows:
```powershell
Invoke-Pester -Tag Bicep-Tasks    # Only Bicep tests
Invoke-Pester -Tag Golang-Tasks   # Only Golang tests
```

## Release Script Pattern

Create `Create-Release.ps1` for automated release packaging:

```powershell
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

# Validate version format (SemVer)
if ($Version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$') {
    Write-Error "Invalid version format. Use SemVer (e.g., 1.0.0 or 1.0.0-beta)"
    exit 1
}

# Define package name
$toolchain = "[toolchain]"  # e.g., "bicep", "golang"
$packageName = "bolt-starter-$toolchain-$Version"
$zipFile = "$packageName.zip"
$checksumFile = "$zipFile.sha256"

# Create release directory
$releaseDir = New-Item -Path $OutputDirectory -ItemType Directory -Force
$tempDir = Join-Path $releaseDir "temp-$packageName"
New-Item -Path $tempDir -ItemType Directory -Force

try {
    # Copy task files
    $taskFiles = Get-ChildItem -Path $PSScriptRoot -Filter "Invoke-*.ps1" -File
    foreach ($file in $taskFiles) {
        Copy-Item -Path $file.FullName -Destination $tempDir -Force
    }

    # Create zip archive
    $zipPath = Join-Path $releaseDir $zipFile
    Compress-Archive -Path "$tempDir/*" -DestinationPath $zipPath -Force

    # Generate SHA256 checksum
    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    $checksumPath = Join-Path $releaseDir $checksumFile
    "$hash  $zipFile" | Out-File -FilePath $checksumPath -Encoding ASCII -NoNewline

    Write-Host "✓ Created: $zipFile" -ForegroundColor Green
    Write-Host "✓ Created: $checksumFile" -ForegroundColor Green
    Write-Host "  SHA256: $hash" -ForegroundColor Gray

    exit 0
}
catch {
    Write-Error "Release creation failed: $_"
    exit 1
}
finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}
```

## Package-Specific Documentation

Create `README.md` in package directory:

```markdown
# [Toolchain] Starter Package for Bolt

[Brief description of what this package provides]

## Requirements

- [Tool] [version]+
  - **Windows**: [installation command]
  - **Linux**: [installation command]
  - **macOS**: [installation command]

## Installation

See main [packages/README.md](../README.md) for installation options.

### Quick Install

```powershell
# Interactive download and install
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex

# Or manual copy from source
Copy-Item -Path "packages/.build-[toolchain]/Invoke-*.ps1" -Destination ".build/" -Force
```

## Included Tasks

- **format** (alias: fmt) - [description]
- **lint** - [description]
- **test** - [description]
- **build** - [description]

## Usage

```powershell
# Format files
.\bolt.ps1 format

# Validate syntax
.\bolt.ps1 lint

# Run tests
.\bolt.ps1 test

# Full build pipeline (format → lint → test → build)
.\bolt.ps1 build
```

## Task Dependencies

- `build` depends on: `format`, `lint`, `test`
- `test` depends on: `format`, `lint`
- `lint` depends on: `format`

## Testing

Run the test suite:

```powershell
# Install Pester if needed
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run package tests
Invoke-Pester -Tag [Toolchain]-Tasks
```

## Examples

[Provide real-world examples of common workflows]

## Troubleshooting

### Tool Not Found

If you get "[Tool] CLI not found" error:
1. Install [Tool]: [installation instructions]
2. Verify installation: `[tool] --version`
3. Restart PowerShell session

### Files Not Discovered

Tasks search from parent directory of script location. Ensure your files are in the expected structure.
```

## Multi-Namespace Support

Package starters can be used in multi-namespace mode:

### Installation Pattern

```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/[toolchain]" -Force

# Install tasks
Copy-Item -Path "packages/.build-[toolchain]/Invoke-*.ps1" -Destination ".build/[toolchain]/" -Force
```

### Task Naming

Tasks in namespace subdirectories are automatically prefixed:
- `.build/bicep/Invoke-Lint.ps1` → `bicep-lint`
- `.build/golang/Invoke-Build.ps1` → `golang-build`

### Namespace-Aware Dependencies

When declaring dependencies in namespace subdirectories:

```powershell
# .build/bicep/Invoke-Build.ps1
# TASK: build
# DEPENDS: format, lint

# Dependencies resolve as:
# - bicep-format (same namespace, priority)
# - bicep-lint (same namespace, priority)
# - format (fallback if namespace version doesn't exist)
# - lint (fallback if namespace version doesn't exist)
```

**Key Rule**: Dependencies within the same namespace are resolved first, providing proper isolation.

## Integration with Bolt Core

### How Tasks Are Discovered

1. Bolt scans `.build/` directory (or custom via `-TaskDirectory`)
2. Finds all `Invoke-*.ps1` files
3. Reads first 30 lines for metadata
4. Registers tasks with names from `# TASK:` header
5. Builds dependency graph from `# DEPENDS:` declarations

### Task Execution

1. User runs: `.\bolt.ps1 build`
2. Bolt resolves dependencies: `format` → `lint` → `build`
3. Executes each task in order
4. Tracks executed tasks to prevent duplicate execution
5. Checks `$LASTEXITCODE` after each task
6. Stops on first failure (exit code 1)

### Tab Completion

Tasks auto-complete in PowerShell:
- Restart shell after adding new tasks
- Works in both script mode and module mode
- Namespace-aware (shows `bicep-format`, `golang-lint`, etc.)

## Common Patterns

### Recursive File Discovery

```powershell
# Find all source files recursively
$files = Get-ChildItem -Path $rootPath -Recurse -Filter "*.[ext]" -File -Force

# Exclude certain directories
$files = Get-ChildItem -Path $rootPath -Recurse -Filter "*.[ext]" -File -Force |
         Where-Object { $_.FullName -notmatch 'node_modules|vendor|bin|obj' }
```

### Conditional Compilation

```powershell
# Only compile main files, not modules
$files = Get-ChildItem -Path $rootPath -Recurse -Filter "*.bicep" -File -Force |
         Where-Object { $_.Name -match '^main.*\.bicep$' }
```

### Progress Reporting

```powershell
$i = 0
$total = $files.Count
foreach ($file in $files) {
    $i++
    Write-Host "  [$i/$total] Processing: $($file.Name)" -ForegroundColor Gray
    # Process file
}
```

### Capturing Tool Output

```powershell
# Capture both stdout and stderr
$output = & [tool] [args] $file.FullName 2>&1

# Parse output for diagnostics
$errors = $output | Where-Object { $_ -match 'error|failed' }
if ($errors) {
    foreach ($error in $errors) {
        Write-Host "    ✗ $error" -ForegroundColor Red
    }
}
```

## Checklist for New Package Starters

Before submitting a pull request:

- [ ] Directory structure follows convention
- [ ] All task files use `Invoke-*.ps1` naming
- [ ] Comment-based metadata included in all tasks
- [ ] External tool checks are in place
- [ ] Error handling uses explicit exit codes
- [ ] Output formatting uses Bolt color standards
- [ ] Cross-platform compatibility (no Unix commands)
- [ ] Path construction uses `Join-Path`
- [ ] Tests include both structure and integration tests
- [ ] Test tags use `[Toolchain]-Tasks` pattern
- [ ] Release script creates valid archives
- [ ] Package-specific README.md is complete
- [ ] Main packages/README.md updated with new entry
- [ ] Example project files included for testing
- [ ] Dependencies declared correctly
- [ ] Namespace-aware if in subdirectory
- [ ] All tests pass: `Invoke-Pester -Tag [Toolchain]-Tasks`

## Resources

- **Reference Implementations**: Review existing package starters in `packages/`
- **Bolt Core**: See `bolt.ps1` for task discovery and execution logic
- **Main Documentation**: packages/README.md, README.md, IMPLEMENTATION.md
- **Testing Guide**: CONTRIBUTING.md
- **Copilot Instructions**: .github/copilot-instructions.md

## Getting Help

- Review existing package starters as examples
- Read Bolt core documentation for task patterns
- Test with real-world project examples
- Ask questions in GitHub issues or discussions

## Contributing

We welcome new package starters! Follow this guide and submit a pull request. Ensure:
1. Code is tested and working
2. Documentation is complete
3. Cross-platform compatibility verified
4. Existing patterns are followed
