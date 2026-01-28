#Requires -Version 7.0

Describe ".NET Package Starter - Integration Tests" -Tag "DotNet-Tasks" {
    BeforeAll {
        # Check for dotnet CLI or Docker availability
        $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        
        if (-not $dotnetCmd -and -not $dockerCmd) {
            Set-ItResult -Skipped -Because ".NET SDK or Docker not installed"
        }

        # Get module root (parent of tests directory)
        $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
        $projectRoot = $moduleRoot
        
        # Get project root (find .git directory)
        $currentPath = $projectRoot
        while ($currentPath -and $currentPath -ne (Split-Path -Parent $currentPath)) {
            if (Test-Path (Join-Path $currentPath '.git')) {
                $projectRoot = $currentPath
                break
            }
            $currentPath = Split-Path -Parent $currentPath
        }
        $script:BoltScriptPath = Join-Path $projectRoot 'bolt.ps1'
        
        $script:testProjectPath = Join-Path $PSScriptRoot "app"
        
        # Helper function to invoke bolt with captured output
        function Invoke-Bolt {
            param(
                [Parameter()]
                [string[]]$Arguments = @(),

                [Parameter()]
                [hashtable]$Parameters = @{}
            )

            # Always use the module root task directory for these tests
            # Convert absolute path to relative path from project root
            $relativePath = [System.IO.Path]::GetRelativePath($projectRoot, $moduleRoot)
            $Parameters['TaskDirectory'] = $relativePath

            # Build splatting hashtable for named parameters
            $splatParams = @{}
            foreach ($key in $Parameters.Keys) {
                $splatParams[$key] = $Parameters[$key]
            }

            # Add positional arguments if provided
            if ($Arguments.Count -gt 0) {
                $splatParams['Task'] = $Arguments
            }

            # Execute with splatting
            $output = & $script:BoltScriptPath @splatParams 2>&1
            $exitCode = $LASTEXITCODE

            return @{
                Output   = $output
                ExitCode = $exitCode
                Success  = $exitCode -eq 0
            }
        }
        
        # Store original location
        $originalLocation = Get-Location
    }

    AfterAll {
        # Restore original location
        Set-Location $originalLocation
    }

    Context "Format Task" {
        It "should format .NET projects successfully" {
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Restore Task" {
        It "should restore NuGet packages successfully" {
            $result = Invoke-Bolt -Arguments @('restore') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }

        It "should create obj directories after restore" {
            $objDir = Join-Path $script:testProjectPath "obj"
            Test-Path $objDir | Should -Be $true
        }
    }

    Context "Test Task" {
        It "should run .NET tests successfully" {
            $result = Invoke-Bolt -Arguments @('test') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Build Task" {
        It "should build .NET projects successfully" {
            $result = Invoke-Bolt -Arguments @('build') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }

        It "should create bin directory after build" {
            $binDir = Join-Path $script:testProjectPath "bin"
            Test-Path $binDir | Should -Be $true
        }

        It "should create output assembly" {
            $binDir = Join-Path $script:testProjectPath "bin"
            $dllFiles = Get-ChildItem -Path $binDir -Filter "HelloWorld.dll" -Recurse -File -ErrorAction SilentlyContinue
            $dllFiles | Should -Not -BeNullOrEmpty
        }
    }

    Context "Full Build Pipeline" {
        It "should complete full pipeline (format -> restore -> test -> build)" {
            $result = Invoke-Bolt -Arguments @('build')
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Docker Fallback Detection" {
        It "tasks should detect dotnet or docker" {
            $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
            $formatScript = Join-Path $moduleRoot "Invoke-Format.ps1"
            $content = Get-Content -Path $formatScript -Raw
            
            # Should have detection logic
            $content | Should -Match "Get-Command dotnet"
            $content | Should -Match "Get-Command docker"
        }
    }
}
