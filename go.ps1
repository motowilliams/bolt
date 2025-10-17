#Requires -Version 7.0
using namespace System.Management.Automation

<#
.SYNOPSIS
    Universal build script with extensible task system
.DESCRIPTION
    Core build tasks are built into this script. Project-specific tasks can be
    added by placing PowerShell scripts in a .build directory.
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Task,
    
    [Parameter()]
    [switch]$ListTasks,
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# Main script logic
$ErrorActionPreference = 'Stop'

# Register argument completer
$taskCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    # Extract the script path from the command AST
    $scriptPath = $commandAst.CommandElements[0].Value
    $scriptDir = Split-Path -Parent (Resolve-Path $scriptPath -ErrorAction SilentlyContinue)
    
    if (-not $scriptDir) { return }
    
    # Core tasks (defined in this script)
    $coreTasks = @('check-index', 'check')
    
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
    
    # Combine and get unique task names
    $allTasks = ($coreTasks + $projectTasks) | Select-Object -Unique | Sort-Object
    
    # Return matching completions
    $allTasks | Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object {
        [CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -CommandName 'go.ps1' -ParameterName 'Task' -ScriptBlock $taskCompleter

#region Core Tasks

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

#endregion Core Tasks

#region Task Discovery and Execution

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
            $metadata.Names = @((Get-Item $FilePath).BaseName)
        }
        
        # Extract description
        if ($content -match '(?m)^#\s*DESCRIPTION:\s*(.+)$') {
            $metadata.Description = $Matches[1].Trim()
        }
        
        # Extract dependencies
        if ($content -match '(?m)^#\s*DEPENDS:\s*(.+)$') {
            $metadata.Dependencies = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
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
        [hashtable]$ExecutedTasks = @{}
    )
    
    $primaryName = $TaskInfo.Names[0]
    
    # Check if already executed (prevent circular dependencies)
    if ($ExecutedTasks.ContainsKey($primaryName)) {
        return $true
    }
    
    # Execute dependencies first
    if ($TaskInfo.Dependencies.Count -gt 0) {
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

#endregion Task Discovery and Execution

#region Main Execution

# Discover all available tasks
$availableTasks = Get-AllTasks

# Handle -ListTasks flag
if ($ListTasks) {
    Write-Host "Available tasks:" -ForegroundColor Cyan
    Write-Host ""
    
    $uniqueTasks = @{}
    foreach ($key in $availableTasks.Keys) {
        $task = $availableTasks[$key]
        if ($null -eq $task) {
            Write-Warning "Task key '$key' has null value"
            continue
        }
        if ($null -eq $task.Names) {
            Write-Warning "Task '$key' has null Names property"
            continue
        }
        if ($task.Names.Count -eq 0) {
            Write-Warning "Task '$key' has empty Names array"
            continue
        }
        $primaryName = $task.Names[0]
        if (-not $uniqueTasks.ContainsKey($primaryName)) {
            $uniqueTasks[$primaryName] = $task
        }
    }
    
    foreach ($taskName in ($uniqueTasks.Keys | Sort-Object)) {
        $task = $uniqueTasks[$taskName]
        $aliases = $task.Names | Where-Object { $_ -ne $taskName }
        $source = if ($task.IsCore) { "core" } else { "project" }
        
        Write-Host "  $taskName" -ForegroundColor Green -NoNewline
        if ($aliases.Count -gt 0) {
            Write-Host " (aliases: $($aliases -join ', '))" -ForegroundColor Gray -NoNewline
        }
        Write-Host " [$source]" -ForegroundColor DarkGray
        
        if ($task.Description) {
            Write-Host "    $($task.Description)" -ForegroundColor Gray
        }
        
        if ($task.Dependencies.Count -gt 0) {
            Write-Host "    Dependencies: $($task.Dependencies -join ', ')" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    exit 0
}

# Check if task was provided
if ([string]::IsNullOrWhiteSpace($Task)) {
    Write-Host "Error: No task specified" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\go.ps1 <task> [arguments]" -ForegroundColor Yellow
    Write-Host "       .\go.ps1 -ListTasks" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available tasks: $($availableTasks.Keys | Sort-Object -Unique | Join-String -Separator ', ')" -ForegroundColor Cyan
    exit 1
}

# Check if requested task exists
if (-not $availableTasks.ContainsKey($Task)) {
    Write-Error "Task '$Task' not found. Available tasks: $($availableTasks.Keys | Sort-Object -Unique | Join-String -Separator ', ')"
    exit 1
}

# Get the task metadata
$taskInfo = $availableTasks[$Task]

Write-Host "Executing task: $Task" -ForegroundColor Cyan
if ($taskInfo.Description) {
    Write-Host "Description: $($taskInfo.Description)" -ForegroundColor Gray
}
Write-Host ""

# Execute the task with dependency resolution
$executedTasks = @{}
$result = Invoke-Task -TaskInfo $taskInfo -AllTasks $availableTasks -Arguments $Arguments -ExecutedTasks $executedTasks

if (-not $result) {
    Write-Host "`nTask '$Task' failed" -ForegroundColor Red
    exit 1
}

Write-Host "`nTask '$Task' completed successfully" -ForegroundColor Green
exit 0

#endregion Main Execution
