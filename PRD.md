# Product Requirements Document (PRD)

## Bolt! Build System

**Version:** 0.10.0  
**Last Updated:** January 26, 2026  
**Product Owner:** motowilliams  
**Status:** Active Development

---

## Executive Summary

Bolt is a self-contained, cross-platform PowerShell build orchestration system that provides automatic task discovery, dependency resolution, and extensible workflows. It requires zero external dependencies beyond PowerShell Core 7.0+ and runs identically on Windows, Linux, and macOS. Bolt is designed for developers who need reliable, reproducible build workflows without the complexity of traditional build systems.

---

## 1. Product Vision

### 1.1 Vision Statement

Create a lightning-fast, developer-friendly build orchestration system that works identically across all platforms and environments, requiring no installation, configuration, or external dependencies. Empower developers to automate any workflow - from infrastructure-as-code to application builds - with simple, self-documenting task scripts.

### 1.2 Problem Statement

**Current Pain Points:**
- Build systems require complex setup and external dependencies
- Tasks behave differently locally vs. CI/CD environments
- Learning curve for build tools is steep
- Cross-platform compatibility is difficult to achieve
- Task dependencies are often implicit or poorly documented
- Build scripts are scattered and hard to discover

**Solution:**
Bolt eliminates these pain points by providing:
- Single-file orchestrator (`bolt.ps1`) with no dependencies
- Automatic task discovery via filesystem scanning
- Comment-based metadata for self-documenting tasks
- Explicit dependency resolution with circular dependency prevention
- Identical behavior locally and in CI/CD (90/10 principle)
- Cross-platform PowerShell Core support

### 1.3 Target Audience

**Primary Users:**
- **Infrastructure Engineers**: Building and deploying Azure/cloud resources
- **DevOps Engineers**: Creating CI/CD pipelines and automation workflows
- **Software Developers**: Building applications with multiple build steps
- **Platform Engineers**: Managing multi-tool workflows (Terraform, Bicep, Go, .NET)

**User Personas:**

1. **"Alex" - Infrastructure Engineer**
   - Builds Azure infrastructure with Bicep/Terraform
   - Needs reliable format → lint → build → deploy workflows
   - Works on Windows and WSL, deploys to Linux
   - Values consistency across environments

2. **"Jordan" - DevOps Engineer**
   - Creates CI/CD pipelines for multiple projects
   - Needs simple, reproducible build commands
   - Must work across GitHub Actions, Azure DevOps, GitLab CI
   - Values deterministic, exit-code-driven workflows

3. **"Morgan" - Full-Stack Developer**
   - Builds applications with Go, .NET, or Node.js
   - Runs format → test → build sequences frequently
   - Switches between projects with different toolchains
   - Values fast iteration with `-Only` flag

---

## 2. Business Goals

### 2.1 Success Metrics

**Adoption Metrics:**
- GitHub Stars: Target 100+ (current: [track in repo])
- Downloads/Clones: Track via GitHub Insights
- Package Starter Usage: Bicep, Golang, Terraform, .NET adoption rates

**Quality Metrics:**
- Test Coverage: 100% of core functionality (currently: 2394 total test lines)
- Cross-Platform CI: Pass rate on Ubuntu and Windows (current: 100%)
- Security: Zero P0 vulnerabilities (validated via security tests)
- Documentation: Complete coverage of features and use cases

**Performance Metrics:**
- Core Task Discovery: < 100ms for typical projects
- Test Suite: Core tests < 2s, Full suite < 60s
- Module Installation: < 5s on all platforms

### 2.2 Business Objectives

1. **Provide Zero-Dependency Build Orchestration**
   - Single PowerShell script, no npm/pip/gem installations
   - Works immediately after downloading bolt.ps1
   - No configuration files required (optional bolt.config.json)

2. **Enable Cross-Platform Workflows**
   - Identical behavior on Windows, Linux, macOS
   - CI/CD integration without platform-specific logic
   - Package starters with Docker fallback support

3. **Support Multiple Toolchains**
   - Package starters for popular tools (Bicep, Terraform, Go, .NET)
   - Extensible architecture for custom task development
   - Multi-namespace support for using multiple starters simultaneously

4. **Maintain Developer-Friendly UX**
   - Tab completion for task names
   - Colorized output with consistent formatting
   - Helpful error messages and validation
   - Preview mode with `-Outline` flag

---

## 3. Product Requirements

### 3.1 Core Features

#### 3.1.1 Task Orchestration (P0)

**Requirement:** Automatically discover and execute tasks with dependency resolution.

**Acceptance Criteria:**
- Tasks placed in `.build/` directory are discovered automatically
- Tasks can be executed individually: `.\bolt.ps1 taskname`
- Multiple tasks can be executed in sequence: `.\bolt.ps1 task1 task2 task3`
- Dependencies declared via `# DEPENDS:` are executed first
- Circular dependencies are detected and prevented
- Tasks execute in correct order based on dependency graph
- Exit codes (0=success, 1=failure) propagate correctly

**Status:** ✅ Implemented (v0.1.0+)

**Test Coverage:**
- `tests/bolt.Tests.ps1`: Task execution and dependency resolution
- `tests/Namespaces.Tests.ps1`: Namespace-aware dependency resolution

---

#### 3.1.2 Task Discovery (P0)

**Requirement:** Find and parse task scripts from filesystem without explicit registration.

**Acceptance Criteria:**
- Scan `.build/` directory (or custom via `-TaskDirectory`)
- Read first 30 lines of each `*.ps1` file
- Parse metadata: `# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`
- Support task aliases (comma-separated in `# TASK:`)
- Filename fallback for files without metadata
- Tab completion reflects discovered tasks

**Status:** ✅ Implemented (v0.1.0+)

**Test Coverage:**
- `tests/bolt.Tests.ps1`: Task discovery and metadata parsing
- Security validated via `tests/security/Security.Tests.ps1`

---

#### 3.1.3 Dependency Resolution (P0)

**Requirement:** Execute task dependencies before the main task.

**Acceptance Criteria:**
- Parse `# DEPENDS: dep1, dep2` from task metadata
- Resolve dependencies recursively (depth-first)
- Execute each dependency only once (deduplication)
- Detect and prevent circular dependencies
- `-Only` flag skips all dependencies
- Stop execution on first failure

**Status:** ✅ Implemented (v0.1.0+)

**Design:**
- `$ExecutedTasks` hashtable tracks completed tasks
- Recursive `Invoke-Task` function
- Exit code checking after each task

**Test Coverage:**
- `tests/bolt.Tests.ps1`: Dependency chains, circular dependencies
- `tests/fixtures/`: Mock tasks with various dependency patterns

---

#### 3.1.4 Task Outline Visualization (P1)

**Requirement:** Preview task execution plan without running tasks.

**Acceptance Criteria:**
- `.\bolt.ps1 taskname -Outline` shows dependency tree
- ASCII tree structure (├── └──) with task descriptions
- Shows execution order (numbered list)
- Respects `-Only` flag (shows what would execute)
- Highlights missing dependencies in red
- Works with namespace-prefixed tasks

**Status:** ✅ Implemented (v0.5.0)

**Example Output:**
```
Task execution plan for: build

build (Compiles source files)
├── format (Formats source files)
└── lint (Validates source files)

Execution order:
  1. format
  2. lint
  3. build
```

**Test Coverage:**
- `tests/bolt.Tests.ps1`: Outline flag validation

---

#### 3.1.5 Parameter Sets (P1)

**Requirement:** Provide validated operation modes via PowerShell parameter sets.

**Acceptance Criteria:**
- Parameter sets prevent invalid combinations
- Sets: Help, TaskExecution, ListTasks, CreateTask, ValidateTasks, ListVariables, AddVariable, RemoveVariable
- Default parameter set shows help
- Each set has clear purpose and validation
- Error messages indicate valid combinations

**Status:** ✅ Implemented (v0.6.0)

**Test Coverage:**
- `tests/bolt.Tests.ps1`: Parameter validation
- Validated via PowerShell's built-in parameter set logic

---

#### 3.1.6 Module Installation (P1)

**Requirement:** Install Bolt as a PowerShell module for global access.

**Acceptance Criteria:**
- `.\New-BoltModule.ps1 -Install` creates module
- Module installed to platform-specific paths:
  - Windows: `~/Documents/PowerShell/Modules/Bolt/`
  - Linux/macOS: `~/.local/share/powershell/Modules/Bolt/`
- `bolt` command available globally after installation
- Upward directory search finds `.build/` like git
- Works from any subdirectory within project
- `.\New-BoltModule.ps1 -Uninstall` removes module

**Status:** ✅ Implemented (v0.6.0)

**Test Coverage:**
- `tests/New-BoltModule.Tests.ps1`: Module installation and uninstallation

---

#### 3.1.7 Configuration Variables (P1)

**Requirement:** Project-level configuration via `bolt.config.json`.

**Acceptance Criteria:**
- JSON file in project root or found via upward search
- Schema validation via `bolt.config.schema.json`
- Auto-injected as `$BoltConfig` into all tasks
- Type-safe access: `$BoltConfig.Azure.SubscriptionId`
- CLI commands: `-ListVariables`, `-AddVariable`, `-RemoveVariable`
- Config caching per-invocation for performance
- Invalidation on add/remove operations

**Status:** ✅ Implemented (v0.9.0)

**Test Coverage:**
- `tests/Variables.Tests.ps1`: Config loading, CLI operations, caching

---

#### 3.1.8 Task Validation (P2)

**Requirement:** Validate task file structure and metadata.

**Acceptance Criteria:**
- `.\bolt.ps1 -ValidateTasks` checks all task files
- Validates TASK, DESCRIPTION, DEPENDS metadata
- Checks for explicit exit codes (exit 0/1)
- Validates task name format (lowercase alphanumeric + hyphens)
- Color-coded report (✓ Pass, ⚠ Warn, ✗ Fail)
- Summary statistics (pass/warning/failure counts)
- Exit code reflects validation status

**Status:** ✅ Implemented (v0.8.0)

**Test Coverage:**
- `tests/bolt.Tests.ps1`: Validation feature tests

---

### 3.2 Security Requirements (P0)

#### 3.2.1 Input Validation

**Requirement:** Sanitize and validate all user inputs to prevent injection attacks.

**Acceptance Criteria:**
- Task names: Only lowercase alphanumeric and hyphens, max 50 chars
- TaskDirectory: Relative paths only, no `..` traversal, within project root
- Script paths: Resolved to absolute paths, validated against project root
- Command injection prevention: No semicolons, pipes, backticks in inputs

**Status:** ✅ Implemented (v0.7.0)

**Test Coverage:**
- `tests/security/Security.Tests.ps1`: P0 security validation tests

---

#### 3.2.2 Output Sanitization

**Requirement:** Prevent terminal injection via ANSI escape sequences.

**Acceptance Criteria:**
- Strip ANSI escape sequences from external command output
- Remove control characters (null bytes, bell, backspace)
- Enforce length limits (100KB default)
- Enforce line limits (1000 lines default)
- Maintain readability while ensuring security

**Status:** ✅ Implemented (v0.9.0)

**Test Coverage:**
- `tests/security/OutputValidation.Tests.ps1`: Output sanitization tests

---

#### 3.2.3 Security Logging (Optional)

**Requirement:** Opt-in audit logging for security monitoring.

**Acceptance Criteria:**
- Enable via `$env:BOLT_AUDIT_LOG = 1`
- Log task executions, file creations, external commands
- Logs written to `.bolt/audit.log` (gitignored)
- Structured format: timestamp, level, user, action, details
- No sensitive data in logs

**Status:** ✅ Implemented (v0.9.0)

**Test Coverage:**
- `tests/security/SecurityLogging.Tests.ps1`: Audit logging tests

---

#### 3.2.4 RFC 9116 Compliance

**Requirement:** Security policy file for vulnerability reporting.

**Acceptance Criteria:**
- `.well-known/security.txt` file exists
- Contains required fields: Contact, Expires, Preferred-Languages
- Points to GitHub Security Advisories
- Updated regularly (expires annually)

**Status:** ✅ Implemented (v0.9.0)

**Test Coverage:**
- `tests/security/SecurityTxt.Tests.ps1`: RFC 9116 compliance tests

---

### 3.3 Package Starters

Package starters provide pre-built task collections for specific toolchains. Each starter follows consistent patterns for formatting, linting, testing, and building.

#### 3.3.1 Bicep Starter Package (P1)

**Purpose:** Infrastructure-as-Code tasks for Azure Bicep.

**Tasks:**
- `format` (alias: `fmt`) - Format Bicep files with `bicep format`
- `lint` - Validate Bicep files with `bicep lint`
- `build` - Compile Bicep to ARM JSON (depends: format, lint)

**Requirements:**
- Bicep CLI installed or Docker available
- Recursively discovers `.bicep` files
- Only compiles `main*.bicep` files
- Outputs `.json` alongside `.bicep` files

**Status:** ✅ Implemented (v0.1.0)

**Test Coverage:**
- `packages/.build-bicep/tests/Tasks.Tests.ps1`: Task structure validation
- `packages/.build-bicep/tests/Integration.Tests.ps1`: End-to-end integration

---

#### 3.3.2 Golang Starter Package (P1)

**Purpose:** Go application development tasks.

**Tasks:**
- `format` (alias: `fmt`) - Format Go files with `go fmt`
- `lint` - Validate Go code with `go vet`
- `test` - Run Go tests with `go test`
- `build` - Build Go application (depends: format, lint, test)

**Requirements:**
- Go CLI installed or Docker available
- Recursively discovers `.go` files
- Produces binary in project root

**Status:** ✅ Implemented (v0.8.0)

**Test Coverage:**
- `packages/.build-golang/tests/Tasks.Tests.ps1`: Task structure validation
- `packages/.build-golang/tests/Integration.Tests.ps1`: End-to-end integration

---

#### 3.3.3 Terraform Starter Package (P1)

**Purpose:** Infrastructure-as-Code tasks for Terraform.

**Tasks:**
- `format` (alias: `fmt`) - Format `.tf` files with `terraform fmt`
- `validate` - Validate configuration with `terraform init` + `terraform validate`
- `plan` - Generate execution plan with `terraform plan`
- `apply` (alias: `deploy`) - Apply changes with `terraform apply` (5s safety delay)

**Requirements:**
- Terraform CLI installed or Docker available
- Dependency chain: apply → plan → validate → format
- Saves plan to `terraform.tfplan`

**Status:** ✅ Implemented (v0.9.0)

**Test Coverage:**
- `packages/.build-terraform/tests/Tasks.Tests.ps1`: Task structure validation
- `packages/.build-terraform/tests/Integration.Tests.ps1`: End-to-end integration

---

#### 3.3.4 .NET Starter Package (P1)

**Purpose:** .NET/C# application development tasks.

**Tasks:**
- `format` (alias: `fmt`) - Format C# files with `dotnet format`
- `restore` - Restore NuGet packages with `dotnet restore`
- `test` - Run .NET tests with `dotnet test`
- `build` - Build .NET projects (depends: format, restore, test)

**Requirements:**
- .NET SDK installed or Docker available
- Recursively discovers `.csproj` files
- Supports xUnit, NUnit, MSTest frameworks

**Status:** ✅ Implemented (v0.10.0)

**Test Coverage:**
- `packages/.build-dotnet/tests/Tasks.Tests.ps1`: Task structure validation
- `packages/.build-dotnet/tests/Integration.Tests.ps1`: End-to-end integration

---

### 3.4 Multi-Namespace Support (P2)

**Requirement:** Use multiple package starters simultaneously with namespace isolation.

**Acceptance Criteria:**
- Tasks in subdirectories get namespace prefixes:
  - `.build/bicep/Invoke-Lint.ps1` → `bicep-lint`
  - `.build/golang/Invoke-Build.ps1` → `golang-build`
- Dependencies resolve with namespace priority:
  - Within same namespace first
  - Fallback to root namespace
- Tab completion shows namespace-prefixed tasks
- `-Outline` works with namespaced dependencies

**Status:** ✅ Implemented (v0.7.0)

**Test Coverage:**
- `tests/Namespaces.Tests.ps1`: Namespace resolution tests

---

## 4. Non-Goals

The following features are **intentionally excluded** from Bolt's roadmap. These are permanent design decisions.

### 4.1 Build System Caching

**Description:** Automatic file change detection to skip tasks if inputs haven't changed.

**Rationale:**
- Requires accurate dependency tracking (extremely complex)
- Incorrect cache invalidation causes stale builds (broken builds worse than slow builds)
- Each toolchain has unique caching needs (better handled in task scripts)
- `-Only` flag provides explicit fast iteration control

**Alternative:** Task-level caching, tool-specific caching (e.g., `go build` cache)

---

### 4.2 Task Parallelism

**Description:** Running multiple tasks simultaneously in parallel threads/processes.

**Rationale:**
- Race conditions with shared file access (format and lint modifying same files)
- Non-deterministic failures and interleaved output
- Loss of predictability and debuggability
- Tasks can implement internal parallelism if needed

**Alternative:** Tasks use `ForEach-Object -Parallel` for internal file processing

---

### 4.3 Task Argument Passing

**Description:** Passing named arguments to tasks via bolt.ps1 CLI (e.g., `.\bolt.ps1 deploy -Environment prod`).

**Rationale:**
- Parameter ambiguity with multi-task execution
- Parameter collision with bolt's own parameters
- Complex parsing to distinguish bolt vs. task parameters
- Direct script invocation works but bypasses dependencies

**Alternatives:**
1. **bolt.config.json** (preferred) - Type-safe, validated, auto-injected
2. **Environment variables** - For dynamic/runtime values
3. **Direct invocation** - `.\Invoke-Deploy.ps1 -Environment prod` (no dependency resolution)

---

## 5. Technical Requirements

### 5.1 Platform Support

**Required:**
- PowerShell Core 7.0+ (uses `#Requires -Version 7.0`)
- Windows 10/11, Windows Server 2016+
- Ubuntu 20.04+, Debian 10+, CentOS 8+
- macOS 11+ (Big Sur and later)

**Optional:**
- Git (for `check-index` task)
- Docker (for package starter fallback support)
- External tools per package starter (Bicep, Go, Terraform, .NET)

---

### 5.2 Performance Requirements

**Task Discovery:**
- < 100ms for typical projects (< 100 tasks)
- < 500ms for large projects (500+ tasks)

**Task Execution:**
- Overhead < 50ms per task invocation
- No measurable overhead for dependency resolution

**Test Suite:**
- Core tests: < 2s (fast iteration)
- Security tests: < 10s
- Full suite: < 60s (all package starters)

---

### 5.3 Compatibility Requirements

**PowerShell Features:**
- `using namespace` syntax (PS 5.0+)
- Ternary operator `? :` (PS 7.0+)
- `$IsWindows`, `$IsLinux`, `$IsMacOS` variables (PS Core)
- Parameter sets (PS 3.0+)
- Tab completion via `Register-ArgumentCompleter` (PS 5.0+)

**Cross-Platform:**
- Use `Join-Path` for all path construction
- Use PowerShell cmdlets, not Unix commands (grep, tail, cat, etc.)
- Use `-Force` with `Get-ChildItem` for hidden directories (`.build`)
- Platform-specific module paths (Windows vs. Linux/macOS)

---

### 5.4 CI/CD Integration

**Requirements:**
- Exit codes propagate correctly (0=success, 1=failure)
- No interactive prompts in CI mode
- Deterministic behavior (same results every run)
- Works with GitHub Actions, Azure DevOps, GitLab CI, Jenkins

**CI Workflow:**
- Triggers: Push to all branches, PRs to main
- Platforms: Ubuntu and Windows matrix
- Pipeline: Core tests → Package starter tests → Build pipeline
- Artifacts: Test results (NUnit XML), Build outputs

**Status:** ✅ Implemented (v0.1.0)
- `.github/workflows/ci.yml`: Multi-platform CI
- `.github/workflows/release.yml`: Automated releases

---

## 6. User Experience Requirements

### 6.1 Command-Line Interface

**Design Principles:**
- Clear, consistent command structure
- Helpful error messages with actionable guidance
- Preview mode with `-Outline` before execution
- Validation mode with `-ValidateTasks` for quality checks

**Examples:**
```powershell
# Task execution
.\bolt.ps1 build                    # With dependencies
.\bolt.ps1 build -Only              # Skip dependencies
.\bolt.ps1 format lint build        # Multiple tasks

# Discovery and inspection
.\bolt.ps1 -ListTasks               # List all tasks
.\bolt.ps1 build -Outline           # Preview execution plan
.\bolt.ps1 -ValidateTasks           # Validate task files

# Task management
.\bolt.ps1 -NewTask deploy          # Create new task
.\bolt.ps1 -TaskDirectory "custom"  # Use custom directory

# Configuration
.\bolt.ps1 -ListVariables           # Show all variables
.\bolt.ps1 -AddVariable -Name "Env" -Value "prod"
.\bolt.ps1 -RemoveVariable -VariableName "Env"
```

---

### 6.2 Output Formatting

**Color Conventions:**
- **Cyan**: Task headers and section titles
- **Gray**: Progress updates and file names
- **Green**: Success messages (✓)
- **Yellow**: Warnings (⚠)
- **Red**: Errors (✗)

**Format Standards:**
- Consistent use of Unicode symbols (✓ ✗ ⚠)
- Clear task boundaries with blank lines
- Indentation for hierarchical output
- Summary statistics at end

---

### 6.3 Error Handling

**Requirements:**
- Clear error messages with context
- Actionable guidance ("Install X with...")
- Exit immediately on first failure (fail-fast)
- Proper exit codes for CI/CD integration

**Examples:**
```
Error: Task 'invalid-name' contains invalid characters. 
Only lowercase letters, numbers, and hyphens are allowed.

Error: Bicep CLI not found. Please install: https://aka.ms/bicep-install

Error: Circular dependency detected: build → lint → format → build
```

---

### 6.4 Documentation

**Requirements:**
- README.md: Quick start, features, examples
- IMPLEMENTATION.md: Complete feature documentation
- CONTRIBUTING.md: Task development guidelines
- CHANGELOG.md: Version history (Keep a Changelog format)
- SECURITY.md: Security practices and vulnerability reporting
- Package READMEs: Per-package installation and usage

**Status:** ✅ Complete

---

## 7. Success Metrics

### 7.1 Adoption Metrics

**GitHub Metrics:**
- Stars: Target 100+ (track via GitHub Insights)
- Forks: Track community engagement
- Issues/PRs: Track activity and contributions

**Usage Metrics:**
- Downloads from GitHub Releases
- Package starter adoption rates (which packages are popular)
- Module installations (track via telemetry if added)

---

### 7.2 Quality Metrics

**Test Coverage:**
- Core functionality: 100% (2394+ test lines)
- Security validation: P0 coverage complete
- Package starters: Each has structure + integration tests
- Cross-platform: CI passes on Ubuntu and Windows

**Bug Metrics:**
- P0 bugs: 0 open (security, data loss, crashes)
- P1 bugs: Track and prioritize
- Average resolution time: < 7 days for P1, < 30 days for P2

---

### 7.3 Performance Metrics

**Benchmarks:**
- Task discovery: < 100ms (typical project)
- Core tests: < 2s
- Full test suite: < 60s
- Module installation: < 5s

---

### 7.4 User Satisfaction

**Feedback Channels:**
- GitHub Issues: Bug reports, feature requests
- GitHub Discussions: Questions, use cases, tips
- Pull Requests: Community contributions

**Quality Indicators:**
- Issue resolution rate
- PR acceptance rate
- Documentation clarity (measured by "how do I" questions)

---

## 8. Roadmap

### 8.1 Completed Milestones

- ✅ **v0.1.0** - Core orchestration, Bicep starter package
- ✅ **v0.5.0** - Task outline visualization
- ✅ **v0.6.0** - Module installation, parameter sets
- ✅ **v0.7.0** - Multi-namespace support, security validation
- ✅ **v0.8.0** - Task validation, Golang starter package
- ✅ **v0.9.0** - Configuration variables, Terraform starter package, security logging
- ✅ **v0.10.0** - .NET starter package

### 8.2 Possible Future Features

Features under consideration (not committed):

**Named Parameter Passing** (Design Phase)
- Hashtable-based approach for task arguments
- Alternative to environment variables
- See IMPLEMENTATION.md for design discussion

**Additional Package Starters** (Community-Driven)
- Python (format, lint, test, build)
- Node.js/TypeScript (format, lint, test, build)
- Rust (format, lint, test, build)
- Docker (build, tag, push)

**Enhanced Validation** (P2)
- Task complexity analysis
- Dependency graph visualization
- Performance profiling per task

**Telemetry** (Opt-In Only)
- Anonymous usage statistics
- Error tracking
- Performance benchmarks

---

## 9. Dependencies

### 9.1 Required Dependencies

**Core:**
- PowerShell Core 7.0+ (cross-platform runtime)

**Optional:**
- Git (for `check-index` task)
- Pester 5.0+ (for running test suite)

### 9.2 Package Starter Dependencies

Each package starter optionally requires its toolchain CLI:

**Bicep Starter:**
- Bicep CLI (or Docker fallback)

**Golang Starter:**
- Go CLI (or Docker fallback)

**Terraform Starter:**
- Terraform CLI (or Docker fallback)

**.NET Starter:**
- .NET SDK (or Docker fallback)

---

## 10. Risks and Mitigation

### 10.1 Technical Risks

**Risk:** Cross-platform compatibility issues
- **Mitigation:** CI tests on Ubuntu and Windows; use PowerShell cmdlets only; avoid Unix commands

**Risk:** Security vulnerabilities in user-provided tasks
- **Mitigation:** Input validation, output sanitization, security testing, audit logging

**Risk:** Performance degradation with large projects
- **Mitigation:** Efficient task discovery; deduplication; caching where appropriate

---

### 10.2 Adoption Risks

**Risk:** Users unfamiliar with PowerShell
- **Mitigation:** Clear examples; package starters for common tools; comprehensive documentation

**Risk:** Competition from established build systems (Make, Rake, Gradle)
- **Mitigation:** Focus on PowerShell ecosystem; zero dependencies; cross-platform support; module mode

**Risk:** Limited community contributions
- **Mitigation:** Clear contribution guidelines; package starter development guides; welcoming community

---

## 11. Appendix

### 11.1 Glossary

- **Task**: A PowerShell script in `.build/` that performs a specific action
- **Package Starter**: Pre-built collection of tasks for a specific toolchain
- **Namespace**: Subdirectory in `.build/` that prefixes task names (e.g., `bicep-lint`)
- **Metadata**: Comment-based headers in task files (`# TASK:`, `# DESCRIPTION:`, `# DEPENDS:`)
- **Dependency**: A task that must execute before another task
- **Orchestration**: The process of discovering, resolving, and executing tasks
- **Module Mode**: Bolt installed as PowerShell module for global `bolt` command
- **Script Mode**: Bolt invoked directly via `.\bolt.ps1`

### 11.2 References

- **Repository:** https://github.com/motowilliams/bolt
- **Documentation:**
  - README.md - Quick start and overview
  - IMPLEMENTATION.md - Feature details and examples
  - CONTRIBUTING.md - Development guidelines
  - SECURITY.md - Security practices
  - CHANGELOG.md - Version history
- **Package Starters:** packages/README.md
- **CI/CD:** .github/workflows/ci.yml
- **Security Policy:** .well-known/security.txt (RFC 9116)

---

## Document Control

**Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-26 | copilot | Initial PRD creation based on existing documentation |

**Approval:**

- Product Owner: [To be signed]
- Engineering Lead: [To be signed]
- Date: [To be signed]

**Next Review Date:** 2026-07-26 (6 months)

---

_This PRD is a living document and will be updated as the product evolves._
