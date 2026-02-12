#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Python Docker tasks
.DESCRIPTION
    Tests the format, lint, test, and build tasks.
    These tests verify task structure, metadata, and dependencies.
    Tagged with Package-Python-Tasks-Docker to differentiate from non-Docker variant.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Split-Path -Parent $PSScriptRoot

    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:LintTaskPath = Join-Path $moduleRoot 'Invoke-Lint.ps1'
    $script:TestTaskPath = Join-Path $moduleRoot 'Invoke-Test.ps1'
    $script:BuildTaskPath = Join-Path $moduleRoot 'Invoke-Build.ps1'
    $script:DockerfilePath = Join-Path $moduleRoot 'Dockerfile'
}

Describe 'Task Validation' -Tag 'Package-Python-Tasks-Docker' {
    Context 'Format Task' {
        It 'Should exist' {
            Test-Path $script:FormatTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
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

        It 'Should reference Docker' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match 'docker'
            }
        }
    }

    Context 'Lint Task' {
        It 'Should exist' {
            Test-Path $script:LintTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# TASK: lint'
            $content | Should -Match '# DESCRIPTION:'
            $content | Should -Match '# DEPENDS:'
        }

        It 'Should depend on format task' {
            $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*format'
        }

        It 'Should reference Docker' {
            $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
            $content | Should -Match 'docker'
        }
    }

    Context 'Test Task' {
        It 'Should exist' {
            Test-Path $script:TestTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $content = Get-Content $script:TestTaskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:TestTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# TASK: test'
            $content | Should -Match '# DESCRIPTION:'
            $content | Should -Match '# DEPENDS:'
        }

        It 'Should depend on lint task' {
            $content = Get-Content $script:TestTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*lint'
        }

        It 'Should reference Docker' {
            $content = Get-Content $script:TestTaskPath -Raw -ErrorAction Stop
            $content | Should -Match 'docker'
        }
    }

    Context 'Build Task' {
        It 'Should exist' {
            Test-Path $script:BuildTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# TASK: build'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format, lint, and test tasks' {
            $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*format.*lint.*test'
        }

        It 'Should reference Docker' {
            $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
            $content | Should -Match 'docker'
        }
    }

    Context 'Dockerfile' {
        It 'Should exist' {
            Test-Path $script:DockerfilePath | Should -Be $true
        }

        It 'Should use Python base image' {
            $content = Get-Content $script:DockerfilePath -Raw -ErrorAction Stop
            $content | Should -Match 'FROM.*python'
        }

        It 'Should set working directory' {
            $content = Get-Content $script:DockerfilePath -Raw -ErrorAction Stop
            $content | Should -Match 'WORKDIR'
        }
    }
}
