#Requires -Version 7.0

<#
.SYNOPSIS
    Security tests for Gosh build system.

.DESCRIPTION
    Tests for security vulnerabilities and input validation in gosh.ps1.
    Covers P0 security fixes: TaskDirectory validation and Path sanitization.
#>

BeforeAll {
    $GoshScript = Join-Path $PSScriptRoot ".." ".." "gosh.ps1"

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

    # Helper function to invoke Gosh with parameters
    function Invoke-Gosh {
        param(
            [string[]]$Tasks = @(),
            [hashtable]$Parameters = @{}
        )

        # Build splatting hashtable for proper parameter binding
        $goshParams = @{}

        # Add tasks if provided
        if ($Tasks.Count -gt 0) {
            $goshParams['Task'] = $Tasks
        }

        # Merge additional parameters
        foreach ($key in $Parameters.Keys) {
            $goshParams[$key] = $Parameters[$key]
        }

        # Use splatting for proper PowerShell parameter binding
        try {
            $output = & $GoshScript @goshParams 2>&1
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
            $result = Invoke-Gosh -Parameters @{
                TaskDirectory = "tests-fixtures"
                ListTasks = $true
            }
            # Should not throw validation error about TaskDirectory format
            $result.Output -join "" | Should -Not -Match "TaskDirectory.*invalid"
        }

        It "Should accept valid directory names with dashes" {
            $result = Invoke-Gosh -Parameters @{
                TaskDirectory = "build-tasks"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "TaskDirectory.*invalid"
        }

        It "Should accept valid directory names with underscores" {
            $result = Invoke-Gosh -Parameters @{
                TaskDirectory = "build_tasks"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "TaskDirectory.*invalid"
        }

        It "Should reject path traversal attempts with .." {
            # Call gosh.ps1 directly to catch parameter validation exception
            {
                & $GoshScript -TaskDirectory "../etc" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject absolute paths on Windows" {
            {
                & $GoshScript -TaskDirectory "C:\Windows\System32" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject absolute paths on Unix" {
            {
                & $GoshScript -TaskDirectory "/etc/passwd" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject directory names with special characters" {
            {
                & $GoshScript -TaskDirectory "tasks;rm -rf /" -ListTasks
            } | Should -Throw "*TaskDirectory*"
        }

        It "Should reject directory names with backticks" {
            {
                & $GoshScript -TaskDirectory "tasks`$(Get-Process)" -ListTasks
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

            # Read the gosh.ps1 file and verify path sanitization code exists
            $goshContent = Get-Content $GoshScript -Raw
            $goshContent | Should -Match 'if \(\$scriptPath -match ''\[\`\$\(\);{}\\\[\\\]\|&<>\]''\)'
            $goshContent | Should -Match 'throw "Script path contains potentially dangerous characters'
        }

        It "Should reject script paths outside project directory" {
            # Verify validation code exists for path boundary checks
            $goshContent = Get-Content $GoshScript -Raw
            $goshContent | Should -Match '\$fullScriptPath = \[System\.IO\.Path\]::GetFullPath\(\$scriptPath\)'
            $goshContent | Should -Match 'if \(-not \$fullScriptPath\.StartsWith\(\$projectRoot'
            $goshContent | Should -Match 'throw "Script path is outside project directory'
        }

        It "Should accept valid script paths within project directory" {
            # Test with actual fixtures that should work
            $result = Invoke-Gosh -Tasks @("mock-simple") -Parameters @{
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
            $goshContent = Get-Content $GoshScript -Raw

            # Verify validation happens BEFORE ScriptBlock.Create
            $validationIndex = $goshContent.IndexOf('# SECURITY: Validate script path')
            $scriptBlockIndex = $goshContent.IndexOf('$scriptBlock = [ScriptBlock]::Create($scriptContent)')

            $validationIndex | Should -BeGreaterThan 0
            $scriptBlockIndex | Should -BeGreaterThan 0
            $validationIndex | Should -BeLessThan $scriptBlockIndex
        }
    }

    Context "Combined Security Validation" {

        It "Should protect against path traversal via TaskDirectory and malicious script paths" {
            # This is a defense-in-depth test: even if one validation fails, the other should catch it
            # Call gosh.ps1 directly to catch parameter validation exception
            {
                & $GoshScript -Task "malicious" -TaskDirectory "../../../Windows/System32" -Only
            } | Should -Throw
        }
    }

    Context "Task Name Validation (P0 - Action Item #3)" {

        It "Should accept valid lowercase task names" {
            $result = Invoke-Gosh -Tasks @("build") -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should accept task names with numbers" {
            $result = Invoke-Gosh -Tasks @("test123") -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should accept task names with hyphens" {
            $result = Invoke-Gosh -Tasks @("deploy-prod") -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should reject task names with uppercase letters" {
            {
                & $GoshScript -Task "Build" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with spaces" {
            {
                & $GoshScript -Task "my task" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with semicolons (command injection attempt)" {
            {
                & $GoshScript -Task "test;rm-rf" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with dollar signs (variable expansion attempt)" {
            {
                & $GoshScript -Task "task`$(evil)" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names with backticks (command substitution attempt)" {
            {
                & $GoshScript -Task "task``ls" -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should reject task names that are too long (> 50 chars)" {
            $longTaskName = "a" * 51
            {
                & $GoshScript -Task $longTaskName -ListTasks
            } | Should -Throw "*Task*"
        }

        It "Should accept task names at the maximum length (50 chars)" {
            $maxTaskName = "a" * 50
            $result = Invoke-Gosh -Tasks @($maxTaskName) -Parameters @{
                TaskDirectory = "tests/fixtures"
                ListTasks = $true
            }
            $result.Output -join "" | Should -Not -Match "validation error"
        }

        It "Should validate NewTask parameter format" {
            {
                & $GoshScript -NewTask "Invalid-Task-Name-With-Uppercase"
            } | Should -Throw "*NewTask*"
        }

        It "Should validate NewTask parameter length" {
            $longTaskName = "a" * 51
            {
                & $GoshScript -NewTask $longTaskName
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
                Invoke-Gosh -Parameters @{
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
            $allOutput = & $GoshScript -TaskDirectory $relativeTaskDir -ListTasks 3>&1 2>&1 | Out-String

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
            $output = & $GoshScript -TaskDirectory $relativeTaskDir -ListTasks 6>&1 3>&1 2>&1
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
            $allOutput = & $GoshScript -TaskDirectory $relativeTaskDir -ListTasks 3>&1 2>&1 | Out-String

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

        $script:GoshScript = Join-Path $PSScriptRoot ".." ".." "gosh.ps1"
    }

    Context "Git Status Output Safety (P1 - Git Output Sanitization)" {

        It "Should execute git commands safely without command injection" {
            if (-not $script:gitAvailable) {
                Set-ItResult -Skipped -Because "Git is not available"
                return
            }

            # Verify that git commands in Get-GitStatus use safe execution
            $goshContent = Get-Content $script:GoshScript -Raw

            # Should use proper git command invocation (not Invoke-Expression or string evaluation)
            $goshContent | Should -Match '\$status = git status --porcelain 2>\$null'
            $goshContent | Should -Not -Match 'Invoke-Expression.*git'
            $goshContent | Should -Not -Match 'iex.*git'
        }

        It "Should safely display git status output without code execution" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Get current git status
            $result = & $script:GoshScript -Task "check-index" -Only 2>&1
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
                    $result = & $script:GoshScript -Task "check-index" -Only 2>&1
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
                    Get-ChildItem -Path $tempDir -Force | Remove-Item -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $tempDir -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should not expose sensitive information in git status output" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Run check-index
            $result = & $script:GoshScript -Task "check-index" -Only 2>&1
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
            $goshContent = Get-Content $script:GoshScript -Raw

            # Git commands should redirect stderr to prevent sensitive error messages
            $goshContent | Should -Match 'git.*2>\$null'
            $goshContent | Should -Match 'git rev-parse --git-dir 2>\$null'
        }

        It "Should sanitize git status output display" {
            if (-not $script:gitAvailable -or -not $script:inRepo) {
                Set-ItResult -Skipped -Because "Not in a git repository"
                return
            }

            # Verify that the check-index function uses git status --short
            $goshContent = Get-Content $script:GoshScript -Raw
            $goshContent | Should -Match 'git status --short'

            # The output should be displayed via Write-Host (safe) not Invoke-Expression
            # Find the check-index function and verify it uses Write-Host for output
            if ($goshContent -match 'function Invoke-CheckGitIndex[\s\S]+?^}') {
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
            $goshContent = Get-Content $script:GoshScript -Raw

            # Should create PSCustomObject with defined properties
            $goshContent | Should -Match 'function Get-GitStatus'
            $goshContent | Should -Match '\[PSCustomObject\]@\{'
            $goshContent | Should -Match 'IsClean\s*='
            $goshContent | Should -Match 'Status\s*='
            $goshContent | Should -Match 'HasGit\s*='
        }

        It "Should store git output in a variable, not execute it" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # Get-GitStatus should store output in $status variable
            if ($goshContent -match 'function Get-GitStatus[\s\S]+?^}') {
                $getGitStatusFunction = $matches[0]
                $getGitStatusFunction | Should -Match '\$status = git status --porcelain'
                # Should not pass $status to Invoke-Expression
                $getGitStatusFunction | Should -Not -Match 'Invoke-Expression \$status'
                $getGitStatusFunction | Should -Not -Match 'iex \$status'
            }
        }

        It "Should use --porcelain flag for machine-readable output" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # --porcelain provides consistent, parseable output
            $goshContent | Should -Match 'git status --porcelain'
        }

        It "Should check for null/whitespace safely" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # Should use [string]::IsNullOrWhiteSpace for safe null checking
            if ($goshContent -match 'function Get-GitStatus[\s\S]+?^}') {
                $getGitStatusFunction = $matches[0]
                $getGitStatusFunction | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$status\)'
            }
        }
    }

    Context "Git Command Execution Pattern (P1)" {

        It "Should not use Invoke-Expression with git output anywhere" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # Global check: no Invoke-Expression on git output
            $goshContent | Should -Not -Match 'Invoke-Expression.*\$.*git'
            $goshContent | Should -Not -Match 'iex.*\$.*git'
        }

        It "Should not use string interpolation with git output in commands" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # Should not have patterns like: & "$($gitOutput)"
            $goshContent | Should -Not -Match '&\s*"\$\([^)]*git[^)]*\)"'
        }

        It "Should not use eval-like patterns with git output" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # Should not use ScriptBlock.Create with git output
            $goshContent | Should -Not -Match '\[ScriptBlock\]::Create.*\$status'
            $goshContent | Should -Not -Match '\[ScriptBlock\]::Create.*git'
        }
    }

    Context "Defense Against Malicious Git Configurations (P1)" {

        It "Should use git with explicit arguments (not aliases)" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # Should call git with explicit command names, not rely on aliases
            # which could be configured maliciously in .gitconfig
            $goshContent | Should -Match 'git status'
            $goshContent | Should -Match 'git rev-parse'

            # Should not use short aliases that could be overridden
            $goshContent | Should -Not -Match 'git st\b'
        }

        It "Should redirect git stderr to prevent error message attacks" {
            $goshContent = Get-Content $script:GoshScript -Raw

            # All git commands should redirect stderr
            # This prevents attackers from injecting malicious content via error messages
            # Check that key git commands have stderr redirection
            $goshContent | Should -Match 'git status --porcelain 2>\$null'
            $goshContent | Should -Match 'git rev-parse --git-dir 2>\$null'
        }
    }
}
