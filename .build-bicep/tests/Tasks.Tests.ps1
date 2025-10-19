#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for project tasks
.DESCRIPTION
    Tests the format, lint, and build tasks.
    These tests verify task structure, metadata, and dependencies.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Split-Path -Parent $PSScriptRoot

    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:LintTaskPath = Join-Path $moduleRoot 'Invoke-Lint.ps1'
    $script:BuildTaskPath = Join-Path $moduleRoot 'Invoke-Build.ps1'
}

Describe 'Task Validation' -Tag 'Bicep-Tasks' {
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

        It 'Should have format alias' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match '# TASK:.*fmt'
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

        It 'Should not declare dependencies in metadata' {
            $content = Get-Content $script:LintTaskPath -Raw
            # Lint task doesn't declare dependencies - format is run by user
            $content | Should -Not -Match '# DEPENDS:'
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
