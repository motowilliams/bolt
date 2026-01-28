#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for Terraform package starter
.DESCRIPTION
    End-to-end tests that verify Terraform tasks work correctly
    with actual Terraform CLI or Docker.
#>

BeforeAll {
    # Check if Terraform or Docker is available
    $script:terraformCmd = Get-Command terraform -ErrorAction SilentlyContinue
    $script:dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    
    if (-not $script:terraformCmd -and -not $script:dockerCmd) {
        Set-ItResult -Skipped -Because "Neither Terraform CLI nor Docker is installed"
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
    
    $script:testProjectPath = Join-Path $PSScriptRoot "tf"
    
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
    
    # Clean up any existing Terraform state from previous tests
    $stateFiles = Get-ChildItem -Path $script:testProjectPath -Filter ".terraform*" -Force -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $stateFiles) {
        if ($file.PSIsContainer) {
            Remove-Item -Path $file.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Clean up any plan files
    $planFiles = Get-ChildItem -Path $script:testProjectPath -Filter "*.tfplan" -Force -ErrorAction SilentlyContinue
    foreach ($file in $planFiles) {
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Terraform Package Starter - Integration Tests' -Tag 'Terraform-Tasks' {
    Context 'Format Task' {
        It 'Should format Terraform files successfully' {
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Validate Task' {
        It 'Should validate Terraform configuration successfully' {
            $result = Invoke-Bolt -Arguments @('validate') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Plan Task' {
        It 'Should generate Terraform execution plan' {
            $result = Invoke-Bolt -Arguments @('plan') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
            
            # Verify plan file was created
            $planFile = Join-Path $script:testProjectPath "terraform.tfplan"
            Test-Path $planFile | Should -Be $true
        }
    }

    Context 'Apply Task (Dry Run)' {
        # Note: We don't actually apply changes in tests to avoid side effects
        # Instead, we verify the task script exists and has correct metadata
        It 'Should have apply task with proper dependencies' {
            $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
            $applyScript = Join-Path $moduleRoot "Invoke-Apply.ps1"
            
            Test-Path $applyScript | Should -Be $true
            
            $content = Get-Content $applyScript -Raw
            $content | Should -Match '# DEPENDS:.*format.*validate.*plan'
        }
    }
}

AfterAll {
    # Clean up test artifacts
    if ($script:testProjectPath) {
        # Remove Terraform state and plan files
        $cleanupItems = @(
            ".terraform",
            ".terraform.lock.hcl",
            "*.tfplan",
            "terraform.tfstate",
            "terraform.tfstate.backup",
            "output.txt"  # File created by example Terraform config
        )
        
        foreach ($pattern in $cleanupItems) {
            $items = Get-ChildItem -Path $script:testProjectPath -Filter $pattern -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.PSIsContainer) {
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
                else {
                    Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
