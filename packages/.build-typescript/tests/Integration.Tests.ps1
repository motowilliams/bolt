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
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $testAppPath = Join-Path $PSScriptRoot 'app'
    
    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:LintTaskPath = Join-Path $moduleRoot 'Invoke-Lint.ps1'
    $script:TestTaskPath = Join-Path $moduleRoot 'Invoke-Test.ps1'
    $script:BuildTaskPath = Join-Path $moduleRoot 'Invoke-Build.ps1'
    
    # Check for npm or Docker availability
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    
    if (-not $npmCmd -and -not $dockerCmd) {
        Set-ItResult -Skipped -Because "Neither npm nor Docker is available"
    }
    
    # Clean up any previous build artifacts
    $distPath = Join-Path $testAppPath 'dist'
    if (Test-Path -Path $distPath) {
        Remove-Item -Path $distPath -Recurse -Force
    }
    
    $nodeModulesPath = Join-Path $testAppPath 'node_modules'
    if (Test-Path -Path $nodeModulesPath) {
        Remove-Item -Path $nodeModulesPath -Recurse -Force
    }
}

Describe 'TypeScript Package Starter - Integration Tests' -Tag 'TypeScript-Tasks' {
    Context 'Format Task' {
        It 'Should format files successfully' {
            & $script:FormatTaskPath
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Lint Task' {
        It 'Should validate files successfully' {
            & $script:LintTaskPath
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Test Task' {
        It 'Should run tests successfully' {
            & $script:TestTaskPath
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Build Task' {
        It 'Should compile TypeScript successfully' {
            & $script:BuildTaskPath
            $LASTEXITCODE | Should -Be 0
        }

        It 'Should generate JavaScript files in dist/' {
            $distPath = Join-Path $testAppPath 'dist'
            Test-Path -Path $distPath | Should -Be $true
            
            $jsFiles = Get-ChildItem -Path $distPath -Filter "*.js" -File
            $jsFiles.Count | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    # Clean up build artifacts
    $testAppPath = Join-Path $PSScriptRoot 'app'
    $distPath = Join-Path $testAppPath 'dist'
    if (Test-Path -Path $distPath) {
        Remove-Item -Path $distPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $nodeModulesPath = Join-Path $testAppPath 'node_modules'
    if (Test-Path -Path $nodeModulesPath) {
        Remove-Item -Path $nodeModulesPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
