#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Bicep tasks
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

    # Test project paths for configuration validation
    $script:TestProjectPath = $null
    if ($env:BOLT_BICEP_PATH) {
        $script:TestProjectPath = $env:BOLT_BICEP_PATH
    }
    elseif (Test-Path (Join-Path $moduleRoot 'tests' 'iac')) {
        $script:TestProjectPath = Join-Path $moduleRoot 'tests' 'iac'
    }
}

Describe 'Task Validation' -Tag 'Package-Bicep-Tasks' {
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
                # Should check for bicep availability
                $content | Should -Match '(Get-Command|Test-Path|bicep)'
            }
        }

        It 'Should not declare dependencies' {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                # Format task has no dependencies - users run format manually
                $content | Should -Not -Match '# DEPENDS:'
            }
        }
    }

    Context 'Lint Task' {
        It 'Should exist' {
            Test-Path $script:LintTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            if (Test-Path $script:LintTaskPath) {
                $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
                { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
            }
        }

        It 'Should have proper task metadata' {
            if (Test-Path $script:LintTaskPath) {
                $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
                $content | Should -Match '# TASK: lint'
                $content | Should -Match '# DESCRIPTION:'
            }
        }

        It 'Should check for tool availability' {
            if (Test-Path $script:LintTaskPath) {
                $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
                # Should check for bicep availability
                $content | Should -Match '(Get-Command|Test-Path|bicep)'
            }
        }

        It 'Should not declare dependencies' {
            if (Test-Path $script:LintTaskPath) {
                $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
                # Lint task has no dependencies - intentional Bicep design
                $content | Should -Not -Match '# DEPENDS:'
            }
        }

        It 'Should validate Bicep syntax' {
            if (Test-Path $script:LintTaskPath) {
                $content = Get-Content $script:LintTaskPath -Raw -ErrorAction Stop
                # Lint task should use bicep lint command
                $content | Should -Match 'bicep lint'
            }
        }
    }

    Context 'Build Task' {
        It 'Should exist' {
            Test-Path $script:BuildTaskPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            if (Test-Path $script:BuildTaskPath) {
                $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
                { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
            }
        }

        It 'Should have proper task metadata' {
            if (Test-Path $script:BuildTaskPath) {
                $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
                $content | Should -Match '# TASK: build'
                $content | Should -Match '# DESCRIPTION:'
            }
        }

        It 'Should depend on format and lint tasks' {
            if (Test-Path $script:BuildTaskPath) {
                $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
                $content | Should -Match '# DEPENDS:.*format.*lint'
            }
        }

        It 'Should check for tool availability' {
            if (Test-Path $script:BuildTaskPath) {
                $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
                # Should check for bicep availability
                $content | Should -Match '(Get-Command|Test-Path|bicep)'
            }
        }

        It 'Should compile Bicep to ARM templates' {
            if (Test-Path $script:BuildTaskPath) {
                $content = Get-Content $script:BuildTaskPath -Raw -ErrorAction Stop
                # Build task should invoke bicep CLI with build subcommand
                $content | Should -Match '(&|\$bicepCmd).*build'
            }
        }
    }

    Context 'Configuration' {
        It 'Should have Bicep files in test project' {
            if ($script:TestProjectPath) {
                $bicepFiles = Get-ChildItem -Path $script:TestProjectPath -Filter "*.bicep" -Recurse -File -ErrorAction SilentlyContinue
                $bicepFiles | Should -Not -BeNullOrEmpty
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_BICEP_PATH not configured"
            }
        }

        It 'Should have main Bicep files for compilation' {
            if ($script:TestProjectPath) {
                # Look for main*.bicep files (main.bicep, main.dev.bicep, etc.)
                $mainFiles = Get-ChildItem -Path $script:TestProjectPath -Filter "main*.bicep" -File -ErrorAction SilentlyContinue
                $mainFiles | Should -Not -BeNullOrEmpty
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_BICEP_PATH not configured"
            }
        }

        It 'Should have proper Bicep module structure' {
            if ($script:TestProjectPath) {
                # Check if there's either a modules directory or at least one main Bicep file
                $modulesPath = Join-Path $script:TestProjectPath "modules"
                $hasModules = Test-Path $modulesPath
                $mainFiles = Get-ChildItem -Path $script:TestProjectPath -Filter "main*.bicep" -File -ErrorAction SilentlyContinue

                ($hasModules -or ($mainFiles.Count -gt 0)) | Should -Be $true
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_BICEP_PATH not configured"
            }
        }

        It 'Should have parameters file for deployments' {
            if ($script:TestProjectPath) {
                # Look for .parameters.json files (e.g., main.parameters.json)
                $paramFiles = Get-ChildItem -Path $script:TestProjectPath -Filter "*.parameters.json" -Recurse -File -ErrorAction SilentlyContinue

                # Parameters files are common but not strictly required
                if ($paramFiles.Count -eq 0) {
                    Set-ItResult -Skipped -Because "No parameter files found (not required for all Bicep projects)"
                }
                else {
                    $paramFiles | Should -Not -BeNullOrEmpty
                }
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_BICEP_PATH not configured"
            }
        }

        It 'Should have modules directory with reusable components' {
            if ($script:TestProjectPath) {
                $modulesPath = Join-Path $script:TestProjectPath "modules"
                if (Test-Path $modulesPath) {
                    $moduleFiles = Get-ChildItem -Path $modulesPath -Filter "*.bicep" -File -ErrorAction SilentlyContinue
                    $moduleFiles | Should -Not -BeNullOrEmpty
                }
                else {
                    Set-ItResult -Skipped -Because "No modules directory found (not required for simple projects)"
                }
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_BICEP_PATH not configured"
            }
        }
    }
}
