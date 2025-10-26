#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

<#
.SYNOPSIS
    Tests for RFC 9116 compliant security.txt file

.DESCRIPTION
    Validates that the .well-known/security.txt file exists and conforms
    to RFC 9116 specifications for security vulnerability disclosure.

.NOTES
    Test Tags: SecurityTxt, Operational
#>

BeforeAll {
    $ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $SecurityTxtPath = Join-Path $ProjectRoot ".well-known" "security.txt"
}

Describe "Security.txt File Compliance" -Tag "SecurityTxt", "Operational" {

    Context "File Existence and Location" {

        It "Should exist at .well-known/security.txt" {
            Test-Path $SecurityTxtPath | Should -Be $true
        }

        It "Should be readable" {
            { Get-Content $SecurityTxtPath -Raw } | Should -Not -Throw
        }
    }

    Context "RFC 9116 Required Fields" {

        BeforeAll {
            $content = Get-Content $SecurityTxtPath -Raw
        }

        It "Should contain Contact field" {
            $content | Should -Match '(?m)^Contact:\s+.+'
        }

        It "Should contain Expires field" {
            $content | Should -Match '(?m)^Expires:\s+\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z'
        }

        It "Should have Expires date in the future" {
            if ($content -match '(?m)^Expires:\s+(.+)$') {
                $expiresDate = [DateTime]::Parse($Matches[1])
                $expiresDate | Should -BeGreaterThan (Get-Date)
            } else {
                throw "Expires field not found"
            }
        }

        It "Should have Expires date within 1 year" {
            if ($content -match '(?m)^Expires:\s+(.+)$') {
                $expiresDate = [DateTime]::Parse($Matches[1])
                $oneYearFromNow = (Get-Date).AddYears(1).AddDays(7) # Allow 7 day grace period
                $expiresDate | Should -BeLessThan $oneYearFromNow
            } else {
                throw "Expires field not found"
            }
        }
    }

    Context "RFC 9116 Recommended Fields" {

        BeforeAll {
            $content = Get-Content $SecurityTxtPath -Raw
        }

        It "Should contain Preferred-Languages field" {
            $content | Should -Match '(?m)^Preferred-Languages:\s+.+'
        }

        It "Should contain Canonical field" {
            $content | Should -Match '(?m)^Canonical:\s+https?://.+'
        }

        It "Should contain Policy field" {
            $content | Should -Match '(?m)^Policy:\s+https?://.+'
        }

        It "Should link to SECURITY.md in Policy field" {
            $content | Should -Match '(?m)^Policy:\s+.*SECURITY\.md'
        }
    }

    Context "Contact Information Validity" {

        BeforeAll {
            $content = Get-Content $SecurityTxtPath -Raw
        }

        It "Should use GitHub Security Advisories for contact" {
            $content | Should -Match 'Contact:.*github\.com.*security/advisories'
        }

        It "Should use https:// for contact URL" {
            if ($content -match '(?m)^Contact:\s+(.+)$') {
                $Matches[1] | Should -Match '^https://'
            } else {
                throw "Contact field not found"
            }
        }
    }

    Context "File Format and Structure" {

        BeforeAll {
            $content = Get-Content $SecurityTxtPath -Raw
            $lines = Get-Content $SecurityTxtPath
        }

        It "Should use UTF-8 encoding" {
            $bytes = [System.IO.File]::ReadAllBytes($SecurityTxtPath)
            # Check for UTF-8 BOM or plain ASCII (valid UTF-8)
            if ($bytes.Length -ge 3) {
                $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
                # If no BOM, check that content is valid UTF-8 (ASCII is valid UTF-8)
                $isValidUTF8 = try {
                    [System.Text.Encoding]::UTF8.GetString($bytes) | Out-Null
                    $true
                } catch {
                    $false
                }
                $isValidUTF8 | Should -Be $true
            }
        }

        It "Should not contain malformed field names" {
            # Field names should be alphanumeric with hyphens
            foreach ($line in $lines) {
                if ($line -match '^([^#\s][^:]*):') {
                    $fieldName = $Matches[1]
                    $fieldName | Should -Match '^[A-Z][A-Za-z0-9\-]*$'
                }
            }
        }

        It "Should have comments starting with #" {
            $commentLines = $lines | Where-Object { $_ -match '^\s*#' }
            $commentLines.Count | Should -BeGreaterThan 0
        }
    }

    Context "Security Policy Content" {

        BeforeAll {
            $content = Get-Content $SecurityTxtPath -Raw
        }

        It "Should provide guidance on how to report vulnerabilities" {
            $content | Should -Match '(?i)report.*vulnerabilit'
        }

        It "Should mention not to use public issues" {
            $content | Should -Match '(?i)do not.*public.*issue'
        }

        It "Should include response timeline information" {
            $content | Should -Match '(?i)(48 hours|2 days|response.*within)'
        }
    }

    Context "Integration with Repository" {

        It "Should reference the GitHub repository" {
            $content = Get-Content $SecurityTxtPath -Raw
            $content | Should -Match 'github\.com/motowilliams/gosh'
        }

        It "Should be tracked in git (not in .gitignore)" {
            $gitignorePath = Join-Path $ProjectRoot ".gitignore"
            if (Test-Path $gitignorePath) {
                $gitignoreContent = Get-Content $gitignorePath -Raw
                $gitignoreContent | Should -Not -Match '\.well-known'
                $gitignoreContent | Should -Not -Match 'security\.txt'
            }
        }
    }
}
