#Requires -Version 7.0
using namespace System.Management.Automation

<#
.SYNOPSIS
    Gosh! Module builder and installer
.DESCRIPTION
    Manages the Gosh PowerShell module installation, uninstallation, and building.
    This script handles creating the module structure, copying files, and managing
    module paths across different platforms (Windows, Linux, macOS).
.PARAMETER Install
    Install Gosh as a PowerShell module for the current user. This enables the
    'gosh' command to be used globally from any directory.
.PARAMETER Uninstall
    Remove Gosh from the PowerShell module installation. Automatically detects all
    installed versions and removes them.
.PARAMETER ModuleOutputPath
    Specify a custom path where the module should be installed. If not provided,
    uses the default user module path. Used with -Install parameter.
.PARAMETER NoImport
    Do not automatically import the module after installation. Used with -Install
    parameter for build and release scenarios.
.PARAMETER Force
    Skip confirmation prompt before uninstalling. Used with -Uninstall parameter.
.EXAMPLE
    .\New-GoshModule.ps1 -Install
    Installs Gosh as a PowerShell module for the current user.
.EXAMPLE
    .\New-GoshModule.ps1 -Install -NoImport
    Installs the module without importing it (useful for build scenarios).
.EXAMPLE
    .\New-GoshModule.ps1 -Install -ModuleOutputPath "C:\Custom\Path"
    Installs the module to a custom path.
.EXAMPLE
    .\New-GoshModule.ps1 -Uninstall
    Removes Gosh from all installed locations.
.EXAMPLE
    .\New-GoshModule.ps1 -Uninstall -Force
    Removes Gosh without confirmation prompt.
#>
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    # Install parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Install')]
    [string]$ModuleOutputPath,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$NoImport,

    # Uninstall parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'Uninstall')]
    [switch]$Uninstall,

    [Parameter(ParameterSetName = 'Uninstall')]
    [switch]$Force
)

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
    .PARAMETER ModuleOutputPath
        Custom path where the module should be installed. If not provided,
        uses the default user module path.
    .PARAMETER NoImport
        Do not automatically import the module after installation. Used for
        build and release scenarios.
    #>
    [CmdletBinding()]
    param(
        [string]$ModuleOutputPath,
        [switch]$NoImport
    )

    Write-Host "Installing Gosh as a PowerShell module..." -ForegroundColor Cyan
    Write-Host ""

    # Determine module installation path (cross-platform)
    $moduleName = "Gosh"

    if ($ModuleOutputPath) {
        # Use custom path
        $userModulePath = Join-Path $ModuleOutputPath $moduleName
        Write-Host "Using custom module path: $userModulePath" -ForegroundColor Gray
    }
    else {
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
        Write-Host "Using default module path: $userModulePath" -ForegroundColor Gray
    }

    # Create module directory (overwrites if exists for idempotency)
    if (Test-Path $userModulePath) {
        Write-Host "Module directory exists, updating..." -ForegroundColor Yellow
        Remove-Item -Path $userModulePath -Recurse -Force
    }

    New-Item -Path $userModulePath -ItemType Directory -Force | Out-Null
    Write-Host "Created module directory: $userModulePath" -ForegroundColor Gray

    # Copy gosh.ps1 to the module directory (so it can be invoked as a script)
    $goshScriptPath = Join-Path $PSScriptRoot "gosh.ps1"
    if (-not (Test-Path $goshScriptPath)) {
        Write-Error "Could not find gosh.ps1 at: $goshScriptPath"
        return $false
    }

    $goshCorePath = Join-Path $userModulePath "gosh-core.ps1"
    Copy-Item -Path $goshScriptPath -Destination $goshCorePath -Force
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

    if (-not $NoImport) {
        # Import the module automatically
        Write-Host "Importing module..." -ForegroundColor Gray
        try {
            Import-Module $userModulePath -Force
            Write-Host "✓ Module imported successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "You can now use 'gosh' command from any directory." -ForegroundColor Yellow
            Write-Host "Examples:" -ForegroundColor Gray
            Write-Host "  gosh build" -ForegroundColor Gray
            Write-Host "  gosh -ListTasks" -ForegroundColor Gray
            Write-Host "  gosh format lint build -Only" -ForegroundColor Gray
        }
        catch {
            Write-Host "⚠ Module installed but import failed. You may need to restart PowerShell." -ForegroundColor Yellow
            Write-Host "To import manually: Import-Module '$userModulePath' -Force" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "Module installation complete (not imported due to -NoImport flag)." -ForegroundColor Yellow
        Write-Host "To use the module, run: Import-Module '$userModulePath' -Force" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Examples (after importing):" -ForegroundColor Gray
        Write-Host "  gosh build" -ForegroundColor Gray
        Write-Host "  gosh -ListTasks" -ForegroundColor Gray
        Write-Host "  gosh format lint build -Only" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "The module searches upward from your current directory to find .build/ folders," -ForegroundColor Yellow
    Write-Host "so you can run gosh from any subdirectory within your project!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Module location: $userModulePath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "To update the module after modifying gosh.ps1, run: .\New-GoshModule.ps1 -Install" -ForegroundColor DarkGray

    return $true
}

function Invoke-UninstallGoshModule {
    <#
    .SYNOPSIS
        Removes Gosh from all installed module locations
    .DESCRIPTION
        Uninstalls Gosh from the PowerShell module installation. Automatically detects
        and removes all installed versions from default user paths. If removal fails,
        creates a recovery file with manual removal instructions.
    .PARAMETER Force
        Skip confirmation prompt before uninstalling
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    Write-Host "Gosh Module Uninstallation" -ForegroundColor Cyan
    Write-Host ""

    # Detect all Gosh module installations (current platform only)
    $moduleName = "Gosh"
    $installLocations = @()

    # Build list of potential installation paths based on current platform
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
        # Windows: Check Documents\PowerShell\Modules
        $userModulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell" "Modules" $moduleName
        if (Test-Path $userModulePath) {
            $installLocations += $userModulePath
        }
    }
    else {
        # Linux/macOS: Check .local/share/powershell/Modules
        $userModulePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "powershell" "Modules" $moduleName
        if (Test-Path $userModulePath) {
            $installLocations += $userModulePath
        }
    }

    # Check for installed module in PSModulePath
    $modulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    foreach ($modulePath in $modulePaths) {
        $goshModulePath = Join-Path $modulePath $moduleName
        if ((Test-Path $goshModulePath) -and $goshModulePath -notin $installLocations) {
            $installLocations += $goshModulePath
        }
    }

    if ($installLocations.Count -eq 0) {
        Write-Host "⚠ Gosh module is not installed in any known location." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Checked paths:" -ForegroundColor Gray
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -or (-not $IsLinux -and -not $IsMacOS)) {
            $userModulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell" "Modules" $moduleName
            Write-Host "  - $userModulePath" -ForegroundColor Gray
        }
        else {
            $userModulePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "powershell" "Modules" $moduleName
            Write-Host "  - $userModulePath" -ForegroundColor Gray
        }
        Write-Host ""
        return $false
    }

    # Display installations found
    Write-Host "Found $($installLocations.Count) Gosh installation(s):" -ForegroundColor Yellow
    Write-Host ""
    foreach ($location in $installLocations) {
        Write-Host "  - $location" -ForegroundColor Gray
    }
    Write-Host ""

    # Confirm uninstallation
    if (-not $Force) {
        $response = Read-Host "Uninstall Gosh from all locations? (y/n)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
            return $false
        }
    }

    Write-Host ""
    Write-Host "Uninstalling Gosh..." -ForegroundColor Cyan

    # Track removal status
    $successCount = 0
    $failureLocations = @()

    # Remove module from memory if currently imported
    $goshModule = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
    if ($goshModule) {
        Write-Host "Removing Gosh module from current session..." -ForegroundColor Gray
        Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    }

    # Remove each installation
    foreach ($location in $installLocations) {
        try {
            # Remove the directory
            Write-Host "Removing: $location" -ForegroundColor Gray
            Remove-Item -Path $location -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ Successfully removed" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "  ✗ Failed to remove: $($_.Exception.Message)" -ForegroundColor Red
            $failureLocations += @{
                Path = $location
                Error = $_.Exception.Message
            }
        }
    }

    Write-Host ""

    # Handle results
    if ($failureLocations.Count -eq 0) {
        # Complete success
        Write-Host "✓ Gosh module uninstalled successfully from all locations!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The 'gosh' command will no longer be available." -ForegroundColor Yellow
        Write-Host "You may need to restart PowerShell for changes to take effect." -ForegroundColor Yellow
        Write-Host ""
        return $true
    }
    else {
        # Partial or complete failure - create recovery file
        Write-Host "⚠ Partial uninstallation failure - cleaning up what we can" -ForegroundColor Yellow
        Write-Host ""

        # Create recovery instruction file
        $recoveryPath = Join-Path $env:TEMP "Gosh-Uninstall-Manual.txt"
        $recoveryContent = @"
GOSH UNINSTALLATION - MANUAL CLEANUP REQUIRED
==============================================

Automatic uninstallation failed for the following locations.
Please remove them manually:

"@

        foreach ($failure in $failureLocations) {
            $recoveryContent += "Location: $($failure.Path)$([Environment]::NewLine)"
            $recoveryContent += "Error: $($failure.Error)$([Environment]::NewLine)"
            $recoveryContent += [Environment]::NewLine
            $recoveryContent += "To remove manually:$([Environment]::NewLine)"
            $recoveryContent += "  - Use your file manager to navigate to: $(Split-Path $failure.Path)$([Environment]::NewLine)"
            $recoveryContent += "  - Delete the 'Gosh' folder at that location.$([Environment]::NewLine)"
            $recoveryContent += [Environment]::NewLine
        }

        $recoveryContent += "Locations successfully removed: $successCount$([Environment]::NewLine)"
        $recoveryContent += [Environment]::NewLine
        $recoveryContent += "After removing the above locations manually, you may need to:$([Environment]::NewLine)"
        $recoveryContent += "  - Restart PowerShell$([Environment]::NewLine)"
        $recoveryContent += "  - Clear the module cache by running:$([Environment]::NewLine)"
        $recoveryContent += "    Remove-Item -Path (Join-Path `$env:TEMP 'PowerShellModuleCache') -Force -Recurse$([Environment]::NewLine)"
        $recoveryContent += [Environment]::NewLine
        $recoveryContent += "For more help, visit: https://github.com/motowilliams/gosh$([Environment]::NewLine)"

        try {
            $recoveryContent | Out-File -FilePath $recoveryPath -Encoding UTF8 -Force
            Write-Host "Recovery instructions saved to:" -ForegroundColor Yellow
            Write-Host "  $recoveryPath" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Please follow the manual cleanup instructions in that file." -ForegroundColor Yellow
        }
        catch {
            Write-Host "Could not create recovery file: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Failed locations:" -ForegroundColor Yellow
            foreach ($failure in $failureLocations) {
                Write-Host "  - $($failure.Path)" -ForegroundColor Gray
                Write-Host "    Error: $($failure.Error)" -ForegroundColor Gray
            }
        }

        Write-Host ""
        return $false
    }
}

# Main script execution
switch ($PSCmdlet.ParameterSetName) {
    'Install' {
        $result = Install-GoshModule -ModuleOutputPath $ModuleOutputPath -NoImport:$NoImport
        exit $(if ($result) { 0 } else { 1 })
    }
    'Uninstall' {
        $result = Invoke-UninstallGoshModule -Force:$Force
        exit $(if ($result) { 0 } else { 1 })
    }
}

exit 0
