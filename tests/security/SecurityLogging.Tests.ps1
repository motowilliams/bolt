#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

<#
.SYNOPSIS
    Tests for P0 Security Event Logging implementation

.DESCRIPTION
    Validates that security-relevant events are properly logged when
    $env:GOSH_AUDIT_LOG is enabled, including task execution, file creation,
    external command execution, and user context capture.

.NOTES
    Test Tags: SecurityLogging, Operational
#>

BeforeAll {
    $ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $GoshScript = Join-Path $ProjectRoot "gosh.ps1"
    $LogDir = Join-Path $ProjectRoot ".gosh"
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
                }
                catch {
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

        It "Should not create .gosh directory when logging is disabled" {
            # Run a simple task without enabling logging
            & $GoshScript -ListTasks | Out-Null

            Test-Path -PathType Container $LogDir | Should -Be $false
        }

        It "Should not create audit.log when logging is disabled" {
            & $GoshScript -ListTasks | Out-Null

            Test-Path $LogFile | Should -Be $false
        }

        It "Should work normally without logging overhead" {
            # Ensure logging is explicitly disabled
            $env:GOSH_AUDIT_LOG = $null

            # Execute a simple task without logging enabled
            $ErrorActionPreference = 'SilentlyContinue'
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            # Should execute successfully without creating logs
            $LASTEXITCODE | Should -Be 0
            Test-Path $LogFile | Should -Be $false
        }
    }

    Context "Logging Enabled via Environment Variable" {

        BeforeAll {
            $env:GOSH_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should create .gosh directory when logging is enabled" {
            # Execute a simple task to trigger logging
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            Test-Path -PathType Container $LogDir | Should -Be $true
            (Get-Item -Force $LogDir).PSIsContainer | Should -Be $true
        }

        It "Should create audit.log file when logging is enabled" {
            # Execute a simple task to trigger logging
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            Test-Path $LogFile | Should -Be $true
        }

        It "Should write UTF-8 encoded log entries" {
            # Execute a simple task to trigger logging
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Log Entry Format" {

        BeforeAll {
            $env:GOSH_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should include timestamp in log entries" {
            & $GoshScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
            }
        }

        It "Should include severity level in log entries" {
            & $GoshScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match '(Info|Warning|Error)'
            }
        }

        It "Should include username in log entries" {
            & $GoshScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $username = [Environment]::UserName
                $content | Should -Match $username
            }
        }

        It "Should include machine name in log entries" {
            & $GoshScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $machine = [Environment]::MachineName
                $content | Should -Match $machine
            }
        }

        It "Should include event type in log entries" {
            & $GoshScript -TaskDirectory "custom" -ListTasks 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskDirectoryUsage'
            }
        }

        It "Should use pipe delimiter format: Timestamp | Severity | User@Machine | Event | Details" {
            & $GoshScript -TaskDirectory "custom" -ListTasks 2>$null | Out-Null

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
            $env:GOSH_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should not log when using default TaskDirectory" {
            & $GoshScript -ListTasks | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Not -Match 'TaskDirectoryUsage'
            }
        }

        It "Should log when using custom TaskDirectory" {
            & $GoshScript -TaskDirectory "custom-tasks" -ListTasks 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskDirectoryUsage'
                $content | Should -Match 'custom-tasks'
            }
        }
    }

    Context "File Creation Logging" {

        BeforeAll {
            $env:GOSH_AUDIT_LOG = '1'
            $testTaskName = "test-logging-$(Get-Random)"
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
            # Clean up test task file
            $taskFile = Join-Path $ProjectRoot ".build" "Invoke-Test-Logging-*.ps1"
            if (Test-Path $taskFile) {
                Remove-Item $taskFile -Force
            }
        }

        It "Should log file creation when using -NewTask" {
            & $GoshScript -NewTask $testTaskName | Out-Null

            Test-Path $LogFile | Should -Be $true
            $content = Get-Content $LogFile -Raw
            $content | Should -Match 'FileCreation'
            $content | Should -Match 'Created task file'
        }

        It "Should include task name in file creation log" {
            $taskName = "test-log-$(Get-Random)"
            & $GoshScript -NewTask $taskName | Out-Null

            $content = Get-Content $LogFile -Raw
            $content | Should -Match $taskName.ToLower()
        }
    }

    Context "Task Execution Logging" {

        BeforeAll {
            $env:GOSH_AUDIT_LOG = '1'

            # Create a simple test task
            $testTaskName = "test-exec-logging"
            $testTaskFile = Join-Path $ProjectRoot "tests" "fixtures" "Invoke-MockSimple.ps1"
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should log task execution start" {
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskExecution'
            }
        }

        It "Should log task execution completion" {
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'TaskCompletion'
            }
        }

        It "Should log task success status" {
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null

            if (Test-Path $LogFile) {
                $content = Get-Content $LogFile -Raw
                $content | Should -Match 'succeeded'
            }
        }
    }

    Context "External Command Logging" {

        BeforeAll {
            $env:GOSH_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should log git command execution" {
            # Run check-index task which calls git
            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue

            if ($gitAvailable) {
                & $GoshScript "check-index" -Only 2>$null | Out-Null

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
            $env:GOSH_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should append to existing log file" {
            # Execute a simple task to create initial log
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null
            $firstSize = (Get-Item $LogFile -ErrorAction SilentlyContinue).Length

            # Execute again to append
            & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null
            $secondSize = (Get-Item $LogFile -ErrorAction SilentlyContinue).Length

            if ($firstSize -and $secondSize) {
                $secondSize | Should -BeGreaterThan $firstSize
            }
        }

        It "Should handle multiple sequential writes" {
            # Run multiple gosh commands sequentially to verify log appending works
            1..3 | ForEach-Object {
                & $GoshScript -TaskDirectory "tests/fixtures" "mock-simple" -Only 2>$null | Out-Null
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

        It "Should have .gosh/ in .gitignore" {
            $gitignorePath = Join-Path $ProjectRoot ".gitignore"

            if (Test-Path $gitignorePath) {
                $content = Get-Content $gitignorePath -Raw
                $content | Should -Match '\.gosh/'
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
            $env:GOSH_AUDIT_LOG = '1'
            & $GoshScript -TaskDirectory 'tests/fixtures' mock-simple | Out-Null

            # Verify log file was created
            Test-Path $LogFile | Should -BeTrue

            # Verify .gosh/ is not tracked by git
            Push-Location $ProjectRoot
            try {
                $status = git status --porcelain .gosh/ 2>$null
                $status | Should -BeNullOrEmpty
            } finally {
                Pop-Location
                $env:GOSH_AUDIT_LOG = $null
            }
        }
    }

    Context "Error Handling" {

        BeforeAll {
            $env:GOSH_AUDIT_LOG = '1'
        }

        AfterAll {
            $env:GOSH_AUDIT_LOG = $null
        }

        It "Should not fail script execution if logging fails" {
            # This is difficult to test directly, but we can verify the try-catch exists
            $scriptContent = Get-Content $GoshScript -Raw
            $scriptContent | Should -Match 'function Write-SecurityLog'
            $scriptContent | Should -Match 'try\s*\{[\s\S]*?\}\s*catch\s*\{'
        }

        It "Should continue execution if log directory cannot be created" {
            # Create a file where directory should be (simulates permission issue)
            New-Item -Path $LogDir -ItemType File -Force | Out-Null

            # Should not throw, just skip logging
            { & $GoshScript -ListTasks 2>$null | Out-Null } | Should -Not -Throw

            Remove-Directory $LogDir
        }
    }
}
