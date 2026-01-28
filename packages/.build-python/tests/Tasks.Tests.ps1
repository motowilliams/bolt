#Requires -Version 7.0

Describe "Python Package Starter - Task Validation" -Tag "Python-Tasks" {
    BeforeAll {
        $packagePath = Join-Path $PSScriptRoot ".."
        $taskFiles = Get-ChildItem -Path $packagePath -Filter "Invoke-*.ps1" -File -Force
    }

    Context "Task Files Exist" {
        It "format task should exist" {
            $formatTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Format.ps1" }
            $formatTask | Should -Not -BeNullOrEmpty
        }

        It "lint task should exist" {
            $lintTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Lint.ps1" }
            $lintTask | Should -Not -BeNullOrEmpty
        }

        It "test task should exist" {
            $testTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Test.ps1" }
            $testTask | Should -Not -BeNullOrEmpty
        }

        It "build task should exist" {
            $buildTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Build.ps1" }
            $buildTask | Should -Not -BeNullOrEmpty
        }
    }

    Context "Task Metadata" {
        It "format task should have TASK metadata" {
            $content = (Get-Content -Path "$packagePath/Invoke-Format.ps1" -First 30) -join "`n"
            $content | Should -Match "# TASK:"
        }

        It "format task should have format and fmt aliases" {
            $content = (Get-Content -Path "$packagePath/Invoke-Format.ps1" -First 30) -join "`n"
            $content | Should -Match "# TASK:\s*format,\s*fmt"
        }

        It "lint task should declare format dependency" {
            $content = (Get-Content -Path "$packagePath/Invoke-Lint.ps1" -First 30) -join "`n"
            $content | Should -Match "# DEPENDS:\s*format"
        }

        It "test task should declare format and lint dependencies" {
            $content = (Get-Content -Path "$packagePath/Invoke-Test.ps1" -First 30) -join "`n"
            $content | Should -Match "# DEPENDS:\s*format,\s*lint"
        }

        It "build task should declare all dependencies" {
            $content = (Get-Content -Path "$packagePath/Invoke-Build.ps1" -First 30) -join "`n"
            $content | Should -Match "# DEPENDS:\s*format,\s*lint,\s*test"
        }
    }

    Context "Task Structure" {
        It "all tasks should have proper PowerShell syntax" {
            foreach ($task in $taskFiles) {
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content -Path $task.FullName -Raw),
                    [ref]$errors
                )
                $errors | Should -BeNullOrEmpty -Because "$($task.Name) should have valid PowerShell syntax"
            }
        }

        It "all tasks should require PowerShell 7.0" {
            foreach ($task in $taskFiles) {
                $content = Get-Content -Path $task.FullName -First 1
                $content | Should -Match "#Requires -Version 7.0"
            }
        }
    }

    Context "Task Documentation" {
        It "all tasks should have DESCRIPTION metadata" {
            foreach ($task in $taskFiles) {
                $content = (Get-Content -Path $task.FullName -First 30) -join "`n"
                $content | Should -Match "# DESCRIPTION:" -Because "$($task.Name) should have a description"
            }
        }

        It "all tasks should have DEPENDS metadata" {
            foreach ($task in $taskFiles) {
                $content = (Get-Content -Path $task.FullName -First 30) -join "`n"
                $content | Should -Match "# DEPENDS:" -Because "$($task.Name) should declare dependencies (even if empty)"
            }
        }
    }
}
