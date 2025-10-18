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

- Test tasks both individually and with dependencies
- Verify tasks work with `-Only` flag
- Check that exit codes propagate correctly
- Test in both PowerShell 7.0+ on Windows and cross-platform if applicable

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
