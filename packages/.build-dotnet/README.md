# .NET (C#) Starter Package for Bolt

.NET/C# application development tasks for building, testing, formatting, and restoring packages.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats C# files using `dotnet format`
- **`restore`** - Restores NuGet packages using `dotnet restore`
- **`test`** - Runs .NET tests using `dotnet test`
- **`build`** - Builds .NET projects (depends on format, restore, test)

## Requirements

- .NET SDK 6.0+ (10.0+ recommended): https://dotnet.microsoft.com/download
  - **Windows**: `winget install Microsoft.DotNet.SDK.10`
  - **macOS**: `brew install dotnet-sdk`
  - **Linux**: See https://dotnet.microsoft.com/download/linux
- PowerShell 7.0+

## Installation

### Option 1: Download from GitHub Releases (Recommended)

```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

### Option 2: Manual Copy from Source

**Single Package (Standard):**
```powershell
# From your project root
Copy-Item -Path "packages/.build-dotnet/Invoke-*.ps1" -Destination ".build/" -Force
```

**Multi-Package (Namespaced):**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/dotnet" -Force

# Copy tasks to namespace subdirectory
Copy-Item -Path "packages/.build-dotnet/Invoke-*.ps1" -Destination ".build/dotnet/" -Force
```

With namespaced installation, tasks are prefixed: `dotnet-format`, `dotnet-restore`, `dotnet-test`, `dotnet-build`. This allows using multiple package starters (e.g., TypeScript + .NET) without conflicts.

## Usage

### Format all C# files

```powershell
.\bolt.ps1 format
# or using alias
.\bolt.ps1 fmt
```

### Restore NuGet packages

```powershell
.\bolt.ps1 restore
```

### Run tests

```powershell
.\bolt.ps1 test
```

### Full build pipeline

Runs format → restore → test → build:

```powershell
.\bolt.ps1 build
```

### Skip dependencies (faster iteration)

```powershell
.\bolt.ps1 build -Only     # Build only, skip format/restore/test
.\bolt.ps1 test -Only      # Test only, skip dependencies
```

### Preview execution plan

```powershell
.\bolt.ps1 build -Outline  # Show dependency tree without executing
```

## Task Details

### Format Task

Uses `dotnet format` to format C# files according to .NET code style conventions.

- Formats all `.csproj` projects recursively
- First checks if formatting is needed (--verify-no-changes)
- Only applies changes when necessary
- Reports which projects were formatted
- Exit code 0 on success, 1 on failure

### Restore Task

Uses `dotnet restore` to restore NuGet packages for all projects.

- Restores packages for all `.csproj` projects
- Downloads dependencies from NuGet feeds
- Prepares projects for build
- Exit code 0 on success, 1 on failure

**Note:** This task is typically run automatically by build task, but can be run standalone.

### Test Task

Runs .NET tests using `dotnet test`.

- Executes tests in all test projects (projects with `.Tests.csproj` or in `Tests` directory)
- If no explicit test projects, runs on all projects (non-test projects are skipped)
- Displays test results with pass/fail status
- Exit code 0 if all tests pass, 1 if any fail

### Build Task

Builds .NET projects into assemblies.

- Dependencies: format, restore, test (run automatically)
- Builds all `.csproj` projects
- Outputs assemblies to `bin/` directories
- Displays assembly size after successful build
- Exit code 0 on success, 1 on failure

## Configuration

### Custom .NET Project Directory

Configure the path to your .NET projects using `bolt.config.json`:

```json
{
  "DotNetPath": "src/"
}
```

Or for multiple projects:

```json
{
  "DotNetPath": "apps/"
}
```

Tasks now require explicit configuration - no default fallback paths.

### Custom Tool Path

If .NET SDK is installed in a non-standard location, configure the executable path:

```json
{
  "DotNetToolPath": "/usr/local/bin/dotnet",
  "DotNetPath": "src/"
}
```

**Windows example:**
```json
{
  "DotNetToolPath": "C:\\Program Files\\dotnet\\dotnet.exe",
  "DotNetPath": "src/"
}
```

If `DotNetToolPath` is not configured, Bolt searches for `dotnet` in your system PATH.

## Example Project Structure

```
myproject/
├── .build/                    # Bolt task files
│   ├── Invoke-Format.ps1
│   ├── Invoke-Restore.ps1
│   ├── Invoke-Test.ps1
│   └── Invoke-Build.ps1
├── bolt.ps1                   # Bolt orchestrator
├── bolt.config.json           # Optional configuration
└── src/                       # Your .NET code (configurable)
    ├── MyApp/
    │   ├── MyApp.csproj
    │   ├── Program.cs
    │   └── Services/
    │       └── MyService.cs
    └── MyApp.Tests/
        ├── MyApp.Tests.csproj
        └── MyServiceTests.cs
```

## Testing

This package includes comprehensive tests:

- `tests/Tasks.Tests.ps1` - Task structure validation
- `tests/Integration.Tests.ps1` - End-to-end integration tests
- `tests/app/` - Example .NET application with tests

Run tests with:

```powershell
# Requires Pester 5.0+ and .NET SDK
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run all .NET tests
Invoke-Pester -Path packages/.build-dotnet/tests/ -Tag Package-Dotnet-Tasks
```

## Troubleshooting

### .NET SDK not found

Error: `.NET SDK not found. Please install...`

**Solution**: Install .NET SDK:
- .NET SDK: https://dotnet.microsoft.com/download

Verify installation:
- .NET SDK: `dotnet --version`

### No .NET projects found

Warning: `No .NET projects found to format/build/test.`

**Solution**: 
1. Ensure your `.csproj` files are in the expected directory
2. Configure custom path in `bolt.config.json`:
   ```json
   {
     "DotNetPath": "your/dotnet/path"
   }
   ```
3. Check that files have the `.csproj` extension

### Format or Build fails

If you see errors:
- Review error messages for specific issues
- Common problems:
  - Missing NuGet packages (run `restore` task)
  - Compilation errors in C# code
  - Missing project references
  - SDK version mismatches

### Tests not showing output

.NET test output may be buffered in PowerShell. The task will still report success/failure correctly with exit codes.

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
