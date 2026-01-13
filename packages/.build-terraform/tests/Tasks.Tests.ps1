#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Terraform package starter tasks
.DESCRIPTION
    Tests the format, validate, plan, and apply tasks.
    These tests verify task structure, metadata, and dependencies.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Split-Path -Parent $PSScriptRoot

    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:ValidateTaskPath = Join-Path $moduleRoot 'Invoke-Validate.ps1'
    $script:PlanTaskPath = Join-Path $moduleRoot 'Invoke-Plan.ps1'
    $script:ApplyTaskPath = Join-Path $moduleRoot 'Invoke-Apply.ps1'
}

Describe 'Task Validation' -Tag 'Terraform-Tasks' {
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

        It 'Should have fmt alias' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match '# TASK:.*fmt'
            }
        }

        It 'Should check for Terraform or Docker' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match 'Get-Command terraform'
                $content | Should -Match 'Get-Command docker'
            }
        }
    }

    Context 'Validate Task' {
        It 'Should exist' {
            Test-Path $script:ValidateTaskPath | Should -Be $true
        }

        It 'Should have valid syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ValidateTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:ValidateTaskPath -Raw
            $content | Should -Match '# TASK: validate'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should check for Terraform or Docker' {
            $content = Get-Content $script:ValidateTaskPath -Raw
            $content | Should -Match 'Get-Command terraform'
            $content | Should -Match 'Get-Command docker'
        }
    }

    Context 'Plan Task' {
        It 'Should exist' {
            Test-Path $script:PlanTaskPath | Should -Be $true
        }

        It 'Should have valid syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:PlanTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:PlanTaskPath -Raw
            $content | Should -Match '# TASK: plan'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format and validate tasks' {
            $content = Get-Content $script:PlanTaskPath -Raw
            $content | Should -Match '# DEPENDS:.*format.*validate'
        }

        It 'Should check for Terraform or Docker' {
            $content = Get-Content $script:PlanTaskPath -Raw
            $content | Should -Match 'Get-Command terraform'
            $content | Should -Match 'Get-Command docker'
        }
    }

    Context 'Apply Task' {
        It 'Should exist' {
            Test-Path $script:ApplyTaskPath | Should -Be $true
        }

        It 'Should have valid syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ApplyTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:ApplyTaskPath -Raw
            $content | Should -Match '# TASK: apply'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should have deploy alias' {
            $content = Get-Content $script:ApplyTaskPath -Raw
            $content | Should -Match '# TASK:.*deploy'
        }

        It 'Should depend on format, validate, and plan tasks' {
            $content = Get-Content $script:ApplyTaskPath -Raw
            $content | Should -Match '# DEPENDS:.*format.*validate.*plan'
        }

        It 'Should have safety warning' {
            $content = Get-Content $script:ApplyTaskPath -Raw
            $content | Should -Match 'WARNING'
            $content | Should -Match 'Start-Sleep'
        }

        It 'Should check for Terraform or Docker' {
            $content = Get-Content $script:ApplyTaskPath -Raw
            $content | Should -Match 'Get-Command terraform'
            $content | Should -Match 'Get-Command docker'
        }
    }
}
