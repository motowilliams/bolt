#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for release package scripts
.DESCRIPTION
    Tests Build-PackageArchives.ps1 and package-specific Create-Release.ps1 scripts.
#>

BeforeAll {
    # Get project root
    $moduleRoot = Resolve-Path -Path (Split-Path -Path $PSScriptRoot -Parent)
    $script:BuildPackageArchivesPath = Join-Path -Path $moduleRoot -ChildPath '.scripts' | 
                                       Join-Path -ChildPath 'release' | 
                                       Join-Path -ChildPath 'Build-PackageArchives.ps1'
    $script:BicepCreateReleasePath = Join-Path -Path $moduleRoot -ChildPath 'packages' | 
                                     Join-Path -ChildPath '.build-bicep' | 
                                     Join-Path -ChildPath 'Create-Release.ps1'
    $script:PackagesDir = Join-Path -Path $moduleRoot -ChildPath 'packages'

    # Helper function to get a temp directory
    function Get-TempTestPath {
        $tempDir = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $tempPath = Join-Path -Path $tempDir -ChildPath "BoltReleaseTest_$(Get-Random)"
        if (-not (Test-Path -Path $tempPath)) {
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        }
        return $tempPath
    }

    # Helper function to clean up temp paths
    function Remove-TempTestPath {
        param([string]$Path)
        if (Test-Path -Path $Path) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Build-PackageArchives.ps1 Script Validation' -Tag 'Release' {
    It 'Should exist and be a valid PowerShell script' {
        $script:BuildPackageArchivesPath | Should -Exist
        Test-Path -Path $script:BuildPackageArchivesPath | Should -Be $true
    }

    It 'Should require PowerShell 7.0+' {
        $content = Get-Content -Path $script:BuildPackageArchivesPath -Raw
        $content | Should -Match '#Requires -Version 7.0'
    }

    It 'Should have CmdletBinding attribute' {
        $content = Get-Content -Path $script:BuildPackageArchivesPath -Raw
        $content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It 'Should have required parameters' {
        $content = Get-Content -Path $script:BuildPackageArchivesPath -Raw
        $content | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true\)\]'
        $content | Should -Match '\[string\]\$Version'
    }
}

Describe 'Bicep Package Create-Release.ps1 Script Validation' -Tag 'Release', 'Bicep-Tasks' {
    It 'Should exist and be a valid PowerShell script' {
        $script:BicepCreateReleasePath | Should -Exist
        Test-Path -Path $script:BicepCreateReleasePath | Should -Be $true
    }

    It 'Should require PowerShell 7.0+' {
        $content = Get-Content -Path $script:BicepCreateReleasePath -Raw
        $content | Should -Match '#Requires -Version 7.0'
    }

    It 'Should have CmdletBinding attribute' {
        $content = Get-Content -Path $script:BicepCreateReleasePath -Raw
        $content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It 'Should accept Version parameter' {
        $content = Get-Content -Path $script:BicepCreateReleasePath -Raw
        $content | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true\)\]'
        $content | Should -Match '\[string\]\$Version'
    }

    It 'Should accept OutputDirectory parameter' {
        $content = Get-Content -Path $script:BicepCreateReleasePath -Raw
        $content | Should -Match '\[string\]\$OutputDirectory'
    }
}

Describe 'Build-PackageArchives.ps1 Functionality' -Tag 'Release' {
    BeforeEach {
        $script:TempOutput = Get-TempTestPath
    }

    AfterEach {
        Remove-TempTestPath -Path $script:TempOutput
    }

    It 'Should discover .build-bicep package' {
        $output = & pwsh -File $script:BuildPackageArchivesPath `
                        -Version "0.1.0-test" `
                        -OutputDirectory $script:TempOutput 2>&1
        
        $outputStr = $output -join "`n"
        $outputStr | Should -Match 'Found 1 starter package'
        $outputStr | Should -Match '\.build-bicep'
    }

    It 'Should create archive for bicep package' {
        & pwsh -File $script:BuildPackageArchivesPath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $archivePath = Join-Path -Path $script:TempOutput -ChildPath "bolt-starter-bicep-0.1.0-test.zip"
        Test-Path -Path $archivePath | Should -Be $true
    }

    It 'Should create checksum for bicep package' {
        & pwsh -File $script:BuildPackageArchivesPath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $checksumPath = Join-Path -Path $script:TempOutput -ChildPath "bolt-starter-bicep-0.1.0-test.zip.sha256"
        Test-Path -Path $checksumPath | Should -Be $true
    }

    It 'Should exit with 0 on success' {
        & pwsh -File $script:BuildPackageArchivesPath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $LASTEXITCODE | Should -Be 0
    }

    It 'Should handle non-existent packages directory gracefully' {
        $fakeDir = Join-Path -Path $script:TempOutput -ChildPath "nonexistent"
        
        $output = & pwsh -File $script:BuildPackageArchivesPath `
                        -Version "0.1.0-test" `
                        -PackagesDirectory $fakeDir `
                        -OutputDirectory $script:TempOutput 2>&1
        
        $LASTEXITCODE | Should -Be 0
        $outputStr = $output -join "`n"
        $outputStr | Should -Match 'No packages directory found'
    }
}

Describe 'Bicep Create-Release.ps1 Functionality' -Tag 'Release', 'Bicep-Tasks' {
    BeforeEach {
        $script:TempOutput = Get-TempTestPath
    }

    AfterEach {
        Remove-TempTestPath -Path $script:TempOutput
    }

    It 'Should create archive with correct naming' {
        & pwsh -File $script:BicepCreateReleasePath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $archivePath = Join-Path -Path $script:TempOutput -ChildPath "bolt-starter-bicep-0.1.0-test.zip"
        Test-Path -Path $archivePath | Should -Be $true
    }

    It 'Should include task files in archive' {
        & pwsh -File $script:BicepCreateReleasePath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $archivePath = Join-Path -Path $script:TempOutput -ChildPath "bolt-starter-bicep-0.1.0-test.zip"
        
        # Extract and verify contents
        $extractPath = Join-Path -Path $script:TempOutput -ChildPath "extracted"
        Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force
        
        Test-Path -Path (Join-Path -Path $extractPath -ChildPath "Invoke-Build.ps1") | Should -Be $true
        Test-Path -Path (Join-Path -Path $extractPath -ChildPath "Invoke-Format.ps1") | Should -Be $true
        Test-Path -Path (Join-Path -Path $extractPath -ChildPath "Invoke-Lint.ps1") | Should -Be $true
    }

    It 'Should generate valid SHA256 checksum' {
        & pwsh -File $script:BicepCreateReleasePath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $archivePath = Join-Path -Path $script:TempOutput -ChildPath "bolt-starter-bicep-0.1.0-test.zip"
        $checksumPath = Join-Path -Path $script:TempOutput -ChildPath "bolt-starter-bicep-0.1.0-test.zip.sha256"
        
        Test-Path -Path $checksumPath | Should -Be $true
        
        # Verify checksum is valid
        $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash
        $checksumContent = Get-Content -Path $checksumPath
        $checksumContent | Should -Match $actualHash
    }

    It 'Should exit with 0 on success' {
        & pwsh -File $script:BicepCreateReleasePath `
              -Version "0.1.0-test" `
              -OutputDirectory $script:TempOutput | Out-Null
        
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Package Release Convention Compliance' -Tag 'Release' {
    It 'Should follow bolt-starter-{name}-{version}.zip naming convention' {
        $tempOutput = Get-TempTestPath
        
        try {
            & pwsh -File $script:BicepCreateReleasePath `
                  -Version "1.2.3" `
                  -OutputDirectory $tempOutput | Out-Null
            
            $archivePath = Join-Path -Path $tempOutput -ChildPath "bolt-starter-bicep-1.2.3.zip"
            Test-Path -Path $archivePath | Should -Be $true
        }
        finally {
            Remove-TempTestPath -Path $tempOutput
        }
    }

    It 'Should create matching checksum file' {
        $tempOutput = Get-TempTestPath
        
        try {
            & pwsh -File $script:BicepCreateReleasePath `
                  -Version "1.2.3" `
                  -OutputDirectory $tempOutput | Out-Null
            
            $checksumPath = Join-Path -Path $tempOutput -ChildPath "bolt-starter-bicep-1.2.3.zip.sha256"
            Test-Path -Path $checksumPath | Should -Be $true
        }
        finally {
            Remove-TempTestPath -Path $tempOutput
        }
    }
}
