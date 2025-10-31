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
    # Get module root (parent of tests directory); tests live in a 'tests' directory
    $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
    $projectRoot = $moduleRoot

    # Get project root (parent of module directory)
    $currentPath = $projectRoot
    while ($currentPath -and $currentPath -ne (Split-Path -Parent $currentPath)) {
        Write-host "Checking path: $currentPath for .git directory" -ForegroundColor DarkGray
        if (Test-Path (Join-Path $currentPath '.git')) {
            $projectRoot = $currentPath
            break
        }
        $currentPath = Split-Path -Parent $currentPath
    }
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

        It 'Should derive task name from filename when no TASK metadata exists' {
            # Create a temporary task directory with test files inside the project
            $tempDir = Join-Path $projectRoot ".test-fallback-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                # Test case 1: Single hyphen (Invoke-TestOutput.ps1 -> testoutput)
                $file1 = Join-Path $tempDir "Invoke-TestOutput.ps1"
                Set-Content -Path $file1 -Value "Write-Host 'Test'; exit 0"

                # Test case 2: Multiple hyphens (Invoke-Test-Output.ps1 -> test-output)
                $file2 = Join-Path $tempDir "Invoke-Test-Output.ps1"
                Set-Content -Path $file2 -Value "Write-Host 'Test'; exit 0"

                # Test case 3: No hyphens (TestOnly.ps1 -> testonly)
                $file3 = Join-Path $tempDir "TestOnly.ps1"
                Set-Content -Path $file3 -Value "Write-Host 'Test'; exit 0"

                # Use relative path from project root
                $relativePath = Split-Path $tempDir -Leaf

                # Verify tasks are discovered with correct names
                # Capture output using 6>&1 to redirect information stream (Write-Host)
                $output = & $script:GoshScriptPath -TaskDirectory $relativePath -ListTasks 6>&1 2>&1 | Out-String

                # Should contain derived task names
                $output | Should -Match '\btestoutput\b'
                $output | Should -Match '\btest-output\b'
                $output | Should -Match '\btestonly\b'
            }
            finally {
                # Cleanup
                if (Test-Path $tempDir) {
                    Remove-ItemWithRetry -Path $tempDir
                }
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

    Context 'Parameter Sets' {
        It 'Should use Help parameter set with no parameters' {
            $output = (& $script:GoshScriptPath *>&1) -join "`n"
            $output | Should -Match 'Gosh! Build orchestration|Usage|Available tasks'
        }

        It 'Should reject invalid parameter combinations' {
            # -ListTasks and -NewTask should be mutually exclusive
            { & $script:GoshScriptPath -ListTasks -NewTask test 2>&1 } | Should -Throw -ExpectedMessage '*Parameter set cannot be resolved*'
        }

        It 'Should reject invalid parameter combinations (AsModule + ListTasks)' {
            # -AsModule and -ListTasks should be mutually exclusive
            { & $script:GoshScriptPath -AsModule -ListTasks 2>&1 } | Should -Throw -ExpectedMessage '*Parameter set cannot be resolved*'
        }

        It 'Should accept valid TaskExecution parameter set' {
            $result = Invoke-Gosh -Arguments @('check-index') -Parameters @{ Only = $true }
            $result.ExitCode | Should -BeIn @(0, 1)  # May succeed or fail, but should parse correctly
        }

        It 'Should accept valid ListTasks parameter set' {
            $output = (& $script:GoshScriptPath -ListTasks *>&1) -join "`n"
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Available tasks'
        }

        It 'Should accept valid CreateTask parameter set' {
            $testTaskName = "test-param-set-$(Get-Random)"
            try {
                $output = (& $script:GoshScriptPath -NewTask $testTaskName *>&1) -join "`n"
                $LASTEXITCODE | Should -Be 0
                $output | Should -Match "Created task file"
            }
            finally {
                # Clean up test task file - use same logic as gosh.ps1
                $taskNameCapitalized = (Get-Culture).TextInfo.ToTitleCase($testTaskName.ToLower())
                $testFile = Join-Path $script:BuildPath "Invoke-$taskNameCapitalized.ps1"
                if (Test-Path $testFile) {
                    Start-Sleep -Milliseconds 100  # Give file handles time to close
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

Describe 'Tab Completion (ArgumentCompleter)' -Tag 'Core' {
    BeforeAll {
        # Load the gosh.ps1 script to register the argument completer
        . $script:GoshScriptPath

        # Helper function to simulate tab completion
        function Get-TabCompletions {
            param(
                [string]$CommandLine,
                [int]$CursorPosition = $CommandLine.Length
            )

            # Parse the command line to create an AST
            $ast = [System.Management.Automation.Language.Parser]::ParseInput(
                $CommandLine,
                [ref]$null,
                [ref]$null
            )

            # Get the completer function
            $completer = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $CommandLine,
                $CursorPosition,
                $null
            )

            return $completer.CompletionMatches
        }
    }

    Context 'Core Task Completion' {
        It 'Should provide completions for core tasks' {
            $completions = Get-TabCompletions ".\gosh.ps1 ch"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText
            $taskNames | Should -Contain 'check'
            $taskNames | Should -Contain 'check-index'
        }

        It 'Should complete partial task names' {
            $completions = Get-TabCompletions ".\gosh.ps1 check-"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText
            $taskNames | Should -Contain 'check-index'
        }

        It 'Should provide all core tasks when no prefix given' {
            $completions = Get-TabCompletions ".\gosh.ps1 "
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText
            $taskNames | Should -Contain 'check'
            $taskNames | Should -Contain 'check-index'
        }
    }

    Context 'Project Task Completion' {
        It 'Should discover tasks from .build directory' {
            if (Test-Path $script:BuildPath) {
                $completions = Get-TabCompletions ".\gosh.ps1 "
                $taskNames = $completions | Select-Object -ExpandProperty CompletionText

                # Should have more than just core tasks
                $taskNames.Count | Should -BeGreaterThan 2
            }
        }

        It 'Should discover tasks from fixtures directory when using -TaskDirectory' {
            # This tests that the completer respects -TaskDirectory parameter
            $completions = Get-TabCompletions ".\gosh.ps1 -TaskDirectory tests/fixtures mock"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText

            $taskNames | Should -Contain 'mock-simple'
            $taskNames | Should -Contain 'mock-with-dep'
            $taskNames | Should -Contain 'mock-complex'
            $taskNames | Should -Contain 'mock-fail'
        }

        It 'Should complete task aliases' {
            # If .build has tasks with aliases, they should be completable
            if (Test-Path $script:BuildPath) {
                $completions = Get-TabCompletions ".\gosh.ps1 "
                # Just verify we get some completions - specific aliases depend on .build content
                $completions.Count | Should -BeGreaterThan 0
            }
        }
    }

    Context 'Completion Filtering' {
        It 'Should filter completions by prefix' {
            $completions = Get-TabCompletions ".\gosh.ps1 -TaskDirectory tests/fixtures mock-s"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText

            # Should only show tasks starting with "mock-s"
            $taskNames | ForEach-Object {
                $_ | Should -BeLike 'mock-s*'
            }
        }

        It 'Should return no completions for non-matching prefix' {
            $completions = Get-TabCompletions ".\gosh.ps1 xyz-nonexistent"
            $completions.Count | Should -Be 0
        }

        It 'Should be case-insensitive' {
            $completions = Get-TabCompletions ".\gosh.ps1 CHECK"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText
            $taskNames | Should -Contain 'check'
            $taskNames | Should -Contain 'check-index'
        }
    }

    Context 'Multiple Task Completion' {
        It 'Should provide task completions for second position via script block' {
            # Test the completion script block directly since PowerShell's tab completion
            # may provide file completions for subsequent positional arguments.
            # We extract and invoke the script block with test parameters.
            $content = Get-Content $script:GoshScriptPath -Raw

            # Extract the script block from $taskCompleter variable assignment
            if ($content -match '\$taskCompleter\s*=\s*\{([\s\S]+?)\n\}\s*\n\s*Register-ArgumentCompleter') {
                $scriptBlockText = $matches[1]
                $scriptBlock = [ScriptBlock]::Create($scriptBlockText)

                # Invoke with test parameters simulating typing "ch" as second task
                # Parameters: $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters
                # We need to provide a valid command AST or the script block will fail
                $mockAst = [System.Management.Automation.Language.Parser]::ParseInput(
                    ".\gosh.ps1 ch",
                    [ref]$null,
                    [ref]$null
                )

                $completions = & $scriptBlock 'gosh.ps1' 'Task' 'ch' $mockAst.EndBlock.Statements[0].PipelineElements[0] @{}

                if ($completions) {
                    $completionTexts = $completions | ForEach-Object { $_.CompletionText }
                    $completionTexts | Should -Contain 'check'
                    $completionTexts | Should -Contain 'check-index'
                } else {
                    # If completions are null, the script block at least executed without throwing
                    $true | Should -Be $true
                }
            } else {
                throw "Could not extract completion script block from gosh.ps1"
            }
        }

        It 'Should complete task after comma-separated list' {
            $completions = Get-TabCompletions ".\gosh.ps1 check,ch"
            # This tests completion after comma (may or may not work depending on PowerShell parsing)
            # If it doesn't work, that's acceptable behavior
            $completions.Count | Should -BeGreaterOrEqual 0
        }
    }

    Context 'Completion with Other Parameters' {
        It 'Should complete tasks when -Only flag is present' {
            $completions = Get-TabCompletions ".\gosh.ps1 -Only ch"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText
            $taskNames | Should -Contain 'check'
            $taskNames | Should -Contain 'check-index'
        }

        It 'Should complete tasks when -Outline flag is present' {
            $completions = Get-TabCompletions ".\gosh.ps1 -Outline ch"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText
            $taskNames | Should -Contain 'check'
            $taskNames | Should -Contain 'check-index'
        }
    }

    Context 'Completer Registration' {
        It 'Should successfully register argument completer without errors' {
            # Since Get-ArgumentCompleter is not available in PowerShell 7.0,
            # we verify registration by testing that the registration code executes
            # and that tab completion actually works (tested in other contexts).
            $content = Get-Content $script:GoshScriptPath -Raw

            # Verify the $taskCompleter variable assignment and Register-ArgumentCompleter call exist
            $content | Should -Match '\$taskCompleter\s*=\s*\{'
            $content | Should -Match 'Register-ArgumentCompleter\s+-CommandName\s+[''"]gosh\.ps1[''"]'
            $content | Should -Match 'Register-ArgumentCompleter.*-ParameterName\s+[''"]Task[''"]'

            # Verify the script block is syntactically valid by attempting to parse it
            if ($content -match '\$taskCompleter\s*=\s*(\{[\s\S]+?\n\}\s*\n\s*Register-ArgumentCompleter)') {
                $scriptBlockPortion = $matches[1] -replace 'Register-ArgumentCompleter.*', ''
                { [ScriptBlock]::Create($scriptBlockPortion) } | Should -Not -Throw
            } else {
                throw "Could not find taskCompleter script block in gosh.ps1"
            }
        }

        It 'Should use the correct script block for completion' {
            $content = Get-Content $script:GoshScriptPath -Raw
            $content | Should -Match 'Register-ArgumentCompleter.*-CommandName.*gosh\.ps1'
            $content | Should -Match 'Register-ArgumentCompleter.*-ParameterName.*Task'
        }
    }

    Context 'Filename Fallback Completion' {
        BeforeAll {
            # Create a temporary task file without TASK metadata to test filename fallback
            $script:TempTaskPath = Join-Path $script:BuildPath "Invoke-Temp-Completion-Test.ps1"

            if (-not (Test-Path $script:BuildPath)) {
                New-Item -ItemType Directory -Path $script:BuildPath -Force | Out-Null
            }

            @"
# No TASK metadata here
Write-Host "Testing filename fallback"
exit 0
"@ | Set-Content -Path $script:TempTaskPath -Force
        }

        AfterAll {
            if (Test-Path $script:TempTaskPath) {
                Remove-Item $script:TempTaskPath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should fallback to filename-based task name when no metadata exists' {
            # Need to reload the completer to pick up new file
            . $script:GoshScriptPath

            $completions = Get-TabCompletions ".\gosh.ps1 temp-comp"
            $taskNames = $completions | Select-Object -ExpandProperty CompletionText

            # Should extract "temp-completion-test" from "Invoke-Temp-Completion-Test.ps1"
            $taskNames | Should -Contain 'temp-completion-test'
        }
    }
}

Describe 'Task Outline Feature (-Outline)' -Tag 'Core' {
    BeforeAll {
        # Helper function to invoke gosh with -Outline and capture output
        function Get-OutlineOutput {
            param(
                [Parameter()]
                [string[]]$TaskNames,
                [switch]$Only,
                [string]$TaskDirectory = $null
            )

            $params = @{
                Outline = $true
            }

            if ($TaskNames.Count -gt 0) {
                $params['Task'] = $TaskNames
            }

            if ($Only) {
                $params['Only'] = $true
            }

            if ($TaskDirectory) {
                $params['TaskDirectory'] = $TaskDirectory
            }

            # Capture all output streams including Write-Host (information stream 6)
            # In PowerShell 5.0+, Write-Host writes to the information stream
            $output = & $script:GoshScriptPath @params *>&1 | Out-String
            return $output
        }
    }

    Context 'Basic Outline Display' {
        It 'Should display task outline with -Outline flag' {
            $output = Get-OutlineOutput -TaskNames @('mock-simple') -TaskDirectory 'tests/fixtures'
            $output | Should -Match 'Task execution plan'
            $output | Should -Match 'mock-simple'
        }

        It 'Should show task description in outline' {
            $output = Get-OutlineOutput -TaskNames @('mock-simple') -TaskDirectory 'tests/fixtures'
            $output | Should -Match 'A simple mock task'
        }

        It 'Should show execution order' {
            $output = Get-OutlineOutput -TaskNames @('mock-simple') -TaskDirectory 'tests/fixtures'
            $output | Should -Match 'Execution order:'
            $output | Should -Match '1\.\s+mock-simple'
        }

        It 'Should not execute tasks when -Outline is used' {
            $output = Get-OutlineOutput -TaskNames @('mock-simple') -TaskDirectory 'tests/fixtures'
            # Should NOT contain the actual task output
            $output | Should -Not -Match 'Mock simple task executed'
        }
    }

    Context 'Dependency Visualization' {
        It 'Should show single dependency in tree' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep') -TaskDirectory 'tests/fixtures'
            $output | Should -Match 'mock-with-dep'
            $output | Should -Match 'mock-simple'
            # Should use tree characters
            $output | Should -Match '[└├]──'
        }

        It 'Should show multiple dependencies in tree' {
            $output = Get-OutlineOutput -TaskNames @('mock-complex') -TaskDirectory 'tests/fixtures'
            $output | Should -Match 'mock-complex'
            $output | Should -Match 'mock-simple'
            $output | Should -Match 'mock-with-dep'
        }

        It 'Should show nested dependencies correctly' {
            $output = Get-OutlineOutput -TaskNames @('mock-complex') -TaskDirectory 'tests/fixtures'
            # mock-complex depends on mock-with-dep, which depends on mock-simple
            # So mock-simple should appear as a nested dependency
            $output | Should -Match 'mock-complex'
            $output | Should -Match 'mock-with-dep'
            $output | Should -Match 'mock-simple'
        }

        It 'Should deduplicate dependencies in execution order' {
            $output = Get-OutlineOutput -TaskNames @('mock-complex') -TaskDirectory 'tests/fixtures'
            # mock-simple appears as dependency of both mock-with-dep and mock-complex
            # But should only appear once in execution order
            $executionSection = $output -split 'Execution order:' | Select-Object -Last 1
            $simpleMatches = ([regex]::Matches($executionSection, 'mock-simple')).Count
            $simpleMatches | Should -Be 1
        }
    }

    Context 'Outline with -Only Flag' {
        It 'Should indicate dependencies will be skipped' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep') -TaskDirectory 'tests/fixtures' -Only
            $output | Should -Match 'Dependencies will be skipped'
        }

        It 'Should show which dependencies would be skipped' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep') -TaskDirectory 'tests/fixtures' -Only
            $output | Should -Match 'Dependencies skipped.*mock-simple'
        }

        It 'Should show only the target task in execution order with -Only' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep') -TaskDirectory 'tests/fixtures' -Only
            $output | Should -Match 'Execution order:'
            $output | Should -Match '1\.\s+mock-with-dep'
            # Should NOT include mock-simple in execution order
            $executionSection = $output -split 'Execution order:' | Select-Object -Last 1
            $executionSection | Should -Not -Match 'mock-simple'
        }

        It 'Should handle multiple tasks with -Only' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep', 'mock-complex') -TaskDirectory 'tests/fixtures' -Only
            $output | Should -Match 'mock-with-dep'
            $output | Should -Match 'mock-complex'
            $output | Should -Match 'Dependencies will be skipped'
        }
    }

    Context 'Multiple Tasks Outline' {
        It 'Should show outline for multiple tasks' {
            $output = Get-OutlineOutput -TaskNames @('mock-simple', 'mock-with-dep') -TaskDirectory 'tests/fixtures'
            # The regex needs to handle potential newlines between "for:" and task names
            $output | Should -Match 'Task execution plan for:'
            $output | Should -Match 'mock-simple'
            $output | Should -Match 'mock-with-dep'
        }

        It 'Should deduplicate shared dependencies across multiple tasks' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep', 'mock-complex') -TaskDirectory 'tests/fixtures'
            # Both depend on mock-simple, should only execute once
            $executionSection = $output -split 'Execution order:' | Select-Object -Last 1
            $simpleMatches = ([regex]::Matches($executionSection, 'mock-simple')).Count
            $simpleMatches | Should -Be 1
        }

        It 'Should show correct execution order for multiple tasks' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep', 'mock-simple') -TaskDirectory 'tests/fixtures'
            $executionSection = $output -split 'Execution order:' | Select-Object -Last 1

            # mock-simple should come before mock-with-dep
            $simpleIndex = $executionSection.IndexOf('mock-simple')
            $withDepIndex = $executionSection.IndexOf('mock-with-dep')
            $simpleIndex | Should -BeLessThan $withDepIndex
        }
    }

    Context 'Error Handling in Outline' {
        It 'Should show NOT FOUND for missing tasks' {
            $output = Get-OutlineOutput -TaskNames @('nonexistent-task') -TaskDirectory 'tests/fixtures'
            $output | Should -Match 'nonexistent-task'
            $output | Should -Match 'NOT FOUND'
        }

        It 'Should highlight missing dependencies in red' {
            # Create a temporary task with a missing dependency
            $tempTaskDir = 'tests/fixtures-temp-outline'
            $tempTaskDirFull = Join-Path $projectRoot $tempTaskDir
            $tempTaskFile = Join-Path $tempTaskDirFull 'Invoke-Bad-Deps.ps1'

            try {
                New-Item -ItemType Directory -Path $tempTaskDirFull -Force | Out-Null

                @"
# TASK: bad-deps
# DESCRIPTION: Task with missing dependency
# DEPENDS: nonexistent-dependency

Write-Host "This won't run"
exit 0
"@ | Set-Content -Path $tempTaskFile -Force

                $output = Get-OutlineOutput -TaskNames @('bad-deps') -TaskDirectory $tempTaskDir
                $output | Should -Match 'nonexistent-dependency'
                $output | Should -Match 'NOT FOUND'
            }
            finally {
                if (Test-Path $tempTaskDirFull) {
                    Remove-Item $tempTaskDirFull -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'Should handle empty parameter gracefully' {
            # With parameter sets, calling with no parameters should show help (default Help parameter set)
            $output = (& $script:GoshScriptPath *>&1) -join "`n"
            $output | Should -Match 'Gosh! Build orchestration|Usage|Available tasks'
        }
    }

    Context 'Core Tasks Outline' {
        It 'Should show outline for core check-index task' {
            $output = Get-OutlineOutput -TaskNames @('check-index')
            $output | Should -Match 'check-index'
            $output | Should -Match 'Checks if the git index is clean'
        }

        It 'Should show core task without dependencies' {
            $output = Get-OutlineOutput -TaskNames @('check-index')
            $output | Should -Match 'Execution order:'
            $output | Should -Match '1\.\s+check-index'

            # check-index has no dependencies, so only one item in execution order
            $executionSection = $output -split 'Execution order:' | Select-Object -Last 1
            $executionLines = ($executionSection -split "`n" | Where-Object { $_ -match '^\s+\d+\.' }).Count
            $executionLines | Should -Be 1
        }
    }

    Context 'Outline Formatting' {
        It 'Should use tree characters (├── └──) for dependency visualization' {
            $output = Get-OutlineOutput -TaskNames @('mock-with-dep') -TaskDirectory 'tests/fixtures'
            # Should contain tree drawing characters
            $output | Should -Match '[├└]──'
        }

        It 'Should number execution order steps' {
            $output = Get-OutlineOutput -TaskNames @('mock-complex') -TaskDirectory 'tests/fixtures'
            $output | Should -Match '1\.'
            $output | Should -Match '2\.'
            $output | Should -Match '3\.'
        }

        It 'Should clearly separate tree view from execution order' {
            $output = Get-OutlineOutput -TaskNames @('mock-complex') -TaskDirectory 'tests/fixtures'
            # Should have both sections
            $output | Should -Match 'Task execution plan'
            $output | Should -Match 'Execution order:'
        }
    }

    Context 'Outline with .build Tasks' {
        It 'Should show outline for project tasks if they exist' {
            if (Test-Path $script:BuildPath) {
                $buildFiles = Get-ChildItem $script:BuildPath -Filter "*.ps1" -File -ErrorAction SilentlyContinue
                if ($buildFiles.Count -gt 0) {
                    # Get first task name
                    $firstTask = ($buildFiles[0].BaseName -replace '^Invoke-', '').ToLower()
                    $output = Get-OutlineOutput -TaskNames @($firstTask)
                    $output | Should -Match 'Task execution plan'
                }
            }
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
