# GitHub Security Evaluation - gosh.ps1

**Project:** Gosh! PowerShell Build System  
**Analysis Date:** October 25, 2025  
**Evaluator:** GitHub Security Team (AI-Assisted)  
**Scope:** Complete security assessment of gosh.ps1 v1.0  
**Methodology:** Code review, threat modeling, dependency analysis, configuration review

> **Note:** This report complements the existing [SECURITY.md](./SECURITY.md) file. While SECURITY.md focuses on code-level security fixes (P0-P2 implementation tasks), this GitHub evaluation focuses on operational security, supply chain security, and GitHub platform integration.

---

## Executive Summary

This security evaluation identifies **13 total (9 actionable + 4 marked as Won't Implement) security findings** across multiple categories. The assessment reveals that while the project has implemented several security controls (as documented in SECURITY.md), there are additional concerns from a GitHub security perspective, particularly around supply chain security, secrets management, and operational security.

**Overall Risk Level:** 🟡 MODERATE

**Key Findings:**
- ✅ **Strengths:** Good input validation, no hardcoded secrets, comprehensive parameter validation
- ⚠️ **Concerns:** Missing security.txt, no dependency pinning, limited logging for security events
- 🔴 **Critical:** Dynamic code execution via ScriptBlock::Create (mitigated but requires monitoring)

---

## Actionable Security Tasks

### 🔴 Critical Priority (P0)

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

**LLM Prompt for Resolution:**
```
Task: Implement RFC 9116 compliant security.txt file for the Gosh project

Context: The project needs a security policy file to facilitate responsible vulnerability disclosure. This follows RFC 9116 standard for security.txt files.

Requirements:
1. Create a `.well-known/security.txt` file in the repository root
2. Include required fields: Contact, Expires, Canonical, Policy
3. Set expiration date 1 year from today
4. Link to existing SECURITY.md for detailed policy
5. Update README.md to reference the security.txt file
6. Ensure the file is accessible at: https://github.com/motowilliams/gosh/.well-known/security.txt

Please implement this security policy file following RFC 9116 specifications and update relevant documentation.
```

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

**LLM Prompt for Resolution:**
```
Task: Implement security event logging system in gosh.ps1

Context: The build orchestrator needs audit logging to track security-relevant operations for incident investigation and compliance.

Requirements:
1. Create Write-SecurityLog function in gosh.ps1
2. Implement opt-in logging via $env:GOSH_AUDIT_LOG environment variable
3. Log these events:
   - Task executions (with taskName and TaskDirectory)
   - File system operations (New-Item, Set-Content with file paths)
   - External command executions (git, bicep)
   - Include timestamp, user, machine name, event type, and details
4. Write logs to .gosh/audit.log with proper formatting
5. Add .gosh/ to .gitignore to exclude audit logs from version control
6. Update documentation with logging setup instructions

File to modify: gosh.ps1
Add logging calls at strategic points: task execution start, file creation, external commands
Please implement this comprehensive security logging system.
```

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

**LLM Prompt for Resolution:**
```
Task: Implement output sanitization for external commands in gosh.ps1

Context: External command output (git, bicep) may contain ANSI escape sequences or control characters that could cause terminal injection attacks.

Requirements:
1. Create Remove-AnsiEscapeSequences function in gosh.ps1
2. Strip ANSI escape sequences using regex: \x1b\[[0-9;]*[a-zA-Z]
3. Remove control characters (0x00-0x1F, 0x7F-0x9F) except newline, carriage return, tab
4. Apply sanitization to all git command outputs before display:
   - git status output (lines 347-348)
   - git diff output (if used)
5. Test with malicious filenames containing ANSI sequences
6. Ensure no terminal corruption occurs

Files to modify: gosh.ps1 (Invoke-CheckGitIndex function and other git output locations)
Please implement this output sanitization to prevent terminal injection attacks.
```

---

### 🟠 High Priority (P1)

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

**LLM Prompt for Resolution:**
```
Task: Implement dependency pinning and version checking in Gosh

Context: The project needs to track and verify versions of external dependencies (PowerShell, Git, Pester, Bicep) for supply chain security and reproducible builds.

Requirements:
1. Create dependencies.json manifest file with:
   - PowerShell >= 7.2.0
   - Pester >= 5.0.0
   - Git >= 2.30.0
   - Bicep >= 0.20.0 (optional)
   - Azure CLI >= 2.50.0 (optional)
2. Implement Test-Dependencies function in gosh.ps1:
   - Load and parse dependencies.json
   - Check PowerShell version ($PSVersionTable.PSVersion)
   - Verify other tools are installed and meet version requirements
   - Return clear error messages for missing/outdated dependencies
3. Call Test-Dependencies at gosh.ps1 startup (early in script)
4. Update CI/CD workflows to verify dependency versions
5. Document dependency requirements in README.md

Please implement dependency management to ensure consistent, secure builds.
```

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

**LLM Prompt for Resolution:**
```
Task: Implement code signing verification for task scripts in gosh.ps1

Context: Task scripts in .build/ directory should optionally support signature verification to ensure code integrity and prevent execution of tampered scripts.

Requirements:
1. Modify Get-ProjectTasks function (lines 459-465) in gosh.ps1
2. Add signature verification when $env:GOSH_REQUIRE_SIGNED_TASKS=1:
   - Use Get-AuthenticodeSignature to check each .ps1 file
   - Skip unsigned or invalid scripts with clear warning
   - Only execute scripts with Status='Valid'
3. Create example signing script (Sign-TaskScripts.ps1):
   - Show how to sign .ps1 files with Set-AuthenticodeSignature
   - Include certificate acquisition instructions
4. Document the signing process in CONTRIBUTING.md:
   - How to obtain a code signing certificate
   - How to sign task scripts
   - How to enable verification mode
5. Test with both signed and unsigned scripts

Please implement optional code signing verification for enhanced security.
```

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

**LLM Prompt for Resolution:**
```
Task: Implement rate limiting for task execution in gosh.ps1

Context: Prevent DoS attacks and resource exhaustion from rapid or infinite task execution loops.

Requirements:
1. Add global execution tracking in gosh.ps1:
   - $script:ExecutionHistory hashtable to track task execution timestamps
   - $script:MaxExecutionsPerMinute = 10 (configurable via $env:GOSH_RATE_LIMIT)
2. Create Test-RateLimit function:
   - Accept $TaskName parameter
   - Track execution times per task
   - Remove entries older than 1 minute
   - Return $false if limit exceeded, $true otherwise
3. Call Test-RateLimit before each task execution in Invoke-Task function
4. Provide clear error message when rate limit exceeded
5. Allow configuration via environment variable
6. Test with rapid task execution scenarios

Files to modify: gosh.ps1 (add function and integrate into Invoke-Task)
Please implement rate limiting to prevent resource exhaustion attacks.
```

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

**LLM Prompt for Resolution:**
```
Task: Sanitize file paths in error and warning messages in gosh.ps1

Context: Full file paths in error messages expose sensitive directory structure and user information.

Requirements:
1. Create Get-SanitizedPath function in gosh.ps1:
   - Accept path and optional -Verbose switch
   - Convert absolute paths to relative paths from project root
   - Remove user-specific components (usernames, home directories)
   - Show full paths only when -Verbose or $VerbosePreference='Continue'
2. Apply sanitization to all error and warning messages at these locations:
   - Line 336 (git error messages)
   - Line 413 (task name validation warnings)
   - Lines 505-507 (TaskDirectory warnings)
   - Line 774 (task execution errors)
   - Lines 826, 835 (file creation errors)
3. Test that sanitized paths hide sensitive information
4. Ensure debugging is still possible with -Verbose flag

Files to modify: gosh.ps1 (add function and update all Write-Error/Write-Warning calls)
Please implement path sanitization to prevent information disclosure.
```

---

### 🟡 Medium Priority (P2)

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

**LLM Prompt for Resolution:**
```
Task: Implement secrets detection scanner for task scripts in gosh.ps1

Context: Prevent accidental commits of API keys, passwords, tokens, and other secrets in .build/ task scripts.

Requirements:
1. Create Test-TaskScriptForSecrets function in gosh.ps1:
   - Scan file content for common secret patterns (API keys, passwords, tokens, connection strings, private keys)
   - Use regex patterns to detect: api[_-]?key, password, token, connection[_-]?string, -----BEGIN.*PRIVATE KEY-----
   - Return $false if secrets found, $true otherwise
   - Display clear warnings with detected secret types
2. Integrate scanning:
   - Call during -NewTask creation (validate template before writing)
   - Optionally scan before task execution when $env:GOSH_SCAN_SECRETS=1
3. Create pre-commit hook script (.githooks/pre-commit):
   - Scan all .ps1 files in .build/ before commit
   - Block commits if secrets detected
4. Document secrets management best practices:
   - Use environment variables for sensitive data
   - Use Azure Key Vault or similar for production secrets
   - How to enable secret scanning

Please implement comprehensive secrets detection to prevent credential leaks.
```

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

**LLM Prompt for Resolution:**
```
Task: Implement content security policy and HTML encoding for task output in gosh.ps1

Context: Task descriptions and names displayed in -ListTasks and -Outline outputs could contain HTML/JavaScript that executes if output is rendered in a web context.

Requirements:
1. Create ConvertTo-SafeHtml function in gosh.ps1:
   - Encode HTML entities: & < > " '
   - Convert to: &amp; &lt; &gt; &quot; &#39;
   - Return sanitized string
2. Apply HTML encoding to all task display outputs:
   - Task descriptions in -ListTasks output
   - Task names in -Outline tree display
   - Task descriptions in -Outline display
   - Any other user-controlled content shown to terminal
3. Test with malicious inputs:
   - Task name: "test<script>alert('xss')</script>"
   - Description: "Click <a href='evil.com'>here</a>"
4. Ensure no code execution possible via task metadata

Files to modify: gosh.ps1 (add function and apply to Show-TaskOutline and task listing code)
Please implement output encoding to prevent injection attacks.
```

---

### 🔵 Low Priority (P3)

#### [x] L1 (Won't Implement): Implement Multi-Factor Authentication for Critical Tasks
**Category:** Access Control  

> **Note:** This feature will not be added to Gosh. The project is designed as a lightweight build orchestrator for trusted development environments. Multi-factor authentication is beyond the scope of this tool.
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

**LLM Prompt for Resolution:**
```
Task: Implement multi-factor authentication for critical tasks in gosh.ps1

Context: Sensitive tasks (like production deployments) require additional confirmation to prevent unauthorized or accidental execution.

Requirements:
1. Add CRITICAL metadata support in task files:
   - # CRITICAL: true in task metadata
   - Parse in Get-TaskMetadata function
2. Create Confirm-CriticalTaskExecution function:
   - Display warning with task name
   - Require user to type 'CONFIRM' to proceed
   - Optional: Support TOTP verification when $env:GOSH_REQUIRE_TOTP=1
   - Return $false if confirmation fails, $true if succeeds
3. Integrate into Invoke-Task:
   - Check if task is marked CRITICAL
   - Call confirmation function before execution
   - Skip confirmation with $env:GOSH_SKIP_CONFIRMATION=1 (for CI/CD)
4. Document critical task marking:
   - How to mark tasks as critical
   - How MFA/confirmation works
   - How to configure TOTP (if implemented)

Files to modify: gosh.ps1 (add metadata parsing and confirmation function)
Please implement MFA to protect sensitive operations.
```

---

#### [x] L2 (Won't Implement): Add Sandbox Mode for Untrusted Tasks
**Category:** Isolation  

> **Note:** This feature will not be added to Gosh. The project operates in trusted development environments where task scripts are under developer control. Sandboxing would limit legitimate use cases without significant security benefit in the intended usage context.
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

**LLM Prompt for Resolution:**
```
Task: Implement sandbox mode for untrusted tasks in gosh.ps1

Context: Isolate potentially untrusted task scripts by running them in PowerShell's constrained language mode with limited cmdlet access.

Requirements:
1. Create Invoke-TaskInSandbox function:
   - Create constrained session with InitialSessionState.CreateDefault2()
   - Set LanguageMode to RestrictedLanguage
   - Define allowlist of safe cmdlets: Get-ChildItem, Get-Content, Write-Host, Write-Output
   - Prevent network access (no Invoke-WebRequest, Invoke-RestMethod)
   - Limit file system access to task directory only
2. Add --Sandbox parameter to gosh.ps1
3. Modify Invoke-Task to use sandbox when flag present
4. Document sandbox limitations:
   - Which cmdlets are allowed/blocked
   - What operations are restricted
   - When to use sandbox mode
5. Test with various task scenarios

Files to modify: gosh.ps1 (add sandbox function and parameter)
Please implement sandbox isolation for untrusted task execution.
```

---

#### [x] L3 (Won't Implement): Implement License Compliance Scanning
**Category:** Legal Compliance  

> **Note:** This feature will not be added to Gosh. License compliance scanning is not applicable to this build orchestrator project. Dependencies are managed at the system level (PowerShell modules, Bicep CLI, Git) and are the responsibility of the development environment, not the build script.
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

**LLM Prompt for Resolution:**
```
Task: Implement license compliance scanning for dependencies in gosh.ps1

Context: Ensure all PowerShell module dependencies have MIT-compatible licenses to comply with project licensing requirements.

Requirements:
1. Create Test-LicenseCompliance function:
   - Get list of all PowerShell modules used (Get-Module -ListAvailable)
   - Check module manifests for license information
   - Identify incompatible licenses (GPL, AGPL)
   - Return warnings for incompatible licenses
2. Generate NOTICE.txt file:
   - List all dependencies with their licenses
   - Include copyright notices
   - Attribution requirements
3. Add license check to CI/CD:
   - Run Test-LicenseCompliance in GitHub Actions workflow
   - Fail build if incompatible licenses detected
4. Document license policy:
   - Which licenses are acceptable
   - How to verify module licenses
   - Alternative modules for incompatible licenses

Files to create/modify: gosh.ps1 (add function), .github/workflows/ci.yml (add license check)
Please implement license compliance scanning.
```

---

#### [x] L4 (Won't Implement): Add Security Headers for Web-Based Task Outputs
**Category:** Web Security  

> **Note:** This feature will not be added to Gosh. The project outputs to terminal/console, not web interfaces. Web security headers are not applicable to a command-line build orchestrator.
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

**LLM Prompt for Resolution:**
```
Task: Add security headers for web-based task output display

Context: If task output is ever displayed in a web UI, it needs proper security headers to prevent XSS and other web attacks.

Requirements:
1. Create ConvertTo-SecureHtmlOutput function:
   - Generate complete HTML document with proper security headers
   - Include Content-Security-Policy: default-src 'self'; script-src 'none'
   - Include X-Content-Type-Options: nosniff
   - Include X-Frame-Options: DENY
   - Include Referrer-Policy: no-referrer
   - Sanitize content using ConvertTo-SafeHtml before insertion
2. Make this an optional output format:
   - Add -HtmlOutput parameter to gosh.ps1
   - Only generate HTML when explicitly requested
   - Default to plain text output
3. Document web security integration:
   - How to use HTML output mode
   - Security considerations for web display
   - CSP policy explanation
4. Test that all security headers are present and effective

Files to modify: gosh.ps1 (add HTML output function and parameter)
Please implement secure web output format.
```

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

**LLM Prompt for Resolution:**
```
Task: Enable and configure GitHub security features for the Gosh repository

Context: GitHub provides built-in security scanning tools that should be enabled to detect vulnerabilities, secrets, and code issues.

Requirements:
1. Create .github/workflows/security.yml workflow:
   - Enable CodeQL code scanning (note: PowerShell support limited, use JavaScript as proxy)
   - Add TruffleHog for secret scanning
   - Run on: push to main, pull requests, weekly schedule (cron: '0 0 * * 0')
   - Set permissions: security-events: write for CodeQL
2. Enable GitHub Security Features in repository settings:
   - Go to Settings > Security & analysis
   - Enable Dependabot security alerts
   - Enable Secret scanning (if available)
   - Enable Code scanning alerts
3. Configure security policy:
   - Ensure SECURITY.md exists (already present ✓)
   - Link to vulnerability reporting process
4. Set up alert monitoring:
   - Configure notifications for security alerts
   - Assign security champion to review alerts
5. Document security workflow in CONTRIBUTING.md

Files to create: .github/workflows/security.yml
Please enable comprehensive GitHub security features.
```

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

**LLM Prompt for Resolution:**
```
Task: Implement branch protection rules for the main branch

Context: Protect the main branch from direct commits and require code review for all changes.

Requirements:
1. Configure branch protection for 'main' branch (GitHub UI: Settings > Branches):
   - Require pull request before merging
   - Require at least 1 approving review
   - Dismiss stale pull request approvals when new commits pushed
   - Require review from code owners (requires CODEOWNERS file - see GH3)
   - Require status checks to pass: "ci/test", "security-scan"
   - Require branches to be up to date before merging
   - Enforce restrictions for administrators
   - Optional: Require signed commits
2. Alternative: Use GitHub API or Terraform to configure:
   - Create branch protection config JSON (example provided in report)
   - Apply via API: PUT /repos/:owner/:repo/branches/:branch/protection
3. Update CONTRIBUTING.md:
   - Document branch protection requirements
   - Explain PR review process
   - Note that direct commits to main are blocked
4. Test protection rules work as expected

Configuration location: GitHub repository settings
Please implement branch protection to enforce code review.
```

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

**LLM Prompt for Resolution:**
```
Task: Create CODEOWNERS file to require reviews from designated owners

Context: Ensure security-critical files are reviewed by appropriate team members before changes are merged.

Requirements:
1. Create .github/CODEOWNERS file with ownership assignments:
   - /gosh.ps1 → @motowilliams (main script)
   - /SECURITY.md → @motowilliams (security documentation)
   - /security-github.md → @motowilliams (security report)
   - /.github/workflows/ → @motowilliams (CI/CD workflows)
   - /.build/ → @motowilliams (task scripts)
   - /tests/ → @motowilliams (test suite)
2. Understand CODEOWNERS syntax:
   - Use glob patterns or specific paths
   - Assign GitHub usernames or teams (@org/team-name)
   - Last matching pattern takes precedence
3. Integrate with branch protection (see GH2):
   - Enable "Require review from Code Owners" in branch protection
4. Document code ownership:
   - Add CODEOWNERS explanation to CONTRIBUTING.md
   - Describe review process for security-critical changes
5. Test that owner reviews are required

File to create: .github/CODEOWNERS
Please implement code ownership for security-critical files.
```

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

**LLM Prompt for Resolution:**
```
Task: Configure security advisories and vulnerability disclosure process

Context: Establish a formal process for receiving, triaging, and responding to security vulnerability reports.

Requirements:
1. Enable private vulnerability reporting in GitHub:
   - Go to Settings > Security > Private vulnerability reporting
   - Enable "Allow users to privately report potential security vulnerabilities"
2. Update SECURITY.md with vulnerability reporting section:
   - Add GitHub Security Advisories as preferred reporting method
   - Provide link: https://github.com/motowilliams/gosh/security/advisories/new
   - Include alternative contact method (email)
   - Define response SLAs:
     * Initial response: Within 48 hours
     * Triage: Within 7 days
     * Fix development: Within 30 days (critical issues)
     * Public disclosure: 90 days after fix (coordinated disclosure)
   - Specify required information: description, reproduction steps, impact, suggested fix
3. Create security advisory workflow:
   - Document triage process
   - Assign security champion
   - Define severity levels
4. Test process with mock vulnerability report
5. Document in CONTRIBUTING.md

Files to modify: SECURITY.md (add reporting section), GitHub settings
Please implement comprehensive vulnerability disclosure process.
```

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
| L1-L4: Won't Implement | N/A | N/A | N/A | N/A |

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
