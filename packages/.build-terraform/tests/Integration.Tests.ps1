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
    
    $script:packagePath = Split-Path -Parent $PSScriptRoot
    $script:testProjectPath = Join-Path $PSScriptRoot "tf"
    
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
            $formatScript = Join-Path $script:packagePath "Invoke-Format.ps1"
            
            # Run format task
            & $formatScript
            
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Validate Task' {
        It 'Should validate Terraform configuration successfully' {
            $validateScript = Join-Path $script:packagePath "Invoke-Validate.ps1"
            
            # Run validate task
            & $validateScript
            
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Plan Task' {
        It 'Should generate Terraform execution plan' {
            $planScript = Join-Path $script:packagePath "Invoke-Plan.ps1"
            
            # Run plan task
            & $planScript
            
            $LASTEXITCODE | Should -Be 0
            
            # Verify plan file was created
            $planFile = Join-Path $script:testProjectPath "terraform.tfplan"
            Test-Path $planFile | Should -Be $true
        }
    }

    Context 'Apply Task (Dry Run)' {
        # Note: We don't actually apply changes in tests to avoid side effects
        # Instead, we verify the task script exists and has correct metadata
        It 'Should have apply task with proper dependencies' {
            $applyScript = Join-Path $script:packagePath "Invoke-Apply.ps1"
            
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
