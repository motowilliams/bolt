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
        It "Should discover tasks from .build/bicep subdirectory" {
            # Create .build/bicep subdirectory with a task
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $bicepPath = Join-Path -Path $buildPath -ChildPath 'bicep'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            
            $taskContent = @'
# TASK: format
# DESCRIPTION: Formats Bicep files
# DEPENDS: 

Write-Host "Formatting Bicep files" -ForegroundColor Cyan
exit 0
'@
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-Format.ps1') -Value $taskContent
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'bicep-format'
            $result.Output | Should -Match '\[project:bicep\]'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should discover tasks from .build/golang subdirectory" {
            # Create .build/golang subdirectory with a task
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $golangPath = Join-Path -Path $buildPath -ChildPath 'golang'
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            $taskContent = @'
# TASK: test
# DESCRIPTION: Runs Go tests
# DEPENDS: 

Write-Host "Running Go tests" -ForegroundColor Cyan
exit 0
'@
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-Test.ps1') -Value $taskContent
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'golang-test'
            $result.Output | Should -Match '\[project:golang\]'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should execute tasks from namespaced subdirectories" {
            # Create .build/test subdirectory with a task
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $testPath = Join-Path -Path $buildPath -ChildPath 'test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            $taskContent = @'
# TASK: hello
# DESCRIPTION: Says hello
# DEPENDS: 

Write-Host "Hello from namespace!" -ForegroundColor Cyan
exit 0
'@
            Set-Content -Path (Join-Path -Path $testPath -ChildPath 'Invoke-Hello.ps1') -Value $taskContent
            
            $result = Invoke-Bolt -Arguments @('test-hello')
            
            $result.Output | Should -Match 'Hello from namespace!'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Multiple Namespace Discovery" {
        It "Should discover tasks from multiple namespaced subdirectories" {
            # Create multiple namespaced subdirectories
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $bicepPath = Join-Path -Path $buildPath -ChildPath 'bicep'
            $golangPath = Join-Path -Path $buildPath -ChildPath 'golang'
            New-Item -ItemType Directory -Path $bicepPath -Force | Out-Null
            New-Item -ItemType Directory -Path $golangPath -Force | Out-Null
            
            # Add tasks to each
            Set-Content -Path (Join-Path -Path $bicepPath -ChildPath 'Invoke-Format.ps1') -Value @'
# TASK: format
# DESCRIPTION: Formats Bicep files
Write-Host "Bicep format" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $golangPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: test
# DESCRIPTION: Runs Go tests
Write-Host "Go test" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'bicep-format.*\[project:bicep\]'
            $result.Output | Should -Match 'golang-test.*\[project:golang\]'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should discover tasks from both root .build and namespaced subdirectories" {
            # Create tasks in both .build root and .build/test subdirectory
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $testPath = Join-Path -Path $buildPath -ChildPath 'test'
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $buildPath -ChildPath 'Invoke-Default.ps1') -Value @'
# TASK: default-task
# DESCRIPTION: Default task
Write-Host "Default task" -ForegroundColor Cyan
exit 0
'@
            
            Set-Content -Path (Join-Path -Path $testPath -ChildPath 'Invoke-TestTask.ps1') -Value @'
# TASK: task
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
    
    Context "Task Name Prefixing" {
        It "Should prefix task names with namespace" {
            # Create same base task name in multiple namespaces
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $bicepPath = Join-Path -Path $buildPath -ChildPath 'bicep'
            $golangPath = Join-Path -Path $buildPath -ChildPath 'golang'
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
            
            # Should show both tasks with namespace prefixes
            $result.Output | Should -Match 'bicep-build'
            $result.Output | Should -Match 'golang-build'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should execute correct namespaced task" {
            # Create same base task name in multiple namespaces
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $bicepPath = Join-Path -Path $buildPath -ChildPath 'bicep'
            $golangPath = Join-Path -Path $buildPath -ChildPath 'golang'
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
            
            # Execute bicep-build
            $result1 = Invoke-Bolt -Arguments @('bicep-build')
            $result1.Output | Should -Match 'Bicep build executed'
            $result1.Output | Should -Not -Match 'Go build executed'
            
            # Execute golang-build
            $result2 = Invoke-Bolt -Arguments @('golang-build')
            $result2.Output | Should -Match 'Go build executed'
            $result2.Output | Should -Not -Match 'Bicep build executed'
        }
        
        It "Should keep root-level tasks without prefix" {
            # Create task in .build root and .build/test subdirectory with same base name
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $testPath = Join-Path -Path $buildPath -ChildPath 'test'
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
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            # Should have both 'build' (root) and 'test-build' (namespaced)
            $result.Output | Should -Match '\bbuild\b(?!-)'  # 'build' without hyphen after
            $result.Output | Should -Match 'test-build'
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
            # Create a custom task directory structure
            $customPath = Join-Path -Path $script:TempTestRoot -ChildPath 'custom-tasks'
            New-Item -ItemType Directory -Path $customPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $customPath -ChildPath 'Invoke-Custom.ps1') -Value @'
# TASK: custom-task
# DESCRIPTION: Custom task
Write-Host "Custom task" -ForegroundColor Cyan
exit 0
'@
            
            # Also create .build with a subdirectory to ensure it's not scanned
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $testPath = Join-Path -Path $buildPath -ChildPath 'test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $testPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: test
# DESCRIPTION: Test task
Write-Host "Test" -ForegroundColor Cyan
exit 0
'@
            
            # Use -TaskDirectory to point to custom directory
            $result = Invoke-Bolt -Arguments @('-TaskDirectory', 'custom-tasks', '-ListTasks')
            
            # Should only show custom task, not namespaced test task
            $result.Output | Should -Match 'custom-task'
            $result.Output | Should -Not -Match 'test-test'
            $result.ExitCode | Should -Be 0
        }
    }
    
    Context "Namespace Validation" {
        It "Should skip subdirectories with invalid namespace names" {
            # Create .build with invalid subdirectory (uppercase)
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $invalidPath = Join-Path -Path $buildPath -ChildPath 'INVALID'
            New-Item -ItemType Directory -Path $invalidPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $invalidPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: task
# DESCRIPTION: Invalid task
Write-Host "Invalid" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            # Should warn about invalid directory (warnings go to stderr)
            $combinedOutput = $result.Error + $result.Output
            $combinedOutput | Should -Match "Skipping directory.*invalid characters"
            # Should not include the task with INVALID prefix
            $result.Output | Should -Not -Match 'INVALID-task'
            $result.ExitCode | Should -Be 0
        }
        
        It "Should accept valid lowercase namespaces with hyphens" {
            $buildPath = Join-Path -Path $script:TempTestRoot -ChildPath '.build'
            $validPath = Join-Path -Path $buildPath -ChildPath 'my-namespace'
            New-Item -ItemType Directory -Path $validPath -Force | Out-Null
            
            Set-Content -Path (Join-Path -Path $validPath -ChildPath 'Invoke-Test.ps1') -Value @'
# TASK: task
# DESCRIPTION: Valid task
Write-Host "Valid" -ForegroundColor Cyan
exit 0
'@
            
            $result = Invoke-Bolt -Arguments @('-ListTasks')
            
            $result.Output | Should -Match 'my-namespace-task.*\[project:my-namespace\]'
            $result.ExitCode | Should -Be 0
        }
    }
}
