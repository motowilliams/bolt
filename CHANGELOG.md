# Changelog

All notable changes to the Gosh build system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Gosh build system
- Task orchestration with automatic dependency resolution
- Multi-task execution (space and comma-separated)
- Tab completion for task names
- Azure Bicep integration (format, lint, build tasks)
- Example infrastructure (App Service + SQL)
- Comprehensive documentation (README, IMPLEMENTATION, copilot-instructions)
- MIT License
- VS Code workspace settings
- Editor configuration files

### Features
- `format` task - Formats Bicep files using bicep format
- `lint` task - Validates Bicep files using bicep lint
- `build` task - Compiles Bicep to ARM JSON templates
- `-Only` flag to skip task dependencies
- `-Help` / `-ListTasks` to show available tasks
- Color-coded output for better readability
- Exit code propagation for CI/CD integration

### Documentation
- README.md - User guide with examples
- IMPLEMENTATION.md - Technical feature documentation
- CONTRIBUTING.md - Contribution guidelines
- .github/copilot-instructions.md - AI agent context
- VS Code task integration
- Recommended extensions

## [1.0.0] - 2025-10-17

### Initial Release
- Core orchestration system (gosh.ps1)
- Task discovery via comment-based metadata
- Dependency resolution with circular prevention
- Example Azure Bicep infrastructure
- Complete documentation suite

---

## Version Notes

### Versioning Strategy

- **Major (X.0.0)**: Breaking changes to gosh.ps1 or task metadata format
- **Minor (1.X.0)**: New features, new tasks, non-breaking enhancements
- **Patch (1.0.X)**: Bug fixes, documentation updates, minor improvements

### Future Considerations

Potential features for future releases:
- Parameter forwarding from gosh.ps1 to task scripts
- Pester test task integration
- Parallel task execution (where dependencies allow)
- Task output caching
- Pre/post task hooks
- Task timing and performance metrics
