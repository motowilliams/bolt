#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for project tasks
.DESCRIPTION
    End-to-end tests that actually execute format, lint, and build tasks
    against real infrastructure files. Requires Bicep CLI to be installed.
#>

BeforeAll {
    # Get .build-bicep root (parent of tests directory)
    $bicepRoot = Split-Path -Parent $PSScriptRoot

    # Get project root (parent of .build-bicep directory)
    $projectRoot = Split-Path -Parent $bicepRoot

    $script:GoshScriptPath = Join-Path $projectRoot 'gosh.ps1'
    $script:IacPath = Join-Path $PSScriptRoot 'iac'

    # Helper function to invoke gosh with captured output
    function Invoke-Gosh {
        param(
            [Parameter()]
            [string[]]$Arguments = @(),

            [Parameter()]
            [hashtable]$Parameters = @{}
        )

        # Always use the .build-bicep task directory for these tests
        $Parameters['TaskDirectory'] = $bicepRoot

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

Describe 'Task Integration Tests' -Tag 'Tasks' {
    Context 'Format Task Integration' {
        It 'Should format Bicep files if bicep CLI is available' {
            # Check if Bicep CLI is available
            $bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
            if (-not $bicepCmd) {
                Set-ItResult -Skipped -Because "Bicep CLI not installed"
                return
            }

            Test-Path $script:IacPath | Should -Be $true
            $result = Invoke-Gosh -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Lint Task Integration' {
        It 'Should lint Bicep files if bicep CLI is available' {
            # Check if Bicep CLI is available
            $bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
            if (-not $bicepCmd) {
                Set-ItResult -Skipped -Because "Bicep CLI not installed"
                return
            }

            Test-Path $script:IacPath | Should -Be $true
            $result = Invoke-Gosh -Arguments @('lint') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Build Task Integration' {
        It 'Should build Bicep files if bicep CLI is available' {
            # Check if Bicep CLI is available
            $bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
            if (-not $bicepCmd) {
                Set-ItResult -Skipped -Because "Bicep CLI not installed"
                return
            }

            Test-Path $script:IacPath | Should -Be $true
            $result = Invoke-Gosh -Arguments @('build') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Full Build Pipeline' {
        It 'Should execute complete build pipeline with dependencies' {
            # Check if Bicep CLI is available
            $bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
            if (-not $bicepCmd) {
                Set-ItResult -Skipped -Because "Bicep CLI not installed"
                return
            }

            Test-Path $script:IacPath | Should -Be $true
            # Run build without -Only flag to test full dependency chain
            $result = Invoke-Gosh -Arguments @('build')
            $result.ExitCode | Should -Be 0
        }
    }
}
