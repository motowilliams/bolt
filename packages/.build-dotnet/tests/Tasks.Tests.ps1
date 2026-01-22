#Requires -Version 7.0

Describe ".NET Package Starter - Task Validation" -Tag "DotNet-Tasks" {
    BeforeAll {
        $packagePath = Join-Path $PSScriptRoot ".."
        $taskFiles = Get-ChildItem -Path $packagePath -Filter "Invoke-*.ps1" -File -Force
    }

    Context "Task Files Exist" {
        It "format task should exist" {
            $formatTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Format.ps1" }
            $formatTask | Should -Not -BeNullOrEmpty
        }

        It "restore task should exist" {
            $restoreTask = $taskFiles | Where-Object { $_.Name -eq "Invoke-Restore.ps1" }
            $restoreTask | Should -Not -BeNullOrEmpty
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
            $content = Get-Content -Path "$packagePath/Invoke-Format.ps1" -First 30 -Raw
            $content | Should -Match "# TASK:"
        }

        It "format task should have DESCRIPTION metadata" {
            $content = Get-Content -Path "$packagePath/Invoke-Format.ps1" -First 30 -Raw
            $content | Should -Match "# DESCRIPTION:"
        }

        It "restore task should have TASK metadata" {
            $content = Get-Content -Path "$packagePath/Invoke-Restore.ps1" -First 30 -Raw
            $content | Should -Match "# TASK:"
        }

        It "test task should have TASK metadata" {
            $content = Get-Content -Path "$packagePath/Invoke-Test.ps1" -First 30 -Raw
            $content | Should -Match "# TASK:"
        }

        It "build task should have TASK metadata" {
            $content = Get-Content -Path "$packagePath/Invoke-Build.ps1" -First 30 -Raw
            $content | Should -Match "# TASK:"
        }

        It "build task should declare dependencies" {
            $content = Get-Content -Path "$packagePath/Invoke-Build.ps1" -First 30 -Raw
            $content | Should -Match "# DEPENDS:"
        }

        It "build task should depend on format, restore, and test" {
            $content = Get-Content -Path "$packagePath/Invoke-Build.ps1" -First 30 -Raw
            $content | Should -Match "# DEPENDS:\s+format,\s+restore,\s+test"
        }
    }

    Context "Task Structure" {
        It "format task should check for dotnet CLI" {
            $content = Get-Content -Path "$packagePath/Invoke-Format.ps1" -Raw
            $content | Should -Match "Get-Command dotnet"
        }

        It "format task should have Docker fallback" {
            $content = Get-Content -Path "$packagePath/Invoke-Format.ps1" -Raw
            $content | Should -Match "Get-Command docker"
            $content | Should -Match "mcr.microsoft.com/dotnet/sdk"
        }

        It "restore task should check for dotnet CLI" {
            $content = Get-Content -Path "$packagePath/Invoke-Restore.ps1" -Raw
            $content | Should -Match "Get-Command dotnet"
        }

        It "test task should check for dotnet CLI" {
            $content = Get-Content -Path "$packagePath/Invoke-Test.ps1" -Raw
            $content | Should -Match "Get-Command dotnet"
        }

        It "build task should check for dotnet CLI" {
            $content = Get-Content -Path "$packagePath/Invoke-Build.ps1" -Raw
            $content | Should -Match "Get-Command dotnet"
        }
    }

    Context "Release Script" {
        It "Create-Release.ps1 should exist" {
            $releaseScript = Join-Path $packagePath "Create-Release.ps1"
            Test-Path $releaseScript | Should -Be $true
        }

        It "Create-Release.ps1 should have version parameter" {
            $content = Get-Content -Path "$packagePath/Create-Release.ps1" -Raw
            $content | Should -Match '\[Parameter\(Mandatory = \$true\)\]'
            $content | Should -Match '\[string\]\$Version'
        }
    }

    Context "Documentation" {
        It "README.md should exist" {
            $readme = Join-Path $packagePath "README.md"
            Test-Path $readme | Should -Be $true
        }

        It "README.md should document all tasks" {
            $content = Get-Content -Path "$packagePath/README.md" -Raw
            $content | Should -Match "format"
            $content | Should -Match "restore"
            $content | Should -Match "test"
            $content | Should -Match "build"
        }

        It "README.md should mention Docker fallback" {
            $content = Get-Content -Path "$packagePath/README.md" -Raw
            $content | Should -Match "Docker"
            $content | Should -Match "fallback"
        }
    }

    Context "Example Project" {
        It "example .NET project should exist" {
            $exampleProject = Join-Path $PSScriptRoot "app" "HelloWorld.csproj"
            Test-Path $exampleProject | Should -Be $true
        }

        It "example test project should exist" {
            $testProject = Join-Path $PSScriptRoot "app" "HelloWorld.Tests" "HelloWorld.Tests.csproj"
            Test-Path $testProject | Should -Be $true
        }

        It "example Program.cs should exist" {
            $programFile = Join-Path $PSScriptRoot "app" "Program.cs"
            Test-Path $programFile | Should -Be $true
        }

        It "example test file should exist" {
            $testFile = Join-Path $PSScriptRoot "app" "HelloWorld.Tests" "CalculatorTests.cs"
            Test-Path $testFile | Should -Be $true
        }
    }
}
