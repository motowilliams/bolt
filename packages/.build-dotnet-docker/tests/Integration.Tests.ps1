#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for .NET Docker tasks
.DESCRIPTION
    End-to-end tests that actually execute format, lint, test, and build tasks
    in Docker containers. Requires Docker to be installed and running.
    Tagged with Package-Dotnet-Tasks-Docker to differentiate from non-Docker variant.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
    $projectRoot = $moduleRoot

    # Get project root (parent of module directory)
    $currentPath = $projectRoot
    while ($currentPath -and $currentPath -ne (Split-Path -Parent $currentPath)) {
        if (Test-Path (Join-Path $currentPath '.git')) {
            $projectRoot = $currentPath
            break
        }
        $currentPath = Split-Path -Parent $currentPath
    }
    $script:BoltScriptPath = Join-Path $projectRoot 'bolt.ps1'

    $script:DotNetAppPath = Join-Path $PSScriptRoot 'app'

    # Check for Docker availability
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    $script:hasDocker = ($null -ne $dockerCmd)

    if ($script:hasDocker) {
        # Verify Docker daemon is running
        try {
            $null = docker ps 2>&1
            $script:dockerRunning = $LASTEXITCODE -eq 0
        }
        catch {
            $script:dockerRunning = $false
        }
    }
    else {
        $script:dockerRunning = $false
    }

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

Describe 'Docker Task Integration Tests' -Tag 'Package-Dotnet-Tasks-Docker' {
    Context 'Format Task Integration' {
        It 'Should format .NET files in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:DotNetAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Test Task Integration' {
        It 'Should run .NET tests in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:DotNetAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('test') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Build Task Integration' {
        It 'Should build .NET application in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:DotNetAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('build') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0

            # Verify binary was created
            $binPath = Join-Path $script:DotNetAppPath 'bin'
            Test-Path $binPath | Should -Be $true
        }
    }

    Context 'Full Pipeline Integration' {
        It 'Should execute full build pipeline with dependencies in Docker' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:DotNetAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('build')
            $result.ExitCode | Should -Be 0

            # Verify binary was created
            $binPath = Join-Path $script:DotNetAppPath 'bin'
            Test-Path $binPath | Should -Be $true
        }
    }
}
