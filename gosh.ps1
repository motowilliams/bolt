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
.PARAMETER Outline
    Display the task dependency tree and execution order without executing tasks.
    Shows what would be executed when the task is run.
.PARAMETER TaskDirectory
    Directory containing task scripts. Defaults to .build in the script's directory.
    Relative paths are resolved relative to the script location.
.PARAMETER NewTask
    Create a new task file with the specified name. Creates a stubbed file in
    the task directory with proper metadata structure.
.PARAMETER Arguments
    Additional arguments to pass to the task scripts.
.EXAMPLE
    .\gosh.ps1 build
    Executes the build task and its dependencies (format, lint).
.EXAMPLE
    .\gosh.ps1 format lint build -Only
    Executes format, lint, and build tasks without their dependencies.
.EXAMPLE
    .\gosh.ps1 -TaskDirectory "custom-tasks"
    Lists and executes tasks from the custom-tasks directory instead of .build.
.EXAMPLE
    .\gosh.ps1 -ListTasks
    Shows all available tasks.
.EXAMPLE
    .\gosh.ps1 build -Outline
    Shows the dependency tree and execution order for the build task without executing it.
.EXAMPLE
    .\gosh.ps1 -NewTask clean
    Creates a new task file named Invoke-Clean.ps1 in the task directory.
.EXAMPLE
    .\gosh.ps1 format,lint,build -ErrorAction Continue
    Runs all tasks even if one fails (useful for seeing all errors at once).
.EXAMPLE
    .\gosh.ps1 -AsModule
    Installs Gosh as a PowerShell module for the current user, enabling the 'gosh' command.
#>
[CmdletBinding(DefaultParameterSetName = 'Help')]
param(
    # TaskExecution parameter set (for running tasks)
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'TaskExecution')]
    [ValidateScript({
        foreach ($taskArg in $_) {
            # SECURITY: Validate task name format (P0 - Task Name Validation)
            # Split on commas first in case user provided comma-separated list
            $taskNames = $taskArg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            foreach ($taskName in $taskNames) {
                if ($taskName -cnotmatch '^[a-z0-9][a-z0-9\-]*$') {
                    throw "Task name '$taskName' contains invalid characters. Only lowercase letters, numbers, and hyphens are allowed."
                }
                if ($taskName.Length -gt 50) {
                    throw "Task name '$taskName' is too long (max 50 characters)."
                }
            }
        }
        return $true
    })]
    [string[]]$Task,

    # ListTasks parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'ListTasks')]
    [Alias('Help')]
    [switch]$ListTasks,

    # TaskExecution parameter set options
    [Parameter(ParameterSetName = 'TaskExecution')]
    [switch]$Only,

    [Parameter(ParameterSetName = 'TaskExecution')]
    [switch]$Outline,

    # Available in multiple parameter sets
    [Parameter(ParameterSetName = 'TaskExecution')]
    [Parameter(ParameterSetName = 'ListTasks')]
    [Parameter(ParameterSetName = 'CreateTask')]
    [ValidatePattern('^[a-zA-Z0-9_\-\./\\]+$')]
    [ValidateScript({
        if ($_ -match '\.\.' -or [System.IO.Path]::IsPathRooted($_)) {
            throw "TaskDirectory must be a relative path without '..' sequences or absolute paths"
        }
        return $true
    })]
    [string]$TaskDirectory = ".build",

    # CreateTask parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'CreateTask')]
    [ValidateScript({
        # SECURITY: Validate task name format (P0 - Task Name Validation)
        if ($_ -cnotmatch '^[a-z0-9][a-z0-9\-]*$') {
            throw "Task name '$_' contains invalid characters. Only lowercase letters, numbers, and hyphens are allowed."
        }
        if ($_.Length -gt 50) {
            throw "Task name '$_' is too long (max 50 characters)."
        }
        return $true
    })]
    [string]$NewTask,

    # InstallModule parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'InstallModule')]
    [switch]$AsModule,

    # TaskExecution parameter set - additional arguments
    [Parameter(ParameterSetName = 'TaskExecution', ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# SECURITY: Execution policy awareness (P2 - Action Item #7)
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq 'Unrestricted' -or $executionPolicy -eq 'Bypass') {
    Write-Verbose "Running with permissive execution policy: $executionPolicy"
    Write-Verbose "Consider using RemoteSigned or AllSigned for better security"
}
elseif ($executionPolicy -eq 'Restricted') {
    Write-Warning "PowerShell execution policy is set to Restricted"
    Write-Warning "You may need to change it to run this script"
    Write-Warning "Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
}

# Main script logic
# Note: Don't override $ErrorActionPreference here - respect the common parameter from CmdletBinding
# Default ErrorActionPreference for scripts is 'Continue', but we want 'Stop' unless user specifies otherwise
if ($PSBoundParameters.ContainsKey('ErrorAction')) {
    # User explicitly set ErrorAction, use it
    $ErrorActionPreference = $PSBoundParameters['ErrorAction']
} else {
    # Default to Stop for build script behavior
    $ErrorActionPreference = 'Stop'
}

# Register argument completer
# Note: $commandName and $parameterName are required by PowerShell's argument completer signature
# even though they're not used in this implementation
$taskCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    # Extract the script path from the command abstract syntax tree (AST)
    $scriptPath = $commandAst.CommandElements[0].Value
    $scriptDir = Split-Path -Parent (Resolve-Path $scriptPath -ErrorAction SilentlyContinue)

    if (-not $scriptDir) { return }

    # Check if -TaskDirectory was specified in the command
    $taskDir = ".build"  # Default
    if ($fakeBoundParameters.ContainsKey('TaskDirectory')) {
        $taskDir = $fakeBoundParameters['TaskDirectory']
    }

    # Scan for project-specific tasks in task directory
    $projectTasks = @()
    $buildPath = Join-Path $scriptDir $taskDir
    if (Test-Path $buildPath) {
        $buildFiles = Get-ChildItem $buildPath -Filter "*.ps1" -File -Force
        foreach ($file in $buildFiles) {
            # Extract task name from file
            $lines = Get-Content $file.FullName -First 20 -ErrorAction SilentlyContinue
            $content = $lines -join "`n"
            if ($content -match '(?m)^#\s*TASK:\s*(.+)$') {
                $taskNames = $Matches[1] -split ',' | ForEach-Object { $_.Trim() }
                $projectTasks += $taskNames
            } else {
                # if there is no TASK tag, use the noun portion of the filename as the task name
                # Extract task name: Invoke-My-Custom-Task -> my-custom-task
                # Split on '-', skip first part (verb), join remaining with '-', convert to lowercase
                $parts = $file.BaseName -split '-'
                if ($parts.Count -gt 1) {
                    $taskName = ($parts[1..($parts.Count-1)] -join '-').ToLower()
                } else {
                    $taskName = $parts[0].ToLower()
                }
                $projectTasks += $taskName
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

#region Security Event Logging
function Write-SecurityLog {
    <#
    .SYNOPSIS
        Writes security-relevant events to audit log
    .DESCRIPTION
        Logs security events to .gosh/audit.log when $env:GOSH_AUDIT_LOG is set to 1.
        Captures timestamp, severity, user context, event type, and details.
    .PARAMETER Event
        The type of security event (e.g., TaskExecution, FileCreation, CommandExecution)
    .PARAMETER Details
        Additional details about the event
    .PARAMETER Severity
        The severity level: Info, Warning, or Error
    .EXAMPLE
        Write-SecurityLog -Event "TaskExecution" -Details "Task: build, Directory: .build"
        Write-SecurityLog -Event "FileCreation" -Details "Created: .build/Invoke-Deploy.ps1" -Severity "Warning"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Event,

        [Parameter(Mandatory)]
        [string]$Details,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Severity = 'Info'
    )

    # Only log if audit logging is enabled
    if ($env:GOSH_AUDIT_LOG -ne '1') {
        return
    }

    try {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $user = [Environment]::UserName
        $machine = [Environment]::MachineName
        $entry = "$timestamp | $Severity | $user@$machine | $Event | $Details"

        $logDir = Join-Path $PSScriptRoot '.gosh'
        $logPath = Join-Path $logDir 'audit.log'

        # Ensure .gosh directory exists and is actually a directory
        if (Test-Path $logDir) {
            # If .gosh exists but is not a directory, remove it first
            if (-not (Test-Path -PathType Container $logDir)) {
                Remove-Item $logDir -Force
            }
        }

        # Create .gosh directory if it doesn't exist (more robust approach)
        if (-not (Test-Path -PathType Container $logDir)) {
            $null = New-Item -Path $logDir -ItemType Directory -Force -ErrorAction SilentlyContinue
            # Double-check the directory was created successfully
            if (-not (Test-Path -PathType Container $logDir)) {
                throw "Failed to create log directory: $logDir"
            }
        }

        # Append log entry
        Add-Content -Path $logPath -Value $entry -Encoding UTF8
    }
    catch {
        # Silently fail - don't interrupt script execution if logging fails
        Write-Verbose "Failed to write security log: $_"
    }
}

function Test-CommandOutput {
    <#
    .SYNOPSIS
        Validates and sanitizes external command output before display

    .DESCRIPTION
        Protects against terminal injection attacks by validating and sanitizing
        output from external commands (git, bicep, etc.). Removes ANSI escape
        sequences, control characters, and excessively long output.

    .PARAMETER Output
        The raw command output to validate and sanitize

    .PARAMETER MaxLength
        Maximum allowed output length in characters (default: 100KB)

    .PARAMETER MaxLines
        Maximum allowed number of lines (default: 1000)

    .EXAMPLE
        $gitOutput = git status --porcelain 2>&1
        $safeOutput = Test-CommandOutput -Output $gitOutput
        Write-Host $safeOutput

    .NOTES
        This function:
        - Strips ANSI escape sequences (\x1b[...m)
        - Removes dangerous control characters (0x00-0x1F, 0x7F-0x9F)
        - Preserves newline (\n), carriage return (\r), and tab (\t)
        - Truncates excessively long output
        - Detects and warns about suspicious content
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Output,

        [Parameter()]
        [int]$MaxLength = 102400,  # 100KB default

        [Parameter()]
        [int]$MaxLines = 1000
    )

    begin {
        Write-Verbose "Validating command output (MaxLength: $MaxLength, MaxLines: $MaxLines)"
    }

    process {
        # Handle null or empty input
        if ([string]::IsNullOrEmpty($Output)) {
            return ''
        }

        $sanitized = $Output
        $warnings = @()

        # Check for suspicious binary content (null bytes)
        if ($sanitized -match '\x00') {
            $warnings += 'Binary content detected in output'
            # Remove null bytes
            $sanitized = $sanitized -replace '\x00', '?'
        }

        # Remove ANSI escape sequences (e.g., \x1b[31m for red text)
        # Pattern: ESC [ <parameters> <command>
        # \x1b\[ matches the escape sequence start
        # [0-9;]* matches parameters (numbers and semicolons)
        # [a-zA-Z] matches the command character
        if ($sanitized -match '\x1b\[') {
            Write-Verbose 'ANSI escape sequences detected - sanitizing'
            $sanitized = $sanitized -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        }

        # Remove other dangerous control characters
        # Preserve: \n (0x0A), \r (0x0D), \t (0x09)
        # Remove: 0x00-0x08, 0x0B-0x0C, 0x0E-0x1F, 0x7F-0x9F
        $sanitized = $sanitized -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]', '?'

        # Check output length
        if ($sanitized.Length -gt $MaxLength) {
            $warnings += "Output truncated (exceeded $MaxLength characters)"
            $sanitized = $sanitized.Substring(0, $MaxLength) + "`n... [output truncated]"
        }

        # Check line count
        $lines = $sanitized -split '\r?\n'
        if ($lines.Count -gt $MaxLines) {
            $warnings += "Output truncated (exceeded $MaxLines lines)"
            $sanitized = ($lines | Select-Object -First $MaxLines) -join "`n"
            $sanitized += "`n... [output truncated]"
        }

        # Write warnings if any were collected
        foreach ($warning in $warnings) {
            Write-Warning "Output validation: $warning"
        }

        return $sanitized
    }
}
#endregion

#region Utility Functions - Available to all tasks
function Get-ProjectRoot {
    <#
    .SYNOPSIS
        Finds the project root directory by looking for .git directory
    .DESCRIPTION
        Recursively searches upward from the starting path to find the project root,
        identified by the presence of a .git directory
    .PARAMETER StartPath
        The path to start searching from. Defaults to the current location.
    .EXAMPLE
        $root = Get-ProjectRoot
        Gets the project root starting from the current location
    .EXAMPLE
        $root = Get-ProjectRoot -StartPath $PSScriptRoot
        Gets the project root starting from a specific directory
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$StartPath
    )

    # Default to current location if not specified or if PSScriptRoot is empty
    if ([string]::IsNullOrWhiteSpace($StartPath)) {
        $StartPath = Get-Location
    }

    $projectRoot = $StartPath
    do {
        Write-Verbose "$($MyInvocation.MyCommand.Name): Checking for .git in $projectRoot"
        if (Test-Path (Join-Path $projectRoot '.git')) {
            return $projectRoot
        }
        $parent = Split-Path -Parent $projectRoot
        if ($parent -eq $projectRoot) {
            # We've reached the root of the filesystem
            break
        }
        $projectRoot = $parent
    } while ($projectRoot)

    # If no .git directory found, return the original start path
    return $StartPath
}

function Get-GitStatus {
    <#
    .SYNOPSIS
        Gets the current git repository status
    .DESCRIPTION
        Checks git availability, repository status, and index cleanliness.
        Returns structured data without side effects (no Write-Host/Write-Error).
        This is a pure utility function that can be used by any task.
    .EXAMPLE
        $status = Get-GitStatus
        if ($status.IsClean) {
            Write-Host "Git is clean" -ForegroundColor Green
        } else {
            Write-Host "Git has changes: $($status.Status)" -ForegroundColor Yellow
        }
    .OUTPUTS
        PSCustomObject with the following properties:
        - IsClean: $true if no uncommitted changes, $false if dirty, $null if error
        - Status: Output from 'git status --porcelain' or $null
        - HasGit: $true if git command is available, $false otherwise
        - InRepo: $true if current directory is in a git repository, $false otherwise
        - ErrorMessage: Description of error if any, $null otherwise
    #>
    [CmdletBinding()]
    param()

    # Check if git is available
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        return [PSCustomObject]@{
            IsClean      = $null
            Status       = $null
            HasGit       = $false
            InRepo       = $false
            ErrorMessage = "Git is not installed or not in PATH"
        }
    }

    # Check if we're in a git repository
    $null = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        return [PSCustomObject]@{
            IsClean      = $null
            Status       = $null
            HasGit       = $true
            InRepo       = $false
            ErrorMessage = "Not in a git repository"
        }
    }

    # Get git status
    # SECURITY: Log external command execution (P0 - Security Event Logging)
    Write-SecurityLog -Event "CommandExecution" -Details "Executing: git status --porcelain" -Severity "Info"

    $status = git status --porcelain 2>$null

    # Determine if clean and return result
    $isClean = [string]::IsNullOrWhiteSpace($status)

    return [PSCustomObject]@{
        IsClean      = $isClean
        Status       = $status
        HasGit       = $true
        InRepo       = $true
        ErrorMessage = $null
    }
}

function Get-GoshUtilities {
    <#
    .SYNOPSIS
        Returns a hashtable of utility functions available to tasks
    .DESCRIPTION
        This function exports utility functions that can be injected into task execution contexts
    #>
    return @{
        'Get-ProjectRoot' = ${function:Get-ProjectRoot}
        'Get-GitStatus'   = ${function:Get-GitStatus}
    }
}

function Install-GoshModule {
    <#
    .SYNOPSIS
        Installs Gosh as a PowerShell module for the current user
    .DESCRIPTION
        Creates a PowerShell module in the user module path:
        - Windows: ~/Documents/PowerShell/Modules/Gosh/
        - Linux/macOS: ~/.local/share/powershell/Modules/Gosh/

        The module allows running 'gosh' commands from any directory and
        searches upward from the current directory for .build/ folders.
    #>
    [CmdletBinding()]
    param()

    Write-Host "Installing Gosh as a PowerShell module..." -ForegroundColor Cyan
    Write-Host ""

    # Determine module installation path (cross-platform)
    $moduleName = "Gosh"

    # Use the first user-writable path from $env:PSModulePath
    # Windows: ~/Documents/PowerShell/Modules (via MyDocuments)
    # Linux/macOS: ~/.local/share/powershell/Modules (via LocalApplicationData)
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
        # Windows
        $userModulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell" "Modules" $moduleName
    }
    else {
        # Linux/macOS
        $userModulePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "powershell" "Modules" $moduleName
    }

    # Create module directory (overwrites if exists for idempotency)
    if (Test-Path $userModulePath) {
        Write-Host "Module directory exists, updating..." -ForegroundColor Yellow
        Remove-Item -Path $userModulePath -Recurse -Force
    }

    New-Item -Path $userModulePath -ItemType Directory -Force | Out-Null
    Write-Host "Created module directory: $userModulePath" -ForegroundColor Gray

    # Generate module manifest (.psd1)
    $manifestPath = Join-Path $userModulePath "$moduleName.psd1"
    $manifestContent = @"
@{
    # Module metadata
    RootModule = '$moduleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = '$(New-Guid)'
    Author = 'Gosh Contributors'
    CompanyName = 'Unknown'
    Copyright = '(c) Gosh Contributors. All rights reserved.'
    Description = 'Gosh! Build orchestration for PowerShell - A self-contained build system with extensible task orchestration.'

    # Minimum PowerShell version
    PowerShellVersion = '7.0'

    # Functions and aliases to export
    FunctionsToExport = @('Invoke-Gosh')
    AliasesToExport = @('gosh')
    CmdletsToExport = @()
    VariablesToExport = @()

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Build', 'Task', 'Orchestration', 'PowerShell', 'Bicep', 'Azure')
            LicenseUri = 'https://github.com/motowilliams/gosh/blob/main/LICENSE'
            ProjectUri = 'https://github.com/motowilliams/gosh'
        }
    }
}
"@

    $manifestContent | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
    Write-Host "Created module manifest: $moduleName.psd1" -ForegroundColor Gray

    # Copy gosh.ps1 to the module directory (so it can be invoked as a script)
    $goshCorePath = Join-Path $userModulePath "gosh-core.ps1"
    Copy-Item -Path $PSCommandPath -Destination $goshCorePath -Force
    Write-Host "Copied gosh core script to module" -ForegroundColor Gray

    # Generate module script (.psm1) that wraps gosh.ps1 with upward directory search
    $moduleScriptPath = Join-Path $userModulePath "$moduleName.psm1"

    $moduleScript = @"
#Requires -Version 7.0
using namespace System.Management.Automation

<#
.SYNOPSIS
    Gosh! Build orchestration for PowerShell (Module Version)
.DESCRIPTION
    PowerShell module version of Gosh that searches upward from the current directory
    for .build/ folders, enabling 'gosh' command usage from any project directory.
#>

function Find-BuildDirectory {
    <#
    .SYNOPSIS
        Searches upward from current directory for .build folder
    .DESCRIPTION
        Recursively searches parent directories for .build folder, similar to how
        git searches for .git directory. Returns the path to .build if found.
    .PARAMETER StartPath
        The directory to start searching from. Defaults to current location.
    .PARAMETER TaskDirectory
        The directory name to search for. Defaults to '.build'.
    #>
    [CmdletBinding()]
    param(
        [string]`$StartPath = (Get-Location).Path,
        [string]`$TaskDirectory = '.build'
    )

    `$currentPath = `$StartPath
    `$iterations = 0
    `$maxIterations = 100  # Prevent infinite loops

    while (`$currentPath -and `$iterations -lt `$maxIterations) {
        `$buildPath = Join-Path `$currentPath `$TaskDirectory

        Write-Verbose "Searching for '`$TaskDirectory' in: `$currentPath"

        if (Test-Path `$buildPath -PathType Container) {
            Write-Verbose "Found '`$TaskDirectory' at: `$buildPath"
            return `$buildPath
        }

        # Move to parent directory
        `$parent = Split-Path `$currentPath -Parent

        # Check if we've reached the root
        if (`$parent -eq `$currentPath -or [string]::IsNullOrEmpty(`$parent)) {
            break
        }

        `$currentPath = `$parent
        `$iterations++
    }

    Write-Verbose "'`$TaskDirectory' not found in any parent directory"
    return `$null
}

function Invoke-Gosh {
    <#
    .SYNOPSIS
        Gosh! Build orchestration
    .DESCRIPTION
        Executes Gosh build tasks. When running as a module, searches upward from
        the current directory for .build/ folder.
    .PARAMETER Task
        One or more task names to execute
    .PARAMETER ListTasks
        Display all available tasks
    .PARAMETER Only
        Skip task dependencies
    .PARAMETER Outline
        Show task execution plan without running
    .PARAMETER TaskDirectory
        Override the default .build directory name
    .PARAMETER NewTask
        Create a new task file
    .PARAMETER Arguments
        Additional arguments to pass to tasks
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string[]]`$Task,

        [Alias('Help')]
        [switch]`$ListTasks,

        [switch]`$Only,

        [switch]`$Outline,

        [string]`$TaskDirectory = '.build',

        [string]`$NewTask,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]`$Arguments
    )

    # Find the project root with .build directory
    `$buildPath = Find-BuildDirectory -TaskDirectory `$TaskDirectory

    if (-not `$buildPath) {
        Write-Error "Could not find '`$TaskDirectory' directory in current path or any parent directory."
        Write-Host "Searched from: `$(Get-Location)" -ForegroundColor Yellow
        Write-Host "Make sure you're in a directory within a project that has a '`$TaskDirectory' folder." -ForegroundColor Yellow
        return
    }

    # Get the project root (parent of .build)
    `$projectRoot = Split-Path `$buildPath -Parent

    Write-Verbose "Project root: `$projectRoot"
    Write-Verbose "Build path: `$buildPath"

    # Get path to the gosh-core.ps1 script in this module
    `$goshCorePath = Join-Path `$PSScriptRoot "gosh-core.ps1"

    # Build parameter hashtable for splatting
    `$goshParams = @{}
    if (`$Task) { `$goshParams['Task'] = `$Task }
    if (`$ListTasks) { `$goshParams['ListTasks'] = `$true }
    if (`$Only) { `$goshParams['Only'] = `$true }
    if (`$Outline) { `$goshParams['Outline'] = `$true }
    if (`$TaskDirectory -ne '.build') { `$goshParams['TaskDirectory'] = `$TaskDirectory }
    if (`$NewTask) { `$goshParams['NewTask'] = `$NewTask }
    if (`$Arguments) { `$goshParams['Arguments'] = `$Arguments }

    # Execute gosh-core.ps1 from the project root directory
    # Set environment variable to signal module mode and pass the project root
    try {
        Push-Location `$projectRoot

        # Set environment variable to tell gosh.ps1 it's running in module mode
        `$env:GOSH_PROJECT_ROOT = `$projectRoot

        # Execute gosh.ps1 with proper parameter splatting
        & `$goshCorePath @goshParams

        # Propagate exit code
        if (`$LASTEXITCODE -ne 0 -and `$null -ne `$LASTEXITCODE) {
            exit `$LASTEXITCODE
        }

    } finally {
        # Clean up environment variable
        Remove-Item Env:GOSH_PROJECT_ROOT -ErrorAction SilentlyContinue
        Pop-Location
    }
}

# Create alias first, then export
Set-Alias -Name gosh -Value Invoke-Gosh
Export-ModuleMember -Function Invoke-Gosh -Alias gosh

# Register argument completer for tab completion
`$taskCompleter = {
    param(`$commandName, `$parameterName, `$wordToComplete, `$commandAst, `$fakeBoundParameters)

    # Check if -TaskDirectory was specified in the command
    `$taskDir = '.build'
    if (`$fakeBoundParameters.ContainsKey('TaskDirectory')) {
        `$taskDir = `$fakeBoundParameters['TaskDirectory']
    }

    # Find the build directory by searching upward
    `$buildPath = Find-BuildDirectory -TaskDirectory `$taskDir

    if (-not `$buildPath) {
        return @()
    }

    # Scan for project-specific tasks in task directory
    `$projectTasks = @()
    if (Test-Path `$buildPath) {
        `$buildFiles = Get-ChildItem `$buildPath -Filter '*.ps1' -File -Force
        foreach (`$file in `$buildFiles) {
            # Extract task name from file
            `$lines = Get-Content `$file.FullName -First 20 -ErrorAction SilentlyContinue
            `$content = `$lines -join "``n"
            if (`$content -match '(?m)^#\s*TASK:\s*(.+)`$') {
                `$taskNames = `$Matches[1] -split ',' | ForEach-Object { `$_.Trim() }
                `$projectTasks += `$taskNames
            } else {
                # If there is no TASK tag, use the noun portion of the filename as the task name
                `$parts = `$file.BaseName -split '-'
                if (`$parts.Count -gt 1) {
                    `$taskName = (`$parts[1..(`$parts.Count-1)] -join '-').ToLower()
                } else {
                    `$taskName = `$parts[0].ToLower()
                }
                `$projectTasks += `$taskName
            }
        }
    }

    # Core tasks (defined in gosh-core.ps1)
    `$coreTasks = @('check-index', 'check')

    # Combine and get unique task names
    `$allTasks = (`$coreTasks + `$projectTasks) | Select-Object -Unique | Sort-Object

    # Return matching completions
    `$allTasks | Where-Object { `$_ -like "`$wordToComplete*" } |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)
    }
}

Register-ArgumentCompleter -CommandName 'Invoke-Gosh' -ParameterName 'Task' -ScriptBlock `$taskCompleter
Register-ArgumentCompleter -CommandName 'gosh' -ParameterName 'Task' -ScriptBlock `$taskCompleter
"@

    $moduleScript | Out-File -FilePath $moduleScriptPath -Encoding UTF8 -Force
    Write-Host "Created module script: $moduleName.psm1" -ForegroundColor Gray

    Write-Host ""
    Write-Host "✓ Gosh module installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart your PowerShell session (or run: Import-Module Gosh -Force)" -ForegroundColor Gray
    Write-Host "  2. Navigate to any project directory with a .build/ folder" -ForegroundColor Gray
    Write-Host "  3. Run: gosh build" -ForegroundColor Gray
    Write-Host "  4. Use: gosh -ListTasks to see available tasks" -ForegroundColor Gray
    Write-Host ""
    Write-Host "The module searches upward from your current directory to find .build/ folders," -ForegroundColor Yellow
    Write-Host "so you can run gosh from any subdirectory within your project!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Module location: $userModulePath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "To update the module after modifying gosh.ps1, run: .\gosh.ps1 -AsModule" -ForegroundColor DarkGray

    return $true
}
#endregion

function Invoke-CheckGitIndex {
    <#
    .SYNOPSIS
        Checks if the git index is clean
    .DESCRIPTION
        Verifies there are no uncommitted changes in the git repository.
        This task uses Get-GitStatus utility function and provides user-friendly output.
    #>
    [CmdletBinding()]
    param()

    Write-Host "Checking git index status..." -ForegroundColor Cyan

    # Use the pure utility function to get git status
    $gitStatus = Get-GitStatus

    # Handle errors
    if ($null -ne $gitStatus.ErrorMessage) {
        Write-Error $gitStatus.ErrorMessage
        return $false
    }

    # Check if clean
    if ($gitStatus.IsClean) {
        Write-Host "✓ Git index is clean - no uncommitted changes" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ Git index is dirty - uncommitted changes detected:" -ForegroundColor Red
        Write-Host ""

        # SECURITY: Validate git output before display (P0 - Output Validation)
        $rawGitOutput = (git status --short 2>&1) -join "`n"
        $sanitizedOutput = Test-CommandOutput -Output $rawGitOutput
        Write-Host $sanitizedOutput

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
            $taskNames = $Matches[1] -split ',' | ForEach-Object {
                $taskName = $_.Trim()

                # SECURITY: Validate task name format (P0 - Task Name Validation)
                if ($taskName -cnotmatch '^[a-z0-9][a-z0-9\-]*$') {
                    Write-Warning "Invalid task name format '$taskName' in $FilePath (only lowercase letters, numbers, and hyphens allowed)"
                    return $null
                }

                # Enforce reasonable length
                if ($taskName.Length -gt 50) {
                    Write-Warning "Task name too long (max 50 chars): $taskName"
                    return $null
                }

                return $taskName
            } | Where-Object { $null -ne $_ }

            if ($taskNames.Count -gt 0) {
                $metadata.Names = @($taskNames)
            }
        } else {
            # if there is no TASK tag, use the noun portion of the filename as the task name
            # Extract task name: Invoke-My-Custom-Task -> my-custom-task
            # Split on '-', skip first part (verb), join remaining with '-', convert to lowercase
            $parts = (Get-Item $FilePath).BaseName -split '-'
            if ($parts.Count -gt 1) {
                $taskName = ($parts[1..($parts.Count-1)] -join '-').ToLower()
            } else {
                $taskName = $parts[0].ToLower()
            }
            $metadata.Names = @($taskName)
        }

        # Extract description
        if ($content -match '(?m)^#\s*DESCRIPTION:[ \t]*([^\r\n]*)') {
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

    # Load tasks from directory (exclude test files)
    $buildFiles = Get-ChildItem $BuildPath -Filter "*.ps1" -File -Force | Where-Object { $_.Name -notmatch '\.Tests\.ps1$' }
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
    param(
        [string]$TaskDirectory,
        [string]$ScriptRoot = $PSScriptRoot
    )

    $allTasks = @{}

    # Get core tasks
    $coreTasks = Get-CoreTasks
    foreach ($key in $coreTasks.Keys) {
        $allTasks[$key] = $coreTasks[$key]
    }

    # Get project-specific tasks from specified directory
    # SECURITY: Runtime path validation (P1 - Runtime Path Validation)
    # This is defense-in-depth: parameter validation should catch most issues,
    # but we validate again at runtime to ensure resolved paths stay within project

    # Resolve the full path
    if ([System.IO.Path]::IsPathRooted($TaskDirectory)) {
        $buildPath = $TaskDirectory
    } else {
        $buildPath = Join-Path $ScriptRoot $TaskDirectory
    }

    # Get the resolved absolute paths for comparison
    $resolvedPath = [System.IO.Path]::GetFullPath($buildPath)
    $projectRoot = [System.IO.Path]::GetFullPath($ScriptRoot)

    # Ensure the resolved path is within project directory
    if (-not $resolvedPath.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "TaskDirectory resolves outside project directory: $TaskDirectory"
        Write-Warning "Project root: $projectRoot"
        Write-Warning "Resolved path: $resolvedPath"
        throw "TaskDirectory must resolve to a path within the project directory"
    }

    $projectTasks = Get-ProjectTasks -BuildPath $resolvedPath

    # Project tasks override core tasks if there's a naming conflict
    foreach ($key in $projectTasks.Keys) {
        if ($allTasks.ContainsKey($key)) {
            Write-Warning "Project task '$key' is overriding core task"
        }
        $allTasks[$key] = $projectTasks[$key]
    }

    return $allTasks
}

function Show-TaskOutline {
    <#
    .SYNOPSIS
        Displays the task dependency tree without executing tasks
    #>
    param(
        [string[]]$TaskNames,
        [hashtable]$AllTasks,
        [bool]$SkipDependencies = $false
    )

    function Get-ExecutionOrder {
        param(
            [string]$TaskName,
            [hashtable]$Tasks,
            [hashtable]$Visited = @{},
            [System.Collections.ArrayList]$Order
        )

        if ($Visited.ContainsKey($TaskName)) {
            return
        }

        $Visited[$TaskName] = $true

        if ($Tasks.ContainsKey($TaskName)) {
            $taskInfo = $Tasks[$TaskName]

            # Process dependencies first
            foreach ($dep in $taskInfo.Dependencies) {
                if ($Tasks.ContainsKey($dep)) {
                    Get-ExecutionOrder -TaskName $dep -Tasks $Tasks -Visited $Visited -Order $Order
                }
            }

            # Add current task
            [void]$Order.Add($TaskName)
        }
    }

    function Show-DependencyTree {
        param(
            [string]$TaskName,
            [hashtable]$Tasks,
            [int]$Indent = 0,
            [bool]$IsLast = $true,
            [string]$Prefix = ""
        )

        $taskInfo = $Tasks[$TaskName]
        $primaryName = $taskInfo.Names[0]

        # Determine tree characters
        if ($Indent -eq 0) {
            $branch = ""
            $connector = ""
        } else {
            $branch = if ($IsLast) { "└── " } else { "├── " }
            $connector = if ($IsLast) { "    " } else { "│   " }
        }

        # Display task name with description
        $taskDisplay = $primaryName
        if (-not [string]::IsNullOrWhiteSpace($taskInfo.Description)) {
            Write-Host "$Prefix$branch" -NoNewline -ForegroundColor Gray
            Write-Host $taskDisplay -NoNewline -ForegroundColor Cyan
            Write-Host " ($($taskInfo.Description))" -ForegroundColor Gray
        } else {
            Write-Host "$Prefix$branch" -NoNewline -ForegroundColor Gray
            Write-Host $taskDisplay -ForegroundColor Cyan
        }

        # Show dependencies recursively
        if ($taskInfo.Dependencies.Count -gt 0 -and -not $SkipDependencies) {
            $depCount = $taskInfo.Dependencies.Count
            for ($i = 0; $i -lt $depCount; $i++) {
                $dep = $taskInfo.Dependencies[$i]
                $isLastDep = ($i -eq $depCount - 1)

                if ($Tasks.ContainsKey($dep)) {
                    Show-DependencyTree -TaskName $dep -Tasks $Tasks -Indent ($Indent + 1) -IsLast $isLastDep -Prefix "$Prefix$connector"
                } else {
                    # Missing dependency
                    $depBranch = if ($isLastDep) { "└── " } else { "├── " }
                    Write-Host "$Prefix$connector$depBranch" -NoNewline -ForegroundColor Gray
                    Write-Host $dep -NoNewline -ForegroundColor Red
                    Write-Host " (NOT FOUND)" -ForegroundColor Red
                }
            }
        } elseif ($SkipDependencies -and $taskInfo.Dependencies.Count -gt 0) {
            Write-Host "$Prefix$connector" -NoNewline -ForegroundColor Gray
            Write-Host "(Dependencies skipped: $($taskInfo.Dependencies -join ', '))" -ForegroundColor Yellow
        }
    }

    # Header
    Write-Host ""
    Write-Host "Task execution plan for: " -NoNewline -ForegroundColor Cyan
    Write-Host ($TaskNames -join ', ') -ForegroundColor White

    if ($SkipDependencies) {
        Write-Host "(Dependencies will be skipped with -Only flag)" -ForegroundColor Yellow
    }

    Write-Host ""

    # Show dependency tree for each task
    foreach ($taskName in $TaskNames) {
        if ($AllTasks.ContainsKey($taskName)) {
            Show-DependencyTree -TaskName $taskName -Tasks $AllTasks
            Write-Host ""
        } else {
            Write-Host "$taskName " -NoNewline -ForegroundColor Red
            Write-Host "(NOT FOUND)" -ForegroundColor Red
            Write-Host ""
        }
    }

    # Calculate and show execution order
    $executionOrder = New-Object System.Collections.ArrayList
    $visited = @{}

    foreach ($taskName in $TaskNames) {
        if ($AllTasks.ContainsKey($taskName)) {
            if ($SkipDependencies) {
                [void]$executionOrder.Add($taskName)
            } else {
                Get-ExecutionOrder -TaskName $taskName -Tasks $AllTasks -Visited $visited -Order $executionOrder
            }
        }
    }

    if ($executionOrder.Count -gt 0) {
        Write-Host "Execution order:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $executionOrder.Count; $i++) {
            Write-Host "  $($i + 1). $($executionOrder[$i])" -ForegroundColor White
        }
        Write-Host ""
    }
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

    # Mark as executed BEFORE processing dependencies to prevent circular loops
    $ExecutedTasks[$primaryName] = $true

    # Execute dependencies first (unless skipped)
    if ($TaskInfo.Dependencies.Count -gt 0) {
        if ($SkipDependencies) {
            Write-Host "Skipping dependencies for '$primaryName': $($TaskInfo.Dependencies -join ', ')" -ForegroundColor Yellow
        } else {
            Write-Host "Dependencies for '$primaryName': $($TaskInfo.Dependencies -join ', ')" -ForegroundColor Gray
            foreach ($dep in $TaskInfo.Dependencies) {
                if ($AllTasks.ContainsKey($dep)) {
                    Write-Host "`nExecuting dependency: $dep" -ForegroundColor Yellow
                    $depResult = Invoke-Task -TaskInfo $AllTasks[$dep] -AllTasks $AllTasks -Arguments $Arguments -ExecutedTasks $ExecutedTasks
                    if (-not $depResult) {
                        Write-Host "Dependency '$dep' failed" -ForegroundColor Red
                        # Stop on dependency failure unless ErrorAction permits continuing
                        if ($ErrorActionPreference -eq 'Stop') {
                            return $false
                        }
                        Write-Host "Continuing despite dependency failure due to -ErrorAction $ErrorActionPreference..." -ForegroundColor Yellow
                    }
                } else {
                    Write-Warning "Dependency '$dep' not found, skipping"
                }
            }
            Write-Host ""
        }
    }

    # Execute the task
    if ($TaskInfo.IsCore) {
        # SECURITY: Log core task execution (P0 - Security Event Logging)
        Write-SecurityLog -Event "TaskExecution" -Details "Core task: $primaryName" -Severity "Info"

        # Execute core task function
        $result = & $TaskInfo.Function

        # Log completion
        $status = if ($result) { "succeeded" } else { "failed" }
        Write-SecurityLog -Event "TaskCompletion" -Details "Core task: $primaryName ($status)" -Severity $(if ($result) { "Info" } else { "Error" })

        return $result
    } else {
        # SECURITY: Log task execution (P0 - Security Event Logging)
        Write-SecurityLog -Event "TaskExecution" -Details "Task: $primaryName, Script: $($TaskInfo.ScriptPath)" -Severity "Info"

        # Execute external script with utility functions injected
        try {
            # SECURITY: Validate script path before interpolation (P0 - Path Sanitization)
            $scriptPath = $TaskInfo.ScriptPath

            # Check for dangerous characters that could enable code injection
            if ($scriptPath -match '[`$();{}\[\]|&<>]') {
                throw "Script path contains potentially dangerous characters: $scriptPath"
            }

            # Validate path is within project directory
            $fullScriptPath = [System.IO.Path]::GetFullPath($scriptPath)
            $projectRoot = [System.IO.Path]::GetFullPath($script:EffectiveScriptRoot)

            if (-not $fullScriptPath.StartsWith($projectRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $fullScriptPath -ne $projectRoot) {
                throw "Script path is outside project directory: $scriptPath"
            }

            # Get utility functions from Gosh
            $utilities = Get-GoshUtilities

            # Build function definitions for injection
            $utilityDefinitions = @()
            foreach ($util in $utilities.GetEnumerator()) {
                $funcDef = $util.Value.ToString()
                $utilityDefinitions += "function $($util.Key) { $funcDef }"
            }

            # Create the complete script that:
            # 1. Defines utility functions
            # 2. Sets up task context variables
            # 3. Executes the original task script
            $scriptContent = @"
# Injected Gosh utility functions
$($utilityDefinitions -join "`n")

# Set task context variables
`$TaskScriptRoot = '$([System.IO.Path]::GetDirectoryName($TaskInfo.ScriptPath))'

# Execute the original task script in the context of its directory
Push-Location `$TaskScriptRoot
try {
    . '$($TaskInfo.ScriptPath)' @Arguments
} finally {
    Pop-Location
}
"@

            $scriptBlock = [ScriptBlock]::Create($scriptContent)

            # Execute with the injected functions and context
            & $scriptBlock

        } catch {
            Write-Error "Error executing task '$primaryName': $_"
            Write-SecurityLog -Event "TaskCompletion" -Details "Task: $primaryName (failed with error: $_)" -Severity "Error"
            return $false
        }

        # Check exit code
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            Write-SecurityLog -Event "TaskCompletion" -Details "Task: $primaryName (failed with exit code: $LASTEXITCODE)" -Severity "Error"
            return $false
        }

        Write-SecurityLog -Event "TaskCompletion" -Details "Task: $primaryName (succeeded)" -Severity "Info"
        return $true
    }
}

# Handle parameter sets
switch ($PSCmdlet.ParameterSetName) {
    'InstallModule' {
        $installResult = Install-GoshModule
        exit $(if ($installResult) { 0 } else { 1 })
    }
    'Help' {
        # Default behavior when no parameters - show available tasks
        Write-Host "Gosh! Build orchestration for PowerShell" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\gosh.ps1 <task> [task2 task3...] [arguments]" -ForegroundColor Gray
        Write-Host "  .\gosh.ps1 <task>,<task2>,<task3> [arguments]  (comma-separated)" -ForegroundColor Gray
        Write-Host "  .\gosh.ps1 <task> -Only [arguments]  (skip dependencies)" -ForegroundColor Gray
        Write-Host "  .\gosh.ps1 -ListTasks  (or -Help)" -ForegroundColor Gray
        Write-Host "  .\gosh.ps1 -NewTask <name>" -ForegroundColor Gray
        Write-Host "  .\gosh.ps1 -AsModule" -ForegroundColor Gray
        Write-Host ""

        # Show available tasks
        $ListTasks = $true
    }
}

# Determine the effective script root
# When running as a module, use GOSH_PROJECT_ROOT environment variable
# When running as a script, use $PSScriptRoot
$script:EffectiveScriptRoot = if ($env:GOSH_PROJECT_ROOT) {
    Write-Verbose "Running in module mode, using project root: $env:GOSH_PROJECT_ROOT"
    $env:GOSH_PROJECT_ROOT
} else {
    Write-Verbose "Running in script mode, using PSScriptRoot: $PSScriptRoot"
    $PSScriptRoot
}

# Discover all available tasks
$availableTasks = Get-AllTasks -TaskDirectory $TaskDirectory -ScriptRoot $EffectiveScriptRoot

# SECURITY: Log TaskDirectory usage if non-default (P0 - Security Event Logging)
if ($TaskDirectory -ne ".build") {
    Write-SecurityLog -Event "TaskDirectoryUsage" -Details "TaskDirectory: $TaskDirectory" -Severity "Info"
}

# Handle CreateTask parameter set
if ($PSCmdlet.ParameterSetName -eq 'CreateTask') {
    Write-Host "Creating new task: $NewTask" -ForegroundColor Cyan

    # Ensure task directory exists
    $buildPath = Join-Path $EffectiveScriptRoot $TaskDirectory
    if (-not (Test-Path $buildPath)) {
        New-Item -Path $buildPath -ItemType Directory | Out-Null
        Write-Host "Created $TaskDirectory directory" -ForegroundColor Gray
    }

    # Generate filename: Invoke-TaskName.ps1 (with proper capitalization)
    $taskNameCapitalized = (Get-Culture).TextInfo.ToTitleCase($NewTask.ToLower())
    $fileName = "Invoke-$taskNameCapitalized.ps1"
    $filePath = Join-Path $buildPath $fileName

    # Create task file template
    $template = @"
# TASK: $($NewTask.ToLower())
# DESCRIPTION: TODO: Add description for this task
# DEPENDS:

Write-Host "Running $($NewTask.ToLower()) task..." -ForegroundColor Cyan

# TODO: Implement task logic here

Write-Host "✓ Task completed successfully" -ForegroundColor Green
exit 0
"@

    # SECURITY: Use atomic file creation to prevent race conditions (P2 - Atomic File Creation)
    # Use -NoClobber to fail if file exists (atomic check-and-create)
    try {
        $template | Out-File -FilePath $filePath -Encoding UTF8 -NoClobber -ErrorAction Stop

        # SECURITY: Log file creation event (P0 - Security Event Logging)
        Write-SecurityLog -Event "FileCreation" -Details "Created task file: $fileName in $TaskDirectory" -Severity "Info"
    }
    catch [System.IO.IOException] {
        Write-Error "Task file already exists: $fileName"
        exit 1
    }
    catch {
        Write-Error "Failed to create task file: $_"
        exit 1
    }

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

# Handle ListTasks parameter set
if ($PSCmdlet.ParameterSetName -eq 'ListTasks' -or $ListTasks) {
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

# Handle TaskExecution parameter set
if ($PSCmdlet.ParameterSetName -eq 'TaskExecution') {
    # Parse task list - support comma-separated or space-separated tasks
    $taskList = @()
    $remainingArgs = @()
    $collectingTasks = $true

    # Process Task parameter - could be array or single string with commas
    foreach ($taskArg in $Task) {
    if ($taskArg -match ',') {
        # Comma-separated tasks in a single string
        $taskList += $taskArg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
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
        } elseif ($availableTasks.ContainsKey($arg)) {
            # Valid task name
            $taskList += $arg
        } else {
            # Not a task, must be an argument
            $collectingTasks = $false
            $remainingArgs += $arg
        }
    } else {
        $remainingArgs += $arg
    }
}

# Handle -Outline flag (before validation so we can show missing tasks)
if ($Outline) {
    Show-TaskOutline -TaskNames $taskList -AllTasks $availableTasks -SkipDependencies $Only
    exit 0
}

# Validate all tasks exist
foreach ($taskName in $taskList) {
    if (-not $availableTasks.ContainsKey($taskName)) {
        Write-Error "Task '$taskName' not found. Available tasks: $($availableTasks.Keys | Sort-Object -Unique | Join-String -Separator ', ')"
        exit 1
    }
}

function Write-Separator {
        <#
        .SYNOPSIS
            Writes a horizontal separator line
        .DESCRIPTION
            Displays a horizontal line of repeated characters in the specified color
        .PARAMETER Character
            The character to repeat for the separator line. Defaults to '='
        .PARAMETER Length
            The length of the separator line. Defaults to 60
        .PARAMETER Color
            The foreground color for the separator. Defaults to 'DarkGray'
        #>
        [CmdletBinding()]
        param(
            [string]$Character = '=',
            [int]$Length = 60,
            [System.ConsoleColor]$Color = 'DarkGray'
        )

        Write-Host ($Character * $Length) -ForegroundColor $Color
    }

# Execute all tasks in sequence
$executedTasks = @{}
$allSucceeded = $true
$failedTasks = @()

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
        $failedTasks += $taskName

        # Check if we should stop on error (default behavior)
        if ($ErrorActionPreference -eq 'Stop') {
            break
        }
        # Otherwise continue to next task (when ErrorAction is Continue, SilentlyContinue, or Ignore)
        Write-Host "Continuing to next task due to -ErrorAction $ErrorActionPreference..." -ForegroundColor Yellow
    } else {
        Write-Host "`nTask '$taskName' completed successfully" -ForegroundColor Green
    }

    if ($taskList.Count -gt 1 -and $taskName -ne $taskList[-1]) {
        Write-Host ""
        Write-Separator -Character "=" -Length 60 -Color DarkGray
        Write-Host ""
    }
}

# Summary if there were failures
if (-not $allSucceeded) {
    Write-Host ""
    Write-Separator -Character "=" -Length 60 -Color Red
    Write-Host "Build completed with failures" -ForegroundColor Red
    Write-Host "Failed tasks: $($failedTasks -join ', ')" -ForegroundColor Red
    Write-Separator -Character "=" -Length 60 -Color Red
    exit 1
}

} # End TaskExecution parameter set

exit 0
