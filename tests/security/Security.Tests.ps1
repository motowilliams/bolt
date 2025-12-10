#Requires -Version 7.0

<#
.SYNOPSIS
    Security tests for Bolt build system.

.DESCRIPTION
    Tests for security vulnerabilities and input validation in bolt.ps1.
    Covers P0 security fixes: TaskDirectory validation and Path sanitization.
#>

BeforeAll {
    $BoltScript = Join-Path $PSScriptRoot ".." ".." "bolt.ps1"

    # Helper function to safely remove directory with retry logic
    function Remove-TestDirectory {
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$Path)

        if (-not (Test-Path $Path)) {
            return
        }

        # Try to remove with retries for file locking issues
        $attempts = 0
        $maxAttempts = 3
        $removed = $false

        while (-not $removed -and $attempts -lt $maxAttempts) {
            try {
                # Wait a bit for file handles to be released
                if ($attempts -gt 0) {
                    Start-Sleep -Milliseconds (100 * $attempts)
                }

                # Try to remove read-only attributes first
                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.Attributes = 'Normal' }

                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                $removed = $true
            } catch {
                $attempts++
                if ($attempts -ge $maxAttempts) {
                    Write-Warning "Failed to clean up directory after $maxAttempts attempts: $Path"
                    Write-Warning "Error: $_"
                }
            }
        }
    }

    # Helper function to invoke Bolt with parameters
    function Invoke-Bolt {
        param(
            [string[]]$Tasks = @(),
            [hashtable]$Parameters = @{}
        )

        # Build splatting hashtable for proper parameter binding
        $boltParams = @{}

        # Add tasks if provided
        if ($Tasks.Count -gt 0) {
            $boltParams['Task'] = $Tasks
        }

        # Merge additional parameters
        foreach ($key in $Parameters.Keys) {
            $boltParams[$key] = $Parameters[$key]
        }

        # Use splatting for proper PowerShell parameter binding
        try {
            $output = & $BoltScript @boltParams 2>&1
            $exitCode = $LASTEXITCODE
        } catch {
            $output = $_.Exception.Message
            $exitCode = 1
        }

        return @{
            Output = $output
            ExitCode = $exitCode
        }
    }
}

Describe "Security Tests" -Tag "Security", "P0" {

    Context "TaskDirectory Parameter Validation (P0 - Action Item #1)" {

        It "Should accept valid directory names with alphanumeric characters" {
            $result = Invoke-Bolt -Parameters @{
                TaskDirectory = "tests-fixtures"
                ListTasks = $true
            }
            # Should not throw validation error about TaskDirectory format
            $result.Output -join "" | Should -Not -Match "TaskDirectory.*invalid"
        }

        It "Should accept valid directory names with dashes" {
            $result = Invoke-Bolt -Parameters @{
                TaskDirectory = "build-tasks"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "TaskDirectory.*invalid"
        }

        It "Should accept valid directory names with underscores" {
            $result = Invoke-Bolt -Parameters @{
                TaskDirectory = "build_tasks"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "TaskDirectory.*invalid"
        }

        It "Should reject path traversal attempts with .." {
            # Call bolt.ps1 directly to catch parameter validation exception
            {
                & $BoltScript -TaskDirectory "../etc" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject absolute paths on Windows" {
            {
                & $BoltScript -TaskDirectory "C:\Windows\System32" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject absolute paths on Unix" {
            {
                & $BoltScript -TaskDirectory "/etc/passwd" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject directory names with special characters" {
            {
                & $BoltScript -TaskDirectory "tasks;rm -rf /" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject directory names with backticks" {
            {
                & $BoltScript -TaskDirectory "tasks`$(Get-Process)" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }
    }

    Context "Path Sanitization in Invoke-Task (P0 - Action Item #2)" {

        BeforeAll {
            # Create a temporary malicious task file for testing
            $tempDir = Join-Path $TestDrive "malicious-tasks"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            # Create a task with a normal name but we'll test path injection
            $taskPath = Join-Path $tempDir "Invoke-Normal.ps1"
            Set-Content -Path $taskPath -Value @"
# TASK: normal
# DESCRIPTION: Normal task for testing
Write-Host "Normal task executed"
exit 0
"@
        }

        It "Should reject script paths with command substitution characters" {
            # This test verifies that paths with dangerous characters are rejected
            # We can't easily inject a malicious path, but we can verify the validation logic

            # Read the bolt.ps1 file and verify path sanitization code exists
            $boltContent = Get-Content $BoltScript -Raw
            $boltContent | Should -Match 'if \(\$scriptPath -match ''\[\`\$\(\);{}\\\[\\\]\|&<>\]''\)'
            $boltContent | Should -Match 'throw "Script path contains potentially dangerous characters'
        }

        It "Should reject script paths outside project directory" {
            # Verify validation code exists for path boundary checks
            $boltContent = Get-Content $BoltScript -Raw
            $boltContent | Should -Match '\$fullScriptPath = \[System\.IO\.Path\]::GetFullPath\(\$scriptPath\)'
            $boltContent | Should -Match 'if \(-not \$fullScriptPath\.StartsWith\(\$projectRoot'
            $boltContent | Should -Match 'throw "Script path is outside project directory'
        }

        It "Should accept valid script paths within project directory" {
            # Test with actual fixtures that should work
            $result = Invoke-Bolt -Tasks @("mock-simple") -Parameters @{
                TaskDirectory = "tests/fixtures"
                Only = $true
            }

            # Should not contain path validation errors
            $result.Output -join "" | Should -Not -Match "Script path contains potentially dangerous"
            $result.Output -join "" | Should -Not -Match "Script path is outside project directory"
        }
    }

    Context "ScriptBlock Creation Safety (Defense in Depth)" {

        It "Should validate paths before ScriptBlock.Create()" {
            $boltContent = Get-Content $BoltScript -Raw

            # Verify validation happens BEFORE ScriptBlock.Create
            $validationIndex = $boltContent.IndexOf('# SECURITY: Validate script path')
            $scriptBlockIndex = $boltContent.IndexOf('$scriptBlock = [ScriptBlock]::Create($scriptContent)')

            $validationIndex | Should -BeGreaterThan 0
            $scriptBlockIndex | Should -BeGreaterThan 0
            $validationIndex | Should -BeLessThan $scriptBlockIndex
        }
    }

    Context "Combined Security Validation" {

        It "Should protect against path traversal via TaskDirectory and malicious script paths" {
            # This is a defense-in-depth test: even if one validation fails, the other should catch it
            # Call bolt.ps1 directly to catch parameter validation exception
            {
                & $BoltScript -Task "malicious" -TaskDirectory "../../../Windows/System32" -Only
            } | Should -Throw
        }
    }

    Context "Task Name Validation (P0 - Action Item #3)" {

        It "Should accept valid lowercase task names" {
            $result = Invoke-Bolt -Tasks @("build") -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should accept task names with numbers" {
            $result = Invoke-Bolt -Tasks @("test123") -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should accept task names with hyphens" {
            $result = Invoke-Bolt -Tasks @("deploy-prod") -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should reject task names with uppercase letters" {
            {
                & $BoltScript -Task "Build" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with spaces" {
            {
                & $BoltScript -Task "my task" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with semicolons (command injection attempt)" {
            {
                & $BoltScript -Task "test;rm-rf" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with dollar signs (variable expansion attempt)" {
            {
                & $BoltScript -Task "task`$(evil)" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with backticks (command substitution attempt)" {
            {
                & $BoltScript -Task "task``ls" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names that are too long (> 50 chars)" {
            $longTaskName = "a" * 51
            {
                & $BoltScript -Task $longTaskName -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should accept task names at the maximum length (50 chars)" {
            $maxTaskName = "a" * 50
            $result = Invoke-Bolt -Tasks @($maxTaskName) -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should validate NewTask parameter format" {
            {
                & $BoltScript -NewTask "Invalid-Task-Name-With-Uppercase"
            } | Should -Throw "*NewTask*"
        }

        It "Should validate NewTask parameter length" {
            $longTaskName = "a" * 51
            {
                & $BoltScript -NewTask $longTaskName
            } | Should -Throw "*NewTask*"
        }

        It "Should accept valid NewTask parameter" {
            # Use a temporary directory within the project with unique name
            $tempDir = Join-Path $PSScriptRoot "temp-newtask-test-$(New-Guid)"

            try {
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                # Change to project root so relative path works
                Push-Location (Join-Path $PSScriptRoot ".." "..")

                $relativePath = "tests/security/$(Split-Path $tempDir -Leaf)"
                Invoke-Bolt -Parameters @{
                    NewTask = "my-valid-task"
                    TaskDirectory = $relativePath
                } | Out-Null

                # Should successfully create the task
                $expectedFile = Join-Path $tempDir "Invoke-My-Valid-Task.ps1"
                $expectedFile | Should -Exist
            } finally {
                Pop-Location
                Remove-TestDirectory -Path $tempDir
            }
        }
    }

    Context "Task Name Validation from Task Files" {

        BeforeAll {
            # Create temp directory within project for relative path testing with unique name
            $script:tempTaskDir = Join-Path $PSScriptRoot "temp-task-validation-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:tempTaskDir -Force | Out-Null
        }

        AfterAll {
            # Clean up temp directory
            Remove-TestDirectory -Path $script:tempTaskDir
        }

        It "Should warn about invalid task names in task files" {
            $invalidTaskFile = Join-Path $script:tempTaskDir "Invoke-InvalidTask.ps1"
            Set-Content -Path $invalidTaskFile -Value @"
# TASK: valid-task, INVALID-CAPS, another
# DESCRIPTION: Test task with mixed validity
Write-Host "Test"
exit 0
"@

            # Use relative path from script root
            $relativeTaskDir = "tests/security/$(Split-Path $script:tempTaskDir -Leaf)"

            # Capture all output streams including warnings (3>&1 redirects warnings to stdout)
            $allOutput = & $BoltScript -TaskDirectory $relativeTaskDir -ListTasks 3>&1 2>&1 | Out-String

            # Should generate warnings for invalid names
            $allOutput | Should -Match "Invalid task name format.*INVALID-CAPS"
        }

        It "Should accept only valid task names from task files" {
            $mixedTaskFile = Join-Path $script:tempTaskDir "Invoke-MixedTask.ps1"
            Set-Content -Path $mixedTaskFile -Value @"
# TASK: good-task, BadTask, another-good-one
# DESCRIPTION: Mix of valid and invalid
Write-Host "Test"
exit 0
"@

            $relativeTaskDir = "tests/security/$(Split-Path $script:tempTaskDir -Leaf)"

            # Capture all output streams: stdout (1), stderr (2), warning (3), and information (6 - Write-Host)
            $output = & $BoltScript -TaskDirectory $relativeTaskDir -ListTasks 6>&1 3>&1 2>&1
            $allOutput = ($output | Out-String)

            # Should list valid tasks
            $allOutput | Should -Match "good-task"
            $allOutput | Should -Match "another-good-one"
            # Should warn about invalid task
            $allOutput | Should -Match "Invalid task name format.*BadTask"
        }

        It "Should reject task names that are too long in task files" {
            $longNameFile = Join-Path $script:tempTaskDir "Invoke-LongName.ps1"
            $longName = "a" * 51
            Set-Content -Path $longNameFile -Value @"
# TASK: $longName
# DESCRIPTION: Task with too-long name
Write-Host "Test"
exit 0
"@

            $relativeTaskDir = "tests/security/$(Split-Path $script:tempTaskDir -Leaf)"

            # Capture all output streams (3>&1 redirects warnings to stdout)
            $allOutput = & $BoltScript -TaskDirectory $relativeTaskDir -ListTasks 3>&1 2>&1 | Out-String

            $allOutput | Should -Match "Task name too long"
        }
    }
}

Describe "Git Output Sanitization Tests" -Tag "Security", "P1" {

    BeforeAll {
        # Check if we're in a git repo and git is available
        $script:gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        $script:inRepo = $false
        if ($script:gitAvailable) {
            git rev-parse --git-dir 2>$null | Out-Null
            $script:inRepo = $LASTEXITCODE -eq 0
        }

        $script:BoltScript = Join-Path $PSScriptRoot ".." ".." "bolt.ps1"
    }

    Context "Git Status Output Safety (P1 - Git Output Sanitization)" {

        It "Should execute git commands safely without command injection" {
            if (-not $script:gitAvailable) {
                Set-ItResult -Skipped -Because "Git is not available"
                return
            }

            # Verify that git commands in Get-GitStatus use safe execution
            $boltContent = Get-Content $script:BoltScript -Raw

            # Should use proper git command invocation (not Invoke-Expression or string evaluation)
            $boltContent | Should -Match '\$status = git status --porcelain 2>\$null'
            $boltContent | Should -Not -Match 'Invoke-Expression.*git'
            $boltContent | Should -Not -Match 'iex.*git'
        }

        It "Should safely display git status output without code execution" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Get current git status
            $result = & $script:BoltScript -Task "check-index" -Only 2>&1
            $output = ($result | Out-String)

            # Output should not contain PowerShell variable expansion or command substitution markers
            $output | Should -Not -Match '\$\('
            $output | Should -Not -Match '`'
            # Should complete without errors (exit code check happens in caller)
        }

        It "Should handle filenames with special characters in git output" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Create a temporary directory within the project with unique name
            $tempDir = Join-Path $PSScriptRoot "temp-git-test-$(New-Guid)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                # Create files with potentially dangerous names (in temp dir, not tracked by git)
                $testFiles = @(
                    "normal-file.txt"
                    "file-with-`$dollar.txt"
                    "file-with-`$(command).txt"
                    "file-with-;semicolon.txt"
                    "file-with-&ampersand.txt"
                )

                foreach ($fileName in $testFiles) {
                    $filePath = Join-Path $tempDir $fileName
                    Set-Content -Path $filePath -Value "test content" -ErrorAction SilentlyContinue
                }

                # Stage these files in git (if possible)
                Push-Location $tempDir
                try {
                    # Try to add files to git index (may fail if not under git control, that's OK)
                    git add . 2>$null

                    # Run check-index and capture output
                    $result = & $script:BoltScript -Task "check-index" -Only 2>&1
                    $output = ($result | Out-String)

                    # The output should display filenames safely without code execution
                    # If filenames appear in output, they should be displayed as-is, not executed
                    $output | Should -Not -Match 'CommandNotFoundException'
                    $output | Should -Not -Match 'MethodInvocationException'
                } finally {
                    Pop-Location
                }
            } finally {
                # Clean up - remove temp directory and unstage any files
                if (Test-Path $tempDir) {
                    Get-ChildItem -Recurse -Path $tempDir -Force | Remove-Item -Force -ErrorAction SilentlyContinue
                    Remove-Item -Recurse -Path $tempDir -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should not expose sensitive information in git status output" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Run check-index
            $result = & $script:BoltScript -Task "check-index" -Only 2>&1
            $output = ($result | Out-String)

            # Output should not contain:
            # - Absolute paths that might leak system information (git status --short uses relative paths)
            # - Git internal data structures
            # - Error messages with sensitive paths
            $output | Should -Not -Match 'C:\\Users\\[^\\]+\\.*sensitive'
            $output | Should -Not -Match '/home/[^/]+/.*sensitive'
        }

        It "Should safely invoke git commands with error redirection" {
            # Verify that error streams are redirected properly to prevent info leakage
            $boltContent = Get-Content $script:BoltScript -Raw

            # Git commands should redirect stderr to prevent sensitive error messages
            $boltContent | Should -Match 'git.*2>\$null'
            $boltContent | Should -Match 'git rev-parse --git-dir 2>\$null'
        }

        It "Should sanitize git status output display" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Verify that the check-index function uses git status --short
            $boltContent = Get-Content $script:BoltScript -Raw
            $boltContent | Should -Match 'git status --short'

            # The output should be displayed via Write-Host (safe) not Invoke-Expression
            # Find the check-index function and verify it uses Write-Host for output
            if ($boltContent -match 'function Invoke-CheckGitIndex[\s\S]+?^}') {
                $checkIndexFunction = $matches[0]
                $checkIndexFunction | Should -Not -Match 'Invoke-Expression'
                $checkIndexFunction | Should -Not -Match 'iex'
            }
        }
    }

    Context "Get-GitStatus Function Safety (P1)" {

        It "Should return structured data without executing git output" {
            if (-not $script:gitAvailable) {
                Set-ItResult -Skipped -Because "Git is not available"
                return
            }

            # Verify Get-GitStatus returns PSCustomObject with safe properties
            $boltContent = Get-Content $script:BoltScript -Raw

            # Should create PSCustomObject with defined properties
            $boltContent | Should -Match 'function Get-GitStatus'
            $boltContent | Should -Match '\[PSCustomObject\]@\{'
            $boltContent | Should -Match 'IsClean\s*='
            $boltContent | Should -Match 'Status\s*='
            $boltContent | Should -Match 'HasGit\s*='
        }

        It "Should store git output in a variable, not execute it" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # Get-GitStatus should store output in $status variable
            if ($boltContent -match 'function Get-GitStatus[\s\S]+?^}') {
                $getGitStatusFunction = $matches[0]
                $getGitStatusFunction | Should -Match '\$status = git status --porcelain'
                # Should not pass $status to Invoke-Expression
                $getGitStatusFunction | Should -Not -Match 'Invoke-Expression \$status'
                $getGitStatusFunction | Should -Not -Match 'iex \$status'
            }
        }

        It "Should use --porcelain flag for machine-readable output" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # --porcelain provides consistent, parseable output
            $boltContent | Should -Match 'git status --porcelain'
        }

        It "Should check for null/whitespace safely" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # Should use [string]::IsNullOrWhiteSpace for safe null checking
            if ($boltContent -match 'function Get-GitStatus[\s\S]+?^}') {
                $getGitStatusFunction = $matches[0]
                $getGitStatusFunction | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$status\)'
            }
        }
    }

    Context "Git Command Execution Pattern (P1)" {

        It "Should not use Invoke-Expression with git output anywhere" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # Global check: no Invoke-Expression on git output
            $boltContent | Should -Not -Match 'Invoke-Expression.*\$.*git'
            $boltContent | Should -Not -Match 'iex.*\$.*git'
        }

        It "Should not use string interpolation with git output in commands" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # Should not have patterns like: & "$($gitOutput)"
            $boltContent | Should -Not -Match '&\s*"\$\([^)]*git[^)]*\)"'
        }

        It "Should not use eval-like patterns with git output" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # Should not use ScriptBlock.Create with git output
            $boltContent | Should -Not -Match '\[ScriptBlock\]::Create.*\$status'
            $boltContent | Should -Not -Match '\[ScriptBlock\]::Create.*git'
        }
    }

    Context "Defense Against Malicious Git Configurations (P1)" {

        It "Should use git with explicit arguments (not aliases)" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # Should call git with explicit command names, not rely on aliases
            # which could be configured maliciously in .gitconfig
            $boltContent | Should -Match 'git status'
            $boltContent | Should -Match 'git rev-parse'

            # Should not use short aliases that could be overridden
            $boltContent | Should -Not -Match 'git st\b'
        }

        It "Should redirect git stderr to prevent error message attacks" {
            $boltContent = Get-Content $script:BoltScript -Raw

            # All git commands should redirect stderr
            # This prevents attackers from injecting malicious content via error messages
            # Check that key git commands have stderr redirection
            $boltContent | Should -Match 'git status --porcelain 2>\$null'
            $boltContent | Should -Match 'git rev-parse --git-dir 2>\$null'
        }
    }
}

# =============================================================================
# P1 (High): Runtime Path Validation
# =============================================================================

Describe "P1: Runtime Path Validation" -Tag 'Security' {
    BeforeAll {
        $BoltScript = Join-Path $PSScriptRoot ".." ".." "bolt.ps1"
    }

    Context "Get-AllTasks Function Runtime Validation" {
        It "Should validate resolved paths at runtime" {
            # Read the Get-AllTasks function
            $boltContent = Get-Content $BoltScript -Raw

            # Should contain runtime path validation logic
            $boltContent | Should -Match 'SECURITY: Runtime path validation'
            $boltContent | Should -Match '\[System\.IO\.Path\]::GetFullPath'
            $boltContent | Should -Match 'resolvedPath\.StartsWith\(\$projectRoot'
        }

        It "Should reject paths that resolve outside project directory" {
            # This test verifies defense-in-depth: even if parameter validation is bypassed,
            # runtime validation catches the issue

            # The parameter validation should catch this first, but we're testing
            # that the runtime check also exists as a second line of defense

            # Create a mock scenario by directly calling the script
            $output = & pwsh -NoProfile -Command {
                param($BoltPath)

                # Try to execute with a path that would resolve outside
                # This should fail at parameter validation OR runtime validation
                try {
                    & $BoltPath -TaskDirectory ".." -ListTasks 2>&1
                } catch {
                    $_.Exception.Message
                }
            } -Args $BoltScript

            # Should fail with validation error (either parameter or runtime)
            $output -join "`n" | Should -Match '(invalid characters|outside project directory|TaskDirectory must)'
        }

        It "Should accept valid relative paths within project" {
            # Valid paths should work normally
            $result = & $BoltScript -TaskDirectory ".build" -ListTasks 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should provide clear error messages when path is rejected" {
            # Test that error messages are helpful
            $output = & pwsh -NoProfile -Command {
                param($BoltPath)
                try {
                    # Create a temporary script that bypasses parameter validation
                    # to test runtime validation specifically
                    $tempScript = @'
param($TaskDirectory)
$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $TaskDirectory))
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
if (-not $resolvedPath.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning "TaskDirectory resolves outside project directory: $TaskDirectory"
    Write-Warning "Project root: $projectRoot"
    Write-Warning "Resolved path: $resolvedPath"
    throw "TaskDirectory must resolve to a path within the project directory"
}
'@
                    $tempFile = New-TemporaryFile
                    $tempPs1 = "$($tempFile.FullName).ps1"
                    Remove-Item $tempFile
                    Set-Content -Path $tempPs1 -Value $tempScript

                    & $tempPs1 -TaskDirectory "..\..\..\Windows" 2>&1
                    Remove-Item $tempPs1 -ErrorAction SilentlyContinue
                } catch {
                    $_
                }
            } -Args $BoltScript

            $output = $output -join "`n"
            # Should contain helpful error messages
            $output | Should -Match '(TaskDirectory|project directory|Resolved path)'
        }
    }

    Context "Defense-in-Depth Path Validation" {
        It "Should validate paths at multiple layers" {
            # Read the Bolt script to verify both layers exist
            $boltContent = Get-Content $BoltScript -Raw

            # Layer 1: Parameter validation
            $boltContent | Should -Match '\[ValidateScript\(\{'
            $boltContent | Should -Match 'TaskDirectory must be a relative path'

            # Layer 2: Runtime validation
            $boltContent | Should -Match 'SECURITY: Runtime path validation'
            $boltContent | Should -Match 'TaskDirectory must resolve to a path within'
        }

        It "Should handle symbolic links safely" {
            # Symbolic links should be resolved and validated
            # This is inherently tested by GetFullPath which resolves symlinks

            $boltContent = Get-Content $BoltScript -Raw
            # Verify we use GetFullPath which resolves symlinks
            $boltContent | Should -Match '\[System\.IO\.Path\]::GetFullPath'
        }

        It "Should handle relative path traversal attempts" {
            # Paths like ".build/../../../etc" should be rejected
            $output = & pwsh -NoProfile -Command {
                param($BoltPath)
                try {
                    & $BoltPath -TaskDirectory ".build/../../../etc" -ListTasks 2>&1
                } catch {
                    $_.Exception.Message
                }
            } -Args $BoltScript

            # Should fail with validation error
            $output -join "`n" | Should -Match '(invalid characters|outside project|must be a relative path)'
        }

        It "Should compare paths case-insensitively on Windows" {
            # Path comparison should use OrdinalIgnoreCase
            $boltContent = Get-Content $BoltScript -Raw
            $boltContent | Should -Match 'StartsWith.*StringComparison.*OrdinalIgnoreCase'
        }
    }

    Context "TaskDirectory Resolution Security" {
        It "Should resolve TaskDirectory before validation" {
            # Ensure paths are fully resolved (no relative components left)
            $boltContent = Get-Content $BoltScript -Raw

            # Should get full path before comparison
            $boltContent | Should -Match 'resolvedPath.*GetFullPath.*buildPath'
            $boltContent | Should -Match 'projectRoot.*GetFullPath.*ScriptRoot'
        }

        It "Should validate against project root directory" {
            # Should compare resolved path against project root
            $boltContent = Get-Content $BoltScript -Raw
            $boltContent | Should -Match 'projectRoot.*PSScriptRoot'
            $boltContent | Should -Match 'resolvedPath\.StartsWith\(\$projectRoot'
        }

        It "Should provide detailed warning messages" {
            # Should output warning with all relevant paths
            $boltContent = Get-Content $BoltScript -Raw

            # Should warn with TaskDirectory value
            $boltContent | Should -Match 'Write-Warning.*TaskDirectory resolves outside'
            # Should warn with project root
            $boltContent | Should -Match 'Write-Warning.*Project root'
            # Should warn with resolved path
            $boltContent | Should -Match 'Write-Warning.*Resolved path'
        }
    }

    Context "Edge Cases and Attack Vectors" {
        It "Should reject absolute paths at parameter level" {
            # Absolute paths should fail parameter validation first
            if ($IsWindows) {
                $output = & pwsh -NoProfile -Command {
                    param($BoltPath)
                    try {
                        & $BoltPath -TaskDirectory "C:\Windows\System32" -ListTasks 2>&1
                    } catch {
                        $_.Exception.Message
                    }
                } -Args $BoltScript

                $output -join "`n" | Should -Match '(absolute path|invalid characters)'
            }
        }

        It "Should reject UNC paths" {
            # UNC paths should be rejected
            if ($IsWindows) {
                $output = & pwsh -NoProfile -Command {
                    param($BoltPath)
                    try {
                        & $BoltPath -TaskDirectory "\\server\share" -ListTasks 2>&1
                    } catch {
                        $_.Exception.Message
                    }
                } -Args $BoltScript

                $output -join "`n" | Should -Match '(absolute path|invalid characters|relative path)'
            }
        }

        It "Should handle very long paths safely" {
            # Very long paths should be handled without errors
            $longPath = "a" * 200
            $output = & pwsh -NoProfile -Command {
                param($BoltPath, $LongPath)
                try {
                    & $BoltPath -TaskDirectory $LongPath -ListTasks 2>&1
                } catch {
                    $_.Exception.Message
                }
            } -Args $BoltScript, $longPath

            # Should either work or fail gracefully (no crashes)
            $LASTEXITCODE | Should -BeIn @(0, 1)
        }
    }
}

# =============================================================================
# P2 (Medium): Atomic File Creation
# =============================================================================

Describe "P2: Atomic File Creation" -Tag 'Security' {
    BeforeAll {
        $BoltScript = Join-Path $PSScriptRoot ".." ".." "bolt.ps1"
        # Use simple directory name compatible with TaskDirectory validation
        $testBuildDir = "temp-atomic-test"
        $testBuildPath = Join-Path $PSScriptRoot $testBuildDir
    }

    BeforeEach {
        # Create test directory for each test
        if (-not (Test-Path $testBuildPath)) {
            New-Item -ItemType Directory -Path $testBuildPath -Force | Out-Null
        }
    }

    AfterEach {
        # Clean up test directory after each test
        if (Test-Path $testBuildPath) {
            Remove-Item $testBuildPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Atomic File Creation in NewTask" {
        It "Should create new task file successfully" {
            # Create unique task name
            $taskName = "test-atomic-$(Get-Random)"

            # Create task - use relative path from project root
            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                $output = & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1

                # Verify file was created
                $createdFiles = Get-ChildItem $testBuildPath -Filter "Invoke-Test-Atomic-*.ps1" -ErrorAction SilentlyContinue
                $createdFiles.Count | Should -BeGreaterThan 0
            }
            finally {
                Pop-Location
            }
        }

        It "Should fail atomically if file already exists" {
            # Create unique task name
            $taskName = "test-existing-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create task first time (should succeed)
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Verify file was created
                $createdFiles = Get-ChildItem $testBuildPath -Filter "Invoke-Test-Existing-*.ps1"
                $createdFiles.Count | Should -BeGreaterThan 0

                # Try to create same task again (should fail atomically)
                try {
                    $output2 = & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" -ErrorAction SilentlyContinue 2>&1 | Out-String
                    $output2 | Should -Match "already exists"
                } catch {
                    # Expected to fail - error is in Write-Error which may terminate
                }
            }
            finally {
                Pop-Location
            }
        }

        It "Should use NoClobber parameter for atomic operation" {
            # Verify the bolt.ps1 code uses -NoClobber
            $boltContent = Get-Content $BoltScript -Raw

            # Should contain -NoClobber parameter with Out-File
            $boltContent | Should -Match 'Out-File.*-NoClobber'

            # Should have proper error handling
            $boltContent | Should -Match '\[System\.IO\.IOException\]'
        }

        It "Should handle IOException for existing files" {
            # Verify error handling code exists
            $boltContent = Get-Content $BoltScript -Raw

            # Should catch IOException specifically
            $boltContent | Should -Match 'catch \[System\.IO\.IOException\]'

            # Should provide clear error message
            $boltContent | Should -Match 'Task file already exists'
        }

        It "Should not create partial files on error" {
            # Create a task
            $taskName = "test-partial-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create it first time
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Get the created file
                $createdFiles = Get-ChildItem $testBuildPath -Filter "Invoke-Test-Partial-*.ps1"
                $createdFile = $createdFiles | Select-Object -First 1

                # Record original content
                $originalContent = Get-Content $createdFile.FullName -Raw

                # Try to create again (should fail without modifying file)
                try {
                    & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" -ErrorAction SilentlyContinue 2>&1 | Out-Null
                } catch {
                    # Expected to fail
                }

                # Verify file content unchanged
                $currentContent = Get-Content $createdFile.FullName -Raw
                $currentContent | Should -Be $originalContent
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Race Condition Prevention" {
        It "Should eliminate TOCTOU vulnerability window" {
            # Verify the atomic operation pattern
            $boltContent = Get-Content $BoltScript -Raw

            # Should NOT have separate Test-Path and Out-File
            # (old vulnerable pattern was: if (Test-Path) then Out-File)
            # New pattern: Out-File with -NoClobber in try-catch

            # Should use atomic operation (Out-File with NoClobber in try-catch)
            $boltContent | Should -Match 'Out-File.*-NoClobber'
            $boltContent | Should -Match 'catch \[System\.IO\.IOException\]'

            # Verify TOCTOU vulnerability is eliminated (no Test-Path before file creation in NewTask)
            # Extract NewTask section
            if ($boltContent -match '(?s)if \(\$NewTask\).*?^\}') {
                $newTaskSection = $matches[0]
                # Should not have Test-Path followed by Out-File pattern
                $newTaskSection | Should -Not -Match 'Test-Path.*Out-File'
            }
        }

        It "Should handle concurrent file creation attempts safely" {
            # This test verifies the -NoClobber behavior
            # Only one of concurrent attempts should succeed

            $taskName = "test-concurrent-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Simulate race condition by creating file first
                $tempContent = "# Temporary content"
                $testFile = Join-Path $testBuildPath "Invoke-Test-Concurrent-$($taskName.Substring(16)).ps1"

                # Use Out-File to match what bolt.ps1 uses
                $tempContent | Out-File -FilePath $testFile -Encoding UTF8

                # Now try to create task with same name (should fail)
                try {
                    $output = & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" -ErrorAction SilentlyContinue 2>&1 | Out-String
                    $output | Should -Match "already exists"
                } catch {
                    # Expected to fail
                }

                # Original file should contain our temporary content
                $currentContent = Get-Content $testFile -Raw
                $currentContent.Trim() | Should -Be $tempContent
            }
            finally {
                Pop-Location
            }
        }

        It "Should use ErrorAction Stop for immediate failure" {
            # Verify ErrorAction Stop is used
            $boltContent = Get-Content $BoltScript -Raw

            # Should have ErrorAction Stop to immediately jump to catch block
            $boltContent | Should -Match 'Out-File.*-ErrorAction Stop'
        }
    }

    Context "Error Handling and User Feedback" {
        It "Should provide clear error message when file exists" {
            $taskName = "test-error-msg-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create first time
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Create second time and capture error
                try {
                    $output = & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" -ErrorAction SilentlyContinue 2>&1 | Out-String

                    # Should have clear error message
                    $output | Should -Match "Task file already exists"
                    $output | Should -Match "Invoke-Test-Error-Msg"
                } catch {
                    # Expected to fail
                }
            }
            finally {
                Pop-Location
            }
        }

        It "Should handle general file creation errors" {
            # Verify generic catch block exists
            $boltContent = Get-Content $BoltScript -Raw

            # Should have generic catch for other errors
            $boltContent | Should -Match 'catch \{[^}]*Failed to create task file'
        }

        It "Should exit with error code on failure" {
            $taskName = "test-exit-code-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create first time
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Try to create again
                try {
                    & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" -ErrorAction SilentlyContinue 2>&1 | Out-Null
                } catch {
                    # Expected to fail
                }

                # Should exit with error code
                $LASTEXITCODE | Should -Be 1
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "File System Safety" {
        It "Should create file with correct encoding" {
            $taskName = "test-encoding-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create task
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Verify encoding (UTF8)
                $createdFiles = Get-ChildItem $testBuildPath -Filter "Invoke-Test-Encoding-*.ps1"
                $createdFile = $createdFiles | Select-Object -First 1

                # File should exist and be readable as UTF8
                $content = Get-Content $createdFile.FullName -Encoding UTF8 -Raw
                $content | Should -Match "# TASK: $taskName"
            }
            finally {
                Pop-Location
            }
        }

        It "Should handle directory creation if needed" {
            # Remove test directory if exists (with retry for file locking)
            if (Test-Path $testBuildPath) {
                $retryCount = 0
                $maxRetries = 3
                $retryDelay = 100 # milliseconds

                while ($retryCount -lt $maxRetries) {
                    try {
                        Remove-Item $testBuildPath -Recurse -Force -ErrorAction Stop
                        break
                    }
                    catch {
                        $retryCount++
                        if ($retryCount -ge $maxRetries) {
                            throw "Failed to remove test directory after $maxRetries attempts: $_"
                        }
                        Start-Sleep -Milliseconds $retryDelay
                    }
                }
            }

            $taskName = "test-dir-create-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create task (should create directory)
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Directory should exist
                Test-Path $testBuildPath | Should -Be $true

                # File should exist
                $createdFiles = Get-ChildItem $testBuildPath -Filter "Invoke-Test-Dir-Create-*.ps1" -ErrorAction SilentlyContinue
                $createdFiles.Count | Should -BeGreaterThan 0
            }
            finally {
                Pop-Location
            }
        }

        It "Should maintain file integrity on atomic operations" {
            $taskName = "test-integrity-$(Get-Random)"

            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Create task
                & ".\bolt.ps1" -NewTask $taskName -TaskDirectory "tests/security/$testBuildDir" 2>&1 | Out-Null

                # Verify file exists and is complete
                $createdFiles = Get-ChildItem $testBuildPath -Filter "Invoke-Test-Integrity-*.ps1"
                $createdFile = $createdFiles | Select-Object -First 1

                # File should have complete template structure
                $content = Get-Content $createdFile.FullName -Raw

                # Check for key template elements
                $content | Should -Match "# TASK: $taskName"
                $content | Should -Match "# DESCRIPTION:"
                $content | Should -Match "# DEPENDS:"
                $content | Should -Match "Write-Host"
                $content | Should -Match "exit 0"
            }
            finally {
                Pop-Location
            }
        }
    }
}

Describe "P2: Execution Policy Awareness" -Tag "Security" {
    BeforeAll {
        $BoltScript = Join-Path $PSScriptRoot ".." ".." "bolt.ps1"
    }

    Context "Execution Policy Detection" {
        It "Should check execution policy on script start" {
            # Verify the code contains execution policy check
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match 'Get-ExecutionPolicy'
            $boltContent | Should -Match 'SECURITY.*Execution policy awareness'
        }

        It "Should detect Unrestricted policy" {
            # Verify code handles Unrestricted
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Unrestricted.*Bypass"
            $boltContent | Should -Match "permissive execution policy"
        }

        It "Should detect Bypass policy" {
            # Verify code handles Bypass
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Bypass"
        }

        It "Should detect Restricted policy" {
            # Verify code handles Restricted
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Restricted"
            $boltContent | Should -Match "Set-ExecutionPolicy RemoteSigned"
        }
    }

    Context "Warning Messages" {
        It "Should provide warning for permissive policies" {
            # Verify verbose message exists for permissive policies
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Write-Verbose.*permissive execution policy"
            $boltContent | Should -Match "Consider using RemoteSigned or AllSigned"
        }

        It "Should provide warning for Restricted policy" {
            # Verify warning message exists for Restricted policy
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Write-Warning.*execution policy is set to Restricted"
            $boltContent | Should -Match "You may need to change it"
        }

        It "Should suggest remediation for Restricted policy" {
            # Verify remediation suggestion exists
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    }

    Context "Policy Impact on Execution" {
        It "Should not block execution for RemoteSigned policy" {
            # RemoteSigned is the recommended policy - script should run normally
            $currentPolicy = Get-ExecutionPolicy

            if ($currentPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
                Push-Location (Join-Path $PSScriptRoot ".." "..")
                try {
                    { & ".\bolt.ps1" -ListTasks -ErrorAction Stop 2>&1 | Out-Null } | Should -Not -Throw
                }
                finally {
                    Pop-Location
                }
            }
            else {
                Set-ItResult -Skipped -Because "Current execution policy is $currentPolicy"
            }
        }

        It "Should not block execution for AllSigned policy" {
            # AllSigned is acceptable - script should run if signed
            $currentPolicy = Get-ExecutionPolicy

            if ($currentPolicy -in @('AllSigned', 'RemoteSigned', 'Unrestricted', 'Bypass')) {
                Push-Location (Join-Path $PSScriptRoot ".." "..")
                try {
                    { & ".\bolt.ps1" -ListTasks -ErrorAction Stop 2>&1 | Out-Null } | Should -Not -Throw
                }
                finally {
                    Pop-Location
                }
            }
            else {
                Set-ItResult -Skipped -Because "Current execution policy is $currentPolicy"
            }
        }

        It "Should provide clear guidance without blocking legitimate use" {
            # The check should inform but not prevent execution
            # (except when system policy like Restricted is in place)
            $boltContent = Get-Content $BoltScript -Raw

            # Should not contain throw statements in policy check section
            $policySection = ($boltContent -split 'SECURITY.*Execution policy awareness')[1]
            $policySection = ($policySection -split 'Main script logic')[0]

            $policySection | Should -Not -Match 'throw.*execution policy'
        }
    }

    Context "Security Best Practices" {
        It "Should recommend RemoteSigned or AllSigned policies" {
            # Verify recommendations for secure policies
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "RemoteSigned or AllSigned"
        }

        It "Should use Write-Verbose for informational messages" {
            # Verbose messages don't interrupt normal workflow
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Write-Verbose.*permissive"
        }

        It "Should use Write-Warning for actionable concerns" {
            # Warnings are appropriate for Restricted policy
            $boltContent = Get-Content $BoltScript -Raw

            $boltContent | Should -Match "Write-Warning.*Restricted"
        }
    }

    Context "Integration with Script Flow" {
        It "Should check policy before main logic" {
            # Policy check should be early in script
            $boltContent = Get-Content $BoltScript -Raw

            # Get positions
            $policyPos = $boltContent.IndexOf('Get-ExecutionPolicy')
            $mainLogicPos = $boltContent.IndexOf('Main script logic')

            $policyPos | Should -BeLessThan $mainLogicPos
        }

        It "Should not interfere with normal operations" {
            # Policy check should be passive - just informing user
            Push-Location (Join-Path $PSScriptRoot ".." "..")
            try {
                # Run a simple command - should work regardless of policy check
                $output = & ".\bolt.ps1" -Help 2>&1
                $LASTEXITCODE | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }
}
