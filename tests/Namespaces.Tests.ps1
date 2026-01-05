#Requires -Version 7.0

BeforeAll {
    $script:ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:BoltScriptSource = Join-Path -Path $ProjectRoot -ChildPath 'bolt.ps1'
    $script:TempTestRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "BoltNamespaceTests_$(Get-Random)"
    
    # Helper function to invoke bolt.ps1 with arguments
    function Invoke-Bolt {
        param(
            [string[]]$Arguments,
            [hashtable]$Parameters = @{}
        )
        
        $boltScriptPath = Join-Path -Path $script:TempTestRoot -ChildPath 'bolt.ps1'
        
        $params = @{
            FilePath = 'pwsh'
            ArgumentList = @('-NoProfile', '-File', $boltScriptPath) + $Arguments
            WorkingDirectory = $script:TempTestRoot
            Wait = $true
            NoNewWindow = $true
            PassThru = $true
            RedirectStandardOutput = (Join-Path -Path $script:TempTestRoot -ChildPath 'stdout.txt')
            RedirectStandardError = (Join-Path -Path $script:TempTestRoot -ChildPath 'stderr.txt')
        }
        
        foreach ($key in $Parameters.Keys) {
            $params[$key] = $Parameters[$key]
        }
        
        $process = Start-Process @params
        
        $stdout = Get-Content -Path (Join-Path -Path $script:TempTestRoot -ChildPath 'stdout.txt') -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -Path (Join-Path -Path $script:TempTestRoot -ChildPath 'stderr.txt') -Raw -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            ExitCode = $process.ExitCode
            Output = $stdout
            Error = $stderr
        }
    }
    
    # Create temp test directory and copy bolt.ps1
    New-Item -ItemType Directory -Path $script:TempTestRoot -Force | Out-Null
    Copy-Item -Path $script:BoltScriptSource -Destination (Join-Path -Path $script:TempTestRoot -ChildPath 'bolt.ps1') -Force
}

AfterAll {
    # Clean up temp test directory
    if (Test-Path -Path $script:TempTestRoot) {
        Remove-Item -Path $script:TempTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Multi-Namespace Task Discovery" -Tag "Core", "Namespaces" {
    
    BeforeEach {
        # Clean up any existing test directories in temp test root
        Get-ChildItem -Path $script:TempTestRoot -Directory -Filter '.build*' -Force -ErrorAction SilentlyContinue | 
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Context "Single Namespace Discovery" {
        It "Should discover tasks from .build-bicep directory" {
            # Create .build-bicep directory with a task
            $bicepPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-bicep'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            
            $taskContent = @'
# TASK: bicep-format
# DESCRIPTION: Formats Bicep files
# DEPENDS: 

Write-Host "Formatting Bicep files" -ForegroundColor Cyan
exit 0
'@
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-BicepFormat.ps1') -Value $taskContent
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'bicep-format'
            $result.Output | Should -Match '\[project:bicep\]'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should discover tasks from .build-golang directory" {
            # Create .build-golang directory with a task
            $golangPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-golang'
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            $taskContent = @'
# TASK: go-test
# DESCRIPTION: Runs Go tests
# DEPENDS: 

Write-Host "Running Go tests" -ForegroundColor Cyan
exit 0
'@
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-GoTest.ps1') -Value $taskContent
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'go-test'
            $result.Output | Should -Match '\[project:golang\]'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should execute tasks from namespaced directories" {
            # Create .build-test directory with a task
            $testPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            $taskContent = @'
# TASK: hello
# DESCRIPTION: Says hello
# DEPENDS: 

Write-Host "Hello from namespace!" -ForegroundColor Cyan
exit 0
'@
            Set-Content -Path (Join-Path -Path $testPath -ChildPath 'Invoke-Hello.ps1') -Value $taskContent
            
            $result = Invoke-Bolt -Arguments @('hello')
            
            $result.Output | Should -Match 'Hello from namespace!'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Multiple Namespace Discovery" {
        It "Should discover tasks from multiple namespaced directories" {
            # Create multiple namespaced directories
            $bicepPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-bicep'
            $golangPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-golang'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            # Add tasks to each
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-Format.ps1') -Value @'
# TASK: bicep-format
# DESCRIPTION: Formats Bicep files
Write-Host "Bicep format" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: go-test
# DESCRIPTION: Runs Go tests
Write-Host "Go test" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'bicep-format.*\[project:bicep\]'
            $result.Output | Should -Match 'go-test.*\[project:golang\]'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should discover tasks from both .build and .build-* directories" {
            # Create tasks in both .build and .build-test
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $testPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-test'
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $buildPath -ChildPath 'Invoke-Default.ps1') -Value @'
# TASK: default-task
# DESCRIPTION: Default task
Write-Host "Default task" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $testPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: test-task
# DESCRIPTION: Test task
Write-Host "Test task" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'default-task.*\[project\]'
            $result.Output | Should -Match 'test-task.*\[project:test\]'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Task Name Collision Detection" {
        It "Should warn about task name collisions across namespaces" {
            # Create same task name in multiple namespaces
            $bicepPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-bicep'
            $golangPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-golang'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            $taskContent1 = @'
# TASK: build
# DESCRIPTION: Builds Bicep files
Write-Host "Bicep build" -ForegroundColor Cyan
exit 0
'@
            $taskContent2 = @'
# TASK: build
# DESCRIPTION: Builds Go application
Write-Host "Go build" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-Build.ps1') -Value $taskContent1
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-Build.ps1') -Value $taskContent2
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            # Warnings go to stderr in PowerShell
            $combinedOutput = $result.Error + $result.Output
            $combinedOutput | Should -Match "Task 'build' found in multiple namespaces"
            $combinedOutput | Should -Match 'bicep.*golang'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should use first-found task when names collide" {
            # Create colliding tasks (bicep comes before golang alphabetically)
            $bicepPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-bicep'
            $golangPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-golang'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-Build.ps1') -Value @'
# TASK: build
# DESCRIPTION: Builds Bicep files
Write-Host "Bicep build executed" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-Build.ps1') -Value @'
# TASK: build
# DESCRIPTION: Builds Go application
Write-Host "Go build executed" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('build')
            
            # Should execute Bicep version (alphabetically first)
            $result.Output | Should -Match 'Bicep build executed'
            $result.Output | Should -Not -Match 'Go build executed'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should prioritize .build over .build-* directories" {
            # Create same task in .build and .build-test
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $testPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-test'
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $buildPath -ChildPath 'Invoke-Build.ps1') -Value @'
# TASK: build
# DESCRIPTION: Default build
Write-Host "Default build executed" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $testPath -ChildPath 'Invoke-Build.ps1') -Value @'
# TASK: build
# DESCRIPTION: Test build
Write-Host "Test build executed" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('build')
            
            # Should execute .build version (higher priority)
            $result.Output | Should -Match 'Default build executed'
            $result.Output | Should -Not -Match 'Test build executed'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Backward Compatibility" {
        It "Should work with only .build directory (no namespaces)" {
            # Remove any namespaced directories, keep only .build
            Get-ChildItem -Path $script:TempTestRoot -Directory -Filter '.build-*' -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $buildPath -ChildPath 'Invoke-Simple.ps1') -Value @'
# TASK: simple
# DESCRIPTION: Simple task
Write-Host "Simple task executed" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('simple')
            
            $result.Output | Should -Match 'Simple task executed'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should show [project] label for .build tasks (no namespace)" {
            # Ensure clean slate - remove all .build directories first
            Get-ChildItem -Path $script:TempTestRoot -Directory -Filter '.build*' -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            
            # Create only .build directory
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $buildPath -ChildPath 'Invoke-Default.ps1') -Value @'
# TASK: default
# DESCRIPTION: Default task
Write-Host "Default" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            # Should show [project] for the default task
            $result.Output | Should -Match 'default.*\[project\]'
            # Should NOT show any namespaced tasks
            $result.Output | Should -Not -Match '\[project:bicep\]'
            $result.Output | Should -Not -Match '\[project:golang\]'
            $result.Output | Should -Not -Match '\[project:test\]'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Custom -TaskDirectory Parameter" {
        It "Should only scan specified directory when -TaskDirectory is used" {
            # Create multiple namespaced directories
            $bicepPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-bicep'
            $golangPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-golang'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-Format.ps1') -Value @'
# TASK: bicep-format
# DESCRIPTION: Formats Bicep
Write-Host "Bicep format" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: go-test
# DESCRIPTION: Go test
Write-Host "Go test" -ForegroundColor Cyan
exit 0
'@
            
            # Use -TaskDirectory to point to specific directory
            $result = Invoke-Bolt -Arguments @('-TaskDirectory', '.build-bicep', '-ListTasks')
            
            # Should only show bicep tasks
            $result.Output | Should -Match 'bicep-format'
            $result.Output | Should -Not -Match 'go-test'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Namespace Validation" {
        It "Should skip directories with invalid namespace names" {
            # Create directory with invalid namespace (uppercase)
            $invalidPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-INVALID'
            New-Item -ItemType Directory -Path $invalidPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $invalidPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: invalid-task
# DESCRIPTION: Invalid task
Write-Host "Invalid" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            # Should warn about invalid directory (warnings go to stderr)
            $combinedOutput = $result.Error + $result.Output
            $combinedOutput | Should -Match "Skipping directory.*invalid characters"
            # Should not include the task
            $result.Output | Should -Not -Match 'invalid-task'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should accept valid lowercase namespaces with hyphens" {
            $validPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build-my-namespace'
            New-Item -ItemType Directory -Path $validPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $validPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: valid-task
# DESCRIPTION: Valid task
Write-Host "Valid" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'valid-task.*\[project:my-namespace\]'
            $result.ExitCode | Should -Be 0
        }
    }
}
