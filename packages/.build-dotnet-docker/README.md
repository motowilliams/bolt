# .NET Docker Starter Package for Bolt

**Docker-only** .NET application development tasks for building, testing, and formatting C# code using containerized .NET SDK tooling.

⚠️ **DOCKER-ONLY PACKAGE**: This package ONLY uses Docker containers for all operations. No local .NET SDK installation is required or used.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats C# source files using dotnet format (Docker)
- **`restore`** - Restores NuGet packages for .NET projects (Docker)
- **`test`** - Runs .NET tests (depends on restore) (Docker)
- **`build`** - Builds .NET projects (depends on format, restore, test) (Docker)

## Requirements

- **Docker with Linux containers** (especially important on Windows): https://docs.docker.com/get-docker/
- PowerShell 7.0+

**Note**: Local .NET SDK installation is NOT required. All operations run in Docker containers.

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
New-Item -ItemType Directory -Path ".build/dotnet-docker" -Force

# Copy tasks and Dockerfile to namespace subdirectory
Copy-Item -Path "packages/.build-dotnet-docker/Invoke-*.ps1" -Destination ".build/dotnet-docker/" -Force
Copy-Item -Path "packages/.build-dotnet-docker/Dockerfile" -Destination ".build/dotnet-docker/" -Force
```

With namespaced installation, tasks are prefixed: `dotnet-docker-format`, `dotnet-docker-restore`, `dotnet-docker-test`, `dotnet-docker-build`.

## Configuration

By default, tasks look for .NET projects in `tests/app/` directory. To use a custom path, create a `bolt.config.json` in your project root:

```json
{
  "DotNetPath": "src/"
}
```

Or for a different project structure:

```json
{
  "DotNetPath": "apps/MyApp/"
}
```

## Docker Image Customization

By default, tasks use the `mcr.microsoft.com/dotnet/sdk:10.0` Docker image. To build a custom image from the included Dockerfile:

```powershell
# Set environment variable to trigger custom image build
$env:BOLT_DOTNET_DOCKER_REBUILD = "1"

# Run any task (will build custom image first)
.\bolt.ps1 build
```

The custom image is tagged as `bolt-dotnet:latest` and will be used for subsequent task runs until Docker is restarted or the image is removed.

To always use the default image, unset the environment variable:

```powershell
Remove-Item Env:\BOLT_DOTNET_DOCKER_REBUILD
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

### Skip dependencies (faster iteration)

```powershell
.\bolt.ps1 build -Only
```

## Docker Notes

- All tasks run in ephemeral Docker containers (removed after execution)
- Project directory is mounted as a volume at `/project` inside containers
- Default image: `mcr.microsoft.com/dotnet/sdk:10.0` (official Microsoft .NET SDK)
- Custom images can be built from the included Dockerfile using `BOLT_DOTNET_DOCKER_REBUILD` env var

## Differences from Standard .NET Package

This Docker-only package:
- ✅ Does NOT check for local .NET SDK installation
- ✅ Does NOT use bolt.config.json tool paths (DotNetToolPath)
- ✅ Does NOT fall back to PATH-based CLI detection
- ✅ ONLY uses Docker containers for all operations
- ✅ Supports custom Docker image builds via environment variable
- ✅ Same task names and dependencies as standard package

## Troubleshooting

### Docker not found

Ensure Docker is installed and the Docker daemon is running:
```powershell
docker --version
docker ps
```

### Windows: Linux containers required

On Windows with Docker Desktop, ensure Linux containers are enabled (not Windows containers):
- Right-click Docker Desktop tray icon → "Switch to Linux containers"

### Volume mount issues

If you encounter permission errors, ensure Docker has access to your project directory:
- Docker Desktop → Settings → Resources → File Sharing
- Add your project directory to allowed paths

### Custom image build fails

If custom image build fails, tasks fall back to the default `mcr.microsoft.com/dotnet/sdk:10.0` image. Check the Dockerfile syntax and Docker daemon logs for details.
