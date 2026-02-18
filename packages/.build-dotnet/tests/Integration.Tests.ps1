#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for .NET tasks
.DESCRIPTION
    End-to-end tests that actually execute format, lint, test, and build tasks.
    Tagged with Package-Dotnet-Tasks to differentiate from Docker variant.
#>


    BeforeAll {
        # Check for dotnet CLI availability
        $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue

        if (-not $dotnetCmd) {
            Set-ItResult -Skipped -Because ".NET SDK not installed"
        }

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

        $script:testProjectPath = Join-Path $PSScriptRoot "app"

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

        # Store original location
        $originalLocation = Get-Location
    }

Describe ".NET Package Starter - Integration Tests" -Tag "Package-Dotnet-Tasks" {
    AfterAll {
        # Restore original location
        Set-Location $originalLocation
    }

    Context "Format Task" {
        It "should format .NET projects successfully" {
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Restore Task" {
        It "should restore NuGet packages successfully" {
            $result = Invoke-Bolt -Arguments @('restore') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Test Task" {
        It "should run .NET tests successfully" {
            $result = Invoke-Bolt -Arguments @('test') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Build Task" {
        It "should build .NET projects successfully" {
            $result = Invoke-Bolt -Arguments @('build') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Full Build Pipeline" {
        It "should complete full pipeline (format -> restore -> test -> build)" {
            $result = Invoke-Bolt -Arguments @('build')
            $result.ExitCode | Should -Be 0
        }
    }
}
