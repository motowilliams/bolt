#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for TypeScript tasks
.DESCRIPTION
    Tests the format, lint, test, and build tasks.
    These tests verify task structure, metadata, and dependencies.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Split-Path -Parent $PSScriptRoot

    $script:FormatTaskPath = Join-Path $moduleRoot 'Invoke-Format.ps1'
    $script:LintTaskPath = Join-Path $moduleRoot 'Invoke-Lint.ps1'
    $script:TestTaskPath = Join-Path $moduleRoot 'Invoke-Test.ps1'
    $script:BuildTaskPath = Join-Path $moduleRoot 'Invoke-Build.ps1'

    # Test project paths for configuration validation
    $script:TestProjectPath = $null
    if ($env:BOLT_TYPESCRIPT_PATH) {
        $script:TestProjectPath = $env:BOLT_TYPESCRIPT_PATH
    }
    elseif (Test-Path (Join-Path $moduleRoot 'tests' 'app')) {
        $script:TestProjectPath = Join-Path $moduleRoot 'tests' 'app'
    }
}

Describe 'Task Validation' -Tag 'Package-Typescript-Tasks' {
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

        It 'Should check for tool availability' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                # Should check for node/npm availability
                $content | Should -Match '(Get-Command|Test-Path|npm|node)'
            }
        }
    }

    Context 'Lint Task' {
        It 'Should exist' {
            Test-Path $script:LintTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:LintTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:LintTaskPath -Raw
            $content | Should -Match '# TASK: lint'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format task' {
            $content = Get-Content $script:LintTaskPath -Raw
            $content | Should -Match '# DEPENDS:.*format'
        }

        It 'Should check for tool availability' {
            $content = Get-Content $script:LintTaskPath -Raw
            # Should check for node/npm availability
            $content | Should -Match '(Get-Command|Test-Path|npm|node)'
        }
    }

    Context 'Test Task' {
        It 'Should exist' {
            Test-Path $script:TestTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:TestTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:TestTaskPath -Raw
            $content | Should -Match '# TASK: test'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format and lint tasks' {
            $content = Get-Content $script:TestTaskPath -Raw
            $content | Should -Match '# DEPENDS:.*format.*lint'
        }

        It 'Should check for tool availability' {
            $content = Get-Content $script:TestTaskPath -Raw
            # Should check for node/npm availability
            $content | Should -Match '(Get-Command|Test-Path|npm|node)'
        }
    }

    Context 'Build Task' {
        It 'Should exist' {
            Test-Path $script:BuildTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:BuildTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It 'Should have proper task metadata' {
            $content = Get-Content $script:BuildTaskPath -Raw
            $content | Should -Match '# TASK: build'
            $content | Should -Match '# DESCRIPTION:'
        }

        It 'Should depend on format, lint, and test tasks' {
            $content = Get-Content $script:BuildTaskPath -Raw
            $content | Should -Match '# DEPENDS:.*format.*lint.*test'
        }

        It 'Should check for tool availability' {
            $content = Get-Content $script:BuildTaskPath -Raw
            # Should check for node/npm availability
            $content | Should -Match '(Get-Command|Test-Path|npm|node)'
        }
    }

    Context 'Configuration' {
        It 'Should have package.json in test project' {
            if ($script:TestProjectPath) {
                $packageJsonPath = Join-Path $script:TestProjectPath 'package.json'
                Test-Path $packageJsonPath | Should -Be $true
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_TYPESCRIPT_PATH not configured"
            }
        }

        It 'Should have tsconfig.json in test project' {
            if ($script:TestProjectPath) {
                $tsconfigPath = Join-Path $script:TestProjectPath 'tsconfig.json'
                Test-Path $tsconfigPath | Should -Be $true
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_TYPESCRIPT_PATH not configured"
            }
        }

        It 'Should have proper npm scripts defined' {
            if ($script:TestProjectPath) {
                $packageJsonPath = Join-Path $script:TestProjectPath 'package.json'
                if (Test-Path $packageJsonPath) {
                    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    $packageJson.scripts | Should -Not -BeNullOrEmpty
                    # Should have at least build or test script
                    ($packageJson.scripts.PSObject.Properties.Name -contains 'build' -or
                     $packageJson.scripts.PSObject.Properties.Name -contains 'test') | Should -Be $true
                }
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_TYPESCRIPT_PATH not configured"
            }
        }
    }
}
