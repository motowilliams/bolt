#Requires -Version 7.0
using namespace System.Management.Automation

<#
.SYNOPSIS
    Gosh! Build orchestration for PowerShell
.DESCRIPTION
    A self-contained PowerShell build system with extensible task orchestration.
    Core build tasks are built into this script. Project-specific tasks can be
    added by placing PowerShell scripts in a .build directory.

    "Go" + "powerShell" = Gosh! 🎉
.PARAMETER Task
    One or more task names to execute. Tasks are executed in sequence.
.PARAMETER ListTasks
    Display all available tasks with their descriptions and dependencies.
.PARAMETER Only
    Skip task dependencies and execute only the specified tasks.
.PARAMETER NewTask
    Create a new task file with the specified name. Creates a stubbed file in
    the .build directory with proper metadata structure.
.PARAMETER Arguments
    Additional arguments to pass to the task scripts.
.EXAMPLE
    .\gosh.ps1 build
    Executes the build task and its dependencies (format, lint).
.EXAMPLE
    .\gosh.ps1 format lint build -Only
    Executes format, lint, and build tasks without their dependencies.
.EXAMPLE
    .\gosh.ps1 -ListTasks
    Shows all available tasks.
.EXAMPLE
    .\gosh.ps1 -NewTask clean
    Creates a new task file named Invoke-Clean.ps1 in the .build directory.
#>param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string[]]$Task,

    [Parameter()]
    [Alias('Help')]
    [switch]$ListTasks,

    [Parameter()]
    [switch]$Only,

    [Parameter()]
    [string]$NewTask,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)# Main script logic
$ErrorActionPreference = 'Stop'

# Register argument completer
$taskCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    # Extract the script path from the command abstract syntax tree (AST)
    $scriptPath = $commandAst.CommandElements[0].Value
    $scriptDir = Split-Path -Parent (Resolve-Path $scriptPath -ErrorAction SilentlyContinue)

    if (-not $scriptDir) { return }

    # Scan for project-specific tasks in .build directory
    $projectTasks = @()
    $buildPath = Join-Path $scriptDir ".build"
    if (Test-Path $buildPath) {
        $buildFiles = Get-ChildItem $buildPath -Filter "*.ps1" -File
        foreach ($file in $buildFiles) {
            # Extract task name from file
            $lines = Get-Content $file.FullName -First 20 -ErrorAction SilentlyContinue
            $content = $lines -join "`n"
            if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
                $taskNames = $Matches[1] -split ',' | ForEach-Object { $_.Trim() }
                $projectTasks += $taskNames
            }
            else {
                $projectTasks += $file.BaseName
            }
        }
    }

    # Core tasks (defined in this script)
    $coreTasks = @('check-index', 'check')

    # Combine and get unique task names
    $allTasks = ($coreTasks + $projectTasks) | Select-Object -Unique | Sort-Object

    # Return matching completions
    $allTasks | Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object {
        [CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -CommandName 'gosh.ps1' -ParameterName 'Task' -ScriptBlock $taskCompleter

function Invoke-CheckGitIndex {
    <#
    .SYNOPSIS
        Checks if the git index is clean
    .DESCRIPTION
        Verifies there are no uncommitted changes in the git repository
    #>
    [CmdletBinding()]
    param()

    # Check if git is available
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        Write-Error "Git is not installed or not in PATH"
        return $false
    }

    # Check if we're in a git repository
    $null = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not in a git repository"
        return $false
    }

    Write-Host "Checking git index status..." -ForegroundColor Cyan

    # Get git status
    $status = git status --porcelain

    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "✓ Git index is clean - no uncommitted changes" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "✗ Git index is dirty - uncommitted changes detected:" -ForegroundColor Red
        Write-Host ""
        git status --short
        Write-Host ""
        Write-Warning "Please commit or stash your changes before proceeding"
        return $false
    }
}

function Get-CoreTasks {
    <#
    .SYNOPSIS
        Returns metadata for all core tasks built into this script
    #>
    return @{
        'check-index' = @{
            Names        = @('check-index', 'check')
            Description  = 'Checks if the git index is clean (no uncommitted changes)'
            Dependencies = @()
            Function     = 'Invoke-CheckGitIndex'
            IsCore       = $true
        }
        'check'       = @{
            Names        = @('check-index', 'check')
            Description  = 'Checks if the git index is clean (no uncommitted changes)'
            Dependencies = @()
            Function     = 'Invoke-CheckGitIndex'
            IsCore       = $true
        }
    }
}

function Get-ProjectTasks {
    <#
    .SYNOPSIS
        Discovers and loads project-specific tasks from .build directory
    #>
    param(
        [string]$BuildPath
    )

    $tasks = @{}

    if (-not (Test-Path $BuildPath)) {
        return $tasks
    }

    # Function to parse task metadata from script files
    function Get-TaskMetadata {
        param($FilePath)

        $lines = Get-Content $FilePath -First 30 -ErrorAction SilentlyContinue
        $content = $lines -join "`n"
        $metadata = @{
            Names        = @()
            Description  = ''
            Dependencies = @()
            ScriptPath   = $FilePath
            IsCore       = $false
        }

        # Extract task names
        if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
            $metadata.Names = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
        }
        else {
            # if there is no TASK tag, use the noun portion of the filename as the task name
            $metadata.Names = @((Get-Item $FilePath).BaseName).ToLower() -split '-' | Select-Object -Last 1
        }

        # Extract description
        if ($content -match '(?m)^#\s*DESCRIPTION:\s*(.+)$') {
            $metadata.Description = $Matches[1].Trim()
        }

        # Extract dependencies
        if ($content -match '(?m)^#\s*DEPENDS:(.*)$') {
            $depString = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($depString)) {
                $metadata.Dependencies = @($depString -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
        }

        return $metadata
    }

    # Load tasks from .build directory
    $buildFiles = Get-ChildItem $BuildPath -Filter "*.ps1" -File
    foreach ($file in $buildFiles) {
        $metadata = Get-TaskMetadata $file.FullName
        foreach ($name in $metadata.Names) {
            $tasks[$name] = $metadata
        }
    }

    return $tasks
}

function Get-AllTasks {
    <#
    .SYNOPSIS
        Returns all available tasks (core + project-specific)
    #>
    $allTasks = @{}

    # Get core tasks
    $coreTasks = Get-CoreTasks
    foreach ($key in $coreTasks.Keys) {
        $allTasks[$key] = $coreTasks[$key]
    }

    # Get project-specific tasks
    $buildPath = Join-Path $PSScriptRoot ".build"
    $projectTasks = Get-ProjectTasks -BuildPath $buildPath

    # Project tasks override core tasks if there's a naming conflict
    foreach ($key in $projectTasks.Keys) {
        if ($allTasks.ContainsKey($key)) {
            Write-Warning "Project task '$key' is overriding core task"
        }
        $allTasks[$key] = $projectTasks[$key]
    }

    return $allTasks
}

function Invoke-Task {
    <#
    .SYNOPSIS
        Executes a task with dependency resolution
    #>
    param(
        [hashtable]$TaskInfo,
        [hashtable]$AllTasks,
        [array]$Arguments,
        [hashtable]$ExecutedTasks = @{},
        [bool]$SkipDependencies = $false
    )

    $primaryName = $TaskInfo.Names[0]

    # Check if already executed (prevent circular dependencies)
    if ($ExecutedTasks.ContainsKey($primaryName)) {
        return $true
    }

    # Execute dependencies first (unless skipped)
    if ($TaskInfo.Dependencies.Count -gt 0) {
        if ($SkipDependencies) {
            Write-Host "Skipping dependencies for '$primaryName': $($TaskInfo.Dependencies -join ', ')" -ForegroundColor Yellow
        }
        else {
            Write-Host "Dependencies for '$primaryName': $($TaskInfo.Dependencies -join ', ')" -ForegroundColor Gray
            foreach ($dep in $TaskInfo.Dependencies) {
                if ($AllTasks.ContainsKey($dep)) {
                    Write-Host "`nExecuting dependency: $dep" -ForegroundColor Yellow
                    $depResult = Invoke-Task -TaskInfo $AllTasks[$dep] -AllTasks $AllTasks -Arguments $Arguments -ExecutedTasks $ExecutedTasks
                    if (-not $depResult) {
                        Write-Error "Dependency '$dep' failed"
                        return $false
                    }
                }
                else {
                    Write-Warning "Dependency '$dep' not found, skipping"
                }
            }
            Write-Host ""
        }
    }

    # Mark as executed
    $ExecutedTasks[$primaryName] = $true

    # Execute the task
    if ($TaskInfo.IsCore) {
        # Execute core task function
        $result = & $TaskInfo.Function
        return $result
    }
    else {
        # Execute external script
        & $TaskInfo.ScriptPath @Arguments

        # Check exit code
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            return $false
        }
        return $true
    }
}

# Discover all available tasks
$availableTasks = Get-AllTasks

# Handle -NewTask flag
if (-not [string]::IsNullOrWhiteSpace($NewTask)) {
    Write-Host "Creating new task: $NewTask" -ForegroundColor Cyan

    # Ensure .build directory exists
    $buildPath = Join-Path $PSScriptRoot ".build"
    if (-not (Test-Path $buildPath)) {
        New-Item -Path $buildPath -ItemType Directory | Out-Null
        Write-Host "Created .build directory" -ForegroundColor Gray
    }

    # Generate filename: Invoke-TaskName.ps1 (with proper capitalization)
    $taskNameCapitalized = (Get-Culture).TextInfo.ToTitleCase($NewTask.ToLower())
    $fileName = "Invoke-$taskNameCapitalized.ps1"
    $filePath = Join-Path $buildPath $fileName

    # Check if file already exists
    if (Test-Path $filePath) {
        Write-Error "Task file already exists: $fileName"
        exit 1
    }

    # Create task file template
    $template = @"
# TASK: $($NewTask.ToLower())
# DESCRIPTION: TODO: Add description for this task
# DEPENDS:

param()

Write-Host "Running $($NewTask.ToLower()) task..." -ForegroundColor Cyan

# TODO: Implement task logic here

Write-Host "✓ Task completed successfully" -ForegroundColor Green
exit 0
"@

    # Write the file
    Set-Content -Path $filePath -Value $template -Encoding UTF8

    Write-Host ""
    Write-Host "✓ Created task file: $fileName" -ForegroundColor Green
    Write-Host "  Location: $filePath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Edit $fileName to implement your task logic" -ForegroundColor Gray
    Write-Host "  2. Update the DESCRIPTION and DEPENDS metadata as needed" -ForegroundColor Gray
    Write-Host "  3. Run '.\gosh.ps1 $($NewTask.ToLower())' to execute your task" -ForegroundColor Gray
    Write-Host "  4. Restart PowerShell to enable tab completion for the new task" -ForegroundColor Gray

    exit 0
}

# Handle -ListTasks flag
if ($ListTasks) {
    Write-Host "Available tasks:" -ForegroundColor Cyan
    Write-Host ""

    $uniqueTasks = @{}
    foreach ($taskKey in $availableTasks.Keys) {
        $taskInfo = $availableTasks[$taskKey]
        if ($null -eq $taskInfo) {
            Write-Warning "Task key '$taskKey' has null value"
            continue
        }
        if ($taskInfo -isnot [hashtable]) {
            Write-Warning "Task '$taskKey' is not a hashtable (type: $($taskInfo.GetType().Name))"
            continue
        }
        if (-not $taskInfo.ContainsKey('Names')) {
            Write-Warning "Task '$taskKey' missing Names property"
            continue
        }
        $names = $taskInfo['Names']
        if ($null -eq $names -or $names.Count -eq 0) {
            Write-Warning "Task '$taskKey' has empty Names"
            continue
        }
        $primaryName = $names[0]
        if (-not $uniqueTasks.ContainsKey($primaryName)) {
            $uniqueTasks[$primaryName] = $taskInfo
        }
    }

    foreach ($taskName in ($uniqueTasks.Keys | Sort-Object)) {
        $taskInfo = $uniqueTasks[$taskName]
        $aliases = $taskInfo['Names'] | Where-Object { $_ -ne $taskName }
        $source = if ($taskInfo['IsCore']) { "core" } else { "project" }

        Write-Host "  $taskName" -ForegroundColor Green -NoNewline
        if ($aliases.Count -gt 0) {
            Write-Host " (aliases: $($aliases -join ', '))" -ForegroundColor Gray -NoNewline
        }
        Write-Host " [$source]" -ForegroundColor DarkGray

        if ($taskInfo['Description']) {
            Write-Host "    $($taskInfo['Description'])" -ForegroundColor Gray
        }

        if ($taskInfo['Dependencies'].Count -gt 0) {
            Write-Host "    Dependencies: $($taskInfo['Dependencies'] -join ', ')" -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    exit 0
}

# Check if task was provided
if ($null -eq $Task -or $Task.Count -eq 0 -or [string]::IsNullOrWhiteSpace($Task[0])) {
    Write-Host "Error: No task specified" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\gosh.ps1 <task> [task2 task3...] [arguments]" -ForegroundColor Yellow
    Write-Host "       .\gosh.ps1 <task>,<task2>,<task3> [arguments]  (comma-separated)" -ForegroundColor Yellow
    Write-Host "       .\gosh.ps1 <task> -Only [arguments]  (skip dependencies)" -ForegroundColor Yellow
    Write-Host "       .\gosh.ps1 -ListTasks  (or -Help)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available tasks: $($availableTasks.Keys | Sort-Object -Unique | Join-String -Separator ', ')" -ForegroundColor Cyan
    exit 1
}

# Parse task list - support comma-separated or space-separated tasks
$taskList = @()
$remainingArgs = @()
$collectingTasks = $true

# Process Task parameter - could be array or single string with commas
foreach ($taskArg in $Task) {
    if ($taskArg -match ',') {
        # Comma-separated tasks in a single string
        $taskList += $taskArg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    else {
        $taskList += $taskArg.Trim()
    }
}

# Check Arguments for additional tasks or actual arguments
foreach ($arg in $Arguments) {
    if ($collectingTasks) {
        # Check if this looks like a task name (exists in available tasks) or contains comma
        if ($arg -match ',') {
            # Comma-separated tasks
            $taskList += $arg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        elseif ($availableTasks.ContainsKey($arg)) {
            # Valid task name
            $taskList += $arg
        }
        else {
            # Not a task, must be an argument
            $collectingTasks = $false
            $remainingArgs += $arg
        }
    }
    else {
        $remainingArgs += $arg
    }
}

# Validate all tasks exist
foreach ($taskName in $taskList) {
    if (-not $availableTasks.ContainsKey($taskName)) {
        Write-Error "Task '$taskName' not found. Available tasks: $($availableTasks.Keys | Sort-Object -Unique | Join-String -Separator ', ')"
        exit 1
    }
}

# Execute all tasks in sequence
$executedTasks = @{}
$allSucceeded = $true

foreach ($taskName in $taskList) {
    $taskInfo = $availableTasks[$taskName]

    Write-Host "Executing task: $taskName" -ForegroundColor Cyan
    if ($taskInfo.Description) {
        Write-Host "Description: $($taskInfo.Description)" -ForegroundColor Gray
    }
    Write-Host ""

    # Execute the task with dependency resolution
    $result = Invoke-Task -TaskInfo $taskInfo -AllTasks $availableTasks -Arguments $remainingArgs -ExecutedTasks $executedTasks -SkipDependencies $Only

    if (-not $result) {
        Write-Host "`nTask '$taskName' failed" -ForegroundColor Red
        $allSucceeded = $false
        break
    }

    Write-Host "`nTask '$taskName' completed successfully" -ForegroundColor Green

    if ($taskList.Count -gt 1 -and $taskName -ne $taskList[-1]) {
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host ""
    }
}

if (-not $allSucceeded) {
    exit 1
}

exit 0
