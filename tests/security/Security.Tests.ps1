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
            # Use a temporary directory within the project
            $tempDir = Join-Path $PSScriptRoot "temp-newtask-test"
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force
            }
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                # Change to project root so relative path works
                Push-Location (Join-Path $PSScriptRoot ".." "..")

                $relativePath = "tests/security/temp-newtask-test"
                $result = Invoke-Gosh -Parameters @{
                    NewTask = "my-valid-task"
                    TaskDirectory = $relativePath
                }

                # Should successfully create the task
                $expectedFile = Join-Path $tempDir "Invoke-My-Valid-Task.ps1"
                $expectedFile | Should -Exist
            } finally {
                Pop-Location
                if (Test-Path $tempDir) {
                    Start-Sleep -Milliseconds 100  # Allow file handles to close
                    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context "Task Name Validation from Task Files" {

        BeforeAll {
            # Create temp directory within project for relative path testing
            $tempTaskDir = Join-Path $PSScriptRoot "temp-task-validation"
            if (Test-Path $tempTaskDir) {
                Remove-Item $tempTaskDir -Recurse -Force
            }
            New-Item -ItemType Directory -Path $tempTaskDir -Force | Out-Null
        }

        AfterAll {
            # Clean up temp directory
            if (Test-Path $tempTaskDir) {
                Start-Sleep -Milliseconds 100  # Allow file handles to close
                Remove-Item $tempTaskDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Should warn about invalid task names in task files" {
            $invalidTaskFile = Join-Path $tempTaskDir "Invoke-InvalidTask.ps1"
            Set-Content -Path $invalidTaskFile -Value @"
# TASK: valid-task, INVALID-CAPS, another
# DESCRIPTION: Test task with mixed validity
Write-Host "Test"
exit 0
"@

            # Use relative path from script root
            $relativeTaskDir = "tests/security/temp-task-validation"

            # Capture all output streams including warnings (3>&1 redirects warnings to stdout)
            $allOutput = & $GoshScript -TaskDirectory $relativeTaskDir -ListTasks 3>&1 2>&1 | Out-String

            # Should generate warnings for invalid names
            $allOutput | Should -Match "Invalid task name format.*INVALID-CAPS"
        }

        It "Should accept only valid task names from task files" {
            $mixedTaskFile = Join-Path $tempTaskDir "Invoke-MixedTask.ps1"
            Set-Content -Path $mixedTaskFile -Value @"
# TASK: good-task, BadTask, another-good-one
# DESCRIPTION: Mix of valid and invalid
Write-Host "Test"
exit 0
"@

            $relativeTaskDir = "tests/security/temp-task-validation"

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
            $longNameFile = Join-Path $tempTaskDir "Invoke-LongName.ps1"
            $longName = "a" * 51
            Set-Content -Path $longNameFile -Value @"
# TASK: $longName
# DESCRIPTION: Task with too-long name
Write-Host "Test"
exit 0
"@

            $relativeTaskDir = "tests/security/temp-task-validation"

            # Capture all output streams (3>&1 redirects warnings to stdout)
            $allOutput = & $GoshScript -TaskDirectory $relativeTaskDir -ListTasks 3>&1 2>&1 | Out-String

            $allOutput | Should -Match "Task name too long"
        }
    }
}
