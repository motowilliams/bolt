#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for project-specific Bicep tasks
.DESCRIPTION
    Tests the format, lint, and build tasks that ship with the Gosh project.
    These tests verify task structure, metadata, and dependencies.
#>

BeforeAll {
    # Get project root (parent of tests directory)
    $projectRoot = Split-Path -Parent $PSScriptRoot

    $script:BuildPath = Join-Path $projectRoot '.build'
    $script:FormatTaskPath = Join-Path $script:BuildPath 'Invoke-Format.ps1'
    $script:LintTaskPath = Join-Path $script:BuildPath 'Invoke-Lint.ps1'
    $script:BuildTaskPath = Join-Path $script:BuildPath 'Invoke-Build.ps1'
}

Describe 'Project Task Validation' {
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
