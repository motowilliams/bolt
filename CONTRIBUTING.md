# Contributing to Bolt

Thank you for considering contributing to Bolt! 🎉

## ⚠️ Important: No Hallucinations Policy

**Before contributing any documentation or code**: Please read our [No Hallucinations Policy](.github/NO-HALLUCINATIONS-POLICY.md). 

**Key requirement**: Never create fictional URLs, endpoints, or features. Always verify information exists before documenting it.

## Project Philosophy

**Keep it simple, keep it self-contained.** Bolt is designed to have zero external dependencies beyond PowerShell 7.0+ and the tools your tasks use (Bicep, Git, etc.).

## Getting Started

1. **Fork and clone** the repository
2. **Install prerequisites**:
   - PowerShell 7.0+
   - Azure Bicep CLI: `winget install Microsoft.Bicep`
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
- Use files (write/read from disk)
- Use environment variables (`$env:VARIABLE_NAME`)
- Use module-level variables (if using advanced patterns)
- Design tasks as independent operations, not pipelines

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

**Recommended pattern**: Use environment variables, configuration files, or `$env:` variables for dynamic task behavior rather than parameters.

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

### Code Style

- **PowerShell**: 4-space indentation, OTBS style
- **Bicep**: 2-space indentation (enforced by bicep format)
- **Comments**: Use descriptive comments for complex logic
- **Naming**: Use PascalCase for functions, camelCase for variables

### Testing

Before submitting changes:

- **Run the test suite**: `Invoke-Pester` to ensure all tests pass (267 tests)
- **Use test tags for faster feedback**:
  - `Invoke-Pester -Tag Core` - Quick orchestration tests (28 tests, ~1s)
  - `Invoke-Pester -Tag Security` - Security validation tests (205 tests, ~10s)
  - `Invoke-Pester -Tag Bicep-Tasks` - Bicep task validation tests (16 tests, ~22s)
- **Test tasks individually**: Verify your task works standalone
- **Test with dependencies**: Check dependency resolution and `-Only` flag
- **Test with custom directories**: Verify `-TaskDirectory` parameter works correctly
- **Verify exit codes**: Ensure tasks return 0 for success, 1 for failure
- **Test cross-platform**: All changes should work on Windows, Linux, and macOS with PowerShell Core
- **Add new tests**: Choose the appropriate test file:
  - **Core orchestration changes** → `tests/bolt.Tests.ps1` (uses mock fixtures, tag with `Core`)
  - **Security changes** → `tests/security/Security.Tests.ps1` (validates security fixes, tag with `Security`)
  - **New Bicep tasks** → `packages/.build-bicep/tests/Tasks.Tests.ps1` (validates task structure, tag with `Bicep-Tasks`)
  - **Bicep integrations** → `packages/.build-bicep/tests/Integration.Tests.ps1` (requires Bicep CLI, tag with `Bicep-Tasks`)

### Cross-Platform Guidelines

Bolt is **cross-platform by design**. Follow these patterns:

**Path Handling:**
```powershell
# ✅ GOOD - Use Join-Path
$iacPath = Join-Path $PSScriptRoot ".." "tests" "iac"
$mainFile = Join-Path $iacPath "main.bicep"

# ❌ BAD - Hardcoded path separators
$iacPath = "$PSScriptRoot\..\tests\iac"      # Windows-only
$iacPath = "$PSScriptRoot/../tests/iac"      # Works, but inconsistent
```

**File Discovery:**
```powershell
# ✅ GOOD - Use -Force for consistent behavior across platforms
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "*.bicep" -Recurse -File -Force

# ❌ BAD - Missing -Force may behave differently on Linux
$bicepFiles = Get-ChildItem -Path $iacPath -Filter "*.bicep" -Recurse -File
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

**For new Bicep tasks**:
```powershell
# Add to packages/.build-bicep/tests/Tasks.Tests.ps1
Describe "YourNewTask Task" -Tag 'Bicep-Tasks' {
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
