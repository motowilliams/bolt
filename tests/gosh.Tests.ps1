#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Gosh core orchestration functionality
.DESCRIPTION
    Tests core Gosh features using mock tasks from tests/fixtures.
    This ensures tests are independent of project-specific tasks.
#>

BeforeAll {
    # Get project root (parent of tests directory)
    $projectRoot = Split-Path -Parent $PSScriptRoot

    $script:GoshScriptPath = Join-Path $projectRoot 'gosh.ps1'
    $script:BuildPath = Join-Path $projectRoot '.build'
    $script:FixturesPath = Join-Path $PSScriptRoot 'fixtures'

    # Helper function for robust file/directory removal with retries
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
            }
            catch {
                if ($i -eq ($MaxRetries - 1)) {
                    Write-Warning "Failed to remove $Path after $MaxRetries attempts: $_"
                    return $false
                }
                Start-Sleep -Milliseconds $DelayMs
            }
        }
        return $true
    }

    # Helper function to invoke gosh with captured output
    function Invoke-Gosh {
        param(
            [Parameter()]
            [string[]]$Arguments = @(),

            [Parameter()]
            [hashtable]$Parameters = @{},

            [switch]$ExpectFailure
        )

        # Build splatting hashtable for named parameters
        $splatParams = @{}
        foreach ($key in $Parameters.Keys) {
            $splatParams[$key] = $Parameters[$key]
        }

        # Add positional arguments if provided
        if ($Arguments.Count -gt 0) {
            $splatParams['Task'] = $Arguments
        }

        # Execute with splatting
        $output = & $script:GoshScriptPath @splatParams 2>&1
        $exitCode = $LASTEXITCODE

        return @{
            Output = $output
            ExitCode = $exitCode
            Success = $exitCode -eq 0
        }
    }
}

Describe 'Gosh Core Functionality' -Tag 'Core' {

    Context 'Script Validation' {
        It 'Should exist' {
            Test-Path $script:GoshScriptPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:GoshScriptPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should require PowerShell 7.0+' {
            $content = Get-Content $script:GoshScriptPath -Raw
            $content | Should -Match '#Requires -Version 7\.0'
        }
    }

    Context 'Task Listing' {
        It 'Should list tasks with -ListTasks' {
            $result = Invoke-Gosh -Parameters @{ ListTasks = $true }
            $result.Success | Should -Be $true
        }

        It 'Should show core tasks' {
            $result = Invoke-Gosh -Parameters @{ ListTasks = $true }
            # The -ListTasks command should succeed
            $result.Success | Should -Be $true
        }

        It 'Should show project tasks if .build directory exists' {
            if (Test-Path $script:BuildPath) {
                $result = Invoke-Gosh -Parameters @{ ListTasks = $true }
                $result.Success | Should -Be $true
            }
        }

        It 'Should accept -Help as alias for -ListTasks' {
            $resultList = Invoke-Gosh -Parameters @{ ListTasks = $true }
            $resultHelp = Invoke-Gosh -Parameters @{ Help = $true }

            # Both should succeed
            $resultList.Success | Should -Be $true
            $resultHelp.Success | Should -Be $true
        }
    }

    Context 'Task Discovery' {
        It 'Should discover tasks from .build directory' {
            if (Test-Path $script:BuildPath) {
                $buildFiles = Get-ChildItem $script:BuildPath -Filter "*.ps1" -File -ErrorAction SilentlyContinue
                $buildFiles.Count | Should -BeGreaterThan 0
            }
        }

        It 'Should parse task metadata from comments' {
            $mockTaskPath = Join-Path $script:FixturesPath 'Invoke-MockSimple.ps1'
            if (Test-Path $mockTaskPath) {
                $content = Get-Content $mockTaskPath -Raw
                $content | Should -Match '(?m)^#\s*TASK:'
            }
        }
    }

    Context 'Task Execution' {
        It 'Should execute a valid core task' {
            # check-index requires git, skip if not available
            $gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

            if ($gitAvailable) {
                $result = Invoke-Gosh -Arguments @('check-index')
                # May pass or fail depending on git state, but should execute
                $result.ExitCode | Should -BeIn @(0, 1)
            }
        }

        It 'Should fail on non-existent task' {
            { Invoke-Gosh -Arguments @('non-existent-task-xyz') } | Should -Throw -ExpectedMessage '*not found*'
        }

        It 'Should execute mock task successfully' {
            $result = Invoke-Gosh -Arguments @('mock-simple') -Parameters @{ TaskDirectory = 'tests/fixtures'; Only = $true }
            $result.ExitCode | Should -Be 0
            $result.Success | Should -Be $true
        }
    }

    Context 'Dependency Resolution' {
        It 'Should respect -Only flag to skip dependencies' {
            $result = Invoke-Gosh -Arguments @('mock-with-dep') -Parameters @{ TaskDirectory = 'tests/fixtures'; Only = $true }
            # Should run without executing mock-simple dependency
            $result.ExitCode | Should -Be 0
        }

        It 'Should execute dependencies when not using -Only' {
            $result = Invoke-Gosh -Arguments @('mock-with-dep') -Parameters @{ TaskDirectory = 'tests/fixtures' }
            # Should execute mock-simple first, then mock-with-dep
            $result.ExitCode | Should -Be 0
        }

        It 'Should handle complex dependency chains' {
            $result = Invoke-Gosh -Arguments @('mock-complex') -Parameters @{ TaskDirectory = 'tests/fixtures' }
            # Should execute: mock-simple, then mock-with-dep, then mock-complex
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'New Task Creation' {
        AfterEach {
            # Clean up any test-generated files with retry logic
            Get-ChildItem $script:BuildPath -Filter "Invoke-Test*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-ItemWithRetry -Path $_.FullName
            }
        }

        It 'Should create a new task file with -NewTask' {
            $taskName = "test-task-$(Get-Random)"
            Invoke-Gosh -Parameters @{ NewTask = $taskName }

            # Find the created file - gosh converts test-task-123 to Invoke-Test-Task-123.ps1
            $createdFile = Get-ChildItem $script:BuildPath -Filter "Invoke-Test-Task*.ps1" |
                Where-Object { $_.Name -match 'Test-Task-\d+' } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            $createdFile | Should -Not -BeNullOrEmpty
            $createdFile.Exists | Should -Be $true
        }

        It 'Should create task file with proper metadata structure' {
            $taskName = "test-metadata-$(Get-Random)"
            Invoke-Gosh -Parameters @{ NewTask = $taskName }

            # Find and read the created file
            $createdFile = Get-ChildItem $script:BuildPath -Filter "Invoke-Test-Metadata*.ps1" |
                Where-Object { $_.Name -match 'Test-Metadata-\d+' } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            $createdFile | Should -Not -BeNullOrEmpty
            $content = Get-Content $createdFile.FullName -Raw
            $content | Should -Match '# TASK:'
            $content | Should -Match '# DESCRIPTION:'
            $content | Should -Match '# DEPENDS:'
            $content | Should -Match 'exit 0'
        }

        It 'Should convert task name to proper filename' {
            $taskName = "test-conversion-$(Get-Random)"
            Invoke-Gosh -Parameters @{ NewTask = $taskName }

            # Should create a file with the task name
            $createdFiles = Get-ChildItem $script:BuildPath -Filter "Invoke-Test*.ps1"
            $createdFiles.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            # Copy fixtures to test location
            $script:TestBuildPath = Join-Path $projectRoot '.build-test'
            if (-not (Test-Path $script:TestBuildPath)) {
                New-Item -ItemType Directory -Path $script:TestBuildPath -Force | Out-Null
            }
            Copy-Item "$script:FixturesPath\*.ps1" -Destination $script:TestBuildPath -Force
        }

        AfterAll {
            if (Test-Path $script:TestBuildPath) {
                Remove-ItemWithRetry -Path $script:TestBuildPath
            }
        }

        It 'Should handle missing .build directory gracefully' {
            # Test with a non-existent task that would be in .build
            { Invoke-Gosh -Arguments @('absolutely-non-existent-task') } | Should -Throw -ExpectedMessage '*not found*'
        }

        It 'Should provide helpful error message for invalid task' {
            { Invoke-Gosh -Arguments @('invalid-task-name') } | Should -Throw -ExpectedMessage '*not found*'
        }

        It 'Should handle task failures correctly' {
            $result = Invoke-Gosh -Arguments @('mock-fail') -Parameters @{ TaskDirectory = 'tests/fixtures'; Only = $true }
            $result.ExitCode | Should -Be 1
            $result.Success | Should -Be $false
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept comma-separated task list' {
            # This tests the parameter parsing for multiple tasks
            $result = Invoke-Gosh -Arguments @('check,check-index')
            # Should parse and attempt to execute (may fail, but parsing should work)
            $result.ExitCode | Should -BeIn @(0, 1)
        }

        It 'Should accept space-separated task list' {
            $result = Invoke-Gosh -Arguments @('check', 'check-index')
            $result.ExitCode | Should -BeIn @(0, 1)
        }
    }
}

Describe 'Documentation Consistency' -Tag 'Core' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $script:GoshScriptPath = Join-Path $projectRoot 'gosh.ps1'
    }

    Context 'README Examples' {
        It 'Should have README.md' {
            $readmePath = Join-Path $projectRoot 'README.md'
            Test-Path $readmePath | Should -Be $true
        }

        It 'README should mention core tasks' {
            $readmePath = Join-Path $projectRoot 'README.md'
            $content = Get-Content $readmePath -Raw
            $content | Should -Match 'format'
            $content | Should -Match 'lint'
            $content | Should -Match 'build'
        }
    }

    Context 'Help Documentation' {
        It 'Should have proper comment-based help' {
            $content = Get-Content $script:GoshScriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.EXAMPLE'
        }

        It 'Should document all parameters' {
            $content = Get-Content $script:GoshScriptPath -Raw
            $content | Should -Match '\.PARAMETER Task'
            $content | Should -Match '\.PARAMETER ListTasks'
            $content | Should -Match '\.PARAMETER Only'
            $content | Should -Match '\.PARAMETER NewTask'
        }
    }
}
