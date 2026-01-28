#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for Python tasks
.DESCRIPTION
    End-to-end tests that validate task execution with the example Python project.
    These tests require Python or Docker to be available.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
    $projectRoot = $moduleRoot

    # Get project root (find .git directory)
    $currentPath = $projectRoot
    while ($currentPath -and $currentPath -ne (Split-Path -Parent $currentPath)) {
        if (Test-Path (Join-Path $currentPath '.git')) {
            $projectRoot = $currentPath
            break
        }
        $currentPath = Split-Path -Parent $currentPath
    }
    $script:BoltScriptPath = Join-Path $projectRoot 'bolt.ps1'

    $script:testAppPath = Join-Path $PSScriptRoot 'app'

    # Helper function to invoke bolt with captured output
    function Invoke-Bolt {
        param(
            [Parameter()]
            [string[]]$Arguments = @(),

            [Parameter()]
            [hashtable]$Parameters = @{}
        )

        # Always use the module root task directory for these tests
        # Convert absolute path to relative path from project root
        $relativePath = [System.IO.Path]::GetRelativePath($projectRoot, $moduleRoot)
        $Parameters['TaskDirectory'] = $relativePath

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
        $output = & $script:BoltScriptPath @splatParams 2>&1
        $exitCode = $LASTEXITCODE

        return @{
            Output   = $output
            ExitCode = $exitCode
            Success  = $exitCode -eq 0
        }
    }

    # Check for Python or Docker availability
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
    }
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue

    if (-not $pythonCmd -and -not $dockerCmd) {
        Set-ItResult -Skipped -Because "Neither Python nor Docker is available"
    }

    # Clean up any previous build artifacts
    $distPath = Join-Path $script:testAppPath 'dist'
    if (Test-Path -Path $distPath) {
        Remove-Item -Path $distPath -Recurse -Force
    }

    $pycachePath = Join-Path $script:testAppPath '__pycache__'
    if (Test-Path -Path $pycachePath) {
        Remove-Item -Path $pycachePath -Recurse -Force
    }
}

Describe "Python Package Starter - Integration Tests" -Tag "Python-Tasks" {
    Context "Format Task" {
        It "should format Python files successfully" {
            $result = Invoke-Bolt -Arguments @('format')
            $result.ExitCode | Should -Be 0 -Because "Format task should succeed"
        }
    }

    Context "Lint Task" {
        It "should validate Python files successfully" {
            $result = Invoke-Bolt -Arguments @('lint')
            $result.ExitCode | Should -Be 0 -Because "Lint task should succeed"
        }
    }

    Context "Test Task" {
        It "should run pytest successfully" {
            $result = Invoke-Bolt -Arguments @('test')
            $result.ExitCode | Should -Be 0 -Because "Test task should succeed"
        }
    }

    Context "Build Task" {
        It "should complete build pipeline successfully" {
            $result = Invoke-Bolt -Arguments @('build')
            $result.ExitCode | Should -Be 0 -Because "Build task should succeed"
        }
    }
}
