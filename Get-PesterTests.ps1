#Requires -Version 7.0

<#
.SYNOPSIS
    Lists all Pester tests without executing them.

.DESCRIPTION
    Discovers all Pester tests without running them. By default, returns PSCustomObject
    collection (one per test) for pipeline processing. Use -Report switch for formatted
    console output with visual indicators and colors.
    Much faster than running the full test suite (~54ms vs ~2s).

.PARAMETER Path
    The path to search for test files. Defaults to current directory.

.PARAMETER Tag
    Filter tests by tag. Note: Tag filtering in discovery mode may not work as expected
    since tags are applied at Describe/Context level, not individual test level.

.PARAMETER Report
    Display formatted, human-readable report with colors and visual indicators.
    Without this switch, returns PSCustomObject collection for pipeline processing.

.EXAMPLE
    .\Get-PesterTests.ps1
    Returns collection of test objects that can be piped or filtered.

.EXAMPLE
    .\Get-PesterTests.ps1 -Report
    Displays formatted report with colors and visual indicators.

.EXAMPLE
    .\Get-PesterTests.ps1 -Path "tests/gosh.Tests.ps1"
    Returns test objects from a specific file.

.EXAMPLE
    .\Get-PesterTests.ps1 | Where-Object FileName -eq 'Security.Tests.ps1'
    Filter tests by file name.

.EXAMPLE
    .\Get-PesterTests.ps1 | Group-Object FileName | Select-Object Name, Count
    Group tests by file and show counts.

.EXAMPLE
    .\Get-PesterTests.ps1 -Tag Core -Report
    Displays formatted report filtered by Core tag (may show all tests due to tag scoping).

.NOTES
    This function uses Pester's SkipRun configuration to discover tests without executing them.
    Requires Pester 5.0 or later.
#>
[CmdletBinding()]
param(
    [string]$Path = $PWD,
    [string[]]$Tag,
    [switch]$Report
)

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Run.PassThru = $true
$config.Run.SkipRun = $true
$config.Output.Verbosity = 'None'

if ($Tag) {
    $config.Filter.Tag = $Tag
}

$result = Invoke-Pester -Configuration $config

# Return PSCustomObjects by default, or display formatted report if -Report switch is used
if ($Report) {
    # Display formatted report
    Write-Host "`nTest Discovery Summary" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Gray
    Write-Host "Total Tests Found: " -NoNewline -ForegroundColor White
    Write-Host $result.TotalCount -ForegroundColor Green
    if ($Tag) {
        Write-Host "Filtered by Tag: " -NoNewline -ForegroundColor White
        Write-Host ($Tag -join ', ') -ForegroundColor Yellow
    }
    Write-Host "Discovery Time: " -NoNewline -ForegroundColor White
    Write-Host "$([math]::Round($result.DiscoveryDuration.TotalMilliseconds, 2))ms" -ForegroundColor Gray

    # Group tests by file
    Write-Host "`nTests by File:" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Gray

    $testsByFile = $result.Tests | Group-Object -Property { $_.ScriptBlock.File } | Sort-Object Name

    foreach ($group in $testsByFile) {
        $fileName = Split-Path $group.Name -Leaf
        $filePath = Split-Path $group.Name -Parent
        $relPath = ($filePath -replace [regex]::Escape($PWD.Path), '.').TrimEnd('\', '/')

        Write-Host "`n📁 " -NoNewline -ForegroundColor Cyan
        Write-Host "$relPath\" -NoNewline -ForegroundColor Gray
        Write-Host $fileName -ForegroundColor Yellow
        Write-Host "   " -NoNewline
        Write-Host "Tests: $($group.Count)" -ForegroundColor Green
        Write-Host "   " -NoNewline
        Write-Host ("-" * 66) -ForegroundColor DarkGray

        foreach ($test in $group.Group | Sort-Object Name) {
            $tags = if ($test.Tag -and $test.Tag.Count -gt 0) {
                " [" + ($test.Tag -join ', ') + "]"
            } else {
                ""
            }
            Write-Host "   ✓ " -NoNewline -ForegroundColor Green
            Write-Host $test.Name -NoNewline -ForegroundColor White
            if ($tags) {
                Write-Host $tags -ForegroundColor DarkGray
            } else {
                Write-Host ""
            }
        }
    }

    Write-Host "`n" -NoNewline
    Write-Host ("=" * 70) -ForegroundColor Gray
    Write-Host ""
}
else {
    # Return PSCustomObject collection (one per test)
    # Parse test files to extract tags from Describe/Context blocks

    # Helper function to extract tags from a Describe/Context line
    function Get-TagsFromLine {
        param([string]$Line)

        if ($Line -match '-Tag\s+(.+?)(?:\s*\{|$)') {
            $tagPart = $Matches[1].Trim()

            # Handle various tag formats:
            # -Tag 'Core'
            # -Tag 'Core', 'Security'
            # -Tag @('Core', 'Security')
            $tagPart = $tagPart -replace "^@\(", "" -replace "\)$", ""
            $tags = $tagPart -split ',' | ForEach-Object {
                $_.Trim().Trim("'", '"')
            }
            return $tags
        }
        return @()
    }

    # Cache file contents to avoid re-reading
    $fileCache = @{}

    # Group tests by file for efficient processing
    $testsByFile = $result.Tests | Group-Object -Property { $_.ScriptBlock.File }

    foreach ($fileGroup in $testsByFile) {
        # Safely resolve file path with error handling
        $resolvedPath = Resolve-Path -Path $fileGroup.Name -ErrorAction SilentlyContinue
        if (-not $resolvedPath) {
            # Skip files that cannot be resolved
            continue
        }
        $filePath = $resolvedPath.Path

        # Read file content once per file (use cache)
        if (-not $fileCache.ContainsKey($filePath)) {
            $fileCache[$filePath] = Get-Content -Path $filePath -Raw
        }
        $fileContent = $fileCache[$filePath]
        $lines = $fileContent -split "`r?`n"

        # Parse the file to associate tags with tests using block-aware logic
        $blockStack = @()
        $testTagMap = @{}
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            # Enter Describe/Context block
            if ($line -match '^\s*(Describe|Context)\s+') {
                $blockTags = Get-TagsFromLine -Line $line
                $blockStack += ,@{ Tags = $blockTags }
                continue
            }

            # Exit block on closing brace
            if ($line -match '^\s*\}') {
                if ($blockStack.Count -gt 0) {
                    $blockStack = $blockStack[0..($blockStack.Count - 2)]
                }
                continue
            }

            # Find It blocks and associate tags from all parent blocks
            if ($line -match '^\s*It\s+["''](.+?)["'']') {
                $itName = $Matches[1]
                $tags = @()
                foreach ($block in $blockStack) {
                    $tags += $block.Tags
                }
                $tags = $tags | Where-Object { $_ } | Select-Object -Unique | Sort-Object
                $testTagMap[$itName] = $tags
            }
        }

        # Output a PSCustomObject for each test with its tags
        foreach ($test in $fileGroup.Group) {
            $testTags = if ($testTagMap.ContainsKey($test.Name)) {
                $testTagMap[$test.Name]
            } else {
                @()
            }

            [PSCustomObject]@{
                TestName = $test.Name
                Tags     = $testTags
                FilePath = $filePath
            }
        }
    }
}
