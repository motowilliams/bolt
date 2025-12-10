# Changelog

All notable changes to the Bolt build system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Configuration Variable System**: New project-level configuration management with `bolt.config.json`
  - Create configuration file at project root with user-defined variables
  - Automatic config injection into all tasks via `$BoltConfig` variable
  - Built-in variables: `ProjectRoot`, `TaskDirectory`, `InvokedTask`, `ExecutedTasks`
  - User-defined variables accessible via `$BoltConfig.UserVariables.YourVariableName`
  - Supports nested objects and complex data structures
  - Per-invocation configuration caching for performance (multiple tasks share same config)
  - Automatic cache invalidation on add/remove operations
  - New files: `bolt.config.json` (configuration), `bolt.config.schema.json` (JSON schema), `bolt.config.example.json` (template)
- **Variable Management CLI**: New command-line interface for managing configuration variables
  - `-ListVariables`: Display all configuration variables (built-in and user-defined) with values
  - `-AddVariable`: Add or update user-defined variables interactively with `-Name` and `-Value` parameters
  - `-RemoveVariable`: Remove user-defined variables by name with `-Name` parameter
  - Works in both script mode (`.\bolt.ps1 -ListVariables`) and module mode (`bolt -ListVariables`)
  - JSON schema validation on add/remove operations
  - Human-readable output with syntax-highlighted JSON display
- **Bicep Task Refactoring**: Refactored all Bicep tasks to use `$BoltConfig` for data access
  - Format, Lint, and Build tasks now use `$BoltConfig.ProjectRoot` instead of environment variables
  - Cleaner task implementation with safer nested value access patterns
  - Example demonstrates best practices for accessing configuration in tasks
  - Maintains backward compatibility (no breaking changes)

### Changed
- **Project Rename: Gosh → Bolt**: Complete rebranding of the project from "Gosh" to "Bolt"
  - Renamed main script from `gosh.ps1` to `bolt.ps1`
  - Renamed module script from `New-GoshModule.ps1` to `New-BoltModule.ps1`
  - Updated all function names, variables, and aliases (e.g., `Invoke-Gosh` → `Invoke-Bolt`)
  - Updated all documentation files (README.md, IMPLEMENTATION.md, CONTRIBUTING.md, SECURITY.md)
  - Updated all test files to use new naming conventions
  - Fixed `.gitignore` to use `.bolt/` instead of `.gosh/`
  - Updated security.txt URLs to reflect new project name
  - Updated copilot instructions and prompts with new naming
  - Repository URL remains `motowilliams/gosh` (GitHub repository name unchanged)
- **Git Worktree Instructions**: Added comprehensive git worktree workflow documentation
  - New instruction file: `.github/instructions/feature-branches.instructions.md`
  - Preferred workflow for feature branch development
  - Naming convention: `../<repo-name>-wt-<branch-name>`
  - Cross-platform PowerShell syntax examples
  - Better than traditional `git checkout` for parallel work
- **Module Installation Refactor**: Separated module installation into dedicated script
  - Moved all module installation code from `bolt.ps1` to `New-BoltModule.ps1`
  - Cleaner separation of concerns: orchestration vs. installation
  - New test file: `tests/New-BoltModule.Tests.ps1` with comprehensive coverage
  - Updated documentation to reference external script for module management
  - CI pipeline updated to use new script for testing
- **Documentation Cleanup**: Removed test counts from user-facing documentation
  - Test counts change frequently and don't add value for users
  - Focus on test quality and coverage categories instead
  - Updated prompt to prevent test counts in documentation
  - Security documentation retains test counts (verification status)

### Fixed
- **Git Ignore Rules**: Enhanced `.gitignore` organization and coverage
  - Clear section headers for different file categories
  - Better coverage of OS-specific files (Windows, macOS, Linux)
  - Proper exclusion of `.bolt/` directory (audit logs)
  - Improved module and build artifact exclusions
- **Test Cleanup**: Removed skipped test requiring user interaction
  - Module installation tests no longer require manual confirmation
  - All tests can run fully automated in CI/CD pipelines

### Added
- **Filename Fallback Warning System**: Tasks using filename-based task names (no `# TASK:` metadata) now display a warning
  - Warning message explains the fallback behavior and encourages explicit metadata
  - Can be disabled via environment variable `$env:BOLT_NO_FALLBACK_WARNINGS = 1`
  - Helps prevent confusion from file rename operations
  - Applies to both script mode and module mode

### Fixed
- **Task Discovery with File Renames**: Fixed issue where renaming task files without explicit `# TASK:` metadata would not update task discovery
  - Tab completion now re-discovers tasks on each invocation (was already correct, verified)
  - Task execution properly updates when files are renamed within same session
  - Added test to verify file rename behavior: `Should handle file renames correctly during task discovery`

### Added
- **Manifest Generation Tooling**: New standalone scripts for PowerShell module manifest creation
  - `generate-manifest.ps1`: Analyzes existing PowerShell modules and generates `.psd1` manifest files
  - `generate-manifest-docker.ps1`: Docker wrapper for containerized manifest generation using `mcr.microsoft.com/powershell:latest`
  - Supports both `.psm1` files and module directories as input
  - Automatic Git repository URI inference (GitHub, GitLab, Bitbucket)
  - Cross-platform compatibility (Windows, Linux, macOS)
  - Robust validation with fallback error handling
- **Module Uninstallation**: New `-UninstallModule` parameter to remove Bolt from all installations
  - Auto-detects all Bolt module installations on current platform (Windows, Linux, macOS)
  - Prompts for confirmation before removal (safe by default)
  - Removes module from current PowerShell session and disk
  - Creates recovery instruction file if automatic removal fails
  - Proper exit codes for CI/CD integration (0=success, 1=failure)
  - Works from both script mode (`.\bolt.ps1 -UninstallModule`) and module mode (`bolt -UninstallModule`)
  - Gracefully handles self-removal when called from installed module
- **Enhanced Module Installation**: Extended `-AsModule` parameter set with new options
  - `-ModuleOutputPath`: Specify custom installation path for build/release scenarios
  - `-NoImport`: Skip automatic module importing after installation
  - Build pipeline integration support for CI/CD scenarios
  - Improved error handling with graceful fallbacks
- **Parameter Sets**: PowerShell parameter sets for improved validation and user experience
  - `Help` (default): Shows usage and available tasks when no parameters provided
  - `TaskExecution`: For running tasks with `-Task`, `-Only`, `-Outline`, `-TaskDirectory`, `-Arguments`
  - `ListTasks`: For listing tasks with `-ListTasks` (alias: `-Help`), `-TaskDirectory`
  - `CreateTask`: For creating new tasks with `-NewTask`, `-TaskDirectory`
  - `InstallModule`: For installing as module with `-AsModule`, `-ModuleOutputPath`, `-NoImport`
  - Prevents invalid parameter combinations (e.g., `-ListTasks -NewTask`)
  - No more terminal hanging when no parameters provided
  - Better IntelliSense and tab completion support
  - Improved help system showing all parameter sets clearly
- **Module Installation**: `-AsModule` parameter to install Bolt as a PowerShell module
  - Enables global `bolt` command accessible from any directory
  - Cross-platform support (Windows, Linux, macOS)
  - Automatic upward directory search for `.build/` folders (like git)
  - Tab completion in module mode for task names
  - Idempotent installation (re-run to update)
- Module installation paths:
  - Windows: `~/Documents/PowerShell/Modules/Bolt/`
  - Linux/macOS: `~/.local/share/powershell/Modules/Bolt/`
- `Find-BuildDirectory` function for upward directory traversal
- Cross-platform path detection using `$IsWindows`, `$IsLinux`, `$IsMacOS`
- **Improved .gitignore**: Comprehensive reorganization with clear sections and comments
  - Bicep Infrastructure: ARM templates, parameter files, configuration
  - Test Results: Pester outputs, temporary directories
  - PowerShell Modules: Generated manifests, module installations
  - Development/IDE: Editor-specific files
  - OS Files: Cross-platform system files (Windows, macOS, Linux)
  - Build/Distribution: NuGet packages, build outputs, logs
- **Anti-Hallucination Policy**: Comprehensive documentation accuracy standards
  - New policy document: `.github/NO-HALLUCINATIONS-POLICY.md`
  - Zero tolerance for fictional URLs, endpoints, or features in documentation
  - Enhanced prompt file with explicit verification requirements
  - Updated copilot-instructions.md with prominent hallucination prevention guidelines
  - Added policy references to README.md and CONTRIBUTING.md
  - Verification requirements for all URLs, file paths, and feature references
  - Examples of past violations documented to prevent repetition

### Changed
- **Manifest Generation Removed from Core**: Separated module manifest generation from `bolt.ps1`
  - Removed hardcoded manifest creation from `Install-BoltModule` function
  - Use dedicated `generate-manifest.ps1` script for publishing/distribution scenarios
  - Cleaner separation of concerns: module installation vs. manifest generation
  - Faster module installation without manifest overhead
- Updated documentation to reflect manifest generation tooling:
  - README.md: Added manifest generation section
  - IMPLEMENTATION.md: Updated module features documentation
  - .github/copilot-instructions.md: Added new script usage patterns
- Task discovery now supports both script mode (`$PSScriptRoot`) and module mode (`$env:BOLT_PROJECT_ROOT`)
- All functions now use `$script:EffectiveScriptRoot` for path resolution

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
- ❌ **Failed**: Passed arguments as array to bolt-core.ps1 instead of hashtable
  - Array splatting doesn't work with parameter names
  - Resulted in positional parameter errors
- ❌ **Failed**: Tab completion only registered for 'bolt.ps1' not module function
  - `Register-ArgumentCompleter` needs both 'Invoke-Bolt' and 'bolt' alias
  - Module mode had no tab completion initially
- ✅ **Solution**: Environment variable `$env:BOLT_PROJECT_ROOT` for context passing
  - Module sets variable before invoking bolt-core.ps1
  - Core script checks variable and sets `$script:EffectiveScriptRoot`
  - All functions use `$script:EffectiveScriptRoot` instead of direct `$PSScriptRoot`
  - No function signature changes required
  - Works transparently in both script and module modes

### Changed
- Updated documentation to reflect module installation feature:
  - README.md: Added comprehensive "Module Installation" section
  - IMPLEMENTATION.md: Added module features to Core Build System
  - .github/copilot-instructions.md: Added module examples and cross-platform paths
- Task discovery now supports both script mode (`$PSScriptRoot`) and module mode (`$env:BOLT_PROJECT_ROOT`)
- All functions now use `$script:EffectiveScriptRoot` for path resolution

### Fixed
- Cross-platform compatibility for module installation (Windows/Linux/macOS paths)
- **Security Logging Directory Creation**: Fixed issue where `.bolt` file could be created instead of directory
  - Enhanced `Write-SecurityLog` function with more robust directory creation logic
  - Explicitly handles file-to-directory conversion when `.bolt` exists as a file
  - Prevents race conditions and ensures audit logging works reliably
  - Added double-verification to confirm directory creation succeeded

**Technical Notes**:
- ❌ **Failed**: Original directory creation logic had race condition vulnerability
  - `Test-Path -PathType Container` + `New-Item -Force` wasn't atomic
  - If `.bolt` existed as a file, `New-Item` might fail silently
  - `Add-Content` could then create `.bolt` as a file instead of `audit.log` in directory
  - Occurred intermittently during parallel test execution
- ✅ **Solution**: Enhanced directory creation with explicit file-to-directory conversion
  - Check if `.bolt` exists and remove if it's a file (not directory)
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
- Core orchestration system (bolt.ps1)
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
- Comprehensive test suite with Pester
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
