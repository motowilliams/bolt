# Python Docker Starter Package for Bolt

**Docker-only** Python application development tasks for building, testing, linting, and formatting Python code using containerized Python tooling.

⚠️ **DOCKER-ONLY PACKAGE**: This package ONLY uses Docker containers for all operations. No local Python installation is required or used.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats Python files using black (Docker)
- **`lint`** - Validates Python code using ruff (Docker)
- **`test`** - Runs Python tests using pytest (Docker)
- **`build`** - Installs dependencies and validates package structure (depends on format, lint, test) (Docker)

## Requirements

- **Docker with Linux containers** (especially important on Windows): https://docs.docker.com/get-docker/
- PowerShell 7.0+

**Note**: Local Python installation is NOT required. All operations run in Docker containers.

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
Copy-Item -Path "packages/.build-python-docker/Invoke-*.ps1" -Destination ".build/" -Force
Copy-Item -Path "packages/.build-python-docker/Dockerfile" -Destination ".build/" -Force
```

**Multi-Package (Namespaced):**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/python-docker" -Force

# Copy tasks and Dockerfile to namespace subdirectory
Copy-Item -Path "packages/.build-python-docker/Invoke-*.ps1" -Destination ".build/python-docker/" -Force
Copy-Item -Path "packages/.build-python-docker/Dockerfile" -Destination ".build/python-docker/" -Force
```

With namespaced installation, tasks are prefixed: `python-docker-format`, `python-docker-lint`, `python-docker-test`, `python-docker-build`.

## Configuration

By default, tasks look for Python code in `tests/app/` directory. To use a custom path, create a `bolt.config.json` in your project root:

```json
{
  "PythonPath": "src/"
}
```

Or for a different project structure:

```json
{
  "PythonPath": "packages/my-app/"
}
```

## Docker Image Customization

By default, tasks use the `python:3.12-slim` Docker image. To build a custom image from the included Dockerfile:

```powershell
# Set environment variable to trigger custom image build
$env:BOLT_PYTHON_DOCKER_REBUILD = "1"

# Run any task (will build custom image first)
.\bolt.ps1 build
```

The custom image is tagged as `bolt-python:latest` and will be used for subsequent task runs until Docker is restarted or the image is removed.

To always use the default image, unset the environment variable:

```powershell
Remove-Item Env:\BOLT_PYTHON_DOCKER_REBUILD
```

## Usage

### Format all Python files

```powershell
.\bolt.ps1 format
# or using alias
.\bolt.ps1 fmt
```

### Lint Python code

```powershell
.\bolt.ps1 lint
```

### Run tests

```powershell
.\bolt.ps1 test
```

### Full build pipeline

Runs format → lint → test → build:

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
- Dependencies are installed inside containers each run
- Default image: `python:3.12-slim` (Debian-based with Python 3.12)
- Custom images can be built from the included Dockerfile using `BOLT_PYTHON_DOCKER_REBUILD` env var

## Differences from Standard Python Package

This Docker-only package:
- ✅ Does NOT check for local Python installation
- ✅ Does NOT use bolt.config.json tool paths (PythonToolPath)
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

If custom image build fails, tasks fall back to the default `python:3.12-slim` image. Check the Dockerfile syntax and Docker daemon logs for details.
