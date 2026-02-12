#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for .NET Docker tasks
.DESCRIPTION
    Tests the format, test, and build tasks.
    These tests verify task structure, metadata, and dependencies.
    Tagged with Package-Dotnet-Tasks-Docker to differentiate from non-Docker variant.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Split-Path -Parent $PSScriptRoot

    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:TestTaskPath = Join-Path $moduleRoot 'Invoke-Test.ps1'
    $script:BuildTaskPath = Join-Path $moduleRoot 'Invoke-Build.ps1'
    $script:RestoreTaskPath = Join-Path $moduleRoot 'Invoke-Restore.ps1'
    $script:DockerfilePath = Join-Path $moduleRoot 'Dockerfile'
}

Describe 'Task Validation' -Tag 'Package-Dotnet-Tasks-Docker' {
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

        It 'Should depend on restore task' {
            $content = Get-Content $script:TestTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*restore'
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

        It 'Should depend on format, restore, and test tasks' {
            $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*format.*restore.*test'
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

        It 'Should use .NET SDK base image' {
            $content = Get-Content $script:DockerfilePath -Raw -ErrorAction Stop
            $content | Should -Match 'FROM.*dotnet/sdk'
        }

        It 'Should set working directory' {
            $content = Get-Content $script:DockerfilePath -Raw -ErrorAction Stop
            $content | Should -Match 'WORKDIR'
        }
    }
}
