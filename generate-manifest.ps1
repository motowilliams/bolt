# Generate PowerShell Module Manifest using Semi-Automatic Approach
# This script uses a module script with -AsModule to install the module, then analyzes it dynamically

param(
    [string]$WorkspacePath = "/workspace",
    [Parameter(Mandatory = $true)]
    [string]$ModulePath,
    [Parameter(Mandatory = $true)]
    [string]$ModuleVersion,
    [Parameter(Mandatory = $true)]
    [string]$Tags,
    [string]$ProjectUri = "",
    [string]$LicenseUri = "",
    [string]$ReleaseNotes = ""
)

Write-Host "🚀 Starting PowerShell module manifest generation..." -ForegroundColor Cyan

# Convert Tags string to array
$TagsArray = $Tags -split ',' | ForEach-Object { $_.Trim() }

Write-Host "📋 Using tags: $($TagsArray -join ', ')" -ForegroundColor Gray

# Step 1: Install module using its built-in -AsModule feature
Write-Host "📦 Installing module using -AsModule feature..." -ForegroundColor Yellow
$moduleScriptPath = Join-Path $WorkspacePath $ModulePath

if (-not (Test-Path $moduleScriptPath)) {
    Write-Error "❌ Module script not found at $moduleScriptPath"
    exit 1
}

# Extract module name from the script path (without extension)
$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)

# Run module script with -AsModule to install it
& $moduleScriptPath -AsModule

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Failed to install module"
    exit 1
}

Write-Host "✅ Module installed successfully" -ForegroundColor Green

# Step 2: Import or analyze the existing module
Write-Host "🔍 Analyzing the installed module..." -ForegroundColor Yellow

# First try to get it from available modules
$module = Get-Module -Name $moduleName -ListAvailable | Select-Object -First 1

if (-not $module) {
    Write-Host "Module not found in ListAvailable, trying to import..." -ForegroundColor Yellow
    try {
        Import-Module -Name $moduleName -Force
        $module = Get-Module -Name $moduleName
    }
    catch {
        Write-Error "❌ Failed to find or import module '$moduleName': $_"
        exit 1
    }
}

if (-not $module) {
    Write-Error "❌ Could not find module '$moduleName' after installation"
    exit 1
}

Write-Host "✅ Found module: $($module.Name) version $($module.Version)" -ForegroundColor Green

# Step 3: Extract information from the module
Write-Host "📋 Extracting module information..." -ForegroundColor Yellow

$exportedFunctions = $module.ExportedFunctions.Keys
$exportedCmdlets = $module.ExportedCmdlets.Keys
$exportedAliases = $module.ExportedAliases.Keys

Write-Host "Exported Functions ($($exportedFunctions.Count)):" -ForegroundColor Cyan
$exportedFunctions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host "Exported Cmdlets ($($exportedCmdlets.Count)):" -ForegroundColor Cyan
$exportedCmdlets | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host "Exported Aliases ($($exportedAliases.Count)):" -ForegroundColor Cyan
$exportedAliases | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

# Get additional module information
$moduleBase = $module.ModuleBase
$rootModule = if ($module.RootModule) { Split-Path -Leaf $module.RootModule } else { $ModulePath }
$description = if ($module.Description) { $module.Description } else { "PowerShell module with build orchestration capabilities" }
$author = if ($module.Author) { $module.Author } else { "Module Author" }
$companyName = if ($module.CompanyName) { $module.CompanyName } else { "" }

# Step 3.5: Determine ProjectUri from git config if not provided
if ([string]::IsNullOrWhiteSpace($ProjectUri)) {
    Write-Host "🔍 ProjectUri not provided, inspecting git config..." -ForegroundColor Yellow

    try {
        # Check if git is available
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            # Check if we're in a git repository and get the remote origin URL
            $gitRemoteUrl = & git config --get remote.origin.url 2>$null

            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRemoteUrl)) {
                # Convert SSH URLs to HTTPS if needed
                if ($gitRemoteUrl -match '^git@github\.com:(.+)\.git$') {
                    $ProjectUri = "https://github.com/$($Matches[1])"
                }
                elseif ($gitRemoteUrl -match '^git@([^:]+):(.+)\.git$') {
                    # Generic Git hosting (GitLab, Bitbucket, etc.)
                    $ProjectUri = "https://$($Matches[1])/$($Matches[2])"
                }
                elseif ($gitRemoteUrl -match '^https://([^/]+)/(.+)\.git$') {
                    $ProjectUri = "https://$($Matches[1])/$($Matches[2])"
                }
                elseif ($gitRemoteUrl -match '^https://([^/]+)/(.+)$') {
                    $ProjectUri = "https://$($Matches[1])/$($Matches[2])"
                }
                else {
                    # For other Git hosting services, try to clean up the URL
                    $ProjectUri = $gitRemoteUrl -replace '\.git$', '' -replace '^git@([^:]+):', 'https://$1/'
                }

                Write-Host "  ✅ Inferred ProjectUri from git: $ProjectUri" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠️  No git remote origin found, ProjectUri will be omitted" -ForegroundColor Yellow
                $ProjectUri = ""
            }
        }
        else {
            Write-Host "  ⚠️  Git not available, ProjectUri will be omitted" -ForegroundColor Yellow
            $ProjectUri = ""
        }
    }
    catch {
        Write-Host "  ⚠️  Error reading git config: $_" -ForegroundColor Yellow
        Write-Host "  ProjectUri will be omitted" -ForegroundColor Yellow
        $ProjectUri = ""
    }
}# Set default LicenseUri if not provided
if ([string]::IsNullOrWhiteSpace($LicenseUri)) {
    # Try to infer from ProjectUri if available
    if (-not [string]::IsNullOrWhiteSpace($ProjectUri)) {
        if ($ProjectUri -match '^https://github\.com/(.+)$') {
            $LicenseUri = "$ProjectUri/blob/main/LICENSE"
        }
        elseif ($ProjectUri -match '^https://gitlab\.com/(.+)$') {
            $LicenseUri = "$ProjectUri/-/blob/main/LICENSE"
        }
        else {
            $LicenseUri = "$ProjectUri/LICENSE"
        }
    }
    else {
        # No ProjectUri available, leave LicenseUri empty
        $LicenseUri = ""
    }
}

# Set default ReleaseNotes if not provided
if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
    $ReleaseNotes = "Generated module manifest for $moduleName v$ModuleVersion"
}

Write-Host "Module Details:" -ForegroundColor Cyan
Write-Host "  Module Name: $moduleName" -ForegroundColor Gray
Write-Host "  Root Module: $rootModule" -ForegroundColor Gray
Write-Host "  Module Base: $moduleBase" -ForegroundColor Gray
Write-Host "  Description: $description" -ForegroundColor Gray
Write-Host "  Author: $author" -ForegroundColor Gray
if (-not [string]::IsNullOrWhiteSpace($ProjectUri)) {
    Write-Host "  Project URI: $ProjectUri" -ForegroundColor Gray
}
if (-not [string]::IsNullOrWhiteSpace($LicenseUri)) {
    Write-Host "  License URI: $LicenseUri" -ForegroundColor Gray
}
Write-Host "  Tags: $($TagsArray -join ', ')" -ForegroundColor Gray

# Step 4: Create manifest with extracted information
Write-Host "📝 Creating module manifest..." -ForegroundColor Yellow

$manifestPath = Join-Path $WorkspacePath "$moduleName.psd1"

# Generate a new GUID for the module
$moduleGuid = [System.Guid]::NewGuid().ToString()

$manifestParams = @{
    Path = $manifestPath
    RootModule = $rootModule
    ModuleVersion = $ModuleVersion
    GUID = $moduleGuid
    Author = $author
    CompanyName = $companyName
    Copyright = "(c) $(Get-Date -Format yyyy) $author. All rights reserved."
    Description = $description
    PowerShellVersion = "7.0"
    FunctionsToExport = $exportedFunctions
    CmdletsToExport = $exportedCmdlets
    AliasesToExport = $exportedAliases
    VariablesToExport = @()
    RequiredModules = @()
    Tags = $TagsArray
}

# Only add ProjectUri and LicenseUri if they have values
if (-not [string]::IsNullOrWhiteSpace($ProjectUri)) {
    $manifestParams.ProjectUri = $ProjectUri
}

if (-not [string]::IsNullOrWhiteSpace($LicenseUri)) {
    $manifestParams.LicenseUri = $LicenseUri
}

# Always add ReleaseNotes
$manifestParams.ReleaseNotes = $ReleaseNotes

New-ModuleManifest @manifestParams

Write-Host "✅ Module manifest created: $manifestPath" -ForegroundColor Green

# Step 5: Verify the manifest
Write-Host "🧪 Testing the generated manifest..." -ForegroundColor Yellow

try {
    $testResult = Test-ModuleManifest -Path $manifestPath
    Write-Host "✅ Manifest is valid!" -ForegroundColor Green
    Write-Host "  Module Name: $($testResult.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($testResult.Version)" -ForegroundColor Gray
    Write-Host "  GUID: $($testResult.Guid)" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Manifest validation failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Manifest generation completed successfully!" -ForegroundColor Green
Write-Host "Generated manifest file: $manifestPath" -ForegroundColor Cyan
