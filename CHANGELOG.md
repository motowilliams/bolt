# Changelog

All notable changes to the Gosh build system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Parameter Sets**: PowerShell parameter sets for improved validation and user experience
  - `Help` (default): Shows usage and available tasks when no parameters provided
  - `TaskExecution`: For running tasks with `-Task`, `-Only`, `-Outline`, `-TaskDirectory`, `-Arguments`
  - `ListTasks`: For listing tasks with `-ListTasks` (alias: `-Help`), `-TaskDirectory`
  - `CreateTask`: For creating new tasks with `-NewTask`, `-TaskDirectory`
  - `InstallModule`: For installing as module with `-AsModule`
  - Prevents invalid parameter combinations (e.g., `-ListTasks -NewTask`)
  - No more terminal hanging when no parameters provided
  - Better IntelliSense and tab completion support
  - Improved help system showing all parameter sets clearly
- **Module Installation**: `-AsModule` parameter to install Gosh as a PowerShell module
  - Enables global `gosh` command accessible from any directory
  - Cross-platform support (Windows, Linux, macOS)
  - Automatic upward directory search for `.build/` folders (like git)
  - Tab completion in module mode for task names
  - Idempotent installation (re-run to update)
- Module installation paths:
  - Windows: `~/Documents/PowerShell/Modules/Gosh/`
  - Linux/macOS: `~/.local/share/powershell/Modules/Gosh/`
- `Find-BuildDirectory` function for upward directory traversal
- Cross-platform path detection using `$IsWindows`, `$IsLinux`, `$IsMacOS`

**Technical Notes**:
- ❌ **Failed**: Attempted to fake `$PSScriptRoot` in module mode using `Set-Variable -Scope Script`
  - PowerShell doesn't allow overriding automatic variables at runtime
  - Module execution always uses module's location, not project root
  - Variables like `$PSScriptRoot`, `$PSCommandPath` are read-only
- ❌ **Failed**: Tried passing project root as parameter to every function call
  - Required adding `$ProjectRoot` parameter to 10+ functions
  - Made function signatures inconsistent and hard to maintain
  - Breaking change for any external callers
- ❌ **Failed**: Used alias export before `Export-ModuleMember` in generated module
  - `Set-Alias` must be called before `Export-ModuleMember`
  - Aliases defined after export are not visible to module users
- ❌ **Failed**: Passed arguments as array to gosh-core.ps1 instead of hashtable
  - Array splatting doesn't work with parameter names
  - Resulted in positional parameter errors
- ❌ **Failed**: Tab completion only registered for 'gosh.ps1' not module function
  - `Register-ArgumentCompleter` needs both 'Invoke-Gosh' and 'gosh' alias
  - Module mode had no tab completion initially
- ✅ **Solution**: Environment variable `$env:GOSH_PROJECT_ROOT` for context passing
  - Module sets variable before invoking gosh-core.ps1
  - Core script checks variable and sets `$script:EffectiveScriptRoot`
  - All functions use `$script:EffectiveScriptRoot` instead of direct `$PSScriptRoot`
  - No function signature changes required
  - Works transparently in both script and module modes

### Changed
- Updated documentation to reflect module installation feature:
  - README.md: Added comprehensive "Module Installation" section
  - IMPLEMENTATION.md: Added module features to Core Build System
  - .github/copilot-instructions.md: Added module examples and cross-platform paths
- Task discovery now supports both script mode (`$PSScriptRoot`) and module mode (`$env:GOSH_PROJECT_ROOT`)
- All functions now use `$script:EffectiveScriptRoot` for path resolution

### Fixed
- Cross-platform compatibility for module installation (Windows/Linux/macOS paths)
- **Security Logging Directory Creation**: Fixed issue where `.gosh` file could be created instead of directory
  - Enhanced `Write-SecurityLog` function with more robust directory creation logic
  - Explicitly handles file-to-directory conversion when `.gosh` exists as a file
  - Prevents race conditions and ensures audit logging works reliably
  - Added double-verification to confirm directory creation succeeded

**Technical Notes**:
- ❌ **Failed**: Original directory creation logic had race condition vulnerability
  - `Test-Path -PathType Container` + `New-Item -Force` wasn't atomic
  - If `.gosh` existed as a file, `New-Item` might fail silently
  - `Add-Content` could then create `.gosh` as a file instead of `audit.log` in directory
  - Occurred intermittently during parallel test execution
- ✅ **Solution**: Enhanced directory creation with explicit file-to-directory conversion
  - Check if `.gosh` exists and remove if it's a file (not directory)
  - Create directory with error handling and double-verification
  - Atomic operation prevents race conditions between multiple processes
  - Throws clear error if directory creation fails, preventing silent failures
- ❌ **Failed**: Used `$HOME/Documents/PowerShell/Modules` with hardcoded path separator
  - Backslash `\` breaks on Linux/macOS
  - `Documents` folder doesn't exist on Linux/macOS
  - Resulted in module installation failures on non-Windows platforms
- ❌ **Failed**: Used `[Environment]::GetFolderPath('MyDocuments')` for all platforms
  - Returns empty or unexpected paths on Linux/macOS
  - PowerShell module paths differ by OS convention
  - Module wouldn't be discovered by `$env:PSModulePath`
- ✅ **Solution**: Platform-specific path detection
  - Windows: `GetFolderPath('MyDocuments')` → `~/Documents/PowerShell/Modules/`
  - Linux/macOS: `GetFolderPath('LocalApplicationData')` → `~/.local/share/powershell/Modules/`
  - Uses `$IsWindows`, `$IsLinux`, `$IsMacOS` automatic variables
  - Paths match PowerShell's default module search locations

## [1.0.0] - 2025-10-17

### Added
- Core orchestration system (gosh.ps1)
- Task discovery via comment-based metadata in `.build/*.ps1` files
- Automatic dependency resolution with circular dependency prevention
- Multi-task execution (space-separated and comma-separated)
- Tab completion for task names via `Register-ArgumentCompleter`
- `-Only` flag to skip task dependencies for faster iteration
- `-Outline` flag to preview task execution plan without running tasks
- `-TaskDirectory` parameter to specify custom task locations
- `-NewTask` parameter to generate new task files with proper metadata
- `-ListTasks` / `-Help` to display available tasks
- Core tasks: `check-index` (git status validation)
- Example Azure Bicep tasks: `format`, `lint`, `build`
- Example Azure infrastructure (App Service + SQL Database)
- Comprehensive test suite with Pester (267 tests)
  - Core orchestration tests (28 tests, fast)
  - Security validation tests (205 tests)
  - Bicep task tests (16 tests)
  - Test tags: `Core`, `Security`, `Bicep-Tasks`
- VS Code integration:
  - Pre-configured tasks (build, format, lint, test)
  - Recommended extensions
  - Workspace settings
- Cross-platform support (Windows, Linux, macOS)
- Security features:
  - Path traversal protection
  - Command injection prevention
  - PowerShell injection prevention
  - Security event logging
  - Output sanitization
- Complete documentation suite:
  - README.md - User guide with quick start
  - IMPLEMENTATION.md - Technical feature documentation
  - CONTRIBUTING.md - Contribution guidelines and patterns
  - .github/copilot-instructions.md - AI agent context
  - SECURITY.md - Security policy and reporting
- GitHub Actions CI pipeline (Ubuntu and Windows)
- MIT License
- EditorConfig for consistent code formatting

[Unreleased]: https://github.com/motowilliams/gosh/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/motowilliams/gosh/releases/tag/v1.0.0
