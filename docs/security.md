# Bolt Security

This document describes Bolt's security features, event logging, and vulnerability reporting.

## 🔒 Security Features

Bolt implements comprehensive security measures including:

- **Input Validation**: Task names, paths, and parameters are validated
- **Path Sanitization**: Protection against directory traversal attacks
- **Execution Policy Awareness**: Runtime checks for PowerShell security settings
- **Atomic File Operations**: Race condition prevention in file creation
- **Git Output Sanitization**: Safe handling of external command output
- **Output Validation**: ANSI escape sequence removal and control character filtering
- **Security Event Logging**: Opt-in audit logging for security-relevant operations

## Security Event Logging

Bolt can optionally log security-relevant events for audit and compliance purposes. Logging is **disabled by default** to minimize performance impact and respect privacy.

### Enable Logging

```powershell
# Windows (PowerShell)
$env:BOLT_AUDIT_LOG = '1'
.\bolt.ps1 build

# Linux/macOS (Bash)
export BOLT_AUDIT_LOG=1
pwsh -File bolt.ps1 build
```

### Log Location

**Logs are written to:** `.bolt/audit.log` (automatically created, excluded from git)

### What Gets Logged

- Task executions (name, script path, user, timestamp)
- File creations (via `-NewTask`)
- Custom `TaskDirectory` usage
- External command executions (e.g., `git status`)
- Task completion status (success/failure with exit codes)

### Log Format

```
2025-10-26 14:30:45 | Info | username@machine | TaskExecution | Task: build, Script: .build/Invoke-Build.ps1
2025-10-26 14:30:46 | Info | username@machine | TaskCompletion | Task 'build' succeeded
```

### View Logs

```powershell
Get-Content .bolt/audit.log
```

## Vulnerability Reporting

For security best practices and vulnerability reporting, see:
- **[SECURITY.md](../SECURITY.md)** - Complete security documentation and analysis
- **[.well-known/security.txt](../.well-known/security.txt)** - RFC 9116 compliant security policy

**Report security vulnerabilities** via [GitHub Security Advisories](https://github.com/motowilliams/bolt/security/advisories/new). Do not report vulnerabilities through public issues.

## Input Validation

### Path Sanitization

Bolt protects against directory traversal attacks by validating all paths:

```powershell
# ✅ Valid paths (relative, within project)
.\bolt.ps1 -TaskDirectory "custom-tasks"
.\bolt.ps1 -TaskDirectory ".build"

# ❌ Invalid paths (rejected by validation)
.\bolt.ps1 -TaskDirectory "../../../etc"        # Path traversal
.\bolt.ps1 -TaskDirectory "/absolute/path"      # Absolute path
.\bolt.ps1 -TaskDirectory "tasks;rm -rf /"      # Command injection
```

### Task Name Validation

Task names must follow strict rules to prevent injection attacks:

**Valid characters:**
- Lowercase letters (a-z)
- Numbers (0-9)
- Hyphens (-)

**Requirements:**
- Must start with letter or number
- Maximum length: 50 characters
- No special characters or spaces

**Examples:**
```powershell
# ✅ Valid task names
build
deploy-prod
my-task-123

# ❌ Invalid task names (rejected)
Build               # Uppercase
../etc/passwd       # Path characters
task;ls             # Command injection
```

### Script Path Security

All task script paths are validated before execution:

1. **Relative path check**: Must be relative to project root
2. **Boundary check**: Must be within project directory tree
3. **Character validation**: No dangerous characters (`;`, `|`, `&`, `$`, backticks)
4. **Existence check**: File must exist before execution

## Output Sanitization

Bolt sanitizes all external command output to prevent terminal injection attacks:

### ANSI Escape Sequence Removal

Removes color codes and cursor control sequences that could manipulate the terminal:

```powershell
# Input:  "\u001b[31mError\u001b[0m"
# Output: "Error"
```

### Control Character Filtering

Removes dangerous control characters:
- Null bytes (`\0`)
- Bell characters (`\a`)
- Backspace (`\b`)
- Vertical tab (`\v`)

### Length and Line Limits

Protects against denial-of-service attacks:
- **Maximum content length**: 100KB (configurable)
- **Maximum line count**: 1000 lines (configurable)
- Exceeding limits triggers truncation with warning

### Real-World Protection

Protects against malicious git output and other external commands:

```powershell
# Malicious branch name with ANSI codes
git branch --list "\u001b[2J\u001b[H"  # Clear screen command

# Bolt sanitizes output before display
# User sees: "branch-name" (safe)
```

## Design Goals

- **Zero external dependencies**: Just PowerShell 7.0+ (tools like Bicep, Git, etc. are optional via package starters)
- **Self-contained**: Single `bolt.ps1` file orchestrates everything
- **Convention over configuration**: Drop tasks in `.build/`, they're discovered automatically
- **Developer-friendly**: Tab completion, colorized output, helpful error messages
- **CI/CD ready**: Exit codes, deterministic behavior, no special flags

## Security Testing

Bolt includes comprehensive security tests in `tests/security/`:

1. **Security.Tests.ps1** - Input validation and injection prevention
2. **SecurityTxt.Tests.ps1** - RFC 9116 compliance testing
3. **SecurityLogging.Tests.ps1** - Audit logging functionality
4. **OutputValidation.Tests.ps1** - Output sanitization testing

Run security tests:
```powershell
Invoke-Pester -Tag Security
```

See [Testing Guide](testing.md) for more details.

---

[← Back to README](../README.md)
