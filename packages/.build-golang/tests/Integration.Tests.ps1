#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for golang tasks
.DESCRIPTION
    End-to-end tests that actually execute format, lint, test, and build tasks
    against a real Go application. Requires Go CLI to be installed.
#>

BeforeAll {
    # Get module root (parent of tests directory); tests live in a 'tests' directory
    $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
    $projectRoot = $moduleRoot

    # Get project root (parent of module directory)
    $currentPath = $projectRoot
    while ($currentPath -and $currentPath -ne (Split-Path -Parent $currentPath)) {
        Write-Host "Checking path: $currentPath for .git directory" -ForegroundColor DarkGray
        if (Test-Path (Join-Path $currentPath '.git')) {
            $projectRoot = $currentPath
            break
        }
        $currentPath = Split-Path -Parent $currentPath
    }
    $script:BoltScriptPath = Join-Path $projectRoot 'bolt.ps1'

    $script:GoAppPath = Join-Path $PSScriptRoot 'app'

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
}

Describe 'Task Integration Tests' -Tag 'Golang-Tasks' {
    Context 'Format Task Integration' {
        It 'Should format Go files if Go CLI is available' {
            # Check if Go CLI is available
            $goCmd = Get-Command go -ErrorAction SilentlyContinue
            if (-not $goCmd) {
                Set-ItResult -Skipped -Because "Go CLI not installed"
                return
            }

            Test-Path $script:GoAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Lint Task Integration' {
        It 'Should lint Go files if Go CLI is available' {
            # Check if Go CLI is available
            $goCmd = Get-Command go -ErrorAction SilentlyContinue
            if (-not $goCmd) {
                Set-ItResult -Skipped -Because "Go CLI not installed"
                return
            }

            Test-Path $script:GoAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('lint') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Test Task Integration' {
        It 'Should run Go tests if Go CLI is available' {
            # Check if Go CLI is available
            $goCmd = Get-Command go -ErrorAction SilentlyContinue
            if (-not $goCmd) {
                Set-ItResult -Skipped -Because "Go CLI not installed"
                return
            }

            Test-Path $script:GoAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('test') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Build Task Integration' {
        It 'Should build Go application if Go CLI is available' {
            # Check if Go CLI is available
            $goCmd = Get-Command go -ErrorAction SilentlyContinue
            if (-not $goCmd) {
                Set-ItResult -Skipped -Because "Go CLI not installed"
                return
            }

            Test-Path $script:GoAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('build') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
            
            # Verify binary was created
            $binPath = Join-Path $script:GoAppPath 'bin'
            Test-Path $binPath | Should -Be $true
        }
    }

    Context 'Full Build Pipeline' {
        It 'Should execute complete build pipeline with dependencies' {
            # Check if Go CLI is available
            $goCmd = Get-Command go -ErrorAction SilentlyContinue
            if (-not $goCmd) {
                Set-ItResult -Skipped -Because "Go CLI not installed"
                return
            }

            Test-Path $script:GoAppPath | Should -Be $true
            # Run build without -Only flag to test full dependency chain
            $result = Invoke-Bolt -Arguments @('build')
            $result.ExitCode | Should -Be 0
            
            # Verify binary was created
            $binPath = Join-Path $script:GoAppPath 'bin'
            Test-Path $binPath | Should -Be $true
        }
    }
}
