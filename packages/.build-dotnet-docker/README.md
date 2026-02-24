# .NET (C#) Docker Starter Package for Bolt

.NET/C# application development tasks for building, testing, formatting, and restoring packages using Docker. No local .NET SDK installation required.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats C# files using `dotnet format` via Docker
- **`restore`** - Restores NuGet packages using `dotnet restore` via Docker
- **`test`** - Runs .NET tests using `dotnet test` via Docker
- **`build`** - Builds .NET projects (depends on format, restore, test) via Docker

## Requirements

- Docker Engine: https://www.docker.com/get-started
  - **Windows**: Docker Desktop with Linux containers enabled
  - **macOS**: Docker Desktop
  - **Linux**: Docker Engine
- PowerShell 7.0+

## How It Works

All tasks build and use a local Docker image based on the included `Dockerfile`. The image uses `mcr.microsoft.com/dotnet/sdk:10.0` as its base.

Tasks always build from the `Dockerfile` — they never pull images directly from Docker Hub. Docker's layer caching makes subsequent builds fast.

To force a clean image rebuild (no cache):

```powershell
$env:BOLT_DOTNET_DOCKER_REBUILD = "1"
.\bolt.ps1 build
```

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
Copy-Item -Path "packages/.build-dotnet-docker/Invoke-*.ps1" -Destination ".build/" -Force
Copy-Item -Path "packages/.build-dotnet-docker/Dockerfile" -Destination ".build/" -Force
```

**Multi-Package (Namespaced):**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/dotnet" -Force

# Copy tasks and Dockerfile to namespace subdirectory
Copy-Item -Path "packages/.build-dotnet-docker/Invoke-*.ps1" -Destination ".build/dotnet/" -Force
Copy-Item -Path "packages/.build-dotnet-docker/Dockerfile" -Destination ".build/dotnet/" -Force
```

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

### Preview execution plan

```powershell
.\bolt.ps1 build -Outline  # Show dependency tree without executing
```

## Task Details

### Format Task

Uses `dotnet format` inside Docker to format C# files according to .NET code style conventions.

- Formats all `.csproj` projects recursively
- First checks if formatting is needed (--verify-no-changes)
- Only applies changes when necessary
- Mounts each project directory into the container

### Restore Task

Uses `dotnet restore` inside Docker to restore NuGet packages.

- Restores packages for all `.csproj` projects
- Downloads dependencies from NuGet feeds
- Mounts project directory for output

### Test Task

Runs .NET tests using `dotnet test` inside Docker.

- Runs tests in all test projects
- Mounts each project directory for test execution

### Build Task

Builds .NET projects into assemblies using Docker.

- Dependencies: format, restore, test (run automatically)
- Mounts each project directory for build output

## Configuration

### Custom .NET Project Directory

Configure the path to your .NET projects in `bolt.config.json`:

```json
{
  "DotNetPath": "src/"
}
```

### Cache Control

By default, Docker uses cached layers for faster builds. To force a complete image rebuild:

```powershell
$env:BOLT_DOTNET_DOCKER_REBUILD = "1"
.\bolt.ps1 build
```

This adds `--no-cache` to the `docker build` command. Useful after updating the `Dockerfile` or SDK version.

## Example Project Structure

```
myproject/
├── .build/                    # Bolt task files
│   ├── Dockerfile
│   ├── Invoke-Format.ps1
│   ├── Invoke-Restore.ps1
│   ├── Invoke-Test.ps1
│   └── Invoke-Build.ps1
├── bolt.ps1                   # Bolt orchestrator
├── bolt.config.json           # Configuration
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
- `tests/Docker.Tests.ps1` - Docker-specific validation
- `tests/app/` - Example .NET application

Run tests with:

```powershell
# Requires Pester 5.0+ and Docker
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run all .NET Docker tests
Invoke-Pester -Path packages/.build-dotnet-docker/tests/ -Tag DotNet-Tasks

# Run Docker-specific tests only
Invoke-Pester -Path packages/.build-dotnet-docker/tests/Docker.Tests.ps1 -Tag DotNet-Docker
```

## Troubleshooting

### Docker not found

Error: `Docker not found. Install from: https://www.docker.com/get-started`

**Solution**: Install Docker:
- https://www.docker.com/get-started

Verify installation:
- `docker --version`

### Docker build fails

If `docker build` fails:
- Check that Docker daemon is running
- Try forcing a clean rebuild: `$env:BOLT_DOTNET_DOCKER_REBUILD = "1"`
- Review the Dockerfile for issues

### Docker volume mount issues

If getting path errors with Docker:
- Ensure Docker has access to your project directory
- On Windows: Check Docker Desktop file sharing settings (Settings > Resources > File Sharing)
- On Linux/macOS: Verify Docker has permission to mount paths

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

### Tests not showing output

.NET test output may be buffered. The task will still report success/failure correctly with exit codes.

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
