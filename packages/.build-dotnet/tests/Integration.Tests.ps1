#Requires -Version 7.0

Describe ".NET Package Starter - Integration Tests" -Tag "DotNet-Tasks" {
    BeforeAll {
        # Check for dotnet CLI or Docker availability
        $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        
        if (-not $dotnetCmd -and -not $dockerCmd) {
            Set-ItResult -Skipped -Because ".NET SDK or Docker not installed"
        }

        $packagePath = Join-Path $PSScriptRoot ".."
        $testProjectPath = Join-Path $PSScriptRoot "app"
        
        # Store original location
        $originalLocation = Get-Location
    }

    AfterAll {
        # Restore original location
        Set-Location $originalLocation
    }

    Context "Format Task" {
        It "should format .NET projects successfully" {
            $formatScript = Join-Path $packagePath "Invoke-Format.ps1"
            & $formatScript
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Restore Task" {
        It "should restore NuGet packages successfully" {
            $restoreScript = Join-Path $packagePath "Invoke-Restore.ps1"
            & $restoreScript
            $LASTEXITCODE | Should -Be 0
        }

        It "should create obj directories after restore" {
            $objDir = Join-Path $testProjectPath "obj"
            Test-Path $objDir | Should -Be $true
        }
    }

    Context "Test Task" {
        It "should run .NET tests successfully" {
            $testScript = Join-Path $packagePath "Invoke-Test.ps1"
            & $testScript
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Build Task" {
        It "should build .NET projects successfully" {
            $buildScript = Join-Path $packagePath "Invoke-Build.ps1"
            & $buildScript
            $LASTEXITCODE | Should -Be 0
        }

        It "should create bin directory after build" {
            $binDir = Join-Path $testProjectPath "bin"
            Test-Path $binDir | Should -Be $true
        }

        It "should create output assembly" {
            $binDir = Join-Path $testProjectPath "bin"
            $dllFiles = Get-ChildItem -Path $binDir -Filter "HelloWorld.dll" -Recurse -File -ErrorAction SilentlyContinue
            $dllFiles | Should -Not -BeNullOrEmpty
        }
    }

    Context "Full Build Pipeline" {
        It "should complete full pipeline (format -> restore -> test -> build)" {
            $buildScript = Join-Path $packagePath "Invoke-Build.ps1"
            & $buildScript
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Docker Fallback Detection" {
        It "tasks should detect dotnet or docker" {
            $formatScript = Join-Path $packagePath "Invoke-Format.ps1"
            $content = Get-Content -Path $formatScript -Raw
            
            # Should have detection logic
            $content | Should -Match "Get-Command dotnet"
            $content | Should -Match "Get-Command docker"
        }
    }
}
