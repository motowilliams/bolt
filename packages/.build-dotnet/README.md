# .NET (C#) Starter Package for Bolt

.NET/C# application development tasks for building, testing, formatting, and restoring packages with Docker fallback support.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats C# files using `dotnet format`
- **`restore`** - Restores NuGet packages using `dotnet restore`
- **`test`** - Runs .NET tests using `dotnet test`
- **`build`** - Builds .NET projects (depends on format, restore, test)

## Requirements

**Option 1: Local .NET SDK** (Recommended)
- .NET SDK 6.0+ (8.0+ recommended): https://dotnet.microsoft.com/download
  - **Windows**: `winget install Microsoft.DotNet.SDK.8`
  - **macOS**: `brew install dotnet-sdk`
  - **Linux**: See https://dotnet.microsoft.com/download/linux

**Option 2: Docker Fallback**
- Docker Engine: https://docs.docker.com/get-docker/
- If .NET SDK is not found, tasks automatically use `mcr.microsoft.com/dotnet/sdk:8.0` Docker image
- Requires Docker volume mount support for working directory

**Additional Requirements:**
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

## Docker Fallback Mode

If .NET SDK is not installed locally, tasks automatically detect and use Docker:

```powershell
# No local .NET SDK? No problem!
# Tasks will automatically use: docker run mcr.microsoft.com/dotnet/sdk:8.0

.\bolt.ps1 format    # Uses Docker if dotnet command not found
.\bolt.ps1 build     # Uses Docker if dotnet command not found
```

**Docker Requirements:**
- Docker must be running
- Tasks use volume mounts to access project files
- Cross-platform path handling is automatic

**Example output when using Docker:**
```
Building .NET projects...
  Using Docker container for .NET SDK (local CLI not found)
Found 1 .NET project(s)
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

Default path (if not configured): `tests/app/` relative to package location.

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
# Requires Pester 5.0+ and either .NET SDK or Docker
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run all .NET tests
Invoke-Pester -Path packages/.build-dotnet/tests/ -Tag DotNet-Tasks
```

## Troubleshooting

### .NET SDK not found and Docker not available

Error: `.NET SDK not found and Docker is not available. Please install...`

**Solution**: Install either .NET SDK or Docker:
- .NET SDK: https://dotnet.microsoft.com/download
- Docker: https://docs.docker.com/get-docker/

Verify installation:
- .NET SDK: `dotnet --version`
- Docker: `docker --version`

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

### Docker volume mount issues

If using Docker fallback and getting path errors:
- Ensure Docker has access to your project directory
- On Windows: Check Docker Desktop file sharing settings
- On Linux/macOS: Verify Docker has permission to mount paths

### Tests not showing output

.NET test output may be buffered in PowerShell. The task will still report success/failure correctly with exit codes.

## Security Considerations

### Docker Security

When using Docker fallback:
- Docker container runs with current user permissions
- Volume mounts grant container access to project files
- Uses official Microsoft .NET SDK image
- Container is removed after execution (--rm flag)

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
