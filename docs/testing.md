# Bolt Testing Guide

This document describes Bolt's comprehensive test suite, including how to run tests, understand test coverage, and integrate with CI/CD pipelines.

## 🧪 Test Structure

The project includes comprehensive **Pester** tests to ensure correct behavior when refactoring or adding new features. Tests are organized for clarity with separate locations for core and module-specific tests.

### Core Tests (`tests/` directory)

- **`tests/bolt.Tests.ps1`** - Core orchestration tests
  - Script validation, task discovery, execution, dependency resolution
  - Uses mock fixtures from `tests/fixtures/` to test Bolt itself
  - Tag: `Core`

- **`tests/security/Security.Tests.ps1`** - Security validation tests
  - Input validation, path sanitization, injection prevention
  - Validates TaskDirectory, task names, and script paths
  - Tag: `Security`, `P0`

- **`tests/security/SecurityTxt.Tests.ps1`** - RFC 9116 compliance
  - Validates .well-known/security.txt file format and content
  - Verifies required and recommended fields
  - Tag: `SecurityTxt`, `Operational`

- **`tests/security/SecurityLogging.Tests.ps1`** - Security event logging
  - Tests opt-in audit logging functionality
  - Validates log format, file management, and GitIgnore integration
  - Tag: `SecurityLogging`, `Operational`

- **`tests/security/OutputValidation.Tests.ps1`** - Output sanitization
  - Tests ANSI escape sequence removal and control character filtering
  - Validates length/line limits and malicious input handling
  - Tag: `OutputValidation`, `Security`

### Package Starter Tests

**Bicep Starter Package** (`packages/.build-bicep/tests/` directory):
- **`packages/.build-bicep/tests/Tasks.Tests.ps1`** - Task validation
  - Validates structure and metadata of Bicep tasks
  - Tag: `Bicep-Tasks`
  
- **`packages/.build-bicep/tests/Integration.Tests.ps1`** - Integration tests
  - Executes actual Bicep operations against real infrastructure files
  - Requires Bicep CLI to be installed
  - Tag: `Bicep-Tasks`

**Golang Starter Package** (`packages/.build-golang/tests/` directory):
- **`packages/.build-golang/tests/Tasks.Tests.ps1`** - Task validation
  - Validates structure and metadata of Golang tasks
  - Tag: `Golang-Tasks`
  
- **`packages/.build-golang/tests/Integration.Tests.ps1`** - Integration tests
  - Executes actual Go operations against example Go application
  - Requires Go CLI to be installed
  - Tag: `Golang-Tasks`

## Running Tests

**Recommended**: Use the `Invoke-Tests.ps1` wrapper script to run all tests, including those in starter packages:

```powershell
# Run all tests (discovers tests in tests/ and packages/)
.\Invoke-Tests.ps1

# Run with detailed output
.\Invoke-Tests.ps1 -Output Detailed

# Run tests by tag
.\Invoke-Tests.ps1 -Tag Core          # Fast core tests (~1s)
.\Invoke-Tests.ps1 -Tag Security      # Security validation (~10s)
.\Invoke-Tests.ps1 -Tag Bicep-Tasks   # Bicep starter package (~22s)

# Return result object for automation
.\Invoke-Tests.ps1 -PassThru
```

**Alternative**: Use `Invoke-Pester` directly (requires explicit paths for starter packages):

```powershell
# Run core tests only (default Pester behavior)
Invoke-Pester

# Run specific test locations
Invoke-Pester -Path tests/bolt.Tests.ps1
Invoke-Pester -Path packages/.build-bicep/tests/

# Run tests by tag
Invoke-Pester -Tag Core
Invoke-Pester -Tag Security
Invoke-Pester -Tag Bicep-Tasks
```

> **Note**: `Invoke-Tests.ps1` automatically discovers tests in both `tests/` and `packages/` directories, making it easier to run the complete test suite.

## Test Tags

Tests are organized with tags for flexible execution:

- **`Core`** - Tests bolt.ps1 orchestration itself
  - Fast execution (~1 second)
  - No external tool dependencies
  - Uses mock fixtures from `tests/fixtures/`

- **`Security`** - Tests security validations and features
  - Moderate execution (~10 seconds)
  - Includes Security.Tests.ps1, SecurityTxt.Tests.ps1, SecurityLogging.Tests.ps1, OutputValidation.Tests.ps1
  - Validates input sanitization, RFC 9116 compliance, audit logging, and output validation
  - Tests P0 security fixes for TaskDirectory, path sanitization, task name validation, and terminal injection protection
  
- **`Bicep-Tasks`** - Tests Bicep task implementation
  - Slower execution (~22 seconds)
  - Requires Bicep CLI for integration tests
  - Tests live with implementation in `packages/.build-bicep/tests/`
  - Validates task structure, metadata, and actual Bicep operations

**Common workflows:**
```powershell
# Quick validation during development
Invoke-Pester -Tag Core

# Security validation
Invoke-Pester -Tag Security

# Full task testing before commit
Invoke-Pester -Tag Bicep-Tasks

# Complete test suite
Invoke-Pester
```

## Test Coverage

### Core Orchestration (`tests/bolt.Tests.ps1`)

- Script validation and PowerShell version requirements
- Task listing with `-ListTasks` and `-Help` parameters
- Task discovery from `.build/` directory and test fixtures
- Filename fallback for tasks without metadata (handles Invoke-Verb-Noun.ps1 patterns)
- Task execution (single, multiple, with dependencies)
- Dependency resolution and `-Only` flag behavior
- New task creation with `-NewTask` parameter
- Error handling for invalid tasks
- Parameter validation (comma/space-separated)
- Documentation consistency

### Security Tests (`tests/security/`)

1. **Security.Tests.ps1** - Core security validation:
   - Path traversal protection (absolute paths, parent directory references)
   - Command injection prevention (semicolons, pipes, backticks)
   - PowerShell injection prevention (special characters, variables, command substitution)
   - Input sanitization and validation
   - Error handling security (secure failure modes)

2. **SecurityTxt.Tests.ps1** - RFC 9116 compliance:
   - File existence and location (.well-known/security.txt)
   - Required fields (Contact, Expires)
   - Recommended fields (Preferred-Languages, Canonical, Policy)
   - Contact information validity (GitHub Security Advisories)
   - File format and structure (UTF-8 encoding, field names)
   - Security policy content (vulnerability reporting guidance)
   - Repository integration (GitHub references, git tracking)

3. **SecurityLogging.Tests.ps1** - Audit logging:
   - Logging disabled by default (no overhead when not enabled)
   - Opt-in via `$env:BOLT_AUDIT_LOG` environment variable
   - Log entry format (timestamp, severity, user, machine, event, details)
   - TaskDirectory usage logging (custom directories only)
   - File creation logging (via -NewTask)
   - Task execution logging (start, completion, success/failure)
   - External command logging (git operations)
   - Log file management (append mode, sequential writes)
   - GitIgnore integration (.bolt/ excluded from version control)
   - Error handling (silent failures, directory conflicts)

4. **OutputValidation.Tests.ps1** - Terminal injection protection:
   - Normal output pass-through (no modification of safe content)
   - ANSI escape sequence removal (colors, cursor control)
   - Control character filtering (null bytes, bell, backspace, etc.)
   - Length validation and truncation (100KB default limit)
   - Line count validation and truncation (1000 lines default)
   - Malicious input handling (command injection attempts)
   - Real-world git scenarios (status output, branch names)
   - Pipeline support (accepts input from pipeline)
   - Verbose output (detailed logging of sanitization)
   - Integration tests (check-index task output validation)

### Bicep Tasks (`packages/.build-bicep/tests/Tasks.Tests.ps1`)

- Format task: existence, syntax, metadata, aliases
- Lint task: existence, syntax, metadata, dependencies
- Build task: existence, syntax, metadata, dependencies

### Bicep Integration (`packages/.build-bicep/tests/Integration.Tests.ps1`)

- Format Bicep files integration
- Lint Bicep files integration
- Build Bicep files integration
- Full build pipeline with dependencies

## Test Fixtures

Mock tasks in `tests/fixtures/` are used to test Bolt orchestration without external dependencies:

- `Invoke-MockSimple.ps1` - Simple task with no dependencies
- `Invoke-MockWithDep.ps1` - Task with single dependency
- `Invoke-MockComplex.ps1` - Task with multiple dependencies
- `Invoke-MockFail.ps1` - Task that intentionally fails

These fixtures enable testing with the `-TaskDirectory` parameter:

```powershell
# Tests explicitly specify the fixture directory
.\bolt.ps1 mock-simple -TaskDirectory 'tests/fixtures'

# This allows clean separation between production tasks and test mocks
```

The fixtures allow testing of:
- Dependency resolution chains
- Error handling
- Task execution order
- Bolt orchestration without relying on real project tasks

## Test Requirements

- **Pester 5.0+**: Install with `Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser`
- **Bicep CLI** (optional): Required only for integration tests, other tests run without it
- Tests run in isolated contexts with proper setup/teardown
- Test results output to `TestResults.xml` (NUnit format for CI/CD)
- All tests pass consistently across platforms (Windows, Linux, macOS)

## CI/CD Integration

Use Pester directly in CI pipelines:

```yaml
# GitHub Actions
- name: Run Tests
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Output Detailed -CI
  shell: pwsh

# Run only fast core tests for quick PR validation
- name: Quick Validation
  run: |
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
    Invoke-Pester -Tag Core -Output Detailed -CI
  shell: pwsh
  
- name: Publish Test Results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: TestResults.xml
```

## Test Results

All tests pass consistently. Run `Invoke-Pester` to see current results.

---

[← Back to README](../README.md)
