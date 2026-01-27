---
agent: agent
---

# Create New Package Starter for Bolt

You are tasked with creating a new package starter for the Bolt build system. Package starters are pre-built task collections for specific toolchains that users can install into their projects.

## Context

Review the existing package starters for reference:
- `packages/.build-bicep/` - Infrastructure-as-Code tasks for Azure Bicep
- `packages/.build-golang/` - Go application development tasks

Read the package starter development guidelines at `.github/instructions/package-starter-development.instructions.md` for detailed patterns and requirements.

## Your Task

Create a new package starter for: **[TOOLCHAIN_NAME]**

## Requirements

### 1. Directory Structure

Create: `packages/.build-[toolchain]/`

Include:
- `Invoke-*.ps1` - Task scripts with proper metadata
- `tests/Tasks.Tests.ps1` - Task structure validation tests
- `tests/Integration.Tests.ps1` - End-to-end integration tests
- `tests/[example-project]/` - Sample files for testing
- `Create-Release.ps1` - Release packaging script
- `README.md` - Package-specific documentation

### 2. Task Files

Each task file must:
- Follow `Invoke-<TaskName>.ps1` naming convention
- Include comment-based metadata:
  ```powershell
  # TASK: taskname, alias1, alias2
  # DESCRIPTION: Clear description of what the task does
  # DEPENDS: dependency1, dependency2
  ```
- Check for external tool availability before execution
- Use consistent error handling with explicit exit codes
- Follow Bolt output formatting standards (Cyan/Gray/Green/Yellow/Red)
- Use PowerShell cmdlets (not Unix commands) for cross-platform compatibility

### 3. Common Tasks Pattern

Most package starters should include:
- **format** (alias: fmt) - Format source files
- **lint** - Validate source files for errors
- **test** - Run tests
- **build** - Build artifacts (depends on format, lint, test)

### 4. External Tool Dependency Check

Include this pattern at the start of each task:

```powershell
$toolCmd = Get-Command [tool-name] -ErrorAction SilentlyContinue
if (-not $toolCmd) {
    Write-Error "[Tool] CLI not found. Please install: [installation-instructions]"
    exit 1
}
```

### 5. Testing Requirements

Create comprehensive Pester tests:

**Tasks.Tests.ps1** - Validate task structure:
```powershell
Describe "[Toolchain] Package Starter - Task Validation" -Tag "[Toolchain]-Tasks" {
    Context "Task Structure" {
        It "format task should exist" { }
        It "lint task should exist" { }
        It "build task should exist" { }
    }
    
    Context "Task Metadata" {
        It "format task should have proper metadata" { }
        It "build task should declare dependencies" { }
    }
}
```

**Integration.Tests.ps1** - End-to-end testing:
```powershell
Describe "[Toolchain] Package Starter - Integration Tests" -Tag "[Toolchain]-Tasks" {
    BeforeAll {
        # Check for tool availability
        $toolCmd = Get-Command [tool-name] -ErrorAction SilentlyContinue
        if (-not $toolCmd) {
            Set-ItResult -Skipped -Because "[Tool] CLI not installed"
        }
    }
    
    It "format task should execute successfully" { }
    It "lint task should validate files" { }
    It "build task should complete pipeline" { }
}
```

### 6. Release Script

Create `Create-Release.ps1`:

```powershell
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release"
)

# 1. Validate files exist
# 2. Create release directory
# 3. Copy task files to temp directory
# 4. Create zip: bolt-starter-[toolchain]-[version].zip
# 5. Generate SHA256: bolt-starter-[toolchain]-[version].zip.sha256
# 6. Exit 0 on success, 1 on failure
```

### 7. Documentation

Create package-specific `README.md`:

```markdown
# [Toolchain] Starter Package for Bolt

[Brief description of what this package provides]

## Requirements

- [Tool] [version]+: [installation instructions]

## Installation

See main [packages/README.md](../README.md) for installation options.

## Included Tasks

- **format** - [description]
- **lint** - [description]
- **test** - [description]
- **build** - [description]

## Usage

[Examples of common workflows]

## Testing

[How to run the test suite]
```

### 8. Update Main Documentation

After creating the package starter:

1. **Add entry to main `README.md`** under "Available Package Starters" section (around line 266):
   ```markdown
   #### [Toolchain] Starter Package

   [Brief description of what the package provides]

   **Included Tasks:** `format` (alias `fmt`), `lint`, `test`, `build`

   **Requirements:** [Tool] [version]+ ([Installation](installation-url)) or Docker ([Installation](https://docs.docker.com/get-docker/))

   See [packages/.build-[toolchain]/README.md](packages/.build-[toolchain]/README.md) for detailed documentation, installation instructions, and usage examples.
   ```

2. **Add entry to `packages/README.md`** under "Available Package Starters"

3. **Update `Invoke-Tests.ps1`** to add the new tag to ValidateSet and test discovery paths

4. **Update `.gitignore`** if the toolchain generates build artifacts (follow pattern of other package starters with section header and comments)

5. **Update `CHANGELOG.md`** under `[Unreleased]` section

6. **Update `.github/copilot-instructions.md`** if toolchain-specific patterns are needed

## Cross-Platform Requirements

- Use `Join-Path` for all path construction
- Use PowerShell cmdlets (Get-ChildItem, Select-String, Where-Object)
- Never use Unix commands (grep, tail, cat, ls, find)
- Use `-Force` with Get-ChildItem for hidden files/directories
- Test on Windows, Linux, and macOS when possible

## Example Workflow

```powershell
# User installs your package starter
.\Download-Starter.ps1
# Or: Copy-Item -Path "packages/.build-[toolchain]/Invoke-*.ps1" -Destination ".build/" -Force

# User runs tasks
.\bolt.ps1 format
.\bolt.ps1 lint
.\bolt.ps1 build

# Tasks execute with proper dependencies and error handling
```

## Validation Checklist

Before submitting:
- [ ] All task files include proper metadata
- [ ] External tool checks are in place
- [ ] Tests pass with tag `[Toolchain]-Tasks`
- [ ] Release script creates valid archives
- [ ] Documentation is complete and accurate
- [ ] Cross-platform compatibility verified
- [ ] Output formatting follows Bolt standards
- [ ] Dependencies are properly declared
- [ ] Error handling uses explicit exit codes
- [ ] No Unix commands used
- [ ] Main `README.md` updated with package starter section
- [ ] Main `packages/README.md` updated with package entry
- [ ] `Invoke-Tests.ps1` updated with new tag
- [ ] `.gitignore` updated if toolchain generates artifacts
- [ ] `CHANGELOG.md` updated

## Additional Notes

- Keep tasks focused and single-purpose
- Use descriptive error messages
- Follow existing package starter patterns
- Test with real-world project examples
- Document external tool version requirements
