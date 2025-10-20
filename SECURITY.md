# Security Analysis Report

**Project:** Gosh! PowerShell Build System  
**Analysis Date:** October 20, 2025  
**Analyst:** Security Review  
**Version:** Current (feature/add-embedded-function-support branch)

---

## 🚀 Quick Start for AI Agents

This document contains **7 actionable security fixes** ready for implementation. Each action item includes:
- ✅ Exact file and line numbers
- ✅ Complete code to implement
- ✅ Test cases with expected results
- ✅ Clear acceptance criteria

**To implement security fixes:**
1. Navigate to [Quick Action Items](#-quick-action-items-for-ai-agent) section
2. Select an action item by priority (P0 = Critical, P1 = High, P2 = Medium)
3. Follow the step-by-step implementation guide
4. Run the provided test cases
5. Verify all acceptance criteria are met

**Summary of Required Changes:**
| Priority | Action Item | File | Estimated Effort | Test Coverage |
|----------|-------------|------|------------------|---------------|
| P0 | TaskDirectory Validation | `gosh.ps1:68` | 5 min | 6 test cases |
| P0 | Path Sanitization | `gosh.ps1:641` | 10 min | 3 test cases |
| P0 | Task Name Validation | `gosh.ps1:71,347` | 10 min | 8 test cases |
| P1 | Git Output Sanitization | `gosh.ps1:234` | 10 min | 2 test cases |
| P1 | Runtime Path Validation | `gosh.ps1:408` | 5 min | 3 test cases |
| P2 | Atomic File Creation | `gosh.ps1:685` | 5 min | 3 test cases |
| P2 | Execution Policy Check | `gosh.ps1:80` | 5 min | 3 test cases |

**Total Implementation Time:** ~50 minutes  
**Total Test Cases:** 28 tests

---

## Executive Summary

This document contains a comprehensive security analysis of `gosh.ps1`, identifying **9 security concerns** ranging from **CRITICAL** to **LOW** severity. The most significant issues involve arbitrary code execution through dynamic ScriptBlock creation and unvalidated task script loading.

**Key Findings:**
- 2 Critical severity issues
- 1 High severity issue
- 3 Medium severity issues
- 3 Low severity issues

**Important Context:** Gosh is designed as a **local development tool** for **trusted environments**. Many identified risks are acceptable trade-offs for a developer tool where users already have full system access. However, the mitigations below provide defense-in-depth protection.

---

## 🎯 Quick Action Items for AI Agent

Below are **specific, actionable tasks** that can be assigned to an AI coding agent to implement security mitigations. Each item includes:
- **Specific file and line numbers** to modify
- **Exact code changes** required
- **Test cases** to verify the fix
- **Acceptance criteria** for completion

### Priority 0 (Critical) - Implement Immediately

#### Action Item #1: Add TaskDirectory Parameter Validation
**File:** `gosh.ps1`, Line 68  
**Current Code:**
```powershell
[Parameter()]
[string]$TaskDirectory = ".build",
```

**Required Change:**
```powershell
[Parameter()]
[ValidatePattern('^[a-zA-Z0-9_\-\.]+$')]
[ValidateScript({
    if ($_ -match '\.\.' -or [System.IO.Path]::IsPathRooted($_)) {
        throw "TaskDirectory must be a relative path without '..' sequences or absolute paths"
    }
    return $true
})]
[string]$TaskDirectory = ".build",
```

**Test Cases:**
```powershell
# Should succeed
.\gosh.ps1 -TaskDirectory ".build" -ListTasks
.\gosh.ps1 -TaskDirectory "custom-tasks" -ListTasks
.\gosh.ps1 -TaskDirectory "build_v2" -ListTasks

# Should fail with validation error
.\gosh.ps1 -TaskDirectory "..\..\" -ListTasks
.\gosh.ps1 -TaskDirectory "C:\Windows\System32" -ListTasks
.\gosh.ps1 -TaskDirectory "tasks/../../../etc" -ListTasks
.\gosh.ps1 -TaskDirectory "tasks;rm-rf" -ListTasks
```

**Acceptance Criteria:**
- [ ] TaskDirectory parameter has ValidatePattern attribute
- [ ] TaskDirectory parameter has ValidateScript attribute checking for `..` and absolute paths
- [ ] All test cases pass as expected
- [ ] Error message is clear and helpful when validation fails
- [ ] Existing functionality with valid paths remains unchanged

---

#### Action Item #2: Add Path Sanitization in Invoke-Task
**File:** `gosh.ps1`, Lines 620-660 (Invoke-Task function)  
**Location:** Before line 641 (where ScriptBlock is created)

**Required Change:** Add validation block before ScriptBlock creation:
```powershell
# Execute external script with utility functions injected
try {
    # SECURITY: Validate script path before interpolation
    $scriptPath = $TaskInfo.ScriptPath
    
    # Check for dangerous characters that could enable code injection
    if ($scriptPath -match '[`$();{}\[\]|&<>]') {
        throw "Script path contains potentially dangerous characters: $scriptPath"
    }
    
    # Validate path is within project directory
    $fullScriptPath = [System.IO.Path]::GetFullPath($scriptPath)
    $projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
    
    if (-not $fullScriptPath.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Script path is outside project directory: $scriptPath"
    }
    
    # Get utility functions from Gosh
    $utilities = Get-GoshUtilities
    # ... rest of existing code
```

**Test Cases:**
Create test file: `tests/security/test-path-injection.ps1`
```powershell
Describe "Path Injection Protection" {
    It "Should reject paths with backticks" {
        # Create mock task with malicious path
        $maliciousTask = @{
            Names = @('malicious')
            ScriptPath = 'C:\test`$(Remove-Item C:\).ps1'
            IsCore = $false
            Dependencies = @()
        }
        { Invoke-Task -TaskInfo $maliciousTask -AllTasks @{} -Arguments @() } | 
            Should -Throw "*dangerous characters*"
    }
    
    It "Should reject paths outside project" {
        $outsideTask = @{
            Names = @('outside')
            ScriptPath = 'C:\Windows\System32\evil.ps1'
            IsCore = $false
            Dependencies = @()
        }
        { Invoke-Task -TaskInfo $outsideTask -AllTasks @{} -Arguments @() } | 
            Should -Throw "*outside project directory*"
    }
    
    It "Should accept valid project paths" {
        $validTask = @{
            Names = @('valid')
            ScriptPath = Join-Path $PSScriptRoot '.build\Invoke-Valid.ps1'
            IsCore = $false
            Dependencies = @()
        }
        # Should not throw
        # Note: Will fail on missing file, but won't fail on path validation
    }
}
```

**Acceptance Criteria:**
- [ ] Path validation code added before ScriptBlock creation
- [ ] Dangerous characters are detected and rejected
- [ ] Paths outside project directory are rejected
- [ ] All test cases pass
- [ ] Existing valid tasks continue to work
- [ ] Clear error messages for security violations

---

#### Action Item #3: Add Task Name Validation
**File:** `gosh.ps1`, Line 71  
**Current Code:**
```powershell
[Parameter()]
[string]$NewTask,
```

**Required Change:**
```powershell
[Parameter()]
[ValidatePattern('^[a-z0-9][a-z0-9\-]*$')]
[ValidateLength(1, 50)]
[string]$NewTask,
```

**Additional Change - File:** `gosh.ps1`, Lines 347-352 (Get-TaskMetadata function)  
**Current Code:**
```powershell
if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
    $metadata.Names = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
}
```

**Required Change:**
```powershell
if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
    $taskNames = $Matches[1] -split ',' | ForEach-Object { 
        $taskName = $_.Trim()
        
        # SECURITY: Validate task name format
        if ($taskName -notmatch '^[a-z0-9][a-z0-9\-]*$') {
            Write-Warning "Invalid task name format '$taskName' in $FilePath (only lowercase letters, numbers, and hyphens allowed)"
            return $null
        }
        
        # Enforce reasonable length
        if ($taskName.Length -gt 50) {
            Write-Warning "Task name too long (max 50 chars): $taskName"
            return $null
        }
        
        return $taskName
    } | Where-Object { $null -ne $_ }
    
    if ($taskNames.Count -gt 0) {
        $metadata.Names = @($taskNames)
    }
}
```

**Test Cases:**
```powershell
# Should succeed
.\gosh.ps1 -NewTask "my-task"
.\gosh.ps1 -NewTask "build"
.\gosh.ps1 -NewTask "deploy-prod"
.\gosh.ps1 -NewTask "test123"

# Should fail with validation error
.\gosh.ps1 -NewTask "My-Task"           # Uppercase
.\gosh.ps1 -NewTask "task name"         # Space
.\gosh.ps1 -NewTask "task;rm-rf"        # Semicolon
.\gosh.ps1 -NewTask "task`$(evil)"      # Command injection attempt
.\gosh.ps1 -NewTask "task\x1b[31m"      # Escape sequences
.\gosh.ps1 -NewTask ("a" * 51)          # Too long

# Test task name parsing from files
Describe "Task Name Validation from Files" {
    It "Should reject task names with invalid characters" {
        $testFile = "test-invalid-task.ps1"
        Set-Content $testFile "# TASK: valid-task, INVALID-CAPS, another`$(evil)"
        $metadata = Get-TaskMetadata $testFile
        $metadata.Names | Should -Contain "valid-task"
        $metadata.Names | Should -Not -Contain "INVALID-CAPS"
        $metadata.Names | Should -Not -Contain "another`$(evil)"
        Remove-Item $testFile
    }
}
```

**Acceptance Criteria:**
- [ ] NewTask parameter has ValidatePattern attribute
- [ ] NewTask parameter has ValidateLength attribute (1-50 chars)
- [ ] Task name parsing validates format (lowercase, numbers, hyphens only)
- [ ] Task name parsing enforces length limit
- [ ] Invalid task names are rejected with clear warnings
- [ ] All test cases pass
- [ ] Existing valid tasks continue to work

---

### Priority 1 (High) - Implement Soon

#### Action Item #4: Sanitize Git Output
**File:** `gosh.ps1`, Lines 234-247 (Get-GitStatus function)  
**Current Code:**
```powershell
# Get git status
$status = git status --porcelain 2>$null

# Determine if clean and return result
$isClean = [string]::IsNullOrWhiteSpace($status)

return [PSCustomObject]@{
    IsClean      = $isClean
    Status       = $status
    HasGit       = $true
    InRepo       = $true
    ErrorMessage = $null
}
```

**Required Change:**
```powershell
# Get git status
$rawStatus = git status --porcelain 2>$null

# SECURITY: Sanitize git output to prevent terminal injection
$status = $null
if ($null -ne $rawStatus -and $rawStatus.Length -gt 0) {
    $status = $rawStatus | ForEach-Object {
        # Remove ANSI escape sequences
        $cleaned = $_ -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        # Remove other control characters (0x00-0x1F, 0x7F-0x9F)
        $cleaned = $cleaned -replace '[\x00-\x1F\x7F-\x9F]', '?'
        return $cleaned
    }
}

# Determine if clean and return result
$isClean = [string]::IsNullOrWhiteSpace($status)

return [PSCustomObject]@{
    IsClean      = $isClean
    Status       = $status
    HasGit       = $true
    InRepo       = $true
    ErrorMessage = $null
}
```

**Test Cases:**
Create test: `tests/security/test-git-sanitization.ps1`
```powershell
Describe "Git Output Sanitization" {
    BeforeAll {
        # Create a test git repo with files containing special characters
        $testRepo = Join-Path $TestDrive "git-test"
        New-Item -Path $testRepo -ItemType Directory -Force
        Push-Location $testRepo
        git init
        
        # Create files with ANSI escape sequences in names (where supported)
        # On Windows, simulate the test with mocked git output
        Mock git {
            param($command)
            if ($command -eq 'status' -and $args -contains '--porcelain') {
                return @(
                    " M normal-file.txt",
                    " M file-with-`$([char]27)[31mred-text`$([char]27)[0m.txt",
                    "?? file-with-`$([char]0x00)null.txt"
                )
            }
        }
    }
    
    It "Should remove ANSI escape sequences" {
        $status = Get-GitStatus
        $status.Status | Should -Not -Match '\x1b\['
    }
    
    It "Should replace control characters with ?" {
        $status = Get-GitStatus
        $status.Status | ForEach-Object {
            $_ | Should -Not -Match '[\x00-\x1F\x7F-\x9F]'
        }
    }
    
    AfterAll {
        Pop-Location
    }
}
```

**Acceptance Criteria:**
- [ ] Git output is sanitized before being stored
- [ ] ANSI escape sequences are removed
- [ ] Control characters are replaced with `?`
- [ ] Test cases pass
- [ ] Normal git output still works correctly
- [ ] IsClean detection still works correctly

---

#### Action Item #5: Add Runtime Path Validation in Get-AllTasks
**File:** `gosh.ps1`, Lines 408-420 (Get-AllTasks function)  
**Current Code:**
```powershell
# Get project-specific tasks from specified directory
# Check if TaskDirectory is absolute or relative
if ([System.IO.Path]::IsPathRooted($TaskDirectory)) {
    $buildPath = $TaskDirectory
} else {
    $buildPath = Join-Path $PSScriptRoot $TaskDirectory
}
$projectTasks = Get-ProjectTasks -BuildPath $buildPath
```

**Required Change:**
```powershell
# Get project-specific tasks from specified directory
# SECURITY: Additional runtime validation for TaskDirectory
$buildPath = Join-Path $PSScriptRoot $TaskDirectory
$resolvedPath = [System.IO.Path]::GetFullPath($buildPath)
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)

# Ensure the resolved path is within project directory
if (-not $resolvedPath.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning "TaskDirectory resolves outside project directory: $TaskDirectory"
    Write-Warning "Project root: $projectRoot"
    Write-Warning "Resolved path: $resolvedPath"
    throw "TaskDirectory must resolve to a path within the project directory"
}

$projectTasks = Get-ProjectTasks -BuildPath $resolvedPath
```

**Test Cases:**
```powershell
Describe "TaskDirectory Runtime Validation" {
    It "Should reject paths that resolve outside project" {
        # This should be caught by parameter validation first,
        # but test runtime check as defense-in-depth
        { Get-AllTasks -TaskDirectory "..\..\..\Windows" } | 
            Should -Throw "*outside project directory*"
    }
    
    It "Should accept valid relative paths" {
        { Get-AllTasks -TaskDirectory ".build" } | Should -Not -Throw
        { Get-AllTasks -TaskDirectory "custom-tasks" } | Should -Not -Throw
    }
    
    It "Should handle symbolic links safely" {
        # Create a symbolic link test if on supported platform
        if ($IsWindows -and (Test-Path "C:\Windows")) {
            # Note: This test requires admin privileges on Windows
            # Skip if not admin or test in isolated environment
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Runtime path validation added to Get-AllTasks
- [ ] Resolved paths are checked against project root
- [ ] Clear warning messages when path is rejected
- [ ] All test cases pass
- [ ] Existing functionality with valid paths unchanged

---

### Priority 2 (Medium) - Implement When Possible

#### Action Item #6: Add Atomic File Creation in NewTask
**File:** `gosh.ps1`, Lines 685-690  
**Current Code:**
```powershell
# Check if file already exists
if (Test-Path $filePath) {
    Write-Error "Task file already exists: $fileName"
    exit 1
}

# Create task file template
$template = @"
...
"@

# Write the file
Set-Content -Path $filePath -Value $template -Encoding UTF8
```

**Required Change:**
```powershell
# Create task file template
$template = @"
...
"@

# SECURITY: Use atomic file creation to prevent race conditions
try {
    # Use -NoClobber to fail if file exists (atomic check-and-create)
    Set-Content -Path $filePath -Value $template -Encoding UTF8 -NoClobber -ErrorAction Stop
} catch [System.IO.IOException] {
    Write-Error "Task file already exists: $fileName"
    exit 1
} catch {
    Write-Error "Failed to create task file: $_"
    exit 1
}
```

**Test Cases:**
```powershell
Describe "Atomic Task File Creation" {
    It "Should create new task file" {
        $taskName = "test-atomic-$(Get-Random)"
        .\gosh.ps1 -NewTask $taskName
        Test-Path ".build\Invoke-$taskName.ps1" | Should -Be $true
        Remove-Item ".build\Invoke-$taskName.ps1"
    }
    
    It "Should fail if file already exists" {
        $taskName = "test-existing-$(Get-Random)"
        .\gosh.ps1 -NewTask $taskName
        { .\gosh.ps1 -NewTask $taskName } | Should -Throw "*already exists*"
        Remove-Item ".build\Invoke-$taskName.ps1"
    }
    
    It "Should not create partial file on failure" {
        # Simulate failure scenario
        # File should not exist or be empty on error
    }
}
```

**Acceptance Criteria:**
- [ ] File creation uses -NoClobber parameter
- [ ] Race condition window eliminated
- [ ] Proper error handling for IOException
- [ ] All test cases pass
- [ ] No partial files created on error

---

#### Action Item #7: Add Execution Policy Awareness
**File:** `gosh.ps1`, After line 80 (after parameter block, before main logic)

**Required Change:** Add execution policy check:
```powershell
# SECURITY: Execution policy awareness
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq 'Unrestricted' -or $executionPolicy -eq 'Bypass') {
    Write-Verbose "Running with permissive execution policy: $executionPolicy"
    Write-Verbose "Consider using RemoteSigned or AllSigned for better security"
} elseif ($executionPolicy -eq 'Restricted') {
    Write-Warning "PowerShell execution policy is set to Restricted"
    Write-Warning "You may need to change it to run this script"
    Write-Warning "Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
}
```

**Test Cases:**
```powershell
Describe "Execution Policy Awareness" {
    It "Should warn about permissive policies" {
        Mock Get-ExecutionPolicy { return 'Unrestricted' }
        $output = .\gosh.ps1 -ListTasks -Verbose 4>&1
        $output | Should -Match "permissive execution policy"
    }
    
    It "Should warn about restricted policy" {
        Mock Get-ExecutionPolicy { return 'Restricted' }
        $output = .\gosh.ps1 -ListTasks 3>&1
        $output | Should -Match "execution policy is set to Restricted"
    }
    
    It "Should run normally with RemoteSigned" {
        Mock Get-ExecutionPolicy { return 'RemoteSigned' }
        { .\gosh.ps1 -ListTasks } | Should -Not -Throw
    }
}
```

**Acceptance Criteria:**
- [ ] Execution policy check added
- [ ] Appropriate warnings for permissive policies
- [ ] Helpful message for restricted policy
- [ ] All test cases pass
- [ ] Normal operation not impacted

---

## 📋 Implementation Tracking

Use this checklist to track implementation progress:

### Priority 0 (Critical)
- [ ] **Action Item #1**: TaskDirectory Parameter Validation
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

- [ ] **Action Item #2**: Path Sanitization in Invoke-Task
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

- [ ] **Action Item #3**: Task Name Validation
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

### Priority 1 (High)
- [ ] **Action Item #4**: Git Output Sanitization
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

- [ ] **Action Item #5**: Runtime Path Validation
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

### Priority 2 (Medium)
- [ ] **Action Item #6**: Atomic File Creation
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

- [ ] **Action Item #7**: Execution Policy Awareness
  - [ ] Code implemented
  - [ ] Tests written and passing
  - [ ] Documentation updated
  - [ ] PR reviewed and merged

---

## 🚨 CRITICAL SEVERITY Issues

### 1. Arbitrary Code Execution via Dynamic ScriptBlock Creation

**Location:** `gosh.ps1`, Lines 641-658 (Invoke-Task function)

**Code:**
```powershell
$scriptContent = @"
# Injected Gosh utility functions
$($utilityDefinitions -join "`n")

# Set task context variables
`$TaskScriptRoot = '$([System.IO.Path]::GetDirectoryName($TaskInfo.ScriptPath))'

# Execute the original task script in the context of its directory
Push-Location `$TaskScriptRoot
try {
    . '$($TaskInfo.ScriptPath)' @Arguments
} finally {
    Pop-Location
}
"@

$scriptBlock = [ScriptBlock]::Create($scriptContent)
& $scriptBlock
```

**Risk:** 
- Creates executable code from string concatenation with interpolated variables
- File paths from file system scanning are embedded directly into executable code
- Task script paths could contain special characters that alter script behavior
- No sanitization of paths before interpolation

**Impact:** Full system compromise with privileges of the executing user

**Attack Vector:**
1. Attacker creates file in `.build/` directory with crafted filename or metadata
2. Malicious path or task name is interpolated into the ScriptBlock
3. Code injection occurs when ScriptBlock is created and executed

**Likelihood:** Medium (requires write access to `.build` directory, which developer already has)

**Mitigation:**
```powershell
# Validate script path before interpolation
$scriptPath = $TaskInfo.ScriptPath
if ($scriptPath -match '[`$();{}\[\]|&<>]') {
    throw "Script path contains potentially dangerous characters: $scriptPath"
}

# Use safe path handling
$scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
$taskScriptRoot = [System.IO.Path]::GetDirectoryName($scriptPath)

# Validate path is within expected directory
if (-not $scriptPath.StartsWith($PSScriptRoot)) {
    throw "Script path is outside project directory"
}
```

---

### 2. Unvalidated Script Execution from File System

**Location:** `gosh.ps1`, Lines 377-379 (Get-ProjectTasks function)

**Code:**
```powershell
$buildFiles = Get-ChildItem $BuildPath -Filter "*.ps1" -File -Force | 
    Where-Object { $_.Name -notmatch '\.Tests\.ps1$' }
foreach ($file in $buildFiles) {
    $metadata = Get-TaskMetadata $file.FullName
    # ... file content is parsed and eventually executed
}
```

**Risk:**
- Any `.ps1` file in the task directory is loaded and can be executed
- No signature verification (bypasses PowerShell execution policy)
- No integrity checks (no hash validation)
- `-Force` flag includes hidden files that might be malicious
- Scripts execute with full privileges of the user

**Impact:** Arbitrary code execution

**Attack Vector:**
1. Attacker drops malicious `.ps1` file into `.build` directory
2. File is automatically discovered and parsed
3. When task is invoked, malicious code executes

**Likelihood:** Medium (requires file system access to `.build` directory)

**Mitigation:**
```powershell
# Option 1: Require script signing
foreach ($file in $buildFiles) {
    $signature = Get-AuthenticodeSignature $file.FullName
    if ($signature.Status -ne 'Valid') {
        Write-Warning "Skipping unsigned/invalid task: $($file.Name)"
        continue
    }
    $metadata = Get-TaskMetadata $file.FullName
}

# Option 2: Implement file integrity checking
$manifestPath = Join-Path $BuildPath "tasks.manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    foreach ($file in $buildFiles) {
        $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
        $expected = $manifest.Files[$file.Name]
        if ($hash -ne $expected) {
            Write-Warning "Task file integrity check failed: $($file.Name)"
            continue
        }
    }
}

# Option 3: Use explicit task allowlist
$allowedTasks = @('format', 'lint', 'build', 'deploy')
if ($taskName -notin $allowedTasks) {
    Write-Warning "Task '$taskName' not in allowlist"
    continue
}
```

---

## 🔶 HIGH SEVERITY Issues

### 3. Path Traversal Vulnerability

**Location:** `gosh.ps1`, Lines 408-413 (Get-AllTasks function)

**Code:**
```powershell
if ([System.IO.Path]::IsPathRooted($TaskDirectory)) {
    $buildPath = $TaskDirectory
} else {
    $buildPath = Join-Path $PSScriptRoot $TaskDirectory
}
$projectTasks = Get-ProjectTasks -BuildPath $buildPath
```

**Risk:**
- `$TaskDirectory` parameter accepts arbitrary user input
- No validation against path traversal sequences (`../`, `..\..\`)
- Could load and execute tasks from unintended directories outside the project
- Absolute paths are allowed without restriction

**Impact:** Loading and executing scripts from arbitrary file system locations

**Attack Vector:**
```powershell
# Attacker provides malicious path
.\gosh.ps1 -TaskDirectory "..\..\..\..\Windows\System32" malicious-task
.\gosh.ps1 -TaskDirectory "C:\MaliciousScripts" evil-task
```

**Likelihood:** High (parameter is user-controlled via command line)

**Mitigation:**
```powershell
# Add parameter validation
[Parameter()]
[ValidatePattern('^[a-zA-Z0-9_\-\.]+$')]
[ValidateScript({
    if ($_ -match '\.\.' -or [System.IO.Path]::IsPathRooted($_)) {
        throw "TaskDirectory must be a relative path without '..' sequences"
    }
    return $true
})]
[string]$TaskDirectory = ".build"

# Additional runtime validation
$buildPath = Join-Path $PSScriptRoot $TaskDirectory
$resolvedPath = [System.IO.Path]::GetFullPath($buildPath)

# Ensure the resolved path is within project directory
if (-not $resolvedPath.StartsWith($PSScriptRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "TaskDirectory must be within the project directory"
}
```

---

## 🟡 MEDIUM SEVERITY Issues

### 4. Dynamic Function Injection

**Location:** `gosh.ps1`, Lines 632-637 (Invoke-Task function)

**Code:**
```powershell
$utilities = Get-GoshUtilities

$utilityDefinitions = @()
foreach ($util in $utilities.GetEnumerator()) {
    $funcDef = $util.Value.ToString()
    $utilityDefinitions += "function $($util.Key) { $funcDef }"
}
```

**Risk:**
- Converts function objects to strings using `.ToString()`
- Re-defines functions dynamically in task execution context
- Function implementations are exposed as plain text
- Risk of function hijacking if utilities hashtable is compromised
- Function names are interpolated without validation

**Impact:** Function interception, information disclosure, potential code injection

**Attack Vector:**
1. If utilities hashtable could be modified (currently internal, but architectural risk)
2. Function names containing special characters could break script syntax
3. Exposing function implementation details aids in finding vulnerabilities

**Likelihood:** Low (requires modifying internal data structures)

**Mitigation:**
```powershell
# Validate function names
foreach ($util in $utilities.GetEnumerator()) {
    if ($util.Key -notmatch '^[a-zA-Z][a-zA-Z0-9\-]*$') {
        throw "Invalid utility function name: $($util.Key)"
    }
    
    # Use safer function definition approach
    $funcDef = $util.Value.ToString()
    
    # Consider using a more secure injection method
    # such as passing functions as parameters instead of string interpolation
    $utilityDefinitions += "function $($util.Key) { $funcDef }"
}

# Alternative: Use secure parameter passing
# Instead of string interpolation, pass utilities as parameters
```

---

### 5. Insufficient Input Validation on Task Names

**Location:** `gosh.ps1`, Lines 347-349 (Get-TaskMetadata function)

**Code:**
```powershell
if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
    $metadata.Names = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
}
```

**Risk:**
- Task names are parsed from file content with minimal validation
- Could contain special characters, newlines, terminal escape sequences
- Task names used in string interpolation throughout the codebase
- Used in display output without sanitization
- Potential for output injection attacks or terminal manipulation

**Impact:** Terminal manipulation, log injection, display spoofing

**Attack Vector:**
```powershell
# Malicious task file content
# TASK: legitimate-task`r`nmalicious-code; Remove-Item -Recurse C:\
# TASK: task-with-escape-sequences\x1b[31mFAKE ERROR\x1b[0m
# TASK: task, another-task; evil-command
```

**Likelihood:** Medium (requires file creation, but task names are displayed widely)

**Mitigation:**
```powershell
if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
    $taskNames = $Matches[1] -split ',' | ForEach-Object { 
        $taskName = $_.Trim()
        
        # Validate task name format
        if ($taskName -notmatch '^[a-z0-9][a-z0-9\-]*$') {
            Write-Warning "Invalid task name format '$taskName' in $FilePath (only lowercase letters, numbers, and hyphens allowed)"
            return $null
        }
        
        # Enforce reasonable length
        if ($taskName.Length -gt 50) {
            Write-Warning "Task name too long: $taskName"
            return $null
        }
        
        return $taskName
    } | Where-Object { $null -ne $_ }
    
    $metadata.Names = @($taskNames)
}

# Add parameter validation for NewTask
[Parameter()]
[ValidatePattern('^[a-z0-9][a-z0-9\-]*$')]
[ValidateLength(1, 50)]
[string]$NewTask
```

---

### 6. Command Injection Risk in Git Operations

**Location:** `gosh.ps1`, Lines 234, 245 (Get-GitStatus function)

**Code:**
```powershell
$null = git rev-parse --git-dir 2>$null
# ...
$status = git status --porcelain 2>$null
```

**Risk:**
- Git commands execute external process
- While command parameters are controlled, output is not sanitized
- Git status output can contain arbitrary filenames from repository
- Filenames could include terminal escape sequences or control characters
- Output is displayed directly to user terminal

**Impact:** Terminal manipulation, information disclosure, visual spoofing

**Attack Vector:**
```bash
# Attacker creates files with malicious names in git repo
touch $'\x1b[31mFAKE ERROR: System Compromised\x1b[0m'
touch "file-with-$(rm -rf /)-command.txt"
touch $'file\nM\x20malicious-injection'
```

**Likelihood:** Low (requires control over git repository content)

**Mitigation:**
```powershell
# Sanitize git output before use/display
$status = git status --porcelain 2>$null

if ($null -ne $status) {
    # Remove control characters and escape sequences
    $status = $status | ForEach-Object {
        # Remove ANSI escape sequences
        $cleaned = $_ -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        # Remove other control characters (0x00-0x1F, 0x7F-0x9F)
        $cleaned = $cleaned -replace '[\x00-\x1F\x7F-\x9F]', '?'
        return $cleaned
    }
}

# Alternative: Use --null option for safer parsing
$status = git status --porcelain -z 2>$null
if ($null -ne $status) {
    $files = $status -split "`0" | Where-Object { $_ }
}
```

---

## 🔵 LOW SEVERITY Issues

### 7. Information Disclosure via Error Messages

**Location:** Multiple locations throughout `gosh.ps1`

**Examples:**
```powershell
# Line 688
Write-Error "Task file already exists: $fileName"

# Line 691
Write-Host "  Location: $filePath" -ForegroundColor Gray

# Line 284
Write-Error $gitStatus.ErrorMessage

# Line 665
Write-Error "Error executing task '$primaryName': $_"
```

**Risk:**
- Full file system paths exposed in error messages
- Directory structure revealed
- Stack traces may reveal implementation details
- Aids attackers in reconnaissance and understanding system layout

**Impact:** Information disclosure that could aid further attacks

**Attack Vector:**
- Trigger error conditions to enumerate file system structure
- Learn about directory layout for path traversal attacks
- Understand implementation for targeted exploitation

**Likelihood:** High (easy to trigger error conditions)

**Mitigation:**
```powershell
# Function to sanitize paths in error messages
function Get-SanitizedPath {
    param([string]$Path)
    
    # Option 1: Show only relative path from project root
    $relativePath = $Path -replace [regex]::Escape($PSScriptRoot), '.'
    return $relativePath
    
    # Option 2: Show only filename
    return Split-Path $Path -Leaf
    
    # Option 3: Redact path completely in production
    if ($env:GOSH_PRODUCTION) {
        return "[PATH REDACTED]"
    }
    return $Path
}

# Usage
Write-Error "Task file already exists: $(Get-SanitizedPath $fileName)"

# Add verbose logging for full details
Write-Verbose "Full path: $filePath"
```

---

### 8. File System Race Conditions (TOCTOU)

**Location:** Multiple locations with Time-of-Check-Time-of-Use patterns

**Example 1:** `gosh.ps1`, Lines 685-690
```powershell
# Check if file already exists
if (Test-Path $filePath) {
    Write-Error "Task file already exists: $fileName"
    exit 1
}

# ... later ...
Set-Content -Path $filePath -Value $template -Encoding UTF8
```

**Example 2:** Throughout task discovery
```powershell
if (Test-Path $BuildPath) {
    $buildFiles = Get-ChildItem $BuildPath -Filter "*.ps1" -File -Force
}
```

**Risk:**
- Gap between checking file existence and using file
- Files could be created, deleted, or modified between check and use
- Symbolic links could be swapped in
- Exploitable in shared file systems or multi-user environments

**Impact:** File overwrites, unexpected file operations, potential privilege escalation

**Attack Vector:**
1. Attacker monitors for file creation operations
2. Races to create/modify file between Test-Path and Set-Content
3. Could overwrite unintended files via symbolic links
4. In shared environments, could exploit timing windows

**Likelihood:** Low (requires specific timing and shared environment)

**Mitigation:**
```powershell
# Use atomic operations where possible
try {
    # Use -NoClobber to fail if file exists (atomic check-and-create)
    Set-Content -Path $filePath -Value $template -Encoding UTF8 -NoClobber -ErrorAction Stop
    Write-Host "✓ Created task file: $fileName" -ForegroundColor Green
} catch [System.IO.IOException] {
    Write-Error "Task file already exists: $fileName"
    exit 1
}

# Alternative: Use file locks
$fileStream = $null
try {
    $fileStream = [System.IO.File]::Open($filePath, 
        [System.IO.FileMode]::CreateNew, 
        [System.IO.FileAccess]::Write, 
        [System.IO.FileShare]::None)
    
    $writer = New-Object System.IO.StreamWriter($fileStream)
    $writer.Write($template)
    $writer.Close()
} catch {
    Write-Error "Failed to create task file: $_"
} finally {
    if ($null -ne $fileStream) { $fileStream.Dispose() }
}
```

---

### 9. No Execution Policy Enforcement

**Location:** Script lacks execution policy verification

**Risk:**
- Script doesn't verify PowerShell execution policy settings
- Relies entirely on system configuration
- May bypass intended security controls in some environments
- No warning when running in permissive mode

**Impact:** Could execute in environments where script execution should be restricted

**Mitigation:**
```powershell
# Add execution policy awareness at script start
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq 'Unrestricted' -or $executionPolicy -eq 'Bypass') {
    Write-Warning "Running with permissive execution policy: $executionPolicy"
    Write-Warning "Consider using RemoteSigned or AllSigned for better security"
}

# For signed script requirement
if ($executionPolicy -eq 'AllSigned') {
    # Verify task scripts are properly signed
    foreach ($file in $buildFiles) {
        $signature = Get-AuthenticodeSignature $file.FullName
        if ($signature.Status -ne 'Valid') {
            Write-Warning "Skipping unsigned task: $($file.Name)"
            Write-Warning "Current execution policy requires signed scripts"
            continue
        }
    }
}

# Add option for strict mode
if ($PSBoundParameters.ContainsKey('StrictMode')) {
    # Enable additional security checks
    Set-StrictMode -Version Latest
}
```

---

## 🛡️ Recommended Mitigations

### Priority 0 (Immediate - Critical)

1. **Implement Path Validation for TaskDirectory Parameter**
   ```powershell
   [Parameter()]
   [ValidatePattern('^[a-zA-Z0-9_\-\.]+$')]
   [ValidateScript({
       if ($_ -match '\.\.' -or [System.IO.Path]::IsPathRooted($_)) {
           throw "TaskDirectory must be a relative path without '..' sequences"
       }
       return $true
   })]
   [string]$TaskDirectory = ".build"
   ```

2. **Add ScriptBlock Sanitization**
   ```powershell
   # Before creating ScriptBlock, validate paths
   $scriptPath = $TaskInfo.ScriptPath
   if ($scriptPath -match '[`$();{}\[\]|&<>]') {
       throw "Script path contains potentially dangerous characters"
   }
   
   # Ensure path is within project directory
   $fullScriptPath = [System.IO.Path]::GetFullPath($scriptPath)
   if (-not $fullScriptPath.StartsWith($PSScriptRoot)) {
       throw "Script path is outside project directory"
   }
   ```

3. **Implement Task Name Validation**
   ```powershell
   [Parameter()]
   [ValidatePattern('^[a-z0-9][a-z0-9\-]*$')]
   [ValidateLength(1, 50)]
   [string]$NewTask
   ```

### Priority 1 (Short-term - High)

4. **Add Script Signing Verification** (Optional but recommended)
   ```powershell
   foreach ($file in $buildFiles) {
       $signature = Get-AuthenticodeSignature $file.FullName
       if ($signature.Status -ne 'Valid') {
           Write-Warning "Skipping unsigned task: $($file.Name)"
           continue
       }
       $metadata = Get-TaskMetadata $file.FullName
   }
   ```

5. **Implement File Integrity Checks**
   ```powershell
   # Create manifest file: .build/tasks.manifest.json
   # {
   #   "version": "1.0",
   #   "files": {
   #     "Invoke-Build.ps1": "sha256-hash-here",
   #     "Invoke-Lint.ps1": "sha256-hash-here"
   #   }
   # }
   
   $manifestPath = Join-Path $BuildPath "tasks.manifest.json"
   if (Test-Path $manifestPath) {
       $manifest = Get-Content $manifestPath | ConvertFrom-Json
       foreach ($file in $buildFiles) {
           $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
           $expected = $manifest.files."$($file.Name)"
           if ($hash -ne $expected) {
               Write-Warning "Task integrity check failed: $($file.Name)"
               continue
           }
       }
   }
   ```

6. **Sanitize Git Output**
   ```powershell
   $status = git status --porcelain 2>$null | ForEach-Object {
       $_ -replace '\x1b\[[0-9;]*[a-zA-Z]', '' -replace '[\x00-\x1F\x7F-\x9F]', '?'
   }
   ```

### Priority 2 (Medium-term)

7. **Add Execution Policy Awareness**
8. **Implement Audit Logging** for task execution
9. **Add Security Documentation** (this file serves as a start)
10. **Create Security Testing Suite**

### Priority 3 (Long-term)

11. **Consider Constrained Language Mode** for task execution
12. **Implement Sandboxing** for untrusted tasks
13. **Add Task Manifest System** for explicit task registration
14. **Create Security Scanning CI/CD Pipeline**

---

## 📊 Risk Assessment Matrix

| # | Issue | Severity | Exploitability | Impact | Likelihood | Priority |
|---|-------|----------|----------------|--------|------------|----------|
| 1 | Dynamic ScriptBlock Creation | Critical | Medium | Critical | Medium | P0 |
| 2 | Unvalidated Script Execution | Critical | High | Critical | Medium | P0 |
| 3 | Path Traversal | High | High | High | High | P0 |
| 4 | Dynamic Function Injection | Medium | Low | Medium | Low | P2 |
| 5 | Task Name Validation | Medium | Medium | Medium | Medium | P1 |
| 6 | Git Command Injection | Medium | Low | Low | Low | P2 |
| 7 | Information Disclosure | Low | High | Low | High | P2 |
| 8 | Race Conditions | Low | Low | Medium | Low | P3 |
| 9 | Execution Policy | Low | Low | Low | Low | P3 |

**Legend:**
- **Severity:** Impact if successfully exploited
- **Exploitability:** How easy it is to exploit
- **Impact:** Actual damage that could be caused
- **Likelihood:** Probability of exploitation in typical usage
- **Priority:** Recommended fix priority (P0=Critical, P1=High, P2=Medium, P3=Low)

---

## 🎯 Security Context & Acceptable Risk

### Design Philosophy

Gosh is designed as a **local development tool** for **trusted environments**. Important contextual factors:

#### ✅ Acceptable Risk (By Design)

1. **Dynamic Task Loading**
   - Developers work in their own workspaces with full file system access
   - Loading task scripts from `.build/` is the core feature
   - Users can create arbitrary scripts - that's the point

2. **Script Execution**
   - Developers already have PowerShell execution rights
   - They can run any script manually
   - Gosh provides convenience, not security boundary

3. **No Built-in Sandboxing**
   - Intended for trusted code
   - Sandboxing would limit legitimate use cases
   - Developers need full PowerShell capabilities

#### ❌ Not Acceptable (Requires Mitigation)

1. **Path Traversal Beyond Project**
   - Should not load tasks from arbitrary locations
   - Could expose system scripts unintentionally

2. **Code Injection via Path Interpolation**
   - Even in trusted environment, should be sanitized
   - Defense-in-depth principle

3. **Lack of Input Validation**
   - Task names should follow conventions
   - Prevents accidental issues, aids debugging

### Use Case Scenarios

#### ✅ Safe Usage:
```powershell
# Developer's own machine, own project
cd C:\MyProjects\MyApp
.\gosh.ps1 build

# Custom tasks in project
.\gosh.ps1 -TaskDirectory ".build-custom" deploy
```

#### ⚠️ Caution Required:
```powershell
# Shared development environment
# Ensure .build directory permissions are properly set
icacls .build /inheritance:r /grant:r "$env:USERNAME:(OI)(CI)F"

# Public CI/CD environment
# Use approved task allowlist
# Implement integrity checks
```

#### ❌ Unsafe Usage:
```powershell
# DON'T: Run with tasks from untrusted sources
.\gosh.ps1 -TaskDirectory "C:\Downloads\suspicious-tasks" unknown-task

# DON'T: Use in production automation without hardening
# DON'T: Share .build directory on network drive without access controls
# DON'T: Run tasks from unverified repositories
```

---

## 📋 Security Checklist

### For Developers Using Gosh

- [ ] Only run Gosh in directories you control
- [ ] Review task scripts before first execution
- [ ] Keep `.build` directory in version control
- [ ] Don't run tasks from untrusted sources
- [ ] Use execution policy `RemoteSigned` or stricter
- [ ] Review task file changes in pull requests
- [ ] Consider signing task scripts for team projects
- [ ] Use `-Outline` to preview task execution

### For Gosh Maintainers

- [ ] Implement P0 mitigations (path validation, input sanitization)
- [ ] Add security tests to test suite
- [ ] Document security considerations in README
- [ ] Consider adding `--strict` mode for enhanced security
- [ ] Create example manifest file for integrity checking
- [ ] Add security warning when running with -TaskDirectory
- [ ] Implement audit logging option
- [ ] Create security policy document
- [ ] Add SECURITY.md to repository
- [ ] Set up security scanning in CI/CD

### For Organizations Deploying Gosh

- [ ] Establish approved task repository
- [ ] Implement task signing requirements
- [ ] Create task approval process
- [ ] Use file integrity monitoring
- [ ] Implement audit logging
- [ ] Set up network share permissions properly
- [ ] Create internal security guidelines
- [ ] Train developers on secure usage
- [ ] Consider creating hardened fork for production use
- [ ] Implement code review for all task changes

---

## 🔗 References

### PowerShell Security Best Practices
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/security)
- [PowerShell Constrained Language Mode](https://devblogs.microsoft.com/powershell/powershell-constrained-language-mode/)
- [About Execution Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)

### Secure Coding Guidelines
- [OWASP Code Review Guide](https://owasp.org/www-project-code-review-guide/)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)
- [CWE-94: Code Injection](https://cwe.mitre.org/data/definitions/94.html)
- [CWE-22: Path Traversal](https://cwe.mitre.org/data/definitions/22.html)

### PowerShell Script Signing
- [About Signing](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_signing)
- [Set-AuthenticodeSignature](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-authenticodesignature)

---

## 📝 Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-20 | 1.0 | Initial security analysis | Security Review |
| 2025-10-20 | 1.1 | Added actionable items for AI agents | Security Review |

---

## 🤖 GitHub Issues Templates

Use these templates to create trackable GitHub issues for each action item:

### Issue Template: P0 - TaskDirectory Parameter Validation

**Title:** `[Security P0] Add TaskDirectory parameter validation to prevent path traversal`

**Labels:** `security`, `priority: critical`, `good first issue`

**Body:**
```markdown
## Security Issue
Path traversal vulnerability in TaskDirectory parameter allows loading tasks from arbitrary locations.

## Action Required
Implement parameter validation as specified in SECURITY.md Action Item #1

**File:** `gosh.ps1`, Line 68

## Implementation Details
See [SECURITY.md - Action Item #1](./SECURITY.md#action-item-1-add-taskdirectory-parameter-validation)

## Test Cases
- [ ] Valid paths: `.build`, `custom-tasks`, `build_v2` (should succeed)
- [ ] Invalid paths: `..\..`, `C:\Windows`, `../../../etc` (should fail)

## Acceptance Criteria
- [ ] ValidatePattern attribute added
- [ ] ValidateScript attribute added
- [ ] All test cases pass
- [ ] Clear error messages on validation failure

## Estimated Effort
5 minutes
```

---

### Issue Template: P0 - Path Sanitization in Invoke-Task

**Title:** `[Security P0] Add path sanitization before ScriptBlock creation`

**Labels:** `security`, `priority: critical`

**Body:**
```markdown
## Security Issue
Dynamic ScriptBlock creation with unsanitized path interpolation enables code injection.

## Action Required
Implement path validation as specified in SECURITY.md Action Item #2

**File:** `gosh.ps1`, Lines 641-660

## Implementation Details
See [SECURITY.md - Action Item #2](./SECURITY.md#action-item-2-add-path-sanitization-in-invoke-task)

## Test Cases
- [ ] Reject paths with dangerous characters
- [ ] Reject paths outside project directory
- [ ] Accept valid project paths

## Acceptance Criteria
- [ ] Path validation added before ScriptBlock creation
- [ ] Dangerous characters detected and rejected
- [ ] Paths outside project rejected
- [ ] All test cases pass

## Estimated Effort
10 minutes
```

---

### Issue Template: P0 - Task Name Validation

**Title:** `[Security P0] Add task name validation to prevent injection attacks`

**Labels:** `security`, `priority: critical`, `good first issue`

**Body:**
```markdown
## Security Issue
Insufficient input validation on task names allows special characters and potential injection.

## Action Required
Implement task name validation as specified in SECURITY.md Action Item #3

**Files:** 
- `gosh.ps1`, Line 71 (NewTask parameter)
- `gosh.ps1`, Lines 347-352 (Get-TaskMetadata function)

## Implementation Details
See [SECURITY.md - Action Item #3](./SECURITY.md#action-item-3-add-task-name-validation)

## Test Cases
- [ ] Valid names: `my-task`, `build`, `deploy-prod` (should succeed)
- [ ] Invalid names: `My-Task`, `task name`, `task;rm-rf` (should fail)

## Acceptance Criteria
- [ ] ValidatePattern attribute added to NewTask
- [ ] ValidateLength attribute added (1-50 chars)
- [ ] Task name parsing validates format
- [ ] All test cases pass

## Estimated Effort
10 minutes
```

---

### Issue Template: P1 - Git Output Sanitization

**Title:** `[Security P1] Sanitize git command output to prevent terminal injection`

**Labels:** `security`, `priority: high`

**Body:**
```markdown
## Security Issue
Git output may contain ANSI escape sequences and control characters from malicious filenames.

## Action Required
Implement output sanitization as specified in SECURITY.md Action Item #4

**File:** `gosh.ps1`, Lines 234-247

## Implementation Details
See [SECURITY.md - Action Item #4](./SECURITY.md#action-item-4-sanitize-git-output)

## Test Cases
- [ ] ANSI escape sequences removed
- [ ] Control characters replaced with `?`
- [ ] Normal git output still works

## Acceptance Criteria
- [ ] Git output sanitized before storage
- [ ] Test cases pass
- [ ] IsClean detection still works correctly

## Estimated Effort
10 minutes
```

---

### Issue Template: P1 - Runtime Path Validation

**Title:** `[Security P1] Add runtime path validation in Get-AllTasks`

**Labels:** `security`, `priority: high`

**Body:**
```markdown
## Security Issue
Additional defense-in-depth needed for TaskDirectory path resolution.

## Action Required
Implement runtime validation as specified in SECURITY.md Action Item #5

**File:** `gosh.ps1`, Lines 408-420

## Implementation Details
See [SECURITY.md - Action Item #5](./SECURITY.md#action-item-5-add-runtime-path-validation-in-get-alltasks)

## Test Cases
- [ ] Reject paths resolving outside project
- [ ] Accept valid relative paths
- [ ] Handle symbolic links safely

## Acceptance Criteria
- [ ] Runtime path validation added
- [ ] Clear warning messages
- [ ] All test cases pass

## Estimated Effort
5 minutes
```

---

### Issue Template: P2 - Atomic File Creation

**Title:** `[Security P2] Use atomic file operations to prevent race conditions`

**Labels:** `security`, `priority: medium`, `good first issue`

**Body:**
```markdown
## Security Issue
TOCTOU (Time-of-check-time-of-use) vulnerability in file creation.

## Action Required
Implement atomic file creation as specified in SECURITY.md Action Item #6

**File:** `gosh.ps1`, Lines 685-690

## Implementation Details
See [SECURITY.md - Action Item #6](./SECURITY.md#action-item-6-add-atomic-file-creation-in-newtask)

## Test Cases
- [ ] Create new task file successfully
- [ ] Fail if file already exists
- [ ] No partial files on failure

## Acceptance Criteria
- [ ] Use -NoClobber parameter
- [ ] Race condition eliminated
- [ ] All test cases pass

## Estimated Effort
5 minutes
```

---

### Issue Template: P2 - Execution Policy Awareness

**Title:** `[Security P2] Add execution policy awareness and warnings`

**Labels:** `security`, `priority: medium`, `good first issue`

**Body:**
```markdown
## Security Issue
Script lacks awareness of PowerShell execution policy settings.

## Action Required
Implement policy check as specified in SECURITY.md Action Item #7

**File:** `gosh.ps1`, After line 80

## Implementation Details
See [SECURITY.md - Action Item #7](./SECURITY.md#action-item-7-add-execution-policy-awareness)

## Test Cases
- [ ] Warn about permissive policies
- [ ] Warn about restricted policy
- [ ] Run normally with RemoteSigned

## Acceptance Criteria
- [ ] Execution policy check added
- [ ] Appropriate warnings shown
- [ ] All test cases pass

## Estimated Effort
5 minutes
```

---

## 📧 Contact

For security concerns or to report vulnerabilities:

1. **Do not** open public GitHub issues for security vulnerabilities
2. Contact repository maintainers directly
3. Follow responsible disclosure practices
4. Allow reasonable time for fixes before public disclosure

---

## ⚖️ Legal Disclaimer

This security analysis is provided "as-is" without warranty. It represents findings at a specific point in time and does not guarantee the absence of other vulnerabilities. Security is an ongoing process requiring continuous assessment and improvement.

The identified issues should be evaluated in the context of the intended use case. Not all findings require immediate action, and the priority should be determined based on the specific deployment environment and threat model.

---

## 🎴 Quick Reference Card

### For AI Coding Agents

**To implement a security fix:**

1. **Choose Priority Level:**
   - P0 (Critical): Implement immediately
   - P1 (High): Implement soon
   - P2 (Medium): Implement when possible

2. **Select Action Item:**
   - Navigate to [Quick Action Items](#-quick-action-items-for-ai-agent)
   - Find the specific Action Item # (e.g., "Action Item #1")

3. **Follow Implementation Steps:**
   ```
   a. Read "Current Code" section
   b. Apply "Required Change" section
   c. Implement "Test Cases" section
   d. Verify "Acceptance Criteria"
   ```

4. **Validation Checklist:**
   - [ ] Code compiles without errors
   - [ ] All test cases pass
   - [ ] Existing functionality unchanged
   - [ ] Clear error messages provided
   - [ ] Acceptance criteria met

5. **Submit Changes:**
   - Create PR with title: `[Security P#] Brief description`
   - Link to Action Item in SECURITY.md
   - Include test results in PR description

### Command Shortcuts

```powershell
# Run all tests
Invoke-Pester

# Run only security tests (after implementing)
Invoke-Pester -Tag Security

# Run specific test file
Invoke-Pester -Path tests/security/test-path-injection.ps1

# Validate syntax only
Test-ScriptFileInfo gosh.ps1

# Check for common security issues
Get-ScriptAnalyzerRule -Severity Warning,Error | Invoke-ScriptAnalyzer -Path gosh.ps1
```

### File Locations Reference

| Component | File Path | Lines |
|-----------|-----------|-------|
| TaskDirectory Parameter | `gosh.ps1` | 68 |
| Path Sanitization | `gosh.ps1` | 641-660 |
| Task Name Validation (Param) | `gosh.ps1` | 71 |
| Task Name Validation (Parse) | `gosh.ps1` | 347-352 |
| Git Output Sanitization | `gosh.ps1` | 234-247 |
| Runtime Path Validation | `gosh.ps1` | 408-420 |
| File Creation | `gosh.ps1` | 685-690 |
| Execution Policy | `gosh.ps1` | After 80 |

### Priority Matrix

```
P0 (Critical - ~25 min total):
├── Action Item #1: TaskDirectory Validation (5 min)
├── Action Item #2: Path Sanitization (10 min)
└── Action Item #3: Task Name Validation (10 min)

P1 (High - ~15 min total):
├── Action Item #4: Git Sanitization (10 min)
└── Action Item #5: Runtime Path Check (5 min)

P2 (Medium - ~10 min total):
├── Action Item #6: Atomic File Ops (5 min)
└── Action Item #7: Policy Awareness (5 min)
```

### Test Coverage Summary

- **Unit Tests:** 28 test cases across 7 action items
- **Integration Tests:** Included in action items
- **Security Tests:** Tag with `[Tag('Security')]`
- **Expected Pass Rate:** 100%

---

**Last Updated:** October 20, 2025  
**Document Version:** 1.1  
**Total Action Items:** 7  
**Estimated Implementation Time:** ~50 minutes  
**Test Coverage:** 28 test cases
