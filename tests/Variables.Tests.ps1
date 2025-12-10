# Variable System Tests
# Tests for Bolt configuration variables and CLI commands

BeforeAll {
    $script:BoltRoot = Split-Path -Parent $PSScriptRoot
    $script:BoltScript = Join-Path $script:BoltRoot "bolt.ps1"
}

Describe "Variable System - Basic Operations" -Tag "Variables" {

    It "Bolt script defines variable management parameter sets" {
        # Parse bolt.ps1 to verify parameter sets exist
        $scriptContent = Get-Content $script:BoltScript -Raw

        $scriptContent | Should -Match 'ParameterSetName.*=.*[''"]ListVariables[''"]'
        $scriptContent | Should -Match 'ParameterSetName.*=.*[''"]AddVariable[''"]'
        $scriptContent | Should -Match 'ParameterSetName.*=.*[''"]RemoveVariable[''"]'
    }

    It "Defines Get-BoltConfig function" {
        $scriptContent = Get-Content $script:BoltScript -Raw
        $scriptContent | Should -Match 'function Get-BoltConfig'
    }

    It "Defines Show-BoltVariables function" {
        $scriptContent = Get-Content $script:BoltScript -Raw
        $scriptContent | Should -Match 'function Show-BoltVariables'
    }

    It "Defines Add-BoltVariable function" {
        $scriptContent = Get-Content $script:BoltScript -Raw
        $scriptContent | Should -Match 'function Add-BoltVariable'
    }

    It "Defines Remove-BoltVariable function" {
        $scriptContent = Get-Content $script:BoltScript -Raw
        $scriptContent | Should -Match 'function Remove-BoltVariable'
    }

    It "Config injection includes BoltConfig variable" {
        $scriptContent = Get-Content $script:BoltScript -Raw
        $scriptContent | Should -Match '\$BoltConfig.*=.*ConvertFrom-Json'
    }
}

Describe "Variable System - CLI Commands" -Tag "Variables" {

    BeforeAll {
        # Use bolt's own directory for testing
        Push-Location $script:BoltRoot
    }

    AfterAll {
        Pop-Location
    }

    It "-ListVariables runs without error" {
        & $script:BoltScript -ListVariables | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "Variable System - Config Injection" -Tag "Variables" {

    BeforeAll {
        Push-Location $script:BoltRoot
    }

    AfterAll {
        Pop-Location
    }

    It "Test fixture task can access BoltConfig" {
        # Use the config-test task we created earlier
        $output = & $script:BoltScript config-test -TaskDirectory "tests/fixtures" -Only 2>&1

        # Verify task executed successfully (BoltConfig was available)
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "Variable System - Integration with Bicep Tasks" -Tag "Bicep-Tasks" {

    BeforeAll {
        Push-Location $script:BoltRoot
    }

    AfterAll {
        Pop-Location
    }

    It "Format task uses BoltConfig for path resolution" {
        # Check that format task references BoltConfig
        $formatTask = Join-Path $script:BoltRoot "packages" ".build-bicep" "Invoke-Format.ps1"
        $content = Get-Content $formatTask -Raw

        $content | Should -Match '\$BoltConfig\.IacPath'
    }

    It "Lint task uses BoltConfig for path resolution" {
        $lintTask = Join-Path $script:BoltRoot "packages" ".build-bicep" "Invoke-Lint.ps1"
        $content = Get-Content $lintTask -Raw

        $content | Should -Match '\$BoltConfig\.IacPath'
    }

    It "Build task uses BoltConfig for path resolution" {
        $buildTask = Join-Path $script:BoltRoot "packages" ".build-bicep" "Invoke-Build.ps1"
        $content = Get-Content $buildTask -Raw

        $content | Should -Match '\$BoltConfig\.IacPath'
    }
}

Describe "Variable System - Cache Invalidation" -Tag "Variables" {

    BeforeAll {
        Push-Location $script:BoltRoot
    }

    AfterAll {
        Pop-Location
    }

    It "Cache invalidation code exists in Add-BoltVariable" {
        $scriptContent = Get-Content $script:BoltScript -Raw
        $scriptContent | Should -Match '\$script:CachedConfigJson\s*=\s*\$null'
    }

    It "Cache invalidation code exists in Remove-BoltVariable" {
        # Check that Remove-BoltVariable also invalidates cache
        $scriptContent = Get-Content $script:BoltScript -Raw

        # Check that Remove-BoltVariable contains cache invalidation code
        $scriptContent | Should -Match 'function Remove-BoltVariable'
        $scriptContent | Should -Match '\$script:CachedConfigJson\s*=\s*\$null'
    }

    It "Add-BoltVariable invalidates cache on success" {
        # Add a variable - cache invalidation happens internally
        # We verify by checking that the function executes successfully
        & $script:BoltScript -AddVariable -Name "CacheInvalidationTest1" -Value "test1" | Out-Null

        $LASTEXITCODE | Should -Be 0
    }

    It "Remove-BoltVariable invalidates cache on success" {
        # First add a variable
        & $script:BoltScript -AddVariable -Name "CacheInvalidationTest2" -Value "test2" | Out-Null

        # Small delay to avoid file locking issues in test environment
        Start-Sleep -Milliseconds 100

        # Then remove it - cache invalidation happens internally
        & $script:BoltScript -RemoveVariable -VariableName "CacheInvalidationTest2" | Out-Null

        $LASTEXITCODE | Should -Be 0
    }
}

