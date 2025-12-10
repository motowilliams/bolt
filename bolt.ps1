#Requires -Version 7.0
using namespace System.Management.Automation

<#
.SYNOPSIS
    Bolt! Build orchestration for PowerShell
.DESCRIPTION
    A self-contained PowerShell build system with extensible task orchestration.
    Core build tasks are built into this script. Project-specific tasks can be
    added by placing PowerShell scripts in a .build directory.

    "Bolt" - Lightning-fast PowerShell! ⚡
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
    .\bolt.ps1 build
    Executes the build task and its dependencies (format, lint).
.EXAMPLE
    .\bolt.ps1 format lint build -Only
    Executes format, lint, and build tasks without their dependencies.
.EXAMPLE
    .\bolt.ps1 -TaskDirectory "custom-tasks"
    Lists and executes tasks from the custom-tasks directory instead of .build.
.EXAMPLE
    .\bolt.ps1 -ListTasks
    Shows all available tasks.
.EXAMPLE
    .\bolt.ps1 build -Outline
    Shows the dependency tree and execution order for the build task without executing it.
.EXAMPLE
    .\bolt.ps1 -NewTask clean
    Creates a new task file named Invoke-Clean.ps1 in the task directory.
.EXAMPLE
    .\bolt.ps1 format,lint,build -ErrorAction Continue
    Runs all tasks even if one fails (useful for seeing all errors at once).
.NOTES
    For module installation, use the New-BoltModule.ps1 script:
    - Install: .\New-BoltModule.ps1 -Install
    - Uninstall: .\New-BoltModule.ps1 -Uninstall
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

    # ListVariables parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'ListVariables')]
    [switch]$ListVariables,

    # AddVariable parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'AddVariable')]
    [switch]$AddVariable,

    [Parameter(Mandatory = $true, ParameterSetName = 'AddVariable')]
    [ValidatePattern('^[a-zA-Z0-9_\-\.]+$')]
    [ValidateScript({
        if ($_.Length -gt 100) {
            throw "Variable name '$_' is too long (max 100 characters)."
        }
        return $true
    })]
    [string]$Name,

    [Parameter(Mandatory = $true, ParameterSetName = 'AddVariable')]
    [AllowEmptyString()]
    [string]$Value,

    # RemoveVariable parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'RemoveVariable')]
    [switch]$RemoveVariable,

    [Parameter(Mandatory = $true, ParameterSetName = 'RemoveVariable')]
    [ValidatePattern('^[a-zA-Z0-9_\-\.]+$')]
    [ValidateScript({
        if ($_.Length -gt 100) {
            throw "Variable name '$_' is too long (max 100 characters)."
        }
        return $true
    })]
    [ValidateScript({
        if ($_.Length -gt 100) {
            throw "Variable name '$_' is too long (max 100 characters)."
        }
        return $true
    })]
    [string]$VariableName,

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

Register-ArgumentCompleter -CommandName 'bolt.ps1' -ParameterName 'Task' -ScriptBlock $taskCompleter

#region Security Event Logging
function Write-SecurityLog {
    <#
    .SYNOPSIS
        Writes security-relevant events to audit log
    .DESCRIPTION
        Logs security events to .bolt/audit.log when $env:BOLT_AUDIT_LOG is set to 1.
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
    if ($env:BOLT_AUDIT_LOG -ne '1') {
        return
    }

    try {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $user = [Environment]::UserName
        $machine = [Environment]::MachineName
        $entry = "$timestamp | $Severity | $user@$machine | $Event | $Details"

        $logDir = Join-Path $PSScriptRoot '.bolt'
        $logPath = Join-Path $logDir 'audit.log'

        # Ensure .bolt directory exists and is actually a directory (robust approach)
        if (Test-Path $logDir) {
            # If .bolt exists but is not a directory, remove it first
            if (-not (Test-Path -PathType Container $logDir)) {
                Remove-Item $logDir -Force -ErrorAction SilentlyContinue
            }
        }

        # Create .bolt directory if it doesn't exist (more robust approach)
        if (-not (Test-Path -PathType Container $logDir)) {
            try {
                $null = New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop
                # Double-check the directory was created successfully
                if (-not (Test-Path -PathType Container $logDir)) {
                    throw "Failed to create log directory: $logDir"
                }
            }
            catch {
                # If directory creation fails, don't attempt to write log
                Write-Verbose "Failed to create log directory: $_"
                return
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

function Get-BoltUtilities {
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


function Get-BoltConfigFile {
    <#
    .SYNOPSIS
        Loads the bolt.config.json file from the project root
    .DESCRIPTION
        Searches for bolt.config.json starting from the configured .build directory,
        searching upward until the first config file is found or reaching the project root.
        Respects module mode ($env:BOLT_PROJECT_ROOT) and script mode ($PSScriptRoot).

        Returns an empty hashtable if the config file doesn't exist.
        Logs warnings for malformed JSON but doesn't fail.
    .PARAMETER ScriptRoot
        The effective script root (project root) to start searching from
    .PARAMETER TaskDirectory
        The task directory name (default: .build) to start the search
    .OUTPUTS
        Hashtable containing user-defined variables from the config file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string]$TaskDirectory = ".build"
    )

    $configFileName = "bolt.config.json"

    # Start searching from the task directory location
    $searchPath = Join-Path $ScriptRoot $TaskDirectory

    # If task directory doesn't exist, start from script root
    if (-not (Test-Path $searchPath)) {
        $searchPath = $ScriptRoot
    }

    # Search upward for bolt.config.json
    $currentPath = $searchPath
    $configPath = $null

    while ($currentPath) {
        $potentialConfig = Join-Path $currentPath $configFileName

        if (Test-Path $potentialConfig) {
            $configPath = $potentialConfig
            Write-Verbose "Found config file: $configPath"
            break
        }

        # Stop at project root (where ScriptRoot points)
        if ($currentPath -eq $ScriptRoot) {
            break
        }

        # Move up one directory
        $parentPath = Split-Path $currentPath -Parent

        # Stop if we can't go up further or reached root
        if (-not $parentPath -or $parentPath -eq $currentPath) {
            break
        }

        $currentPath = $parentPath
    }

    # If no config found, check at script root as fallback
    if (-not $configPath) {
        $fallbackConfig = Join-Path $ScriptRoot $configFileName
        if (Test-Path $fallbackConfig) {
            $configPath = $fallbackConfig
            Write-Verbose "Found config file at script root: $configPath"
        }
    }

    # Return empty hashtable if config doesn't exist
    if (-not $configPath) {
        Write-Verbose "No bolt.config.json found, using empty configuration"
        return @{}
    }

    # Load and parse the config file
    try {
        $configContent = Get-Content -Path $configPath -Raw -ErrorAction Stop
        $config = $configContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop

        Write-Verbose "Loaded config from: $configPath"
        return $config
    }
    catch {
        Write-Warning "Failed to load bolt.config.json from '$configPath': $_"
        Write-Warning "Using empty configuration. Please check the JSON syntax."
        return @{}
    }
}


function Save-BoltConfigFile {
    <#
    .SYNOPSIS
        Saves the configuration hashtable to bolt.config.json
    .DESCRIPTION
        Persists the configuration hashtable to bolt.config.json in the project root.
        Creates the file if it doesn't exist, overwrites if it does.
        Uses ConvertTo-Json with -Depth 10 to handle nested objects.
    .PARAMETER Config
        The configuration hashtable to save
    .PARAMETER ScriptRoot
        The effective script root (project root) where config will be saved
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )

    $configPath = Join-Path $ScriptRoot "bolt.config.json"

    try {
        $jsonContent = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $configPath -Value $jsonContent -Encoding UTF8 -ErrorAction Stop

        Write-Verbose "Saved config to: $configPath"
        return $true
    }
    catch {
        Write-Error "Failed to save bolt.config.json to '$configPath': $_"
        return $false
    }
}


function Add-BoltVariable {
    <#
    .SYNOPSIS
        Adds or updates a variable in the Bolt configuration
    .DESCRIPTION
        Adds or updates a variable in bolt.config.json. Supports dot notation for nested properties
        (e.g., "Colors.Header" to set a nested property). Validates parent object types and warns
        when overriding built-in variables.

        - Auto-creates parent objects when parent is undefined
        - Throws error if parent is a primitive type (string, number, etc.)
        - Warns when overriding built-in variables (ProjectRoot, TaskDirectory, etc.)
    .PARAMETER Name
        Variable name (supports dot notation for nested properties)
    .PARAMETER Value
        Variable value (string)
    .PARAMETER ScriptRoot
        The effective script root (project root)
    .PARAMETER TaskDirectory
        The task directory name (default: .build)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string]$TaskDirectory = ".build"
    )

    # Warn if overriding built-in variables
    $builtInVars = @('ProjectRoot', 'TaskDirectory', 'TaskDirectoryPath', 'TaskScriptRoot', 'TaskName', 'Colors', 'GitRoot', 'GitBranch')
    $rootVarName = ($Name -split '\.')[0]

    if ($builtInVars -contains $rootVarName) {
        Write-Warning "Variable '$Name' overrides a built-in variable. This may affect task behavior."
    }

    # Load current config
    $config = Get-BoltConfigFile -ScriptRoot $ScriptRoot -TaskDirectory $TaskDirectory

    # Handle dot notation for nested properties
    if ($Name -match '\.') {
        $parts = $Name -split '\.'
        $current = $config

        # Navigate/create parent objects
        for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
            $part = $parts[$i]

            if (-not $current.ContainsKey($part)) {
                # Create parent object if it doesn't exist
                $current[$part] = @{}
                Write-Verbose "Created parent object: $part"
            }
            elseif ($current[$part] -isnot [hashtable] -and $current[$part] -isnot [System.Collections.IDictionary]) {
                # Parent exists but is not an object - this is an error
                $parentPath = ($parts[0..$i] -join '.')
                throw "Cannot set '$Name': parent '$parentPath' is a primitive value ($(($current[$part]).GetType().Name)). Remove the parent variable first or use a different name."
            }

            $current = $current[$part]
        }

        # Set the final property
        $finalKey = $parts[-1]
        $current[$finalKey] = $Value
        Write-Verbose "Set $Name = $Value"
    }
    else {
        # Simple variable (no dot notation)
        $config[$Name] = $Value
        Write-Verbose "Set $Name = $Value"
    }

    # Save config
    $saved = Save-BoltConfigFile -Config $config -ScriptRoot $ScriptRoot

    if ($saved) {
        # Invalidate cache so next task execution picks up new config
        $script:CachedConfigJson = $null
        Write-Verbose "Configuration cache invalidated"

        Write-Host "Variable '$Name' set to '$Value'" -ForegroundColor Green
        return $true
    }
    else {
        return $false
    }
}


function Remove-BoltVariable {
    <#
    .SYNOPSIS
        Removes a variable from the Bolt configuration
    .DESCRIPTION
        Removes a variable from bolt.config.json. Supports dot notation for nested properties.
        Cascade deletes empty parent objects after removing the variable.
    .PARAMETER Name
        Variable name (supports dot notation for nested properties)
    .PARAMETER ScriptRoot
        The effective script root (project root)
    .PARAMETER TaskDirectory
        The task directory name (default: .build)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string]$TaskDirectory = ".build"
    )

    # Load current config
    $config = Get-BoltConfigFile -ScriptRoot $ScriptRoot -TaskDirectory $TaskDirectory

    # Handle dot notation for nested properties
    if ($Name -match '\.') {
        $parts = $Name -split '\.'
        $current = $config
        $parents = @()

        # Navigate to the property
        for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
            $part = $parts[$i]

            if (-not $current.ContainsKey($part)) {
                Write-Warning "Variable '$Name' does not exist in configuration"
                return $false
            }

            $parents += @{ Object = $current; Key = $part }
            $current = $current[$part]
        }

        # Remove the final property
        $finalKey = $parts[-1]

        if (-not $current.ContainsKey($finalKey)) {
            Write-Warning "Variable '$Name' does not exist in configuration"
            return $false
        }

        $current.Remove($finalKey)
        Write-Verbose "Removed $Name"

        # Cascade delete empty parents
        for ($i = $parents.Count - 1; $i -ge 0; $i--) {
            $parent = $parents[$i]
            $childObj = $parent.Object[$parent.Key]

            if ($childObj -is [hashtable] -and $childObj.Count -eq 0) {
                $parent.Object.Remove($parent.Key)
                Write-Verbose "Removed empty parent: $($parent.Key)"
            }
            else {
                break  # Stop if parent is not empty
            }
        }
    }
    else {
        # Simple variable (no dot notation)
        if (-not $config.ContainsKey($Name)) {
            Write-Warning "Variable '$Name' does not exist in configuration"
            return $false
        }

        $config.Remove($Name)
        Write-Verbose "Removed $Name"
    }

    # Save config
    $saved = Save-BoltConfigFile -Config $config -ScriptRoot $ScriptRoot

    if ($saved) {
        # Invalidate cache so next task execution picks up updated config
        $script:CachedConfigJson = $null
        Write-Verbose "Configuration cache invalidated"

        Write-Host "Variable '$Name' removed" -ForegroundColor Green
        return $true
    }
    else {
        return $false
    }
}


# Script-level variable for caching serialized config JSON
$script:CachedConfigJson = $null


function Get-BoltConfig {
    <#
    .SYNOPSIS
        Builds the complete Bolt configuration object
    .DESCRIPTION
        Returns a PSCustomObject containing built-in variables merged with user-defined
        variables from bolt.config.json. Includes performance caching - the serialized
        JSON is computed once per bolt.ps1 invocation and reused for all tasks.

        Built-in variables:
        - ProjectRoot: Absolute path to project root
        - TaskDirectory: Name of task directory (e.g., ".build")
        - TaskDirectoryPath: Absolute path to task directory
        - TaskScriptRoot: Directory of current task script (runtime only)
        - TaskName: Name of current task (runtime only)
        - Colors: Standard color scheme (Header, Success, Error, Warning, Info)
        - GitRoot: Git repository root (if in a repo)
        - GitBranch: Current git branch (if in a repo)
    .PARAMETER ScriptRoot
        The effective script root (project root)
    .PARAMETER TaskDirectory
        The task directory name (default: .build)
    .PARAMETER TaskScriptRoot
        The directory of the current task script (injected at runtime)
    .PARAMETER TaskName
        The name of the current task (injected at runtime)
    .OUTPUTS
        PSCustomObject with built-in and user-defined variables
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string]$TaskDirectory = ".build",

        [Parameter(Mandatory = $false)]
        [string]$TaskScriptRoot = $null,

        [Parameter(Mandatory = $false)]
        [string]$TaskName = $null
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Load user-defined variables from config file
    $userConfig = Get-BoltConfigFile -ScriptRoot $ScriptRoot -TaskDirectory $TaskDirectory

    # Build configuration object with built-ins
    $config = @{
        # Project structure
        ProjectRoot = $ScriptRoot
        TaskDirectory = $TaskDirectory
        TaskDirectoryPath = Join-Path $ScriptRoot $TaskDirectory

        # Task context (runtime values, may be null during non-task operations)
        TaskScriptRoot = $TaskScriptRoot
        TaskName = $TaskName

        # Standard color scheme
        Colors = @{
            Header = 'Cyan'
            Success = 'Green'
            Error = 'Red'
            Warning = 'Yellow'
            Info = 'Gray'
        }
    }

    # Add Git information if available
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitRoot) {
            $config['GitRoot'] = $gitRoot.Trim()
        }

        $gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitBranch) {
            $config['GitBranch'] = $gitBranch.Trim()
        }
    }
    catch {
        # Git not available or not in a repo - skip git variables
        Write-Verbose "Git information not available: $_"
    }

    # Merge user-defined variables (user config overrides built-ins if conflicts exist)
    foreach ($key in $userConfig.Keys) {
        if ($config.ContainsKey($key)) {
            Write-Verbose "User config overrides built-in variable: $key"
        }
        $config[$key] = $userConfig[$key]
    }

    $stopwatch.Stop()
    Write-Verbose "Configuration built in $($stopwatch.ElapsedMilliseconds)ms"

    # Convert to PSCustomObject for clean JSON serialization
    return [PSCustomObject]$config
}


function Get-CachedBoltConfigJson {
    <#
    .SYNOPSIS
        Returns cached or newly serialized Bolt configuration JSON
    .DESCRIPTION
        Caches the serialized JSON string for performance. The config is computed once
        per bolt.ps1 invocation and reused for all task executions.
    .PARAMETER ScriptRoot
        The effective script root (project root)
    .PARAMETER TaskDirectory
        The task directory name (default: .build)
    .OUTPUTS
        JSON string representation of the configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string]$TaskDirectory = ".build"
    )

    # Return cached version if available
    if ($script:CachedConfigJson) {
        Write-Verbose "Using cached configuration JSON"
        return $script:CachedConfigJson
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Build config without task-specific context (will be injected per task)
    $config = Get-BoltConfig -ScriptRoot $ScriptRoot -TaskDirectory $TaskDirectory

    # Serialize to JSON
    $script:CachedConfigJson = $config | ConvertTo-Json -Depth 10 -Compress

    $stopwatch.Stop()
    Write-Verbose "Configuration serialized and cached in $($stopwatch.ElapsedMilliseconds)ms"

    return $script:CachedConfigJson
}


function Show-BoltVariables {
    <#
    .SYNOPSIS
        Displays all Bolt configuration variables
    .DESCRIPTION
        Shows both built-in variables (provided by Bolt) and user-defined variables
        (from bolt.config.json) in an organized format.
    .PARAMETER ScriptRoot
        The effective script root (project root)
    .PARAMETER TaskDirectory
        The task directory name (default: .build)
    .OUTPUTS
        Formatted output showing categorized variables
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string]$TaskDirectory = ".build"
    )

    Write-Host "`nBolt Configuration Variables`n" -ForegroundColor Cyan

    # Get full config
    $config = Get-BoltConfig -ScriptRoot $ScriptRoot -TaskDirectory $TaskDirectory

    # Define built-in variable names
    $builtInNames = @(
        'ProjectRoot',
        'TaskDirectory',
        'TaskDirectoryPath',
        'TaskScriptRoot',
        'TaskName',
        'Colors',
        'GitRoot',
        'GitBranch'
    )

    # Categorize variables (config is PSCustomObject, use PSObject.Properties)
    $builtInVars = @{}
    $userVars = @{}

    foreach ($property in $config.PSObject.Properties) {
        $key = $property.Name
        $value = $property.Value

        if ($builtInNames -contains $key) {
            $builtInVars[$key] = $value
        }
        else {
            $userVars[$key] = $value
        }
    }
    # Display built-in variables
    Write-Host "Built-in Variables:" -ForegroundColor Yellow
    if ($builtInVars.Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor Gray
    }
    else {
        foreach ($key in ($builtInVars.Keys | Sort-Object)) {
            $value = $builtInVars[$key]
            if ($null -eq $value) {
                Write-Host "  $key = `$null" -ForegroundColor Gray
            }
            elseif ($value -is [hashtable]) {
                Write-Host "  $key = @{" -ForegroundColor Gray
                foreach ($subKey in ($value.Keys | Sort-Object)) {
                    Write-Host "    $subKey = $($value[$subKey])" -ForegroundColor DarkGray
                }
                Write-Host "  }" -ForegroundColor Gray
            }
            else {
                Write-Host "  $key = $value" -ForegroundColor Gray
            }
        }
    }

    Write-Host ""

    # Display user-defined variables
    Write-Host "User-Defined Variables:" -ForegroundColor Yellow
    if ($userVars.Count -eq 0) {
        Write-Host "  (none - create bolt.config.json to add variables)" -ForegroundColor Gray
    }
    else {
        foreach ($key in ($userVars.Keys | Sort-Object)) {
            $value = $userVars[$key]
            if ($null -eq $value) {
                Write-Host "  $key = `$null" -ForegroundColor Gray
            }
            elseif ($value -is [hashtable]) {
                Write-Host "  $key = @{" -ForegroundColor Gray
                foreach ($subKey in ($value.Keys | Sort-Object)) {
                    Write-Host "    $subKey = $($value[$subKey])" -ForegroundColor DarkGray
                }
                Write-Host "  }" -ForegroundColor Gray
            }
            else {
                Write-Host "  $key = $value" -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
}


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
            Names                  = @()
            Description            = ''
            Dependencies           = @()
            ScriptPath             = $FilePath
            IsCore                 = $false
            UsedFilenameFallback   = $false
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

            # Mark that this task used filename fallback (no # TASK: metadata)
            $metadata.UsedFilenameFallback = $true

            # Warn about filename fallback unless disabled via environment variable
            if (-not $env:BOLT_NO_FALLBACK_WARNINGS) {
                $fileName = Split-Path $FilePath -Leaf
                Write-Warning "Task file '$fileName' does not have a # TASK: metadata tag. Using filename fallback to derive task name '$taskName'. To disable this warning, set: `$env:BOLT_NO_FALLBACK_WARNINGS = 1"
            }
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

            # Get utility functions from Bolt
            $utilities = Get-BoltUtilities

            # Build function definitions for injection
            $utilityDefinitions = @()
            foreach ($util in $utilities.GetEnumerator()) {
                $funcDef = $util.Value.ToString()
                $utilityDefinitions += "function $($util.Key) { $funcDef }"
            }

            # Get Bolt configuration with task context
            $taskScriptRoot = [System.IO.Path]::GetDirectoryName($TaskInfo.ScriptPath)
            $boltConfig = Get-BoltConfig -ScriptRoot $script:EffectiveScriptRoot -TaskDirectory $TaskDirectory -TaskScriptRoot $taskScriptRoot -TaskName $primaryName

            # Serialize config to JSON for injection
            $configJson = $boltConfig | ConvertTo-Json -Depth 10 -Compress

            # Escape single quotes in JSON for PowerShell string literal
            $configJsonEscaped = $configJson -replace "'", "''"

            $stopwatchConfig = [System.Diagnostics.Stopwatch]::StartNew()
            Write-Verbose "Configuration prepared for task '$primaryName' in $($stopwatchConfig.ElapsedMilliseconds)ms"

            # Create the complete script that:
            # 1. Injects BoltConfig object
            # 2. Defines utility functions
            # 3. Sets up task context variables
            # 4. Executes the original task script
            $scriptContent = @"
# Injected Bolt configuration
`$BoltConfig = '$configJsonEscaped' | ConvertFrom-Json

# Injected Bolt utility functions
$($utilityDefinitions -join "`n")

# Set task context variables
`$TaskScriptRoot = '$taskScriptRoot'

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
    'Help' {
        # Default behavior when no parameters - show available tasks
        Write-Host "Bolt! Build orchestration for PowerShell" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\bolt.ps1 <task> [task2 task3...] [arguments]" -ForegroundColor Gray
        Write-Host "  .\bolt.ps1 <task>,<task2>,<task3> [arguments]  (comma-separated)" -ForegroundColor Gray
        Write-Host "  .\bolt.ps1 <task> -Only [arguments]  (skip dependencies)" -ForegroundColor Gray
        Write-Host "  .\bolt.ps1 -ListTasks  (or -Help)" -ForegroundColor Gray
        Write-Host "  .\bolt.ps1 -NewTask <name>" -ForegroundColor Gray
        Write-Host ""
        Write-Host "For module installation, use New-BoltModule.ps1:" -ForegroundColor Yellow
        Write-Host "  .\New-BoltModule.ps1 -Install" -ForegroundColor Gray
        Write-Host "  .\New-BoltModule.ps1 -Uninstall" -ForegroundColor Gray
        Write-Host ""

        # Show available tasks
        $ListTasks = $true
    }
}

# Determine the effective script root
# When running as a module, use BOLT_PROJECT_ROOT environment variable
# When running as a script, use $PSScriptRoot
$script:EffectiveScriptRoot = if ($env:BOLT_PROJECT_ROOT) {
    Write-Verbose "Running in module mode, using project root: $env:BOLT_PROJECT_ROOT"
    $env:BOLT_PROJECT_ROOT
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
    Write-Host "  3. Run '.\bolt.ps1 $($NewTask.ToLower())' to execute your task" -ForegroundColor Gray
    Write-Host "  4. Restart PowerShell to enable tab completion for the new task" -ForegroundColor Gray

    exit 0
}

# Handle ListVariables parameter set
if ($PSCmdlet.ParameterSetName -eq 'ListVariables') {
    Show-BoltVariables -ScriptRoot $EffectiveScriptRoot -TaskDirectory $TaskDirectory
    exit 0
}

# Handle AddVariable parameter set
if ($PSCmdlet.ParameterSetName -eq 'AddVariable') {
    Write-Host "Adding variable: $Name = $Value" -ForegroundColor Cyan

    try {
        Add-BoltVariable -Name $Name -Value $Value -ScriptRoot $EffectiveScriptRoot -TaskDirectory $TaskDirectory
        Write-Host "✓ Variable '$Name' added successfully" -ForegroundColor Green
        Write-Host "  Run '.\bolt.ps1 -ListVariables' to see all variables" -ForegroundColor Gray
        exit 0
    }
    catch {
        Write-Error "Failed to add variable: $_"
        exit 1
    }
}

# Handle RemoveVariable parameter set
if ($PSCmdlet.ParameterSetName -eq 'RemoveVariable') {
    Write-Host "Removing variable: $VariableName" -ForegroundColor Cyan

    try {
        Remove-BoltVariable -Name $VariableName -ScriptRoot $EffectiveScriptRoot -TaskDirectory $TaskDirectory
        Write-Host "✓ Variable '$VariableName' removed successfully" -ForegroundColor Green
        Write-Host "  Run '.\bolt.ps1 -ListVariables' to see remaining variables" -ForegroundColor Gray
        exit 0
    }
    catch {
        Write-Error "Failed to remove variable: $_"
        exit 1
    }
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
