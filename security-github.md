# GitHub Security Evaluation - gosh.ps1

**Project:** Gosh! PowerShell Build System  
**Analysis Date:** October 25, 2025  
**Evaluator:** GitHub Security Team (AI-Assisted)  
**Scope:** Complete security assessment of gosh.ps1 v1.0  
**Methodology:** Code review, threat modeling, dependency analysis, configuration review

> **Note:** This report complements the existing [SECURITY.md](./SECURITY.md) file. While SECURITY.md focuses on code-level security fixes (P0-P2 implementation tasks), this GitHub evaluation focuses on operational security, supply chain security, and GitHub platform integration.

---

## Executive Summary

This security evaluation identifies **12 actionable security findings** across multiple categories. The assessment reveals that while the project has implemented several security controls (as documented in SECURITY.md), there are additional concerns from a GitHub security perspective, particularly around supply chain security, secrets management, and operational security.

**Overall Risk Level:** 🟡 MODERATE

**Key Findings:**
- ✅ **Strengths:** Good input validation, no hardcoded secrets, comprehensive parameter validation
- ⚠️ **Concerns:** Missing security.txt, no dependency pinning, limited logging for security events
- 🔴 **Critical:** Dynamic code execution via ScriptBlock::Create (mitigated but requires monitoring)

---

## Actionable Security Tasks

### 🔴 Critical Priority (P0) - Implement Immediately

#### [ ] C1: Implement Security Policy File
**Category:** Security Operations  
**Risk:** Information disclosure, delayed vulnerability reporting  
**Current State:** No SECURITY.txt or .well-known/security.txt exists  

**Action Items:**
- [ ] Create `.well-known/security.txt` file per RFC 9116
- [ ] Include security contact email
- [ ] Add vulnerability disclosure policy
- [ ] Specify preferred languages (English)
- [ ] Set expiration date (1 year from creation)
- [ ] Sign with PGP key if available

**Implementation:**
```
Contact: security@example.com
Expires: 2026-10-25T00:00:00.000Z
Preferred-Languages: en
Canonical: https://github.com/motowilliams/gosh/security.txt
Policy: https://github.com/motowilliams/gosh/blob/main/SECURITY.md
```

**Acceptance Criteria:**
- [ ] File exists at `.well-known/security.txt`
- [ ] Valid per RFC 9116 format
- [ ] Referenced in README.md
- [ ] Linked from SECURITY.md

---

#### [ ] C2: Add Security Event Logging
**Category:** Security Monitoring  
**Risk:** Inability to detect or investigate security incidents  
**Current State:** No audit logging for security-relevant events  

**Action Items:**
- [ ] Log all task executions with timestamps
- [ ] Log TaskDirectory parameter usage
- [ ] Log file system operations (New-Item, Set-Content)
- [ ] Log external command executions (git, bicep)
- [ ] Include user context (username, machine name)
- [ ] Write logs to `.gosh/audit.log` (optional, off by default)

**Implementation:**
```powershell
function Write-SecurityLog {
    param(
        [string]$Event,
        [string]$Details,
        [string]$Severity = 'Info'
    )
    
    if ($env:GOSH_AUDIT_LOG) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $user = [Environment]::UserName
        $machine = [Environment]::MachineName
        $entry = "$timestamp | $Severity | $user@$machine | $Event | $Details"
        
        $logPath = Join-Path $PSScriptRoot '.gosh' 'audit.log'
        $logDir = Split-Path $logPath -Parent
        
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        Add-Content -Path $logPath -Value $entry
    }
}

# Usage:
Write-SecurityLog -Event "TaskExecution" -Details "Task: $taskName, Directory: $TaskDirectory"
Write-SecurityLog -Event "FileCreation" -Details "Created: $filePath" -Severity "Warning"
```

**Acceptance Criteria:**
- [ ] Security logging function implemented
- [ ] Opt-in via `$env:GOSH_AUDIT_LOG=1`
- [ ] Logs written to `.gosh/audit.log`
- [ ] `.gosh/` added to `.gitignore`
- [ ] Documentation updated with logging instructions

---

#### [ ] C3: Validate External Command Output Before Display
**Category:** Output Security  
**Risk:** Terminal injection, ANSI escape sequence exploitation  
**Current State:** Git output displayed without sanitization in error scenarios  
**Location:** Lines 347-348 (git status output)  

**Action Items:**
- [ ] Sanitize all external command output before display
- [ ] Strip ANSI escape sequences from git output
- [ ] Remove control characters (0x00-0x1F, 0x7F-0x9F)
- [ ] Apply to both git and bicep command outputs
- [ ] Test with malicious filenames

**Implementation:**
```powershell
function Remove-AnsiEscapeSequences {
    param([string]$Text)
    
    # Remove ANSI escape sequences (\x1b[...m)
    $cleaned = $Text -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
    
    # Remove other control characters except \n, \r, \t
    $cleaned = $cleaned -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]', '?'
    
    return $cleaned
}

# Usage in Invoke-CheckGitIndex:
$rawStatus = git status --short
$sanitizedStatus = Remove-AnsiEscapeSequences $rawStatus
Write-Host $sanitizedStatus
```

**Acceptance Criteria:**
- [ ] Sanitization function implemented
- [ ] Applied to git status output
- [ ] Applied to git diff output (if used)
- [ ] Test with files containing ANSI sequences
- [ ] No terminal corruption from malicious filenames

---

### 🟠 High Priority (P1) - Implement Within Sprint

#### [ ] H1: Implement Dependency Pinning
**Category:** Supply Chain Security  
**Risk:** Malicious dependency injection, build reproducibility issues  
**Current State:** No dependency manifest, relies on system-installed tools  

**Action Items:**
- [ ] Create `dependencies.json` manifest
- [ ] Pin PowerShell version (currently >= 7.0)
- [ ] Document Bicep CLI version requirements
- [ ] Add Git version requirements
- [ ] Include Pester version for testing
- [ ] Implement version checking at script startup

**Implementation:**
```json
{
  "name": "gosh",
  "version": "1.0.0",
  "dependencies": {
    "powershell": ">=7.2.0",
    "pester": ">=5.0.0",
    "git": ">=2.30.0"
  },
  "optionalDependencies": {
    "bicep": ">=0.20.0",
    "azure-cli": ">=2.50.0"
  }
}
```

```powershell
function Test-Dependencies {
    $manifest = Get-Content (Join-Path $PSScriptRoot 'dependencies.json') | ConvertFrom-Json
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion -lt [version]$manifest.dependencies.powershell.TrimStart('>=')) {
        Write-Error "PowerShell version $($manifest.dependencies.powershell) required"
        return $false
    }
    
    # Check other dependencies...
    return $true
}
```

**Acceptance Criteria:**
- [ ] `dependencies.json` created
- [ ] Version checking function implemented
- [ ] Called at script startup
- [ ] Clear error messages for missing/outdated dependencies
- [ ] CI/CD updated to verify dependencies

---

#### [ ] H2: Add Code Signing Verification
**Category:** Code Integrity  
**Risk:** Execution of tampered or malicious task scripts  
**Current State:** No signature verification for task scripts  
**Location:** Lines 459-465 (Get-ProjectTasks function)  

**Action Items:**
- [ ] Add optional signature verification mode
- [ ] Check AuthenticodeSignature for task scripts
- [ ] Warn on unsigned scripts when in strict mode
- [ ] Document code signing process
- [ ] Provide example signing script

**Implementation:**
```powershell
# In Get-ProjectTasks function, after line 459:
$buildFiles = Get-ChildItem $BuildPath -Filter "*.ps1" -File -Force | 
    Where-Object { $_.Name -notmatch '\.Tests\.ps1$' }

# Add signature verification if enabled
if ($env:GOSH_REQUIRE_SIGNED_TASKS -eq '1') {
    $buildFiles = $buildFiles | Where-Object {
        $signature = Get-AuthenticodeSignature $_.FullName
        if ($signature.Status -ne 'Valid') {
            Write-Warning "Skipping unsigned task: $($_.Name) (Status: $($signature.Status))"
            return $false
        }
        return $true
    }
}
```

**Acceptance Criteria:**
- [ ] Signature verification implemented
- [ ] Opt-in via `$env:GOSH_REQUIRE_SIGNED_TASKS=1`
- [ ] Unsigned scripts skipped with warning
- [ ] Documentation includes signing instructions
- [ ] Example signing script provided

---

#### [ ] H3: Implement Rate Limiting for Task Execution
**Category:** Denial of Service Prevention  
**Risk:** Resource exhaustion from rapid/infinite task execution  
**Current State:** No limits on task execution frequency  

**Action Items:**
- [ ] Track task execution timestamps
- [ ] Implement configurable rate limit (default: 10 tasks/minute)
- [ ] Add cooldown period for failed tasks
- [ ] Prevent recursive task loops
- [ ] Add emergency circuit breaker

**Implementation:**
```powershell
# Global execution tracker
$script:ExecutionHistory = @{}
$script:MaxExecutionsPerMinute = 10

function Test-RateLimit {
    param([string]$TaskName)
    
    $now = Get-Date
    $oneMinuteAgo = $now.AddMinutes(-1)
    
    if (-not $script:ExecutionHistory.ContainsKey($TaskName)) {
        $script:ExecutionHistory[$TaskName] = @()
    }
    
    # Remove old entries
    $script:ExecutionHistory[$TaskName] = $script:ExecutionHistory[$TaskName] | 
        Where-Object { $_ -gt $oneMinuteAgo }
    
    # Check limit
    if ($script:ExecutionHistory[$TaskName].Count -ge $script:MaxExecutionsPerMinute) {
        Write-Error "Rate limit exceeded for task '$TaskName'. Maximum $script:MaxExecutionsPerMinute executions per minute."
        return $false
    }
    
    # Record execution
    $script:ExecutionHistory[$TaskName] += $now
    return $true
}
```

**Acceptance Criteria:**
- [ ] Rate limiting function implemented
- [ ] Called before each task execution
- [ ] Configurable via `$env:GOSH_RATE_LIMIT`
- [ ] Clear error message when limit exceeded
- [ ] History cleared after successful execution

---

#### [ ] H4: Sanitize File Paths in Error Messages
**Category:** Information Disclosure  
**Risk:** Exposure of sensitive directory structure  
**Current State:** Full file paths revealed in error messages  
**Location:** Lines 336, 413, 505-507, 774, 826, 835  

**Action Items:**
- [ ] Create path sanitization function
- [ ] Show only relative paths from project root
- [ ] Redact user-specific path components
- [ ] Add verbose mode for full paths (debugging)
- [ ] Apply to all error and warning messages

**Implementation:**
```powershell
function Get-SanitizedPath {
    param(
        [string]$Path,
        [switch]$Verbose
    )
    
    # If verbose mode, return full path
    if ($Verbose -or $VerbosePreference -eq 'Continue') {
        return $Path
    }
    
    # Convert to relative path from project root
    $projectRoot = Get-ProjectRoot
    if ($Path.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $Path.Substring($projectRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
        return ".$([IO.Path]::DirectorySeparatorChar)$relativePath"
    }
    
    # Fallback: show only filename
    return [IO.Path]::GetFileName($Path)
}

# Usage:
Write-Error "Task file already exists: $(Get-SanitizedPath $fileName)"
Write-Warning "Project root: $(Get-SanitizedPath $projectRoot -Verbose)"
```

**Acceptance Criteria:**
- [ ] Path sanitization function created
- [ ] Applied to all error messages
- [ ] Applied to all warning messages
- [ ] Verbose mode shows full paths
- [ ] Relative paths displayed by default
- [ ] No user-specific information leaked

---

### 🟡 Medium Priority (P2) - Implement Next Quarter

#### [ ] M1: Add Secrets Detection Scanner
**Category:** Secrets Management  
**Risk:** Accidental commit of secrets in task scripts  
**Current State:** No secrets scanning for task files  

**Action Items:**
- [ ] Implement pre-commit hook for secrets detection
- [ ] Scan task scripts for common secret patterns
- [ ] Check for API keys, tokens, passwords
- [ ] Integrate with GitHub Advanced Security (if available)
- [ ] Block commits containing potential secrets

**Implementation:**
```powershell
function Test-TaskScriptForSecrets {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    $findings = @()
    
    $secretPatterns = @{
        'APIKey' = 'api[_-]?key\s*=\s*[''"]([^''"]+)[''"]'
        'Password' = 'password\s*=\s*[''"]([^''"]+)[''"]'
        'Token' = 'token\s*=\s*[''"]([^''"]+)[''"]'
        'ConnectionString' = 'connection[_-]?string\s*=\s*[''"]([^''"]+)[''"]'
        'PrivateKey' = '-----BEGIN.*PRIVATE KEY-----'
    }
    
    foreach ($pattern in $secretPatterns.GetEnumerator()) {
        if ($content -match $pattern.Value) {
            $findings += "Potential $($pattern.Key) found in $FilePath"
        }
    }
    
    if ($findings.Count -gt 0) {
        Write-Warning "Secrets detected:"
        $findings | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }
    
    return $true
}
```

**Acceptance Criteria:**
- [ ] Secrets scanner function implemented
- [ ] Called during -NewTask creation
- [ ] Called before task execution (optional)
- [ ] Configurable via `$env:GOSH_SCAN_SECRETS=1`
- [ ] Pre-commit hook script provided
- [ ] Documentation includes secrets management guide

---

#### [ ] M2: Implement Content Security Policy for Output
**Category:** Output Security  
**Risk:** HTML/JavaScript injection in task output  
**Current State:** No output encoding for special characters  

**Action Items:**
- [ ] Encode HTML entities in task output
- [ ] Escape JavaScript special characters
- [ ] Prevent code injection via task descriptions
- [ ] Sanitize task names before display
- [ ] Apply to -ListTasks and -Outline outputs

**Implementation:**
```powershell
function ConvertTo-SafeHtml {
    param([string]$Text)
    
    $Text = $Text -replace '&', '&amp;'
    $Text = $Text -replace '<', '&lt;'
    $Text = $Text -replace '>', '&gt;'
    $Text = $Text -replace '"', '&quot;'
    $Text = $Text -replace "'", '&#39;'
    
    return $Text
}

# Usage in task listing:
$safeDescription = ConvertTo-SafeHtml $taskInfo.Description
Write-Host "    $safeDescription" -ForegroundColor Gray
```

**Acceptance Criteria:**
- [ ] HTML encoding function implemented
- [ ] Applied to task descriptions
- [ ] Applied to task names in output
- [ ] Test with malicious HTML/JavaScript
- [ ] No code execution via task metadata

---

#### [ ] M3: Add Telemetry and Crash Reporting
**Category:** Security Operations  
**Risk:** Unknown security issues in production  
**Current State:** No telemetry or crash reporting  

**Action Items:**
- [ ] Implement opt-in telemetry
- [ ] Collect anonymous usage statistics
- [ ] Report unhandled exceptions
- [ ] Include PowerShell version, OS, task types
- [ ] Send to secure endpoint (e.g., Application Insights)
- [ ] Respect privacy (no PII)

**Implementation:**
```powershell
function Send-Telemetry {
    param(
        [string]$EventType,
        [hashtable]$Properties
    )
    
    # Only if opt-in
    if ($env:GOSH_TELEMETRY -ne '1') {
        return
    }
    
    $telemetryData = @{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        version = '1.0.0'
        psVersion = $PSVersionTable.PSVersion.ToString()
        os = $PSVersionTable.OS
        eventType = $EventType
        properties = $Properties
        sessionId = [Guid]::NewGuid().ToString()
    }
    
    # Send to telemetry endpoint (pseudo-code)
    try {
        $json = $telemetryData | ConvertTo-Json -Compress
        # Invoke-RestMethod -Uri 'https://telemetry.example.com/api/events' -Method Post -Body $json
    }
    catch {
        # Fail silently - don't break script execution
        Write-Verbose "Telemetry failed: $_"
    }
}

# Usage:
Send-Telemetry -EventType 'TaskExecution' -Properties @{ TaskName = $taskName; Success = $true }
```

**Acceptance Criteria:**
- [ ] Telemetry function implemented
- [ ] Opt-in via `$env:GOSH_TELEMETRY=1`
- [ ] No PII collected
- [ ] Privacy policy documented
- [ ] Fails gracefully if endpoint unavailable

---

#### [ ] M4: Implement Backup and Recovery for Task Files
**Category:** Availability  
**Risk:** Accidental deletion or corruption of task scripts  
**Current State:** No backup mechanism for `.build/` directory  

**Action Items:**
- [ ] Create automatic backup before task modifications
- [ ] Store backups in `.gosh/backups/`
- [ ] Implement backup rotation (keep last 10)
- [ ] Add restore functionality
- [ ] Backup before -NewTask overwrites

**Implementation:**
```powershell
function Backup-TaskDirectory {
    param([string]$TaskDirectory)
    
    $backupRoot = Join-Path $PSScriptRoot '.gosh' 'backups'
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $backupRoot $timestamp
    
    if (Test-Path $TaskDirectory) {
        Copy-Item -Path $TaskDirectory -Destination $backupPath -Recurse -Force
        Write-Verbose "Backup created: $backupPath"
        
        # Rotate backups (keep last 10)
        $backups = Get-ChildItem $backupRoot | Sort-Object Name -Descending
        if ($backups.Count -gt 10) {
            $backups | Select-Object -Skip 10 | Remove-Item -Recurse -Force
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Backup function implemented
- [ ] Called before task modifications
- [ ] Stored in `.gosh/backups/`
- [ ] Rotation implemented (keep 10 most recent)
- [ ] Restore script provided
- [ ] `.gosh/` added to `.gitignore`

---

### 🔵 Low Priority (P3) - Future Enhancements

#### [ ] L1: Implement Multi-Factor Authentication for Critical Tasks
**Category:** Access Control  
**Risk:** Unauthorized execution of sensitive tasks  
**Current State:** No authentication mechanism  

**Action Items:**
- [ ] Add MFA requirement for tasks marked as `critical`
- [ ] Integrate with Windows Hello or hardware tokens
- [ ] Prompt for confirmation before critical operations
- [ ] Support TOTP (Time-based One-Time Password)
- [ ] Document critical task marking

**Implementation:**
```powershell
# Task metadata:
# TASK: deploy
# DESCRIPTION: Deploys to production
# CRITICAL: true

function Confirm-CriticalTaskExecution {
    param([string]$TaskName)
    
    Write-Host "⚠️  CRITICAL TASK: $TaskName" -ForegroundColor Red
    Write-Host "This task performs sensitive operations." -ForegroundColor Yellow
    Write-Host ""
    
    $confirmation = Read-Host "Type 'CONFIRM' to proceed"
    
    if ($confirmation -ne 'CONFIRM') {
        Write-Error "Task execution cancelled"
        return $false
    }
    
    # Optional: Add TOTP verification
    if ($env:GOSH_REQUIRE_TOTP -eq '1') {
        $token = Read-Host "Enter TOTP token"
        # Verify token...
    }
    
    return $true
}
```

**Acceptance Criteria:**
- [ ] Critical task marking supported
- [ ] Confirmation prompt implemented
- [ ] Optional TOTP support
- [ ] Configurable via metadata
- [ ] Documentation updated

---

#### [ ] L2: Add Sandbox Mode for Untrusted Tasks
**Category:** Isolation  
**Risk:** Execution of malicious task scripts  
**Current State:** Tasks run with full user permissions  

**Action Items:**
- [ ] Implement constrained language mode for tasks
- [ ] Restrict cmdlets available to tasks
- [ ] Prevent network access in sandbox mode
- [ ] Limit file system access
- [ ] Add `--sandbox` flag

**Implementation:**
```powershell
function Invoke-TaskInSandbox {
    param([hashtable]$TaskInfo)
    
    # Create constrained session
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    $sessionState.LanguageMode = [System.Management.Automation.PSLanguageMode]::RestrictedLanguage
    
    # Allow only safe cmdlets
    $safeCmdlets = @('Get-ChildItem', 'Get-Content', 'Write-Host')
    # Configure session state...
    
    # Execute in constrained runspace
    $runspace = [runspacefactory]::CreateRunspace($sessionState)
    $runspace.Open()
    # Execute task...
    $runspace.Close()
}
```

**Acceptance Criteria:**
- [ ] Sandbox mode implemented
- [ ] Constrained language mode enforced
- [ ] Limited cmdlet allowlist
- [ ] Opt-in via `--sandbox` flag
- [ ] Documentation includes limitations

---

#### [ ] L3: Implement License Compliance Scanning
**Category:** Legal Compliance  
**Risk:** Use of incompatible licenses in dependencies  
**Current State:** No license scanning  

**Action Items:**
- [ ] Scan task scripts for copyright notices
- [ ] Check PowerShell module licenses
- [ ] Verify license compatibility with MIT
- [ ] Generate NOTICE.txt with attributions
- [ ] Add license check to CI/CD

**Implementation:**
```powershell
function Test-LicenseCompliance {
    $modules = Get-Module -ListAvailable
    $incompatibleLicenses = @('GPL', 'AGPL')
    
    foreach ($module in $modules) {
        # Check module manifest for license
        $manifest = Test-ModuleManifest $module.Path -ErrorAction SilentlyContinue
        # Verify license compatibility...
    }
}
```

**Acceptance Criteria:**
- [ ] License scanner implemented
- [ ] Incompatible licenses detected
- [ ] NOTICE.txt generated
- [ ] CI/CD integration
- [ ] Documentation updated

---

#### [ ] L4: Add Security Headers for Web-Based Task Outputs
**Category:** Web Security  
**Risk:** XSS if task output is displayed in web UI  
**Current State:** No consideration for web display  

**Action Items:**
- [ ] Add CSP headers if outputting HTML
- [ ] Implement X-Content-Type-Options
- [ ] Add X-Frame-Options
- [ ] Set Referrer-Policy
- [ ] Document secure web integration

**Implementation:**
```powershell
function ConvertTo-SecureHtmlOutput {
    param([string]$Content)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'none'">
    <meta http-equiv="X-Content-Type-Options" content="nosniff">
    <meta http-equiv="X-Frame-Options" content="DENY">
    <meta name="referrer" content="no-referrer">
    <title>Gosh Task Output</title>
</head>
<body>
    <pre>$(ConvertTo-SafeHtml $Content)</pre>
</body>
</html>
"@
    
    return $html
}
```

**Acceptance Criteria:**
- [ ] HTML output function created
- [ ] Security headers included
- [ ] Content sanitized
- [ ] Optional feature (off by default)
- [ ] Documentation includes web security guide

---

## GitHub-Specific Security Recommendations

### [ ] GH1: Enable GitHub Security Features
**Category:** Platform Security  

**Action Items:**
- [ ] Enable Dependabot alerts (if applicable to PowerShell)
- [ ] Enable Secret scanning
- [ ] Enable Code scanning (CodeQL for PowerShell)
- [ ] Configure Security policy (SECURITY.md exists ✓)
- [ ] Add security advisories process

**Implementation in `.github/workflows/security.yml`:**
```yaml
name: Security Scanning

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  codeql:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v3
      - uses: github/codeql-action/init@v2
        with:
          languages: javascript  # CodeQL doesn't support PowerShell directly
      - uses: github/codeql-action/analyze@v2
  
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: TruffleHog Secrets Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
```

**Acceptance Criteria:**
- [ ] Security workflow created
- [ ] CodeQL enabled
- [ ] Secret scanning enabled
- [ ] Runs on PRs and weekly
- [ ] Security alerts monitored

---

### [ ] GH2: Implement Branch Protection Rules
**Category:** Code Review Security  

**Action Items:**
- [ ] Require pull request reviews (minimum 1 reviewer)
- [ ] Require status checks to pass
- [ ] Require conversation resolution
- [ ] Enforce for administrators
- [ ] Require signed commits (optional)

**Configuration (GitHub UI or API):**
```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["ci/test", "security-scan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null
}
```

**Acceptance Criteria:**
- [ ] Branch protection enabled for `main`
- [ ] PR reviews required
- [ ] Status checks required
- [ ] CODEOWNERS file created
- [ ] Documented in CONTRIBUTING.md

---

### [ ] GH3: Add CODEOWNERS File
**Category:** Access Control  

**Action Items:**
- [ ] Create `.github/CODEOWNERS`
- [ ] Assign owners for security-critical files
- [ ] Require owner review for SECURITY.md changes
- [ ] Require owner review for gosh.ps1 changes

**Implementation in `.github/CODEOWNERS`:**
```
# Security-critical files require review from security team
/gosh.ps1 @motowilliams
/SECURITY.md @motowilliams
/security-github.md @motowilliams
/.github/workflows/ @motowilliams

# Task scripts
/.build/ @motowilliams

# Tests
/tests/ @motowilliams
```

**Acceptance Criteria:**
- [ ] CODEOWNERS file created
- [ ] Owners assigned
- [ ] Integrated with branch protection
- [ ] Documented in CONTRIBUTING.md

---

### [ ] GH4: Configure Security Advisories Process
**Category:** Vulnerability Management  

**Action Items:**
- [ ] Document private vulnerability reporting process
- [ ] Set up security advisory workflows
- [ ] Define SLA for vulnerability response
- [ ] Create vulnerability disclosure policy
- [ ] Link from SECURITY.md

**Update to SECURITY.md:**
```markdown
## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via:
1. GitHub Security Advisories (preferred): https://github.com/motowilliams/gosh/security/advisories/new
2. Email: security@example.com

You should receive a response within 48 hours. If not, please follow up via email.

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

## Response Timeline

- **Initial Response:** Within 48 hours
- **Triage:** Within 7 days
- **Fix Development:** Within 30 days (for critical issues)
- **Public Disclosure:** 90 days after fix release (coordinated disclosure)
```

**Acceptance Criteria:**
- [ ] Vulnerability reporting process documented
- [ ] Private reporting enabled in GitHub
- [ ] Response SLAs defined
- [ ] Process tested with mock vulnerability

---

## Testing Requirements

### Security Test Suite Checklist

- [ ] **Input Validation Tests**
  - [ ] Test TaskDirectory path traversal attempts
  - [ ] Test task name injection attempts
  - [ ] Test NewTask parameter validation
  - [ ] Test malformed task metadata

- [ ] **Output Security Tests**
  - [ ] Test ANSI escape sequence handling
  - [ ] Test HTML entity encoding
  - [ ] Test path sanitization in errors
  - [ ] Test malicious filename handling

- [ ] **Authentication Tests** (when implemented)
  - [ ] Test MFA for critical tasks
  - [ ] Test confirmation prompts
  - [ ] Test bypass attempts

- [ ] **Rate Limiting Tests** (when implemented)
  - [ ] Test rate limit enforcement
  - [ ] Test rate limit bypass attempts
  - [ ] Test cooldown periods

- [ ] **Logging Tests** (when implemented)
  - [ ] Test audit log creation
  - [ ] Test log rotation
  - [ ] Test log integrity
  - [ ] Test PII exclusion

- [ ] **Code Signing Tests** (when implemented)
  - [ ] Test unsigned script rejection
  - [ ] Test invalid signature detection
  - [ ] Test valid signature acceptance

---

## Compliance Considerations

### [ ] Privacy (GDPR/CCPA)
- [ ] Document data collection practices
- [ ] Implement data retention policies
- [ ] Provide data export functionality
- [ ] Allow users to disable telemetry
- [ ] Update privacy policy

### [ ] Accessibility (WCAG 2.1)
- [ ] Test with screen readers (if GUI planned)
- [ ] Ensure error messages are clear
- [ ] Provide text alternatives for colors
- [ ] Support high contrast mode

### [ ] Licensing
- [ ] Verify MIT license compatibility
- [ ] Document third-party dependencies
- [ ] Include license notices
- [ ] Create NOTICE.txt file

---

## Risk Assessment Matrix

| Finding | Severity | Likelihood | Impact | Priority |
|---------|----------|------------|--------|----------|
| C1: Missing Security Policy | Medium | High | Low | P0 |
| C2: No Security Logging | High | Medium | High | P0 |
| C3: Unsafe Output Display | High | Low | Medium | P0 |
| H1: No Dependency Pinning | Medium | High | Medium | P1 |
| H2: No Code Signing | Medium | Low | High | P1 |
| H3: No Rate Limiting | Low | Medium | Medium | P1 |
| H4: Path Disclosure | Low | High | Low | P1 |
| M1: No Secrets Scanner | Medium | Medium | Medium | P2 |
| M2: Output Injection | Low | Low | Low | P2 |
| M3: No Telemetry | Low | Low | Low | P2 |
| M4: No Backups | Low | Medium | Medium | P2 |
| L1: No MFA | Low | Low | High | P3 |

---

## Timeline and Milestones

### Sprint 1 (Weeks 1-2)
- [ ] C1: Security Policy File
- [ ] C2: Security Event Logging
- [ ] C3: Output Validation
- [ ] GH1: Enable GitHub Security Features

### Sprint 2 (Weeks 3-4)
- [ ] H1: Dependency Pinning
- [ ] H2: Code Signing
- [ ] H3: Rate Limiting
- [ ] GH2: Branch Protection

### Sprint 3 (Weeks 5-6)
- [ ] H4: Path Sanitization
- [ ] M1: Secrets Scanner
- [ ] GH3: CODEOWNERS
- [ ] GH4: Security Advisories

### Future Sprints
- [ ] M2-M4: Medium priority items
- [ ] L1-L4: Low priority items

---

## Additional Resources

### Security Tools
- **PSScriptAnalyzer:** PowerShell linting with security rules
- **Pester:** Testing framework for PowerShell
- **TruffleHog:** Secrets scanning
- **CodeQL:** Code analysis engine

### Documentation
- [PowerShell Security Best Practices](https://docs.microsoft.com/powershell/scripting/security)
- [GitHub Security Features](https://docs.github.com/en/code-security)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS PowerShell Benchmarks](https://www.cisecurity.org/)

### Security Contacts
- **Project Maintainer:** @motowilliams
- **Security Team:** security@example.com
- **GitHub Security:** security-advisory@github.com

---

## Conclusion

This security evaluation identifies 12 actionable tasks across 4 priority levels. The project has a solid foundation with existing security controls documented in SECURITY.md. The recommendations in this report focus on operational security, supply chain security, and GitHub platform integration.

**Recommended Next Steps:**
1. Implement all P0 (Critical) items within 2 weeks
2. Set up GitHub security features (GH1-GH4)
3. Create security test suite
4. Schedule regular security reviews (quarterly)

**Security Champion:** Assign a security champion responsible for tracking and implementing these recommendations.

---

**Report Version:** 1.0  
**Last Updated:** October 25, 2025  
**Next Review:** January 25, 2026
