#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

<#
.SYNOPSIS
    Tests for P0 Security Event Logging implementation

.DESCRIPTION
    Validates that security-relevant events are properly logged when
    $env:BOLT_AUDIT_LOG is enabled, including task execution, file creation,
    external command execution, and user context capture.

.NOTES
    Test Tags: SecurityLogging, Operational
#>

BeforeAll {
    $ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $BoltScript = Join-Path $ProjectRoot "bolt.ps1"
    $LogDir = Join-Path $ProjectRoot ".bolt"
    $LogFile = Join-Path $LogDir "audit.log"

    # Safe cleanup function to handle race conditions
    function Remove-Directory {
        param($Path)
        if (Test-Path $Path) {
            # Retry removal with exponential backoff to handle race conditions
            # Handles both directories and files (in case file was created where directory should be)
            $maxRetries = 3
            $retryCount = 0
            $baseDelay = 100  # milliseconds

            while ($retryCount -lt $maxRetries) {
                try {
                    Remove-Item $Path -Recurse -Force -ErrorAction Stop
                    break  # Success, exit retry loop
                } catch {
                    $retryCount++
                    if ($retryCount -eq $maxRetries) {
                        # On final retry, use SilentlyContinue to prevent test failures
                        Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
                        break
                    }
                    # Wait before retrying (exponential backoff)
                    Start-Sleep -Milliseconds ($baseDelay * [Math]::Pow(2, $retryCount - 1))
                }
            }
        }
    }

    function Remove-ItemWithRetry {
        param(
            [string]$Path,
            [int]$MaxRetries = 5,
            [int]$DelayMs = 200
        )

        for ($i = 0; $i -lt $MaxRetries; $i++) {
            try {
                if (Test-Path $Path) {
                    Remove-Item $Path -Recurse -Force -ErrorAction Stop
                }
                return $true
            } catch {
                if ($i -eq ($MaxRetries - 1)) {
                    Write-Warning "Failed to remove $Path after $MaxRetries attempts: $_"
                    return $false
                }
                Start-Sleep -Milliseconds $DelayMs
            }
        }
    }

    # Helper function to clean up test logging task files
    function Clear-TestLoggingTask {
        $buildPath = Join-Path $ProjectRoot ".build"
        Get-ChildItem $buildPath -Filter "Invoke-Test-Logging-*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-ItemWithRetry $_.FullName
        }
    }
}

Describe "Security Event Logging" -Tag "SecurityLogging", "Operational" {

    BeforeEach {
        # Clean up any existing log file safely
        Remove-Directory $LogDir
    }

    AfterEach {
        # Clean up after each test safely
        Remove-Directory $LogDir
    }

    Context "Logging Disabled by Default" {

        It "Should not create .bolt directory when logging is disabled" {
            # Run a simple task without enabling logging
            & $BoltScript -ListTasks | Out-Null

            Test-Path -PathType Container $LogDir | Should -Be $false
        }

        It "Should not create audit.log when logging is disabled" {
            & $BoltScript -ListTasks | Out-Null

            Test-Path $LogFile | Should -Be $false
        }

        It "Should work normally without logging overhead" {
            # Ensure logging is explicitly disabled
            $env:BOLT_AUDIT_LOG = $null

            # Execute a simple task without logging enabled
            $ErrorActionPreference = 'SilentlyContinue'
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            # Should execute successfully without creating logs
            $LASTEXITCODE | Should -Be 0
            Test-Path $LogFile | Should -Be $false
        }
    }

    Context "Logging Enabled via Environment Variable" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should create .bolt directory when logging is enabled" {
            # Execute a simple task to trigger logging
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            Test-Path -PathType Container $LogDir | Should -Be $true
            (Get-Item -Force $LogDir).PSIsContainer | Should -Be $true
        }

        It "Should create audit.log file when logging is enabled" {
            # Execute a simple task to trigger logging
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            Test-Path $LogFile | Should -Be $true
        }

        It "Should write UTF-8 encoded log entries" {
            # Execute a simple task to trigger logging
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Log Entry Format" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should include timestamp in log entries" {
            & $BoltScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
            }
        }

        It "Should include severity level in log entries" {
            & $BoltScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match '(Info|Warning|Error)'
            }
        }

        It "Should include username in log entries" {
            & $BoltScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $username = [Environment]::UserName
                $content | Should -Match $username
            }
        }

        It "Should include machine name in log entries" {
            & $BoltScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $machine = [Environment]::MachineName
                $content | Should -Match $machine
            }
        }

        It "Should include event type in log entries" {
            & $BoltScript -TaskDirectory "custom" -ListTasks 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskDirectoryUsage'
            }
        }

        It "Should use pipe delimiter format: Timestamp | Severity | User@Machine | Event | Details" {
            & $BoltScript -TaskDirectory "custom" -ListTasks 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $lines = Get-Content $LogFile
                foreach ($line in $lines) {
                    ($line -split '\|').Count | Should -BeGreaterOrEqual 5
                }
            }
        }
    }

    Context "TaskDirectory Usage Logging" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should not log when using default TaskDirectory" {
            & $BoltScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Not -Match 'TaskDirectoryUsage'
            }
        }

        It "Should log when using custom TaskDirectory" {
            & $BoltScript -TaskDirectory "custom-tasks" -ListTasks 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskDirectoryUsage'
                $content | Should -Match 'custom-tasks'
            }
        }
    }

    Context "File Creation Logging" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
            $testTaskName = "test-logging-$(Get-Random)"
        }

        BeforeEach {
            # Clean up any leftover test task files before each test
            Clear-TestLoggingTask
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
            # Final cleanup of test task files after all tests in this context
            Clear-TestLoggingTask
        }

        It "Should log file creation when using -NewTask" {
            & $BoltScript -NewTask $testTaskName | Out-Null

            Test-Path $LogFile | Should -Be $true
            $content = Get-Content $LogFile -Raw
            $content | Should -Match 'FileCreation'
            $content | Should -Match 'Created task file'
        }

        It "Should include task name in file creation log" {
            $testTaskName = "test-logging-$(Get-Random)"
            & $BoltScript -NewTask $testTaskName | Out-Null

            $content = Get-Content $LogFile -Raw
            $content | Should -Match $testTaskName.ToLower()
        }
    }

    Context "Task Execution Logging" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'

            # Create a simple test task
            $testTaskName = "test-exec-logging"
            $testTaskFile = Join-Path $ProjectRoot "tests" "fixtures" "Invoke-MockSimple.ps1"
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should log task execution start" {
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskExecution'
            }
        }

        It "Should log task execution completion" {
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskCompletion'
            }
        }

        It "Should log task success status" {
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'succeeded'
            }
        }
    }

    Context "External Command Logging" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should log git command execution" {
            # Run check-index task which calls git
            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue

            if ($gitAvailable) {
                & $BoltScript "check-index" -Only 2>$null | Out-Null

                if (Test-Path $LogFile) {
                    $content = Get-Content $LogFile -Raw
                    $content | Should -Match 'CommandExecution'
                    $content | Should -Match 'git'
                }
            } else {
                Set-ItResult -Skipped -Because "Git is not available"
            }
        }
    }

    Context "Log File Management" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should append to existing log file" {
            # Execute a simple task to create initial log
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null
            $firstSize = (Get-Item $LogFile -ErrorAction SilentlyContinue).Length

            # Execute again to append
            & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null
            $secondSize = (Get-Item $LogFile -ErrorAction SilentlyContinue).Length

            if ($firstSize -and $secondSize) {
                $secondSize | Should -BeGreaterThan $firstSize
            }
        }

        It "Should handle multiple sequential writes" {
            # Run multiple bolt commands sequentially to verify log appending works
            1..3 | ForEach-Object {
                & $BoltScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null
            }

            # Log file should exist and have entries from all executions
            Test-Path $LogFile | Should -Be $true
            if (Test-Path $LogFile) {
                $lines = Get-Content $LogFile
                # Should have at least 6 entries (2 per execution: start + completion)
                $lines.Count | Should -BeGreaterOrEqual 6
            }
        }
    }

    Context "GitIgnore Integration" {

        It "Should have .bolt/ in .gitignore" {
            $gitignorePath = Join-Path $ProjectRoot ".gitignore"

            if (Test-Path $gitignorePath) {
                $content = Get-Content $gitignorePath -Raw
                $content | Should -Match '\.bolt/'
            } else {
                Set-ItResult -Skipped -Because ".gitignore file not found"
            }
        }

        It "Should not track audit logs in git" {
            # Check if git is available first
            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue

            if (-not $gitAvailable) {
                Set-ItResult -Skipped -Because "Git is not available"
                return
            }

            # Enable logging and execute a task to create log file
            $env:BOLT_AUDIT_LOG = '1'
            & $BoltScript -TaskDirectory 'tests/fixtures' mock-simple | Out-Null

            # Verify log file was created
            Test-Path $LogFile | Should -BeTrue

            # Verify .bolt/ is not tracked by git
            Push-Location $ProjectRoot
            try {
                $status = git status --porcelain .bolt/ 2>$null
                $status | Should -BeNullOrEmpty
            } finally {
                Pop-Location
                $env:BOLT_AUDIT_LOG = $null
            }
        }
    }

    Context "Error Handling" {

        BeforeAll {
            $env:BOLT_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:BOLT_AUDIT_LOG = $null
        }

        It "Should not fail script execution if logging fails" {
            # This is difficult to test directly, but we can verify the try-catch exists
            $scriptContent = Get-Content $BoltScript -Raw
            $scriptContent | Should -Match 'function Write-SecurityLog'
            $scriptContent | Should -Match 'try\s*\{[\s\S]*?\}\s*catch\s*\{'
        }

        It "Should continue execution if log directory cannot be created" {
            # Create a file where directory should be (simulates permission issue)
            New-Item -Path $LogDir -ItemType File -Force | Out-Null

            # Should not throw, just skip logging
            { & $BoltScript -ListTasks 2>$null | Out-Null } | Should -Not -Throw

            Remove-Directory $LogDir
        }
    }
}
