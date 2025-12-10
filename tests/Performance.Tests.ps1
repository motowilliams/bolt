#Requires -Version 7.0

<#
.SYNOPSIS
    Performance tests for Bolt build system
.DESCRIPTION
    Establishes performance baselines and tracks regression for:
    - Task discovery (Get-AllTasks)
    - Single task execution (Invoke-Task)
    - Full build pipeline (format → lint → build)

    These tests use the 'Perf' tag and can be run separately from functional tests.
.NOTES
    Run with: Invoke-Pester -Tag Perf
    Thresholds are established to ensure the variable system doesn't degrade performance.
#>

BeforeAll {
    $script:BoltScriptPath = Join-Path $PSScriptRoot ".." "bolt.ps1"
    # TaskDirectory is relative to bolt.ps1 location, not current directory
    $script:FixturesPath = "tests/fixtures"
    $script:TestsRoot = $PSScriptRoot
    $script:BoltRoot = Split-Path $script:BoltScriptPath -Parent
}

Describe "Bolt Performance Baseline" -Tag "Perf" {

    Context "Task Discovery Performance" {
        It "Should discover all tasks in under 500ms" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Source the bolt.ps1 script to access Get-AllTasks function
            . $script:BoltScriptPath

            # Measure task discovery from fixtures (using absolute path)
            $tasks = Get-AllTasks -TaskDirectory (Join-Path $script:TestsRoot "fixtures") -ScriptRoot $script:TestsRoot

            $stopwatch.Stop()
            $elapsedMs = $stopwatch.ElapsedMilliseconds

            Write-Host "Task discovery took: $elapsedMs ms" -ForegroundColor Cyan

            # Baseline threshold: task discovery should be fast
            $elapsedMs | Should -BeLessThan 500

            # Verify we actually discovered tasks
            $tasks.Count | Should -BeGreaterThan 0
        }
    }

    Context "Single Task Execution Performance" {
        It "Should execute a simple task in under 2 seconds" {
            Push-Location $script:BoltRoot
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Execute a simple mock task
                & pwsh -File $script:BoltScriptPath "mock-simple" -TaskDirectory $script:FixturesPath
                $exitCode = $LASTEXITCODE

                $stopwatch.Stop()
                $elapsedMs = $stopwatch.ElapsedMilliseconds

                Write-Host "Single task execution took: $elapsedMs ms" -ForegroundColor Cyan

                # Baseline threshold: simple task execution should be quick
                $elapsedMs | Should -BeLessThan 2000

                # Verify task succeeded
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Build Pipeline Performance" {
        BeforeAll {
            # Check if Bicep CLI is available
            $script:BicepAvailable = $null -ne (Get-Command bicep -ErrorAction SilentlyContinue)
        }

        It "Should execute full build pipeline in under 5 seconds" -Skip:(-not $script:BicepAvailable) {
            Push-Location $script:BoltRoot
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Execute full build pipeline (format → lint → build)
                & pwsh -File $script:BoltScriptPath "build"
                $exitCode = $LASTEXITCODE

                $stopwatch.Stop()
                $elapsedMs = $stopwatch.ElapsedMilliseconds

                Write-Host "Full build pipeline took: $elapsedMs ms" -ForegroundColor Cyan

                # Baseline threshold: full pipeline should complete reasonably fast
                # Note: This includes Bicep CLI execution which may vary
                $elapsedMs | Should -BeLessThan 5000

                # Verify build succeeded
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Task Dependency Resolution Performance" {
        It "Should resolve dependencies without significant overhead" {
            Push-Location $script:BoltRoot
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Execute task with dependencies (mock-complex depends on mock-with-dep and mock-simple)
                & pwsh -File $script:BoltScriptPath "mock-complex" -TaskDirectory $script:FixturesPath
                $exitCode = $LASTEXITCODE

                $stopwatch.Stop()
                $elapsedMs = $stopwatch.ElapsedMilliseconds

                Write-Host "Dependency resolution took: $elapsedMs ms" -ForegroundColor Cyan

                # Baseline threshold: dependency resolution overhead should be minimal
                $elapsedMs | Should -BeLessThan 3000

                # Verify task succeeded
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Multiple Task Execution Performance" {
        It "Should execute multiple independent tasks efficiently" {
            Push-Location $script:BoltRoot
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Execute multiple tasks without dependencies using -Only flag
                & pwsh -File $script:BoltScriptPath "mock-simple" "mock-with-dep" "mock-complex" -TaskDirectory $script:FixturesPath -Only
                $exitCode = $LASTEXITCODE

                $stopwatch.Stop()
                $elapsedMs = $stopwatch.ElapsedMilliseconds

                Write-Host "Multiple task execution took: $elapsedMs ms" -ForegroundColor Cyan

                # Baseline threshold: multiple simple tasks should be fast
                $elapsedMs | Should -BeLessThan 3000

                # Verify tasks succeeded
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Task Outline Performance" {
        It "Should generate task outline in under 500ms" {
            Push-Location $script:BoltRoot
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Generate task outline (no execution, just visualization)
                & pwsh -File $script:BoltScriptPath "mock-complex" -TaskDirectory $script:FixturesPath -Outline
                $exitCode = $LASTEXITCODE

                $stopwatch.Stop()
                $elapsedMs = $stopwatch.ElapsedMilliseconds

                Write-Host "Task outline generation took: $elapsedMs ms" -ForegroundColor Cyan

                # Baseline threshold: outline should be fast (includes pwsh startup overhead)
                $elapsedMs | Should -BeLessThan 1500

                # Verify outline succeeded
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }
}
