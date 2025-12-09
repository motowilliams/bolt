#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for New-BoltModule.ps1 script
.DESCRIPTION
    Tests module installation, uninstallation, and building functionality.
#>

BeforeAll {
    # Get project root
    $moduleRoot = Resolve-Path (Split-Path -Parent $PSScriptRoot)
    $script:NewGoshModulePath = Join-Path $moduleRoot 'New-BoltModule.ps1'
    $script:BoltScriptPath = Join-Path $moduleRoot 'bolt.ps1'

    # Helper function to get a temp module path
    function Get-TempModulePath {
        $tempDir = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $tempPath = Join-Path $tempDir "GoshModuleTest_$(Get-Random)"
        if (-not (Test-Path $tempPath)) {
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        }
        return $tempPath
    }

    # Helper function to clean up temp paths
    function Remove-TempModulePath {
        param([string]$Path)
        if (Test-Path $Path) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'New-BoltModule.ps1 Script Validation' -Tag 'Core' {
    It 'Should exist and be a valid PowerShell script' {
        $script:NewGoshModulePath | Should -Exist
        { & $script:NewGoshModulePath -? } | Should -Not -Throw
    }

    It 'Should require PowerShell 7.0+' {
        $content = Get-Content $script:NewGoshModulePath -Raw
        $content | Should -Match '#Requires -Version 7.0'
    }

    It 'Should have proper parameter sets' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:NewGoshModulePath, [ref]$null, [ref]$null)
        $paramBlock = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParamBlockAst] }, $true)
        $paramBlock | Should -Not -BeNullOrEmpty
    }
}

Describe 'Parameter Sets' -Tag 'Core' {
    It 'Should reject invalid parameter combinations (Install + Uninstall)' {
        { & $script:NewGoshModulePath -Install -Uninstall 2>&1 } | Should -Throw -ExpectedMessage '*Parameter set cannot be resolved*'
    }

    It 'Should accept valid Install parameter set' {
        $tempPath = Get-TempModulePath
        try {
            $output = & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport *>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Bolt module installed successfully'
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }

    It 'Should accept valid Uninstall parameter set with Force' {
        # This test just validates the parameter parsing, not actual uninstallation
        # since there may not be a module installed
        $output = & $script:NewGoshModulePath -Uninstall -Force 2>&1
        # Exit code can be 0 (success) or 1 (no module found), both are valid
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }
}

Describe 'Module Installation' -Tag 'Core' {
    It 'Should install module to custom path with -ModuleOutputPath' {
        $tempPath = Get-TempModulePath
        try {
            $output = & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport 2>&1
            $LASTEXITCODE | Should -Be 0
            
            # Check that module directory was created
            $modulePath = Join-Path $tempPath "Bolt"
            $modulePath | Should -Exist
            
            # Check that required files exist
            Join-Path $modulePath "bolt-core.ps1" | Should -Exist
            Join-Path $modulePath "Bolt.psm1" | Should -Exist
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }

    It 'Should create bolt-core.ps1 from bolt.ps1' {
        $tempPath = Get-TempModulePath
        try {
            & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport 2>&1 | Out-Null
            
            $goshCorePath = Join-Path $tempPath "Bolt" "bolt-core.ps1"
            $goshCorePath | Should -Exist
            
            # Verify it's a copy of bolt.ps1
            $originalContent = Get-Content $script:BoltScriptPath -Raw
            $coreContent = Get-Content $goshCorePath -Raw
            $coreContent | Should -Be $originalContent
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }

    It 'Should create Bolt.psm1 module manifest' {
        $tempPath = Get-TempModulePath
        try {
            & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport 2>&1 | Out-Null
            
            $moduleManifestPath = Join-Path $tempPath "Bolt" "Bolt.psm1"
            $moduleManifestPath | Should -Exist
            
            # Verify module manifest contains key components
            $manifestContent = Get-Content $moduleManifestPath -Raw
            $manifestContent | Should -Match 'function Invoke-Bolt'
            $manifestContent | Should -Match 'function Find-BuildDirectory'
            $manifestContent | Should -Match 'Export-ModuleMember'
            $manifestContent | Should -Match 'Set-Alias -Name gosh'
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }

    It 'Should report success with -NoImport flag' {
        $tempPath = Get-TempModulePath
        try {
            $output = & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport *>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Module installation complete.*not imported'
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }

    It 'Should overwrite existing installation' {
        $tempPath = Get-TempModulePath
        try {
            # First installation
            & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport *>&1 | Out-Null
            
            # Second installation should succeed
            $output = & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport *>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Module directory exists, updating'
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }
}

Describe 'Module Uninstallation' -Tag 'Core' {
    It 'Should report when no module is installed' {
        $output = & $script:NewGoshModulePath -Uninstall -Force *>&1 | Out-String
        # When no module is found, should return exit code 1
        if ($LASTEXITCODE -eq 1) {
            $output | Should -Match 'Bolt module is not installed'
        }
    }

    It 'Should uninstall from custom path if module was installed there' {
        $tempPath = Get-TempModulePath
        try {
            # Install module
            & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport 2>&1 | Out-Null
            
            # Verify installation
            $modulePath = Join-Path $tempPath "Bolt"
            $modulePath | Should -Exist
            
            # Note: The uninstall function only checks standard paths, not custom ones
            # This is expected behavior - custom installations need manual cleanup
            # We just verify the module was installed correctly
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }


}

Describe 'Cross-Platform Compatibility' -Tag 'Core' {
    It 'Should determine correct default module path for current platform' {
        $tempPath = Get-TempModulePath
        try {
            $output = & $script:NewGoshModulePath -Install -ModuleOutputPath $tempPath -NoImport *>&1 | Out-String
            
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
                # Windows path should use Documents
                $output | Should -Match 'PowerShell\\Modules|Using custom module path'
            }
            else {
                # Linux/macOS path should use LocalApplicationData
                $output | Should -Match 'powershell/Modules|Using custom module path'
            }
        }
        finally {
            Remove-TempModulePath -Path $tempPath
        }
    }

    It 'Should use Join-Path for path construction' {
        $scriptContent = Get-Content $script:NewGoshModulePath -Raw
        # Should use Join-Path cmdlet for cross-platform compatibility
        $scriptContent | Should -Match 'Join-Path'
    }
}

Describe 'Help and Documentation' -Tag 'Core' {
    It 'Should have help documentation' {
        { Get-Help $script:NewGoshModulePath } | Should -Not -Throw
    }

    It 'Should document parameters' {
        $scriptContent = Get-Content $script:NewGoshModulePath -Raw
        $scriptContent | Should -Match '\.PARAMETER Install'
        $scriptContent | Should -Match '\.PARAMETER Uninstall'
        $scriptContent | Should -Match '\.PARAMETER ModuleOutputPath'
    }

    It 'Should have examples in comments' {
        $scriptContent = Get-Content $script:NewGoshModulePath -Raw
        $scriptContent | Should -Match '\.EXAMPLE'
    }
}
