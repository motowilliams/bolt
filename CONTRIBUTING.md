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

- **Run the test suite**: `Invoke-Pester` to ensure all tests pass (43 tests)
- **Test tasks individually**: Verify your task works standalone
- **Test with dependencies**: Check dependency resolution and `-Only` flag
- **Verify exit codes**: Ensure tasks return 0 for success, 1 for failure
- **Test cross-platform**: If applicable, test on Windows, Linux, and macOS
- **Add new tests**: Choose the appropriate test file:
  - **Core orchestration changes** → `tests/gosh.Tests.ps1` (uses mock fixtures)
  - **New project tasks** → `tests/ProjectTasks.Tests.ps1` (validates task structure)
  - **Bicep integrations** → `tests/Integration.Tests.ps1` (requires Bicep CLI)

### Writing Tests

When adding new functionality, include Pester tests in the appropriate file:

**For core Gosh features** (use mock fixtures from `tests/fixtures/`):
```powershell
# Add to tests/gosh.Tests.ps1
Describe "Your New Feature" {
    BeforeAll {
        # Copy fixtures to .build-test/
        $fixtureSource = Join-Path $PSScriptRoot "fixtures"
        $fixtureDest = Join-Path $PSScriptRoot ".." ".build-test"
        Copy-Item "$fixtureSource\*.ps1" -Destination $fixtureDest -Force
    }
    
    It "Should do something correctly" {
        # Test using mock-simple, mock-with-dep, or mock-complex
        $result = & $goshScript "mock-simple"
        $LASTEXITCODE | Should -Be 0
    }
    
    AfterAll {
        # Clean up .build-test/
        Remove-Item $fixtureDest -Recurse -Force -ErrorAction SilentlyContinue
    }
}
```

**For new project tasks**:
```powershell
# Add to tests/ProjectTasks.Tests.ps1
Describe "YourNewTask Task" {
    It "Should exist in .build directory" {
        $taskPath = Join-Path $projectRoot ".build\Invoke-YourNewTask.ps1"
        $taskPath | Should -Exist
    }
    
    It "Should have valid PowerShell syntax" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $taskPath -Raw), [ref]$errors)
        $errors.Count | Should -Be 0
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
Invoke-Pester -Path .\gosh.Tests.ps1
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

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Gosh, thanks for contributing!** ✨
