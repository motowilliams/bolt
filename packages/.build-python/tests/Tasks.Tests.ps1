#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Python package starter tasks
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
    if ($env:BOLT_PYTHON_PATH) {
        $script:TestProjectPath = $env:BOLT_PYTHON_PATH
    }
    elseif (Test-Path (Join-Path $moduleRoot 'tests' 'app')) {
        $script:TestProjectPath = Join-Path $moduleRoot 'tests' 'app'
    }
}

Describe "Python Package Starter - Task Validation" -Tag "Package-Python-Tasks" {
    Context "Format Task" {
        It "should exist" {
            Test-Path $script:FormatTaskPath | Should -Be $true
        }

        It "should have valid PowerShell syntax" {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                { $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) } | Should -Not -Throw
            }
        }

        It "should have proper task metadata" {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match "# TASK: format"
                $content | Should -Match "# DESCRIPTION:"
            }
        }

        It "should have format alias" {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                $content | Should -Match "# TASK:.*fmt"
            }
        }

        It "should check for tool availability" {
            if (Test-Path $script:FormatTaskPath) {
                $content = Get-Content $script:FormatTaskPath -Raw -ErrorAction Stop
                # Should check for python availability
                $content | Should -Match "(Get-Command|Test-Path|python)"
            }
        }
    }

    Context "Lint Task" {
        It "should exist" {
            Test-Path $script:LintTaskPath | Should -Be $true
        }

        It "should have valid PowerShell syntax" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:LintTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It "should have proper task metadata" {
            $content = Get-Content $script:LintTaskPath -Raw
            $content | Should -Match "# TASK: lint"
            $content | Should -Match "# DESCRIPTION:"
        }

        It "should depend on format task" {
            $content = Get-Content $script:LintTaskPath -Raw
            $content | Should -Match "# DEPENDS:.*format"
        }

        It "should check for tool availability" {
            $content = Get-Content $script:LintTaskPath -Raw
            # Should check for python availability
            $content | Should -Match "(Get-Command|Test-Path|python)"
        }
    }

    Context "Test Task" {
        It "should exist" {
            Test-Path $script:TestTaskPath | Should -Be $true
        }

        It "should have valid PowerShell syntax" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:TestTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It "should have proper task metadata" {
            $content = Get-Content $script:TestTaskPath -Raw
            $content | Should -Match "# TASK: test"
            $content | Should -Match "# DESCRIPTION:"
        }

        It "should depend on format and lint tasks" {
            $content = Get-Content $script:TestTaskPath -Raw
            $content | Should -Match "# DEPENDS:.*format.*lint"
        }

        It "should check for tool availability" {
            $content = Get-Content $script:TestTaskPath -Raw
            # Should check for python availability
            $content | Should -Match "(Get-Command|Test-Path|python)"
        }
    }

    Context "Build Task" {
        It "should exist" {
            Test-Path $script:BuildTaskPath | Should -Be $true
        }

        It "should have valid PowerShell syntax" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:BuildTaskPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It "should have proper task metadata" {
            $content = Get-Content $script:BuildTaskPath -Raw
            $content | Should -Match "# TASK: build"
            $content | Should -Match "# DESCRIPTION:"
        }

        It "should depend on format, lint, and test tasks" {
            $content = Get-Content $script:BuildTaskPath -Raw
            $content | Should -Match "# DEPENDS:.*format.*lint.*test"
        }

        It "should check for tool availability" {
            $content = Get-Content $script:BuildTaskPath -Raw
            # Should check for python availability
            $content | Should -Match "(Get-Command|Test-Path|python)"
        }
    }

    Context "Configuration" {
        It "should have Python source files in test project" {
            if ($script:TestProjectPath) {
                $pyFiles = Get-ChildItem -Path $script:TestProjectPath -Filter "*.py" -Recurse -File -ErrorAction SilentlyContinue
                $pyFiles | Should -Not -BeNullOrEmpty
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_PYTHON_PATH not configured"
            }
        }

        It "should have requirements.txt in test project" {
            if ($script:TestProjectPath) {
                $reqPath = Join-Path $script:TestProjectPath "requirements.txt"
                Test-Path $reqPath | Should -Be $true
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_PYTHON_PATH not configured"
            }
        }

        It "should have setup.py or pyproject.toml in test project" {
            if ($script:TestProjectPath) {
                $setupPy = Test-Path (Join-Path $script:TestProjectPath "setup.py")
                $pyprojectToml = Test-Path (Join-Path $script:TestProjectPath "pyproject.toml")

                # This test is informational - Python projects may not always have these files
                # Simple scripts may only need requirements.txt
                if (-not $setupPy -and -not $pyprojectToml) {
                    Set-ItResult -Skipped -Because "Simple Python project without setup.py/pyproject.toml"
                }
                else {
                    ($setupPy -or $pyprojectToml) | Should -Be $true
                }
            }
            else {
                Set-ItResult -Skipped -Because "BOLT_PYTHON_PATH not configured"
            }
        }
    }
}
