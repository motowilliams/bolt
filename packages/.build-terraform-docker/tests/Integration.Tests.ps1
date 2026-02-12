#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Integration tests for Terraform Docker tasks
.DESCRIPTION
    End-to-end tests that actually execute format, validate, plan, and apply tasks
    in Docker containers. Requires Docker to be installed and running.
    Tagged with Package-Package-Terraform-Tasks-Docker to differentiate from non-Docker variant.
#>

BeforeAll {
    # Get module root (parent of tests directory)
    $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
    $projectRoot = $moduleRoot

    # Get project root (parent of module directory)
    $currentPath = $projectRoot
    while ($currentPath -and $currentPath -ne (Split-Path -Parent $currentPath)) {
        if (Test-Path (Join-Path $currentPath '.git')) {
            $projectRoot = $currentPath
            break
        }
        $currentPath = Split-Path -Parent $currentPath
    }
    $script:BoltScriptPath = Join-Path $projectRoot 'bolt.ps1'

    $script:TerraformAppPath = Join-Path $PSScriptRoot 'tf'

    # Check for Docker availability
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    $script:hasDocker = ($null -ne $dockerCmd)

    if ($script:hasDocker) {
        # Verify Docker daemon is running
        try {
            $null = docker ps 2>&1
            $script:dockerRunning = $LASTEXITCODE -eq 0
        }
        catch {
            $script:dockerRunning = $false
        }
    }
    else {
        $script:dockerRunning = $false
    }

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
}

Describe 'Docker Task Integration Tests' -Tag 'Package-Package-Terraform-Tasks-Docker' {
    Context 'Format Task Integration' {
        It 'Should format Terraform files in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:TerraformAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('format') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Validate Task Integration' {
        It 'Should validate Terraform files in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:TerraformAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('validate') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Plan Task Integration' {
        It 'Should create Terraform plan in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:TerraformAppPath | Should -Be $true
            $result = Invoke-Bolt -Arguments @('plan') -Parameters @{ Only = $true }
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Apply Task Integration' {
        It 'Should apply Terraform configuration in Docker container' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:TerraformAppPath | Should -Be $true

            # Run apply with auto-approve for testing
            $env:TF_AUTO_APPROVE = "true"
            try {
                $result = Invoke-Bolt -Arguments @('apply') -Parameters @{ Only = $true }
                $result.ExitCode | Should -Be 0

                # Verify the output file was created
                $outputFile = Join-Path $script:TerraformAppPath 'output.txt'
                Test-Path $outputFile | Should -Be $true
            }
            finally {
                Remove-Item -Path Env:\TF_AUTO_APPROVE -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Full Pipeline Integration' {
        It 'Should execute full pipeline with dependencies in Docker' {
            if (-not $script:hasDocker) {
                Set-ItResult -Skipped -Because "Docker CLI is not installed"
                return
            }

            if (-not $script:dockerRunning) {
                Set-ItResult -Skipped -Because "Docker daemon is not running"
                return
            }

            Test-Path $script:TerraformAppPath | Should -Be $true

            # Run apply with auto-approve for testing
            $env:TF_AUTO_APPROVE = "true"
            try {
                $result = Invoke-Bolt -Arguments @('apply')
                $result.ExitCode | Should -Be 0

                # Verify the output file was created
                $outputFile = Join-Path $script:TerraformAppPath 'output.txt'
                Test-Path $outputFile | Should -Be $true
            }
            finally {
                Remove-Item -Path Env:\TF_AUTO_APPROVE -ErrorAction SilentlyContinue
            }
        }
    }
}
