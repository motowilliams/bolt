# Changelog

All notable changes to the Bolt build system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Golang Starter Package**: Added Docker fallback support and enhanced format task
  - All tasks (format, lint, test, build) now support automatic Docker fallback
  - Uses `golang:1.22-alpine` container image when Go CLI is not installed
  - Three-tier tool detection: Configured path → PATH search → Docker fallback
  - Seamless module dependency handling via go.mod
  - Binary output works transparently with Docker volume mounts
  - Build task notes Linux binary output when using Docker
  - Enhanced format task to use batch processing (`go fmt ./...`) instead of file-by-file iteration for better performance, especially with Docker
  - Updated documentation with Docker usage and troubleshooting
  - Enhanced integration tests to support Docker execution
  - Maintains full backward compatibility with existing configurations

## [0.13.0] - 2026-01-29

### Added
- **Python Starter Package**: Python application development tasks with Docker fallback support
  - **`format` task** (alias: `fmt`) - Formats Python files using `black` (industry standard formatter)
  - **`lint` task** - Validates Python code using `ruff` (fast, modern linter)
  - **`test` task** - Runs tests using `pytest` (popular testing framework)
  - **`build` task** - Installs dependencies and validates package structure
  - Dependencies: build → format, lint, test
  - Docker Fallback Support: Automatically uses `python:3.12-slim` when Python CLI not installed
  - Cross-platform compatibility (Windows, Linux, macOS)
  - Comprehensive test suite covering task validation and integration tests
  - Example Python calculator module with pytest tests
  - Complete documentation in `packages/.build-python/README.md`
  - Configuration via `PythonPath` and `PythonToolPath` in `bolt.config.json`
  - Supports Python 3.8+ (3.12 recommended)

## [0.12.0] - 2026-01-28

### Added
- **ToolPath Configuration**: Configurable tool executable paths for all package starters
  - **`BicepToolPath`** - Custom path to Bicep CLI executable
  - **`TerraformToolPath`** - Custom path to Terraform CLI executable
  - **`GoToolPath`** - Custom path to Go CLI executable
  - **`DotNetToolPath`** - Custom path to .NET SDK executable
  - **`NodeToolPath`** - Custom path to Node.js executable (for TypeScript tasks)
  - Each ToolPath allows specifying absolute path to CLI tool (e.g., `/usr/local/bin/bicep`, `C:\tools\terraform.exe`)
  - Falls back to PATH search if not configured
  - Clear error messages when tool not found at configured path
  - All package starters updated with ToolPath support

- **Source Path Configuration**: Enhanced path configuration for all package starters
  - **`BicepPath`** - Relative path to Bicep source files
  - **`TerraformPath`** - Relative path to Terraform source files
  - **`TypeScriptPath`** - Relative path to TypeScript source files
  - **`GoPath`** - Already supported, now documented alongside other paths
  - **`DotNetPath`** - Already supported, now documented alongside other paths
  - All paths are relative to project root
  - Configuration schema updated in `bolt.config.schema.json`
  - Example configuration updated in `bolt.config.example.json`

- **Package Starter Configuration Files**: Each package starter now includes `bolt.config.json`
  - Bicep: `BicepPath = "packages/.build-bicep/tests/iac"`
  - Terraform: `TerraformPath = "packages/.build-terraform/tests/tf"`
  - Golang: `GoPath = "packages/.build-golang/tests/app"`
  - .NET: `DotNetPath = "packages/.build-dotnet/tests"`
  - TypeScript: `TypeScriptPath = "packages/.build-typescript/tests/app"`
  - Provides working examples for users to copy and customize

### Changed
- **Bicep Starter Package**: Enhanced with configurable tool paths and explicit configuration
  - All tasks (format, lint, build) now support `BicepToolPath` configuration
  - **BREAKING**: Removed `IacPath` backward compatibility - use `BicepPath` instead
  - **BREAKING**: Removed default fallback paths - explicit configuration required in `bolt.config.json`
  - Improved error messages suggest both installation and configuration options
  - Updated README.md with ToolPath configuration examples

- **Terraform Starter Package**: Enhanced with configurable tool paths and explicit configuration
  - All tasks (format, validate, plan, apply) now support `TerraformToolPath` configuration
  - `TerraformPath` configuration added for source files
  - **BREAKING**: Removed default fallback paths - explicit configuration required in `bolt.config.json`
  - Docker fallback still supported when tool not configured
  - Updated README.md with ToolPath configuration examples

- **Golang Starter Package**: Enhanced with configurable tool paths and explicit configuration
  - All tasks (format, lint, test, build) now support `GoToolPath` configuration
  - **BREAKING**: Removed default fallback paths - explicit configuration required in `bolt.config.json`
  - Improved error messages suggest both installation and configuration options
  - Updated README.md with ToolPath configuration examples

- **.NET Starter Package**: Enhanced with configurable tool paths and explicit configuration
  - All tasks (format, restore, test, build) now support `DotNetToolPath` configuration
  - **BREAKING**: Removed default fallback paths - explicit configuration required in `bolt.config.json`
  - Docker fallback still supported when tool not configured
  - Updated README.md with ToolPath configuration examples

- **TypeScript Starter Package**: Enhanced with configurable tool paths and explicit configuration
  - All tasks (format, lint, test, build) now support `NodeToolPath` configuration
  - npm path automatically derived from Node.js path when custom path specified
  - **BREAKING**: Removed default fallback paths - explicit configuration required in `bolt.config.json`
  - Docker fallback still supported when tool not configured
  - Updated README.md with ToolPath configuration examples

- **Integration Tests**: Updated to use bolt.ps1 orchestrator for consistency
  - Terraform, .NET, and TypeScript integration tests now use `Invoke-Bolt` helper function
  - Changed from direct script invocation to orchestrated execution
  - Ensures `$BoltConfig` is always available when tasks run
  - Matches existing Golang and Bicep test patterns
  - All 448 tests passing

- **Release Scripts**: Synchronized release builder scripts across all package starters
  - Consistent version validation and packaging
  - All packages use same release workflow pattern

### Removed
- **IacPath backward compatibility**: Removed from Bicep package starter
  - Use `BicepPath` configuration instead
  - Tests updated to use `BicepPath`
  - Terraform still supports `IacPath` fallback to `TerraformPath`

- **Default fallback paths**: Removed from all task scripts
  - Tasks no longer fall back to `$PSScriptRoot`-relative paths
  - Explicit configuration in `bolt.config.json` now required
  - Clear error messages guide users to add configuration
  - Prevents silent misconfiguration issues

- **Compiled artifacts from git**: Removed `packages/.build-bicep/tests/iac/main.json`
  - File is generated during Bicep build tests
  - Now properly ignored by `.gitignore` rule
  - No longer pollutes git status after test runs

### Fixed
- **`.gitignore` rule effectiveness**: Removed tracked artifact to allow gitignore rule to work
  - `packages/.build-bicep/tests/iac/main.json` was previously tracked
  - Once tracked, `.gitignore` rules don't apply
  - File removed from tracking, now properly ignored when regenerated

## [0.11.0] - 2026-01-27

### Added
- **TypeScript Starter Package**: TypeScript/JavaScript application development tasks with Docker fallback support
  - **`format` task** (alias: `fmt`) - Formats TypeScript files using Prettier
  - **`lint` task** - Validates TypeScript code using ESLint
  - **`test` task** - Runs tests using Jest test runner
  - **`build` task** - Compiles TypeScript to JavaScript (depends on format, lint, test)
  - Dependencies: `build` → `format`, `lint`, `test`
  - **Docker Fallback Support**: Automatically uses `node:22-alpine` Docker image when Node.js/npm not installed
  - Cross-platform compatibility (Windows, Linux, macOS)
  - Comprehensive test suite (16 task validation + 4 integration tests)
  - Example TypeScript application with Greeter class and Jest tests
  - Complete documentation in `packages/.build-typescript/README.md`

### Changed
- **`.gitattributes`**: Added TypeScript/JavaScript file patterns with `eol=lf` for consistent line endings
  - Added `*.ts`, `*.tsx`, `*.js`, `*.jsx` with `text eol=lf`
  - Prevents Prettier from causing git changes during test runs
  - Follows same pattern as C# files to ensure cross-platform consistency
- **`.gitignore`**: Added TypeScript/Node.js starter package section
  - Added `node_modules/` for Node.js dependencies
  - Added npm/yarn/pnpm lock files (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`)
  - Added Jest test coverage directory (`coverage/`)
  - Added TypeScript build cache (`*.tsbuildinfo`)
  - Added npm and ESLint cache directories (`.npm`, `.eslintcache`)
  - Follows same pattern as other package starters with section header and comments
- **`Invoke-Tests.ps1`**: Added `TypeScript-Tasks` tag to ValidateSet for test filtering
  - Added `packages/.build-typescript/tests/` to test discovery paths
  - Added documentation and examples for TypeScript-Tasks tag
## [0.10.2] - 2026-01-27

### Changed
- **Task Discovery**: Updated task file discovery to only process files matching `Invoke-*.ps1` pattern
  - Filters out helper scripts and utilities (e.g., `Create-Release.ps1`, `Download-Starter.ps1`, `Get-PesterTests.ps1`)
  - Removes warnings for non-task scripts in `.build` directories
  - Applied to main task discovery in `Get-ProjectTasks` function
  - Applied to tab completion for default `.build` directory, namespaced subdirectories, and custom task directories
  - Allows users to keep utility scripts alongside task files without triggering discovery
  - Establishes clear convention: only `Invoke-*.ps1` files are processed as tasks
- **Download-Starter.ps1**: Improved release sorting with semantic version comparison
  - Changed from alphabetical sorting to proper semantic versioning (e.g., v0.9.0 → v0.10.0 instead of v0.10.0 → v0.9.0)
  - Correctly handles major, minor, and patch version components
  - Pre-release versions (e.g., v1.0.0-beta) sort before release versions
  - Ensures latest releases appear at the end of the selection menu

### Fixed
- **Test Suite**: Updated test expectations to match new `Invoke-*.ps1` filtering behavior
  - Changed test case from `TestOnly.ps1` to `Invoke-TestOnly.ps1` to align with filtering pattern

## [0.10.1] - 2026-01-26

### Added
- **.NET Solution File**: Added `bolt.slnx` to .NET starter package test project
  - Organizes main application (`app/HelloWorld.csproj`) and test project (`HelloWorld.Tests/HelloWorld.Tests.csproj`) into solution structure
  - Simplifies building and managing both projects together
  - Located in `packages/.build-dotnet/tests/bolt.slnx`

## [0.10.0] - 2026-01-23

### Added
- **.NET (C#) Starter Package**: .NET/C# application development tasks with Docker fallback support
  - **`format` task** (alias: `fmt`) - Formats C# files using `dotnet format`
  - **`restore` task** - Restores NuGet packages using `dotnet restore`
  - **`test` task** - Runs .NET tests using `dotnet test` with xUnit
  - **`build` task** - Builds .NET projects (depends on format, restore, test)
  - Dependencies: `build` → `format`, `restore`, `test`
  - **Docker Fallback Support**: Automatically uses `mcr.microsoft.com/dotnet/sdk:10.0` Docker image when .NET SDK not installed
  - Cross-platform compatibility (Windows, Linux, macOS)
  - Comprehensive test suite (25 task validation + 9 integration tests)
  - Example C# application with Calculator class and xUnit tests
  - Complete documentation in `packages/.build-dotnet/README.md`

### Changed
- **`.gitattributes`**: Added `*.cs` and `*.csproj` files with `eol=lf` to ensure consistent line endings across platforms
  - Prevents `dotnet format` from modifying files after checkout on Windows
- **`.gitignore`**: Added .NET build artifacts (bin/, obj/, *.dll, *.exe, *.pdb, *.cache, packages/, publish/)
- **`Invoke-Tests.ps1`**: Added `DotNet-Tasks` tag to ValidateSet for test filtering
  - Added `packages/.build-dotnet/tests/` to test discovery paths
  - Added documentation and examples for DotNet-Tasks tag
- **Package Starter Development Instructions**: Enhanced `.github/instructions/package-starter-development.instructions.md`
  - Added "Updating Test Discovery Wrappers" section with detailed requirements
  - Added "Version Bumping and Release Preparation" section
  - Updated checklist to require `Invoke-Tests.ps1` and `CHANGELOG.md` updates

## [0.9.0] - 2026-01-13

### Added
- **Terraform Starter Package**: Infrastructure-as-Code tasks for Terraform workflows
  - **`format` task** (alias: `fmt`) - Formats `.tf` files using `terraform fmt -recursive`
  - **`validate` task** - Validates Terraform configuration after `terraform init -backend=false`
  - **`plan` task** - Generates execution plan, saves to `terraform.tfplan`
  - **`apply` task** (alias: `deploy`) - Applies changes with 5-second safety delay
  - Dependencies: `apply` → `plan` → `validate` → `format`
  - **Docker Fallback Support**: Automatically uses `hashicorp/terraform:latest` Docker image when Terraform CLI not installed
  - Cross-platform compatibility (Windows, Linux, macOS)
  - Comprehensive test suite (21 task validation + 4 integration tests)
  - Example Terraform configuration for testing
  - Complete documentation in `packages/.build-terraform/README.md`
  - CI integration with Terraform CLI installation on both Ubuntu and Windows runners

### Changed
- **CI Workflow**: Added Terraform CLI installation steps for both Ubuntu and Windows
  - Ubuntu: Uses HashiCorp's official apt repository
  - Windows: Uses Chocolatey package manager
  - Ensures consistent cross-platform testing with native Terraform CLI
- **Test Discovery**: Added `packages/.build-terraform/tests` to test discovery paths in CI workflow
- **Invoke-Tests.ps1**: Added `Terraform-Tasks` tag to ValidateSet for test filtering

### Fixed
- **PowerShell Command Execution**: Fixed terraform command invocation to use call operator (`&`) and quoted parameters
  - Changed from `terraform plan -out=$planFile` to `& terraform plan "-out=terraform.tfplan"`
  - Prevents PowerShell variable expansion issues on Windows
  - Ensures consistent behavior across all platforms

### Technical Notes
- **Docker Limitation on Windows**: The `hashicorp/terraform:latest` Docker image only provides Linux containers
  - Windows CI runners don't support Linux containers
  - Solution: Install Terraform CLI natively on both platforms for consistent testing
  - Docker fallback still available for local development on platforms that support Linux containers

## [0.8.1] - 2026-01-12

### Changed
- **Golang Package Starter**: Added DEPENDS metadata section to task files
  - Updated `Invoke-Format.ps1` with explicit DEPENDS section (currently empty)
  - Updated `Invoke-Lint.ps1` with explicit DEPENDS section (currently empty)
  - Updated `Invoke-Test.ps1` with explicit DEPENDS section (currently empty)
  - Improves task metadata completeness and consistency across package starters
  - Updated test expectations to validate DEPENDS metadata presence

## [0.8.0] - 2026-01-08

### Added
- **Task Validation Feature**: New `-ValidateTasks` parameter to validate task file metadata and structure
  - Validates TASK metadata presence and format
  - Checks DESCRIPTION metadata (flags placeholders like "TODO")
  - Verifies DEPENDS metadata exists
  - Ensures explicit exit codes (exit 0 or exit 1)
  - Validates task name format (lowercase alphanumeric + hyphens only)
  - Color-coded report output (✓ Pass, ⚠ Warn, ✗ Fail)
  - Summary statistics showing pass/warning/failure counts
  - Works with `-TaskDirectory` parameter for custom task locations
  - Exit code reflects validation status (0 for success, 1 for failures)
- **ValidateTasks Parameter Set**: New parameter set for task validation workflow
- **Test-TaskMetadata Function**: Core validation logic for checking task file compliance
- **Show-ValidationReport Function**: Formatted report display with color-coded status indicators
- **Comprehensive Test Coverage**: 11 new tests covering validation feature functionality

### Changed
- Updated README.md with validation feature documentation and usage examples
- Updated parameter sets documentation to include ValidateTasks parameter set
- Enhanced help documentation with `-ValidateTasks` parameter and example

## [0.7.1] - 2026-01-08

### Added
- **Package Starter Creation Documentation**: Comprehensive guides for developing new package starters
  - **AI Agent Specification** (`.github/prompts/create-package-starter.prompt.md`): Complete specification for automated package starter creation with AI tools
    - Requirements, patterns, and validation checklist
    - Task structure templates and examples
    - Testing requirements and release conventions
  - **Developer Guidelines** (`.github/instructions/package-starter-development.instructions.md`): Detailed manual development guide
    - Task file requirements and metadata format
    - Cross-platform compatibility patterns (PowerShell cmdlets, path handling)
    - Testing patterns (structure validation and integration tests)
    - Release script conventions
    - Common patterns, examples, and troubleshooting
  - **Bicep Package README** (`packages/.build-bicep/README.md`): Comprehensive Bicep starter documentation
    - Installation instructions (standard and namespaced)
    - Task details (format, lint, build)
    - Usage examples and configuration
    - Testing and troubleshooting sections

### Changed
- **Main README.md**: Simplified Package Starters section for better navigation
  - Package starters now show summaries with links to detailed package-specific READMEs
  - Removed speculative "Coming Soon" lists to focus on current capabilities
  - Added cross-references to package creation guides in Contributing section
  - Added Golang Starter Package tests to Test Structure section
- **packages/README.md**: Enhanced with comprehensive package creation resources
  - Added links to AI-assisted and manual development paths
  - Updated reference implementations to link directly to package READMEs
  - Removed speculative future package lists
- **IMPLEMENTATION.md**: Added Package Starter Development section
  - Central reference point for all package creation documentation
  - Quick overview with links to detailed guides
  - Updated future enhancements to remove specific package types

### Documentation
- **DRY Principle**: Detailed content now lives in package-specific READMEs, main README provides overview
- **Better Navigation**: Reference implementations link directly to package READMEs for easy access
- **Focused Content**: Removed speculative future features to maintain current-state documentation

## [0.7.0] - 2026-01-07

### Changed
- **BREAKING: Namespace-Aware Dependency Resolution**: Task dependencies now resolve with namespace priority
  - When a namespaced task (e.g., `golang-build` in `.build/golang/`) declares dependencies (e.g., `format, lint, test`), the system now:
    1. First looks for namespace-prefixed tasks (e.g., `golang-format`, `golang-lint`, `golang-test`)
    2. Falls back to root-level tasks if not found in namespace (e.g., `format`, `lint`, `test`)
  - **Impact**: Starter packages in subdirectories now correctly use their own tasks instead of root-level tasks
  - **Breaking Change**: Projects with both root-level and namespace-level tasks with the same name will see behavior change
    - Before: Always used root-level task
    - After: Uses namespace-level task when available (correct behavior)
  - Example scenario:
    ```
    .build/golang/Invoke-Build.ps1   # DEPENDS: format, lint, test
    .build/golang/Invoke-Format.ps1  → golang-format (now used ✓)
    .build/Invoke-Format.ps1         → format (was used before ✗)
    ```
  - **Migration**: If you have root-level tasks that namespaced tasks were depending on, you may need to:
    - Copy those tasks into the namespace directory, OR
    - Explicitly reference root tasks by prefixing with root namespace (future enhancement)

### Fixed
- **Task Execution**: Dependency resolution now respects namespace context (commit 513da5f)
  - Prevents incorrect execution of root-level tasks when namespace-local tasks exist
  - Ensures proper task isolation between different starter packages
- **`-Outline` Mode**: Outline now shows correct namespace dependencies (commit eed7e55)
  - Added `Resolve-DependencyWithNamespace` helper function
  - Updated `Get-ExecutionOrder` to use namespace-aware resolution
  - Updated `Show-DependencyTree` to display correct namespace tasks
  - `-Outline` now accurately previews what will actually execute

### Technical Notes
- **Dependency Resolution Algorithm**:
  ```powershell
  # For each dependency in task's DEPENDS list:
  if (task has namespace) {
      # Try namespace-prefixed first
      if (exists: {namespace}-{dependency}) {
          use {namespace}-{dependency}
      }
      else if (exists: {dependency}) {
          use {dependency}  # Fall back to root
      }
      else {
          warn: dependency not found
      }
  }
  else {
      # Root-level task, use standard resolution
      if (exists: {dependency}) {
          use {dependency}
      }
      else {
          warn: dependency not found
      }
  }
  ```
- This fix ensures consistency between task execution and outline preview
- All 74 core tests and 13 namespace tests pass
- Backward compatible: root-level tasks continue to work unchanged

## [0.6.0] - 2026-01-06

### Added
- **Multi-Namespace Task Discovery**: Support for multiple build package starters in a single project
  - Namespaces organized as subdirectories under `.build/` (e.g., `.build/bicep/`, `.build/golang/`)
  - Task names automatically prefixed with namespace (e.g., `lint` in `.build/bicep/` becomes `bicep-lint`)
  - Enables using Bicep and Golang (or any combination of packages) simultaneously without conflicts
  - Display shows namespace labels in task listings (`[project:bicep]`, `[project:golang]`)
  - Tab completion includes namespace-prefixed tasks from all subdirectories
  - Root-level `.build/` tasks remain unprefixed for backward compatibility
- **Smart Task Creation with `-NewTask`**: Automatic namespace detection for nested task creation
  - Parses task names for namespace prefix (e.g., `bolt -NewTask bicep-deploy` creates in `.build/bicep/`)
  - Falls back to root `.build/` if namespace subdirectory doesn't exist
  - Supports dash-named tasks using non-greedy regex matching (e.g., `bicep-build-all`)
  - Displays namespace information and full task name when detected
  - Maintains backward compatibility for non-namespaced task names

### Changed
- **Task Discovery Architecture**: `Get-ProjectTasksFromMultipleDirectories()` now scans subdirectories under `.build/`
  - Namespace extracted from subdirectory name (`.build/bicep/` → `bicep`)
  - Task metadata includes namespace field for tracking
  - Custom `-TaskDirectory` parameter maintains original single-directory behavior
- **Namespace Validation**: Case-sensitive subdirectory name validation
  - Only lowercase letters, numbers, and hyphens allowed
  - Invalid directories skipped with warning message
- **Test Suite Expansion**: Added comprehensive namespace testing
  - New test file `tests/Namespaces.Tests.ps1`
  - Covers discovery, prefixing, validation, and backward compatibility

### Technical Notes
- **Namespace Directory Structure Change**: 
  - ❌ **Old approach**: Top-level `.build-bicep`, `.build-golang` directories
    - Caused clutter at project root
    - Naming collisions with existing patterns
  - ✅ **New approach**: Subdirectories under `.build/` (`.build/bicep/`, `.build/golang/`)
    - Cleaner project structure
    - Follows standard conventions (similar to `.github/workflows/`)
    - Natural grouping of related tasks
- **Task Naming Strategy**:
  - Tasks automatically prefixed with namespace to prevent collisions
  - Example: Both Bicep and Golang can have `lint` task (becomes `bicep-lint` and `golang-lint`)
  - Root-level tasks remain unprefixed (e.g., `.build/Invoke-Build.ps1` → `build`)
- **NewTask Regex Pattern**: Uses non-greedy match `^([a-z0-9][a-z0-9\-]*?)-(.+)$`
  - Captures first segment before first dash as namespace
  - Handles multi-dash names correctly (e.g., `bicep-build-all` → namespace: `bicep`, task: `build-all`)

## [0.5.1] - 2026-01-05

### Fixed
- **Git Tag Creation Security**: Enhanced `New-GitTag.ps1` with comprehensive security and validation improvements
  - Added input validation for tag names to prevent command injection vulnerabilities
  - Tag names now validated against expected format pattern (`v<major>.<minor>.<patch>` or with pre-release suffix)
  - Sanitized all git command inputs before execution
  - Improved git command efficiency by capturing `ls-remote` output once instead of multiple calls
  - Added security considerations to script documentation
  - Made GitHub Actions success message conditional based on environment detection
  - Updated error messages to include pre-release version format examples
  - Improved regex pattern to use horizontal whitespace only, preventing unintended multi-line matches
  - Fixed `Get-Command` to use named parameter (`-Name`) per project coding standards

## [0.5.0] - 2026-01-02

### Added
- **Golang Starter Package**: Complete Go development workflow package (`packages/.build-golang`)
  - **`format`** task - Formats Go source files using `go fmt` (alias: `fmt`)
  - **`lint`** task - Validates Go code using `go vet`
  - **`test`** task - Runs Go tests using `go test -v`
  - **`build`** task - Builds Go application with automatic dependency resolution (format → lint → test → build)
  - Configuration support via `bolt.config.json` with `GoPath` parameter for custom project paths
  - Cross-platform binary naming (`.exe` suffix on Windows)
  - Auto-detection of module name from `go.mod`
  - Binary size reporting post-build
  - Output directory: `bin/` in project root
  - Example Go application with tests included at `tests/app/`
  - Comprehensive test suite: 21 Pester tests (16 validation + 5 integration) tagged `Golang-Tasks`
  - Package-specific README with configuration examples and troubleshooting
  - Release packaging script (`Create-Release.ps1`) for GitHub releases
  - Follows Bicep starter package conventions for consistency

### Changed
- **Release Tests**: Refactored `Build-PackageArchives.ps1 Functionality` tests to be package-agnostic
  - Removed hard-coded Bicep-specific checks (package names, archive paths)
  - Tests now verify generic behavior: discovery count, archive creation for all packages, checksums
  - Package-specific tests remain in their respective test blocks
  - Tests scale automatically with any number of starter packages
- **Documentation**: Updated `packages/README.md` to document Golang starter package
  - Installation instructions (GitHub releases and manual copy)
  - Usage examples for all tasks
  - Requirements (Go 1.21+)
  - Testing instructions with tag filtering

### Fixed
- **Test Discovery**: Updated package discovery test to handle multiple starter packages
  - Changed from expecting "Found 1 starter package" to "Found \d+ starter package"
  - Prevents test failures as new package starters are added
- **Line Endings**: Added LF normalization for Golang files in `.gitattributes`
  - Ensures consistent line endings across platforms for Go source files

## [0.4.2] - 2025-12-31

### Added
- **Invoke-Tests.ps1**: Wrapper script for comprehensive test execution with recursive discovery
  - Automatically discovers tests in both `tests/` and `packages/` directories
  - Supports tag filtering (`-Tag Core`, `-Tag Bicep-Tasks`, `-Tag Security`)
  - Includes `-Output` parameter for verbosity control (None, Normal, Detailed, Diagnostic)
  - Includes `-PassThru` parameter to return result object for automation

### Changed
- **Testing Documentation**: Updated README.md and CONTRIBUTING.md to document new test workflow
  - Documented `Invoke-Tests.ps1` as recommended test runner for comprehensive test execution
  - Maintained backward compatibility with direct `Invoke-Pester` usage
  - Added note about test organization for future starter package separation

### Technical Notes
- Tests for starter packages live within their package directories (e.g., `packages/.build-bicep/tests/`)
- This structure supports future separation of starter packages into separate repositories
- `Invoke-Pester` without arguments still works but only discovers tests in `tests/` directory
- CI workflows continue to use tag-based filtering for selective test execution

## [0.4.1] - 2025-12-30

### Changed
- **Variable Listing**: Enhanced `-ListVariables` output with usage helper text
  - Added inline documentation showing script usage syntax: `$BoltConfig.VariableName`
  - Improved clarity for accessing configuration variables in task scripts
  - Cleaned up whitespace formatting for better readability

## [0.4.0] - 2025-12-29

### Added
- **Download-Starter.ps1**: Interactive script for downloading and installing Bolt starter packages from GitHub releases
  - Two-level menu system: Release selection followed by starter package selection
  - Filters releases to only show versions containing starter packages (bolt-starter-*.zip)
  - Displays available starters for each release (bicep, typescript, etc.)
  - SHA256 checksum validation for secure downloads
  - Extracts packages directly to .build/ directory
  - Handles existing .build/ directories with overwrite warnings
  - Supports remote execution via `iex (irm ...)` pattern
  - No exit codes or CmdletBinding attribute for remote execution compatibility
  - Feature parity with Download.ps1 (interactive menus, prerelease support, default selection)

### Changed
- **Release Packaging**: Updated Copy-AdditionalModuleFiles.ps1 to include Download-Starter.ps1 in module releases
- **Documentation**: Added Download-Starter.ps1 installation option to Package Starters section in README

### Fixed
- **Download-Starter.ps1**: Extraction now works with existing .build/ directories instead of failing
  - Removed blocking error check that prevented execution if .build/ exists
  - Added creation of .build/ directory if missing
  - Added warning messages when using existing directory
  - Uses -Force flag with Expand-Archive to allow overwriting existing files

## [0.3.0] - 2025-12-29

### Added
- **Starter Package Release Automation**: Convention-based system for packaging starter packages as separate release assets
  - New orchestration script: `.scripts/release/Build-PackageArchives.ps1` discovers and builds all packages with `Create-Release.ps1` scripts
  - Package-specific script: `packages/.build-bicep/Create-Release.ps1` creates zip archives for Bicep starter package
  - All packages use the same version as Bolt core module
  - Automatic discovery of `packages/.build-*` directories with release scripts
  - Sequential execution with fail-fast error handling (one error stops all)
  - Archive naming convention: `bolt-starter-{toolchain}-{version}.zip`
  - SHA256 checksum generation for all package archives
  - Comprehensive test suite: 20 Pester tests covering validation, functionality, and convention compliance
- **Release Assets Enhancement**: GitHub releases now include starter package archives
  - Updated release workflow to build and publish starter package archives
  - New release assets: `bolt-starter-bicep-{version}.zip` (~3 KB) and checksum
  - Wildcard pattern matching for automatic inclusion of all starter packages
  - Documentation updates in `.github/workflows/release.md` covering new workflow step
- **Package Development Guide**: Added comprehensive documentation for creating starter packages
  - Convention requirements for `Create-Release.ps1` scripts in packages README
  - Instructions for adding new starter packages (TypeScript, Python, Docker, etc.)
  - Local testing procedures for package release scripts
  - Examples and validation requirements

### Changed
- **Release Workflow**: Enhanced release pipeline to support multiple package types
  - Added "Build starter package archives" step after core archive creation
  - Updated release asset file patterns to include starter packages
  - Performance metrics updated to reflect starter package build time (~5s additional)
  - Total release workflow time increased to ~40s

## [0.2.3] - 2025-12-27

### Changed
- **Release Packaging**: Renamed Copy-Documentation.ps1 to Copy-AdditionalModuleFiles.ps1
  - Better reflects the script's purpose of copying various essential module files
  - Now includes New-BoltModule.ps1 from project root in release packages
  - Ensures all necessary files for module installation are packaged together
  - Updated release workflow to use renamed script

### Added
- **Module Installation**: Added New-BoltModule.ps1 to project root
  - Provides module builder and installer for Bolt PowerShell module
  - Enables global 'bolt' command when installed as a module
  - Cross-platform support (Windows, Linux, macOS)
  - Supports custom installation paths via -ModuleOutputPath parameter
  - Includes -NoImport flag for build/release scenarios
  - Manages uninstallation with automatic detection of all installed versions

## [0.2.2] - 2025-12-24

### Fixed
- **Release Packaging**: Corrected Download.ps1 path in Copy-AdditionalModuleFiles.ps1
  - Fixed incorrect path from `.scripts/release/Download.ps1` to `Download.ps1`
  - Ensures Download.ps1 is correctly included in release packages

## [0.2.1] - 2025-12-24

### Changed
- **Release Packaging**: Updated release workflow to include Download.ps1 in module packages
  - Modified `.scripts/release/Copy-AdditionalModuleFiles.ps1` to copy Download.ps1 to module directory
  - Updated release documentation to reflect Download.ps1 inclusion in packages
  - Fixed README.md URL for Download.ps1 remote invocation (removed `refs/heads/` from path)

## [0.2.0] - 2025-12-24

### Added
- **Download Script**: New `Download.ps1` script for streamlined release installation
  - Interactive menu displaying all GitHub releases sorted by version (oldest first, newest last)
  - Shows release name, update date (ISO format), and prerelease indicators
  - Automatic default selection for newest stable (non-prerelease) release
  - Supports `-Latest` switch for non-interactive installation of latest stable release
  - Downloads release zip and SHA256 checksum files to temporary directory
  - Validates SHA256 checksum before extraction (fails if checksum file missing)
  - Extracts to current directory creating `./Bolt/` subdirectory
  - Automatic cleanup of temporary download files
  - Designed for remote invocation via `Invoke-Expression` for easy installation:
    ```powershell
    iex (irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download.ps1)
    ```
  - Includes coding standard exceptions for exit codes and CmdletBinding to support remote execution
  
### Changed
- **Installation Documentation**: Updated README to include Download.ps1 usage instructions
  - Added remote installation one-liner command
  - Documented both interactive and auto-install modes
  - Clarified next steps after download (navigate to Bolt/ and run installation)

## [0.1.1] - 2025-12-18

### Changed
- **Installation Instructions**: Updated README installation section to prioritize GitHub Releases as the primary installation method
  - Added comprehensive, version-agnostic step-by-step instructions for downloading from GitHub Releases
  - Covers both local (script mode) and module mode installation from releases
  - Added PowerShell commands for downloading release archive and checksum file using `Invoke-WebRequest`
  - Included checksum verification step with validation command
  - Added commands for extracting archive and cleaning up downloaded files
  - Moved clone-from-source option to Option 2 for development use
  - Added helpful tips for updating installations
- **Module Packaging**: Renamed `bolt-core.ps1` to `bolt.ps1` in module package
  - Module now contains `bolt.ps1` instead of `bolt-core.ps1` for consistency
  - Updated `New-BoltModule.ps1` to copy `bolt.ps1` as `bolt.ps1` (not `bolt-core.ps1`)
  - Updated module wrapper to reference `bolt.ps1` instead of `bolt-core.ps1`
  - Updated tests to verify `bolt.ps1` exists in module package

## [0.1.0] - 2025-12-16

### Added
- **GitHub Release Automation**: New CI workflow for publishing Bolt module to GitHub releases
  - Automatic release creation on git tag push (e.g., `v0.1.0`, `v1.0.0-beta`)
  - Module package generation with proper manifest and documentation
  - SHA256 checksums for release assets
  - Changelog validation to ensure version entries exist
  - Pre-release detection for beta/RC versions
  - Documentation prompt for release workflow maintenance
- **Configuration Variable System**: New project-level configuration management with `bolt.config.json`
  - Create configuration file at project root with user-defined variables
  - Automatic config injection into all tasks via `$BoltConfig` variable
  - Built-in variables: `ProjectRoot`, `TaskDirectory`, `TaskDirectoryPath`, `TaskScriptRoot`, `TaskName`, `GitRoot`, `GitBranch`, `Colors`
  - User-defined variables are merged at the root: access them via `$BoltConfig.YourVariableName`
  - Supports nested objects and complex data structures
  - Per-invocation configuration caching for performance (multiple tasks share same config)
  - Automatic cache invalidation on add/remove operations
  - New files: `bolt.config.json` (configuration), `bolt.config.schema.json` (JSON schema), `bolt.config.example.json` (template)
- **Variable Management CLI**: New command-line interface for managing configuration variables
  - `-ListVariables`: Display all configuration variables (built-in and user-defined) with values
  - `-AddVariable`: Add or update user-defined variables interactively with `-Name` and `-Value` parameters
  - `-RemoveVariable`: Remove user-defined variables by name with `-VariableName` parameter
  - Works in both script mode (`.\bolt.ps1 -ListVariables`) and module mode (`bolt -ListVariables`)
  - JSON schema validation on add/remove operations
  - Human-readable output with syntax-highlighted JSON display
- **Bicep Starter Package Refactoring**: Refactored all Bicep starter package tasks to use `$BoltConfig` for data access
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
  - Bicep starter package infrastructure: ARM templates, parameter files, configuration
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
- ❌ **Failed**: Passed arguments as array to bolt.ps1 instead of hashtable
  - Array splatting doesn't work with parameter names
  - Resulted in positional parameter errors
- ❌ **Failed**: Tab completion only registered for 'bolt.ps1' not module function
  - `Register-ArgumentCompleter` needs both 'Invoke-Bolt' and 'bolt' alias
  - Module mode had no tab completion initially
- ✅ **Solution**: Environment variable `$env:BOLT_PROJECT_ROOT` for context passing
  - Module sets variable before invoking bolt.ps1
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
- Example Bicep starter package tasks: `format`, `lint`, `build`
- Example Azure infrastructure (App Service + SQL Database)
- Comprehensive test suite with Pester
  - Core orchestration tests (fast, no external dependencies)
  - Security validation tests
  - Bicep starter package tests (requires Bicep CLI)
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

[Unreleased]: https://github.com/motowilliams/bolt/compare/v0.13.0...HEAD
[0.13.0]: https://github.com/motowilliams/bolt/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/motowilliams/bolt/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/motowilliams/bolt/compare/v0.10.2...v0.11.0
[0.10.2]: https://github.com/motowilliams/bolt/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/motowilliams/bolt/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/motowilliams/bolt/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/motowilliams/bolt/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/motowilliams/bolt/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/motowilliams/bolt/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/motowilliams/bolt/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/motowilliams/bolt/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/motowilliams/bolt/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/motowilliams/bolt/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/motowilliams/bolt/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/motowilliams/bolt/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/motowilliams/bolt/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/motowilliams/bolt/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/motowilliams/bolt/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/motowilliams/bolt/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/motowilliams/bolt/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/motowilliams/bolt/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/motowilliams/bolt/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/motowilliams/bolt/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/motowilliams/bolt/releases/tag/v0.1.0
