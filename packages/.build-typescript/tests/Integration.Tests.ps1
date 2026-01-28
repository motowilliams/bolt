#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for TypeScript tasks
.DESCRIPTION
    End-to-end tests that validate task execution with the example TypeScript project.
    These tests require npm or Docker to be available.
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
    
    # Check for npm or Docker availability
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    
    if (-not $npmCmd -and -not $dockerCmd) {
        Set-ItResult -Skipped -Because "Neither npm nor Docker is available"
    }
    
    # Clean up any previous build artifacts
    $distPath = Join-Path $script:testAppPath 'dist'
    if (Test-Path -Path $distPath) {
        Remove-Item -Path $distPath -Recurse -Force
    }
    
    $nodeModulesPath = Join-Path $script:testAppPath 'node_modules'
    if (Test-Path -Path $nodeModulesPath) {
        Remove-Item -Path $nodeModulesPath -Recurse -Force
    }
}

Describe 'TypeScript Package Starter - Integration Tests' -Tag 'TypeScript-Tasks' {
    Context 'Format Task' {
        It 'Should format files successfully' {
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Lint Task' {
        It 'Should validate files successfully' {
            $result = Invoke-Bolt -Arguments @('lint') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Test Task' {
        It 'Should run tests successfully' {
            $result = Invoke-Bolt -Arguments @('test') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Build Task' {
        It 'Should compile TypeScript successfully' {
            $result = Invoke-Bolt -Arguments @('build') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }

        It 'Should generate JavaScript files in dist/' {
            $distPath = Join-Path $script:testAppPath 'dist'
            Test-Path -Path $distPath | Should -Be $true
            
            $jsFiles = Get-ChildItem -Path $distPath -Filter "*.js" -File
            $jsFiles.Count | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    # Clean up build artifacts
    $distPath = Join-Path $script:testAppPath 'dist'
    if (Test-Path -Path $distPath) {
        Remove-Item -Path $distPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $nodeModulesPath = Join-Path $script:testAppPath 'node_modules'
    if (Test-Path -Path $nodeModulesPath) {
        Remove-Item -Path $nodeModulesPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
