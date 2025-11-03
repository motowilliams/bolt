# Generate PowerShell Module Manifest by analyzing an existing module
# This script analyzes an existing PowerShell module and generates a manifest file

param(
    [string]$WorkspacePath = ".",
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

# Step 1: Locate and validate the module
Write-Host "📦 Locating module at path..." -ForegroundColor Yellow
$fullModulePath = Join-Path $WorkspacePath $ModulePath

if (-not (Test-Path $fullModulePath)) {
    Write-Error "❌ Module not found at $fullModulePath"
    exit 1
}

# Determine if this is a .psm1 file or a module directory
$isModuleFile = $fullModulePath.EndsWith('.psm1')
$isModuleDirectory = (Get-Item $fullModulePath).PSIsContainer

if ($isModuleFile) {
    Write-Host "✅ Found module file: $fullModulePath" -ForegroundColor Green
    $moduleScriptPath = $fullModulePath
    $moduleDirectory = Split-Path $fullModulePath -Parent
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($fullModulePath)
}
elseif ($isModuleDirectory) {
    Write-Host "✅ Found module directory: $fullModulePath" -ForegroundColor Green
    $moduleDirectory = $fullModulePath
    $moduleName = Split-Path $fullModulePath -Leaf

    # Look for .psm1 file in the directory
    $moduleScriptPath = Join-Path $fullModulePath "$moduleName.psm1"
    if (-not (Test-Path $moduleScriptPath)) {
        # Try to find any .psm1 file
        $psmFiles = Get-ChildItem -Path $fullModulePath -Filter "*.psm1" -File
        if ($psmFiles.Count -eq 0) {
            Write-Error "❌ No .psm1 files found in module directory $fullModulePath"
            exit 1
        }
        elseif ($psmFiles.Count -eq 1) {
            $moduleScriptPath = $psmFiles[0].FullName
            Write-Host "Found module script: $($psmFiles[0].Name)" -ForegroundColor Gray
        }
        else {
            Write-Error "❌ Multiple .psm1 files found in $fullModulePath. Please specify the exact .psm1 file path."
            exit 1
        }
    }
}
else {
    Write-Error "❌ ModulePath must be either a .psm1 file or a module directory"
    exit 1
}

# Step 2: Analyze the module directly by importing it
Write-Host "🔍 Analyzing module by importing..." -ForegroundColor Yellow

try {
    # Import the module to analyze its exports
    $module = Import-Module -Name $moduleScriptPath -PassThru -Force

    if (-not $module) {
        Write-Error "❌ Failed to import module from $moduleScriptPath"
        exit 1
    }

    Write-Host "✅ Successfully imported module: $($module.Name)" -ForegroundColor Green
}
catch {
    Write-Error "❌ Failed to import module: $_"
    exit 1
}

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
$rootModuleFileName = if ($module.RootModule) {
    Split-Path -Leaf $module.RootModule
} else {
    Split-Path -Leaf $moduleScriptPath
}
$description = if ($module.Description) {
    $module.Description
} else {
    "PowerShell module with build orchestration capabilities"
}
$author = if ($module.Author) {
    $module.Author
} else {
    "Module Author"
}
$companyName = if ($module.CompanyName) {
    $module.CompanyName
} else {
    ""
}

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
}

# Set default LicenseUri if not provided
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
Write-Host "  Root Module: $rootModuleFileName" -ForegroundColor Gray
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

# Create manifest in the same directory as the module for proper validation
$manifestPath = Join-Path $moduleDirectory "$moduleName.psd1"

# Generate a new GUID for the module
$moduleGuid = [System.Guid]::NewGuid().ToString()

$manifestParams = @{
    Path = $manifestPath
    RootModule = $rootModuleFileName
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
    # Test the manifest from its directory to ensure proper relative path resolution
    $originalLocation = Get-Location
    Set-Location $moduleDirectory

    # Use the manifest file name only (not full path) when testing from the module directory
    $manifestFileName = Split-Path $manifestPath -Leaf
    $testResult = Test-ModuleManifest -Path $manifestFileName

    Set-Location $originalLocation

    Write-Host "✅ Manifest is valid!" -ForegroundColor Green
    Write-Host "  Module Name: $($testResult.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($testResult.Version)" -ForegroundColor Gray
    Write-Host "  GUID: $($testResult.Guid)" -ForegroundColor Gray
}
catch {
    Set-Location $originalLocation -ErrorAction SilentlyContinue
    Write-Host "⚠️  Manifest validation encountered issues: $_" -ForegroundColor Yellow
    Write-Host "   Manifest file created at: $manifestPath" -ForegroundColor Gray
    Write-Host "   Note: Validation may fail in containerized environments or with complex module paths." -ForegroundColor Gray

    # Try to at least check if the file was created and is readable
    if (Test-Path $manifestPath) {
        try {
            $manifestContent = Import-PowerShellDataFile -Path $manifestPath
            Write-Host "   ✓ Manifest file is readable and contains:" -ForegroundColor Green
            Write-Host "     Module Name: $($manifestContent.RootModule)" -ForegroundColor Gray
            Write-Host "     Version: $($manifestContent.ModuleVersion)" -ForegroundColor Gray
            Write-Host "     GUID: $($manifestContent.GUID)" -ForegroundColor Gray
        }
        catch {
            Write-Host "   ✗ Manifest file is not readable: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`n🎉 Manifest generation completed successfully!" -ForegroundColor Green
Write-Host "Generated manifest file: $manifestPath" -ForegroundColor Cyan
