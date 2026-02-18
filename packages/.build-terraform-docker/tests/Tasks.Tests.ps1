#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Terraform Docker tasks
.DESCRIPTION
    Tests the format, validate, plan, and apply tasks.
    These tests verify task structure, metadata, and dependencies.
    Tagged with Package-Terraform-Tasks-Docker to differentiate from non-Docker variant.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Split-Path -Parent $PSScriptRoot

    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:ValidateTaskPath = Join-Path $moduleRoot 'Invoke-Validate.ps1'
    $script:PlanTaskPath = Join-Path $moduleRoot 'Invoke-Plan.ps1'
    $script:ApplyTaskPath = Join-Path $moduleRoot 'Invoke-Apply.ps1'
    $script:DockerfilePath = Join-Path $moduleRoot 'Dockerfile'
}

Describe 'Task Validation' -Tag 'Package-Terraform-Tasks-Docker' {
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

    Context 'Validate Task' {
        It 'Should exist' {
            Test-Path $script:ValidateTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $content = Get-Content $script:ValidateTaskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:ValidateTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# TASK: validate'
            $content | Should -Match '# DESCRIPTION:'
            $content | Should -Match '# DEPENDS:'
        }

        It 'Should depend on format task' {
            $content = Get-Content $script:ValidateTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*format'
        }

        It 'Should reference Docker' {
            $content = Get-Content $script:ValidateTaskPath -Raw -ErrorAction Stop
            $content | Should -Match 'docker'
        }
    }

    Context 'Plan Task' {
        It 'Should exist' {
            Test-Path $script:PlanTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $content = Get-Content $script:PlanTaskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:PlanTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# TASK: plan'
            $content | Should -Match '# DESCRIPTION:'
            $content | Should -Match '# DEPENDS:'
        }

        It 'Should depend on validate task' {
            $content = Get-Content $script:PlanTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*validate'
        }

        It 'Should reference Docker' {
            $content = Get-Content $script:PlanTaskPath -Raw -ErrorAction Stop
            $content | Should -Match 'docker'
        }
    }

    Context 'Apply Task' {
        It 'Should exist' {
            Test-Path $script:ApplyTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $content = Get-Content $script:ApplyTaskPath -Raw -ErrorAction Stop
            { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:ApplyTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# TASK: apply'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format, validate, and plan tasks' {
            $content = Get-Content $script:ApplyTaskPath -Raw -ErrorAction Stop
            $content | Should -Match '# DEPENDS:.*format.*validate.*plan'
        }

        It 'Should reference Docker' {
            $content = Get-Content $script:ApplyTaskPath -Raw -ErrorAction Stop
            $content | Should -Match 'docker'
        }
    }

    Context 'Dockerfile' {
        It 'Should exist' {
            Test-Path $script:DockerfilePath | Should -Be $true
        }

        It 'Should use Terraform base image' {
            $content = Get-Content $script:DockerfilePath -Raw -ErrorAction Stop
            $content | Should -Match 'FROM.*terraform'
        }

        It 'Should set working directory' {
            $content = Get-Content $script:DockerfilePath -Raw -ErrorAction Stop
            $content | Should -Match 'WORKDIR'
        }
    }
}
