---
agent: agent
---

# Create New Package Starter for Bolt

You are tasked with creating a new package starter for the Bolt build system. Package starters are pre-built task collections for specific toolchains that users can install into their projects.

## Context

Review the existing package starters for reference:
- `packages/.build-bicep/` - Infrastructure-as-Code tasks for Azure Bicep (local CLI only)
- `packages/.build-golang/` - Go application development tasks (local CLI only)
- `packages/.build-typescript-docker/` - TypeScript Docker tasks (Docker only)
- `packages/.build-python-docker/` - Python Docker tasks (Docker only)

Read the package starter development guidelines at `.github/instructions/package-starter-development.instructions.md` for detailed patterns and requirements.

## ⚠️ CRITICAL: TESTING IS MANDATORY

**ZERO TOLERANCE for code without tests. This policy is strictly enforced.**

### Required Testing

Every package starter MUST include:

1. **`tests/Tasks.Tests.ps1`** - Task structure validation (MANDATORY)
   - Verify all task files exist
   - Validate PowerShell syntax in each task
   - Check task metadata (TASK, DESCRIPTION, DEPENDS)
   - Test task aliases

2. **`tests/Integration.Tests.ps1`** - End-to-end execution tests (MANDATORY)
   - Check external tool/Docker availability
   - Execute each task and verify exit codes
   - Test task dependencies and execution order
   - Validate output artifacts are created

3. **`tests/app/`** - Example application for testing (MANDATORY)
   - Real-world sample files for the toolchain
   - Must be runnable by the tasks
   - Should demonstrate common patterns

### No Exceptions

- ❌ **DO NOT** create package starters without comprehensive tests
- ❌ **DO NOT** skip test creation "to save time" or "add later"
- ❌ **DO NOT** create placeholder test files with no assertions
- ✅ **DO** test on multiple platforms when possible
- ✅ **DO** include BeforeAll/AfterAll cleanup logic
- ✅ **DO** use proper Pester tags for test filtering

**If you create a package starter without tests, it WILL be rejected.**

## Package Starter Types

Bolt supports TWO types of package starters:

### 1. Non-Docker Packages (Preferred)

**Pattern**: `packages/.build-[toolchain]/`

**Use when**: The toolchain has a well-supported local CLI that's easy to install.

**Characteristics**:
- Requires local tool installation (e.g., Go, Node.js, .NET SDK)
- No Docker references or fallback logic
- Simpler task scripts (just detect tool and execute)
- Faster execution (no container overhead)
- Better developer experience (local debugging, native IDE integration)

**Example**: `.build-bicep`, `.build-golang`, `.build-typescript`

### 2. Docker-Only Packages (Alternative)

**Pattern**: `packages/.build-[toolchain]-docker/`

**Use when**: Users prefer containerized builds or want to avoid local tool installation.

**Characteristics**:
- Requires Docker with Linux containers (important on Windows)
- Includes sibling `Dockerfile` for custom image builds
- Environment variable to force image rebuild (e.g., `BOLT_TYPESCRIPT_DOCKER_REBUILD=1`)
- All tasks execute via `docker run` commands
- No local CLI detection or fallback logic

**Example**: `.build-typescript-docker`, `.build-python-docker`, `.build-golang-docker`

### When to Create Both Variants

For popular toolchains (TypeScript, Python, Go, .NET, Terraform), create BOTH:
1. Non-Docker variant for local development
2. Docker variant for containerized workflows

For specialized tools (Bicep, etc.), create only the variant that makes sense.

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

**For Non-Docker Packages:**

Include this pattern at the start of each task:

```powershell
# Check for configured tool path first
if ($BoltConfig.ToolPathProperty) {
    $toolPath = $BoltConfig.ToolPathProperty
    if (-not (Test-Path -Path $toolPath -PathType Leaf)) {
        Write-Error "Tool not found at configured path: $toolPath. Please check ToolPathProperty in bolt.config.json or install Tool"
        exit 1
    }
    $toolCmd = $toolPath
}
else {
    # Fall back to PATH search
    $toolCmdObj = Get-Command [tool-name] -ErrorAction SilentlyContinue
    if (-not $toolCmdObj) {
        Write-Error "Tool CLI not found. Please install Tool: [installation-url] or configure ToolPathProperty in bolt.config.json"
        exit 1
    }
    $toolCmd = "[tool-name]"
}
```

**For Docker-Only Packages:**

Include Docker detection and Dockerfile-based image building:

```powershell
# Check Docker availability
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Error "Docker not found. Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
}

# Check for custom image rebuild via environment variable
$rebuildImage = $env:BOLT_TOOLCHAIN_DOCKER_REBUILD -eq '1'

if ($rebuildImage) {
    Write-Host "  Rebuilding Docker image..." -ForegroundColor Gray
    $dockerfilePath = Join-Path $PSScriptRoot "Dockerfile"
    & docker build -t bolt-toolchain-local -f $dockerfilePath . 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Docker image"
        exit 1
    }
    $imageName = "bolt-toolchain-local"
}
else {
    $imageName = "official/image:tag"
}

# Execute via Docker
& docker run --rm -v "${absolutePath}:/project" -w /project $imageName [command]
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

**For Non-Docker Packages:**
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

**For Docker-Only Packages:**
```powershell
Describe "[Toolchain] Docker Package Starter - Integration Tests" -Tag "[Toolchain]-Docker-Tasks" {
    BeforeAll {
        # Check for Docker availability
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            Set-ItResult -Skipped -Because "Docker not installed"
        }
    }
    
    It "format task should execute successfully via Docker" { }
    It "lint task should validate files via Docker" { }
    It "build task should complete pipeline via Docker" { }
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

**For Non-Docker Packages:**
```markdown
# [Toolchain] Starter Package for Bolt

[Brief description of what this package provides]

## Requirements

- [Tool] [version]+: [installation URL]
- PowerShell 7.0+

## Installation

See main [packages/README.md](../README.md) for installation options.

## Included Tasks

- **format** (alias: fmt) - [description]
- **lint** - [description]
- **test** - [description]
- **build** - [description]

## Configuration

By default, tasks look for [toolchain] code in `tests/[path]/` directory. To use a custom path, create a `bolt.config.json`:

\`\`\`json
{
  "[Toolchain]Path": "src/"
}
\`\`\`

## Usage

[Examples of common workflows]

## Testing

[How to run the test suite]
```

**For Docker-Only Packages:**
```markdown
# [Toolchain] Docker Starter Package for Bolt

[Brief description - emphasize Docker-only execution]

## Requirements

- Docker: https://docs.docker.com/get-docker/
- PowerShell 7.0+

**Important**: On Windows, this requires Linux containers. Ensure Docker Desktop is configured for Linux containers.

## Installation

See main [packages/README.md](../README.md) for installation options.

## Included Tasks

- **format** (alias: fmt) - [description] (via Docker)
- **lint** - [description] (via Docker)
- **test** - [description] (via Docker)
- **build** - [description] (via Docker)

## Custom Docker Image

To use a custom Dockerfile-based image instead of the pre-built image:

\`\`\`powershell
$env:BOLT_[TOOLCHAIN]_DOCKER_REBUILD = '1'
.\bolt.ps1 build
\`\`\`

This builds the image from the included `Dockerfile` before executing tasks.

## Usage

[Examples of common workflows - all via Docker]

## Testing

[How to run the test suite]
```
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

   **For Non-Docker Package:**
   ```markdown
   #### [Toolchain] Starter Package

   [Brief description of what the package provides]

   **Included Tasks:** `format` (alias `fmt`), `lint`, `test`, `build`

   **Requirements:** [Tool] [version]+ ([Installation](installation-url))

   See [packages/.build-[toolchain]/README.md](packages/.build-[toolchain]/README.md) for detailed documentation, installation instructions, and usage examples.
   ```

   **For Docker-Only Package:**
   ```markdown
   #### [Toolchain] Docker Starter Package

   [Brief description - emphasize containerized execution]

   **Included Tasks:** `format` (alias `fmt`), `lint`, `test`, `build` (all via Docker)

   **Requirements:** Docker ([Installation](https://docs.docker.com/get-docker/)) with Linux containers

   See [packages/.build-[toolchain]-docker/README.md](packages/.build-[toolchain]-docker/README.md) for detailed documentation, installation instructions, and usage examples.
   ```

2. **Add entry to `packages/README.md`** under "Available Package Starters"

3. **Update `Invoke-Tests.ps1`** to add the new tag(s) to ValidateSet and test discovery paths:
   - Non-Docker: Add `[Toolchain]-Tasks` tag
   - Docker-Only: Add `[Toolchain]-Docker-Tasks` tag

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

**STOP**: Do NOT submit without completing ALL items below. Testing is NON-NEGOTIABLE.

### 🔴 CRITICAL (Must Pass) - Testing

- [ ] **`tests/Tasks.Tests.ps1` exists and has comprehensive assertions**
  - [ ] Tests for every task file (format, lint, test, build, etc.)
  - [ ] PowerShell syntax validation for each task
  - [ ] Metadata validation (TASK, DESCRIPTION, DEPENDS)
  - [ ] Alias validation where applicable
  - [ ] At least 15+ test assertions minimum

- [ ] **`tests/Integration.Tests.ps1` exists and executes real tasks**
  - [ ] BeforeAll checks for tool/Docker availability
  - [ ] Tests skip gracefully if tool not installed (use `Set-ItResult -Skipped`)
  - [ ] Each task executed with `-Only` flag
  - [ ] Exit codes verified ($LASTEXITCODE -eq 0)
  - [ ] Output artifacts validated (dist/, build/, bin/, etc.)
  - [ ] Full pipeline test with dependencies
  - [ ] At least 5+ integration test assertions minimum

- [ ] **`tests/app/` directory exists with example files**
  - [ ] Real-world sample code for the toolchain
  - [ ] Files are actually processed by tasks (not empty placeholders)
  - [ ] Demonstrates common patterns and best practices

- [ ] **All tests pass locally**: `Invoke-Pester -Path "packages/.build-[toolchain]/tests" -Output Detailed`

- [ ] **Appropriate Pester tag applied**: `[Toolchain]-Tasks` or `[Toolchain]-Docker-Tasks`

### 🟡 IMPORTANT - Code Quality

- [ ] All task files include proper metadata
- [ ] External tool checks are in place (local CLI for non-Docker, Docker for Docker-only)
- [ ] Output formatting follows Bolt standards (Cyan/Gray/Green/Yellow/Red)
- [ ] Dependencies are properly declared
- [ ] Error handling uses explicit exit codes
- [ ] No Unix commands used (use PowerShell cmdlets)
- [ ] Cross-platform path handling (use `Join-Path`)

### 🟢 REQUIRED - Package-Specific

- [ ] **Non-Docker packages**: No Docker references anywhere
- [ ] **Docker-only packages**: Include Dockerfile and rebuild env var
- [ ] Release script creates valid archives and SHA256 checksums
- [ ] Documentation is complete and accurate
- [ ] Cross-platform compatibility verified (preferably tested on Windows + Linux/macOS)

### 🔵 REQUIRED - Project Updates

- [ ] Main `README.md` updated with package starter section(s)
- [ ] Main `packages/README.md` updated with package entry/entries
- [ ] `Invoke-Tests.ps1` updated with new tag(s) in ValidateSet and test discovery paths
- [ ] `.gitignore` updated if toolchain generates artifacts
- [ ] `CHANGELOG.md` updated with package details

**Remember**: A package starter without tests is incomplete and will not be merged.

## Additional Notes

- Keep tasks focused and single-purpose
- Use descriptive error messages
- Follow existing package starter patterns
- Test with real-world project examples
- Document external tool version requirements
