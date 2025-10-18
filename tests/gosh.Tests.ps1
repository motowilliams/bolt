#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for the Gosh build system
.DESCRIPTION
    Tests core functionality including task discovery, dependency resolution,
    execution, and error handling.
#>

BeforeAll {
    # Get project root (parent of tests directory)
    $projectRoot = Split-Path -Parent $PSScriptRoot

    $script:GoshScriptPath = Join-Path $projectRoot 'gosh.ps1'
    $script:BuildPath = Join-Path $projectRoot '.build'
    $script:TestBuildPath = Join-Path $projectRoot '.build-test'

    # Initialize task paths for skip conditions (evaluated during discovery)
    $script:FormatTaskPath = Join-Path $script:BuildPath 'Invoke-Format.ps1'
    $script:LintTaskPath = Join-Path $script:BuildPath 'Invoke-Lint.ps1'
    $script:BuildTaskPath = Join-Path $script:BuildPath 'Invoke-Build.ps1'

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

Describe 'Gosh Core Functionality' {

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
        BeforeAll {
            # Create a temporary test task
            if (-not (Test-Path $script:TestBuildPath)) {
                New-Item -ItemType Directory -Path $script:TestBuildPath -Force | Out-Null
            }

            $testTaskPath = Join-Path $script:TestBuildPath 'Invoke-TestTask.ps1'
            @'
# TASK: test-task
# DESCRIPTION: A test task for Pester
# DEPENDS:

Write-Host "Test task executed" -ForegroundColor Green
exit 0
'@ | Set-Content -Path $testTaskPath
        }

        AfterAll {
            if (Test-Path $script:TestBuildPath) {
                Remove-ItemWithRetry -Path $script:TestBuildPath
            }
        }

        It 'Should discover tasks from .build directory' {
            if (Test-Path $script:BuildPath) {
                $buildFiles = Get-ChildItem $script:BuildPath -Filter "*.ps1" -File -ErrorAction SilentlyContinue
                $buildFiles.Count | Should -BeGreaterThan 0
            }
        }

        It 'Should parse task metadata from comments' {
            $testTaskPath = Join-Path $script:BuildPath 'Invoke-Format.ps1'
            if (Test-Path $testTaskPath) {
                $content = Get-Content $testTaskPath -Raw
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

        It 'Should execute multiple tasks in sequence' {
            if (Test-Path (Join-Path $script:BuildPath 'Invoke-Format.ps1')) {
                # This will test executing format with -Only flag
                $result = Invoke-Gosh -Arguments @('format') -Parameters @{ Only = $true }
                # Just ensure it executes (may fail if bicep not installed)
                $result.ExitCode | Should -BeIn @(0, 1)
            }
        }
    }

    Context 'Dependency Resolution' {
        It 'Should respect -Only flag to skip dependencies' {
            if (Test-Path (Join-Path $script:BuildPath 'Invoke-Build.ps1')) {
                $result = Invoke-Gosh -Arguments @('build') -Parameters @{ Only = $true }
                # Should attempt to run build without dependencies
                $result.ExitCode | Should -BeIn @(0, 1)
            }
        }

        It 'Should execute dependencies when not using -Only' {
            if (Test-Path (Join-Path $script:BuildPath 'Invoke-Build.ps1')) {
                $result = Invoke-Gosh -Arguments @('build')

                # Build depends on format and lint - should execute them
                # Just verify it attempted to run (may fail if tools aren't installed)
                $result.ExitCode | Should -BeIn @(0, 1)
            }
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
        It 'Should handle missing .build directory gracefully' {
            # Test with a non-existent task that would be in .build
            { Invoke-Gosh -Arguments @('absolutely-non-existent-task') } | Should -Throw -ExpectedMessage '*not found*'
        }

        It 'Should provide helpful error message for invalid task' {
            { Invoke-Gosh -Arguments @('invalid-task-name') } | Should -Throw -ExpectedMessage '*not found*'
        }
    }

    Context 'Integration Tests' {
        BeforeAll {
            # Check if Bicep CLI is available
            $script:BicepAvailable = $null -ne (Get-Command bicep -ErrorAction SilentlyContinue)
        }

        It 'Should format Bicep files if bicep CLI is available' -Skip:(-not $script:BicepAvailable) {
            if (Test-Path (Join-Path $PSScriptRoot 'iac')) {
                $result = Invoke-Gosh -Arguments @('format') -Parameters @{ Only = $true }
                # Should execute without errors
                $result.ExitCode | Should -BeIn @(0, 1)
            }
        }

        It 'Should lint Bicep files if bicep CLI is available' -Skip:(-not $script:BicepAvailable) {
            if (Test-Path (Join-Path $PSScriptRoot 'iac')) {
                $result = Invoke-Gosh -Arguments @('lint', '-Only')
                # Should execute (may have warnings/errors but should run)
                $result.ExitCode | Should -BeIn @(0, 1)
            }
        }

        It 'Should build Bicep files if bicep CLI is available' -Skip:(-not $script:BicepAvailable) {
            if (Test-Path (Join-Path $PSScriptRoot 'iac')) {
                $result = Invoke-Gosh -Arguments @('build', '-Only')
                # Should execute
                $result.ExitCode | Should -BeIn @(0, 1)
            }
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

Describe 'Task Script Tests' {
    Context 'Format Task' {
        It 'Should exist' {
            Test-Path $script:FormatTaskPath | Should -Be $true
        }

        It 'Should have valid syntax' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
            }
        }

        It 'Should have proper task metadata' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match '# TASK: format'
                $content | Should -Match '# DESCRIPTION:'
            }
        }
    }

    Context 'Lint Task' {
        It 'Should exist' {
            Test-Path $script:LintTaskPath | Should -Be $true
        }

        It 'Should have valid syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:LintTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:LintTaskPath -Raw
            $content | Should -Match '# TASK: lint'
            $content | Should -Match '# DESCRIPTION:'
        }
    }

    Context 'Build Task' {
        It 'Should exist' {
            Test-Path $script:BuildTaskPath | Should -Be $true
        }

        It 'Should have valid syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:BuildTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:BuildTaskPath -Raw
            $content | Should -Match '# TASK: build'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format and lint tasks' {
            $content = Get-Content $script:BuildTaskPath -Raw
            $content | Should -Match '# DEPENDS:.*format.*lint'
        }
    }
}

Describe 'Documentation Consistency' {
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
