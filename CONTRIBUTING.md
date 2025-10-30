# Contributing to Gosh

Thank you for considering contributing to Gosh! 🎉

## Project Philosophy

**Keep it simple, keep it self-contained.** Gosh is designed to have zero external dependencies beyond PowerShell 7.0+ and the tools your tasks use (Bicep, Git, etc.).

## Getting Started

1. **Fork and clone** the repository
2. **Install prerequisites**:
   - PowerShell 7.0+
   - Azure Bicep CLI: `winget install Microsoft.Bicep`
3. **Make your changes** following the guidelines below
4. **Test locally**: Run `.\gosh.ps1 build` to ensure everything works
5. **Submit a pull request**

## Development Guidelines

### Task Development

When creating or modifying tasks in `.build/`:

- ✅ **Use explicit exit codes**: `exit 0` (success) or `exit 1` (failure)
- ✅ **Include metadata**: `# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`
- ✅ **Follow color conventions**:
  - Cyan: Task headers
  - Gray: Progress/details
  - Green: Success (✓)
  - Yellow: Warnings (⚠)
  - Red: Errors (✗)
- ✅ **Check $LASTEXITCODE**: After external commands
- ✅ **Use descriptive variable names**: Avoid `$Task` (collides with gosh.ps1)
- ✅ **Only use param() if needed**: Include only if your task accepts parameters

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
  - **Core orchestration changes** → `tests/gosh.Tests.ps1` (uses mock fixtures, tag with `Core`)
  - **Security changes** → `tests/security/Security.Tests.ps1` (validates security fixes, tag with `Security`)
  - **New Bicep tasks** → `packages/.build-bicep/tests/Tasks.Tests.ps1` (validates task structure, tag with `Bicep-Tasks`)
  - **Bicep integrations** → `packages/.build-bicep/tests/Integration.Tests.ps1` (requires Bicep CLI, tag with `Bicep-Tasks`)

### Cross-Platform Guidelines

Gosh is **cross-platform by design**. Follow these patterns:

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

**For core Gosh features** (use `-TaskDirectory` parameter with mock fixtures):
```powershell
# Add to tests/gosh.Tests.ps1
Describe "Your New Feature" -Tag 'Core' {
    It "Should do something correctly" {
        # Tests use -TaskDirectory to point to fixtures
        $result = Invoke-Gosh -Arguments @('mock-simple') `
                              -Parameters @{ TaskDirectory = 'tests/fixtures'; Only = $true }
        $result.ExitCode | Should -Be 0
    }
}
```

**Mock Fixtures Pattern:**
- Tests use `tests/fixtures/` directory containing mock tasks
- Tests explicitly pass `-TaskDirectory 'tests/fixtures'` parameter
- This achieves clean separation between production tasks and test infrastructure
- No need to copy fixtures—they're referenced directly

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
# Via Gosh (tests the integration)
.\gosh.ps1 test

# Directly via Pester (tests gosh.ps1 itself)
Invoke-Pester

# Specific test file
Invoke-Pester -Path tests\gosh.Tests.ps1

# Quick core tests during development
Invoke-Pester -Tag Core
```

> **Important**: When modifying `gosh.ps1`, always test with `Invoke-Pester` directly to avoid circular dependency issues.

## Modifying Core Files

### gosh.ps1

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
- **GitHub Security Advisories** (preferred): https://github.com/motowilliams/gosh/security/advisories/new
- **Security Policy**: See [SECURITY.md](SECURITY.md) for complete vulnerability disclosure process
- **RFC 9116 Policy**: See [.well-known/security.txt](.well-known/security.txt)

You should receive a response within 48 hours. For more details on our security process, response timelines, and coordinated disclosure policy, see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Gosh, thanks for contributing!** ✨
