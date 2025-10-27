#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

<#
.SYNOPSIS
    Tests for P0 Output Validation implementation

.DESCRIPTION
    Validates that external command output is properly sanitized before display
    to prevent terminal injection attacks, ANSI escape sequence exploitation,
    and control character abuse.

.NOTES
    Test Tags: OutputValidation, Operational
#>

BeforeAll {
    $ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $GoshScript = Join-Path $ProjectRoot "gosh.ps1"

    # Dot-source the gosh script to access Test-CommandOutput function
    . $GoshScript
}

Describe "Output Validation - Test-CommandOutput Function" -Tag "OutputValidation", "Operational" {

    Context "Normal Output Pass-Through" {

        It "Should return empty string for empty input" {
            $result = Test-CommandOutput -Output ''

            $result | Should -Be ''
        }

        It "Should return null-safe empty string for null input" {
            $result = Test-CommandOutput -Output $null

            $result | Should -Be ''
        }

        It "Should preserve normal text output" {
            $input = "This is normal text output"

            $result = Test-CommandOutput -Output $input

            $result | Should -Be $input
        }

        It "Should preserve multi-line normal output" {
            $input = @"
Line 1
Line 2
Line 3
"@

            $result = Test-CommandOutput -Output $input

            $result | Should -Be $input
        }

        It "Should preserve newlines, carriage returns, and tabs" {
            $input = "Line1`nLine2`rLine3`tTabbed"

            $result = Test-CommandOutput -Output $input

            $result | Should -Be $input
        }
    }

    Context "ANSI Escape Sequence Removal" {

        It "Should remove ANSI color codes" {
            $input = "`e[31mRed text`e[0m"

            $result = Test-CommandOutput -Output $input

            $result | Should -Be "Red text"
            $result | Should -Not -Match '\x1b'
        }

        It "Should remove multiple ANSI sequences" {
            $input = "`e[32mGreen`e[0m and `e[33mYellow`e[0m"

            $result = Test-CommandOutput -Output $input

            $result | Should -Be "Green and Yellow"
        }

        It "Should remove ANSI cursor movement codes" {
            $input = "`e[2JClear screen`e[H"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x1b'
        }

        It "Should remove complex ANSI sequences with multiple parameters" {
            $input = "`e[1;31;42mBold red on green`e[0m"

            $result = Test-CommandOutput -Output $input

            $result | Should -Be "Bold red on green"
        }

        It "Should handle git output with ANSI color codes" {
            $input = "`e[31mM`e[0m modified.txt`n`e[32mA`e[0m new.txt"

            $result = Test-CommandOutput -Output $input

            $result | Should -Match "M modified.txt"
            $result | Should -Match "A new.txt"
            $result | Should -Not -Match '\x1b'
        }
    }

    Context "Control Character Removal" {

        It "Should remove null bytes (0x00)" {
            $input = "Text`0WithNull"

            $result = Test-CommandOutput -Output $input -WarningAction SilentlyContinue

            $result | Should -Not -Match '\x00'
            $result | Should -Match 'Text.WithNull'
        }

        It "Should warn about binary content" {
            $input = "Binary`0Content"

            $warnings = @()
            $result = Test-CommandOutput -Output $input -WarningVariable warnings

            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'Binary content detected'
        }

        It "Should remove bell character (0x07)" {
            $input = "Text`aWithBell"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x07'
        }

        It "Should remove backspace character (0x08)" {
            $input = "Text`bWithBackspace"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x08'
        }

        It "Should remove vertical tab (0x0B)" {
            $input = "Text`vWithVTab"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x0B'
        }

        It "Should remove form feed (0x0C)" {
            $input = "Text`fWithFormFeed"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x0C'
        }

        It "Should remove escape character (0x1B) when not part of ANSI sequence" {
            $input = "Text`eStandaloneEscape"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x1B(?!\[)'
        }

        It "Should remove delete character (0x7F)" {
            $input = "TextWithDelete" + [char]0x7F

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x7F'
        }

        It "Should remove C1 control characters (0x80-0x9F)" {
            $input = "Text" + [char]0x80 + "With" + [char]0x9F + "C1"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '[\x80-\x9F]'
        }
    }

    Context "Length Validation and Truncation" {

        It "Should not truncate output under MaxLength" {
            $input = "Short output"

            $result = Test-CommandOutput -Output $input -MaxLength 100

            $result | Should -Be $input
            $result | Should -Not -Match 'truncated'
        }

        It "Should truncate output exceeding MaxLength" {
            $input = "A" * 200

            $result = Test-CommandOutput -Output $input -MaxLength 100

            $result.Length | Should -BeLessOrEqual 150  # 100 + truncation message
            $result | Should -Match 'truncated'
        }

        It "Should warn when truncating by length" {
            $input = "X" * 200

            $warnings = @()
            $result = Test-CommandOutput -Output $input -MaxLength 100 -WarningVariable warnings

            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'exceeded .* characters'
        }

        It "Should use default MaxLength of 100KB" {
            $input = "Short text"

            # Should not truncate small input with default MaxLength
            $result = Test-CommandOutput -Output $input

            $result | Should -Be $input
        }
    }

    Context "Line Count Validation and Truncation" {

        It "Should not truncate output under MaxLines" {
            $input = "Line1`nLine2`nLine3"

            $result = Test-CommandOutput -Output $input -MaxLines 10

            $result | Should -Be $input
        }

        It "Should truncate output exceeding MaxLines" {
            $lines = 1..20 | ForEach-Object { "Line $_" }
            $input = $lines -join "`n"

            $result = Test-CommandOutput -Output $input -MaxLines 10

            $resultLines = $result -split '\r?\n'
            $resultLines.Count | Should -BeLessOrEqual 11  # 10 lines + truncation message
            $result | Should -Match 'truncated'
        }

        It "Should warn when truncating by line count" {
            $lines = 1..20 | ForEach-Object { "Line $_" }
            $input = $lines -join "`n"

            $warnings = @()
            $result = Test-CommandOutput -Output $input -MaxLines 10 -WarningVariable warnings

            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'exceeded .* lines'
        }

        It "Should use default MaxLines of 1000" {
            $input = "Line1`nLine2`nLine3"

            # Should not truncate small input with default MaxLines
            $result = Test-CommandOutput -Output $input

            $result | Should -Be $input
        }
    }

    Context "Malicious Input Handling" {

        It "Should sanitize git output with malicious filename containing ANSI codes" {
            $input = " M `e[31m../../../etc/passwd`e[0m"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x1b'
            $result | Should -Match 'M ../../../etc/passwd'
        }

        It "Should handle terminal bell flood attack" {
            $input = [string]::new([char]0x07, 50) + "Text"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x07'
        }

        It "Should handle backspace manipulation attempt" {
            $input = "Fake`b`b`b`bReal"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x08'
        }

        It "Should handle cursor manipulation via ANSI sequences" {
            $input = "Visible`e[H`e[KHidden"

            $result = Test-CommandOutput -Output $input

            $result | Should -Not -Match '\x1b'
            $result | Should -Match 'Visible'
            $result | Should -Match 'Hidden'
        }

        It "Should handle mixed ANSI and control characters" {
            $input = "`e[31mRed`0Null`bBack`e[0m"

            $result = Test-CommandOutput -Output $input -WarningAction SilentlyContinue

            $result | Should -Not -Match '\x1b'
            $result | Should -Not -Match '\x00'
            $result | Should -Not -Match '\x08'
        }
    }

    Context "Real-World Git Output Scenarios" {

        It "Should handle clean git status output" {
            $input = ""

            $result = Test-CommandOutput -Output $input

            $result | Should -Be ""
        }

        It "Should handle git status with modified files" {
            $input = " M file1.txt`n M file2.ps1`nA  newfile.md"

            $result = Test-CommandOutput -Output $input

            $result | Should -Match 'M file1.txt'
            $result | Should -Match 'M file2.ps1'
            $result | Should -Match 'A  newfile.md'
        }

        It "Should handle git status with special characters in filenames" {
            $input = " M `"file with spaces.txt`"`n M file!@#$.ps1"

            $result = Test-CommandOutput -Output $input

            $result | Should -Match 'file with spaces.txt'
            $result | Should -Match 'file!@#\$.ps1'
        }

        It "Should handle git error messages" {
            $input = "fatal: not a git repository (or any of the parent directories): .git"

            $result = Test-CommandOutput -Output $input

            $result | Should -Match 'fatal:'
            $result | Should -Match 'not a git repository'
        }
    }

    Context "Pipeline Support" {

        It "Should accept input from pipeline" {
            $input = "Piped input"

            $result = $input | Test-CommandOutput

            $result | Should -Be $input
        }

        It "Should process multiple pipeline inputs" {
            $inputs = @("Line1", "Line2", "Line3")

            $results = $inputs | Test-CommandOutput

            $results.Count | Should -Be 3
            $results[0] | Should -Be "Line1"
            $results[2] | Should -Be "Line3"
        }
    }

    Context "Verbose Output" {

        It "Should write verbose messages when validation occurs" {
            $input = "`e[31mAnsi text`e[0m"

            $verboseOutput = Test-CommandOutput -Output $input -Verbose 4>&1

            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Output Validation Integration" -Tag "OutputValidation", "Integration" {

    Context "check-index Task Integration" {

        BeforeAll {
            # Check if git is available
            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
        }

        It "Should use sanitized output in check-index task" {
            if (-not $gitAvailable) {
                Set-ItResult -Skipped -Because "Git is not available"
                return
            }

            # Run check-index and capture output
            $output = & $GoshScript check-index -Only 2>&1 | Out-String

            # Output should not contain ANSI escape sequences
            $output | Should -Not -Match '\x1b\['
        }
    }

    Context "Function Availability" {

        It "Should have Test-CommandOutput function defined" {
            Get-Command Test-CommandOutput -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should have proper function signature" {
            $cmd = Get-Command Test-CommandOutput

            $cmd.Parameters.Keys | Should -Contain 'Output'
            $cmd.Parameters.Keys | Should -Contain 'MaxLength'
            $cmd.Parameters.Keys | Should -Contain 'MaxLines'
        }

        It "Should support CmdletBinding" {
            $cmd = Get-Command Test-CommandOutput

            $cmd.CmdletBinding | Should -Be $true
        }

        It "Should support ValueFromPipeline on Output parameter" {
            $cmd = Get-Command Test-CommandOutput

            $cmd.Parameters['Output'].Attributes.ValueFromPipeline | Should -Contain $true
        }
    }
}
