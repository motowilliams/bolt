# Terraform Docker Starter Package for Bolt

**Docker-only** Terraform infrastructure-as-code tasks for formatting, validating, planning, and applying Terraform configurations using containerized Terraform tooling.

⚠️ **DOCKER-ONLY PACKAGE**: This package ONLY uses Docker containers for all operations. No local Terraform CLI installation is required or used.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats Terraform files using terraform fmt (Docker)
- **`validate`** - Validates Terraform configuration syntax (Docker)
- **`plan`** - Generates Terraform execution plan (depends on format, validate) (Docker)
- **`apply`** (alias: `deploy`) - Applies Terraform changes ⚠️ **WARNING: modifies infrastructure** (depends on format, validate, plan) (Docker)

## Requirements

- **Docker with Linux containers** (especially important on Windows): https://docs.docker.com/get-docker/
- PowerShell 7.0+

**Note**: Local Terraform CLI installation is NOT required. All operations run in Docker containers.

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
Copy-Item -Path "packages/.build-terraform-docker/Invoke-*.ps1" -Destination ".build/" -Force
Copy-Item -Path "packages/.build-terraform-docker/Dockerfile" -Destination ".build/" -Force
```

**Multi-Package (Namespaced):**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/terraform-docker" -Force

# Copy tasks and Dockerfile to namespace subdirectory
Copy-Item -Path "packages/.build-terraform-docker/Invoke-*.ps1" -Destination ".build/terraform-docker/" -Force
Copy-Item -Path "packages/.build-terraform-docker/Dockerfile" -Destination ".build/terraform-docker/" -Force
```

With namespaced installation, tasks are prefixed: `terraform-docker-format`, `terraform-docker-validate`, `terraform-docker-plan`, `terraform-docker-apply`.

## Configuration

By default, tasks look for Terraform files in `tests/iac/` directory. To use a custom path, create a `bolt.config.json` in your project root:

```json
{
  "TerraformPath": "infra/"
}
```

Or for a different project structure:

```json
{
  "TerraformPath": "environments/production/"
}
```

## Docker Image Customization

By default, tasks use the `hashicorp/terraform:latest` Docker image. To build a custom image from the included Dockerfile:

```powershell
# Set environment variable to trigger custom image build
$env:BOLT_TERRAFORM_DOCKER_REBUILD = "1"

# Run any task (will build custom image first)
.\bolt.ps1 plan
```

The custom image is tagged as `bolt-terraform:latest` and will be used for subsequent task runs until Docker is restarted or the image is removed.

To always use the default image, unset the environment variable:

```powershell
Remove-Item Env:\BOLT_TERRAFORM_DOCKER_REBUILD
```

## Usage

### Format all Terraform files

```powershell
.\bolt.ps1 format
# or using alias
.\bolt.ps1 fmt
```

### Validate Terraform configuration

```powershell
.\bolt.ps1 validate
```

### Generate execution plan

```powershell
.\bolt.ps1 plan
```

### Apply changes (WARNING: modifies infrastructure)

```powershell
.\bolt.ps1 apply
# or using alias
.\bolt.ps1 deploy
```

### Full pipeline (recommended before apply)

Runs format → validate → plan:

```powershell
.\bolt.ps1 plan
```

### Skip dependencies (faster iteration)

```powershell
.\bolt.ps1 validate -Only
```

## Docker Notes

- All tasks run in ephemeral Docker containers (removed after execution)
- Project directory is mounted as a volume at `/tf` inside containers
- Default image: `hashicorp/terraform:latest` (official HashiCorp Terraform image)
- Custom images can be built from the included Dockerfile using `BOLT_TERRAFORM_DOCKER_REBUILD` env var
- Plan files (`terraform.tfplan`) are generated on the host filesystem

## Differences from Standard Terraform Package

This Docker-only package:
- ✅ Does NOT check for local Terraform CLI installation
- ✅ Does NOT use bolt.config.json tool paths (TerraformToolPath)
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

If custom image build fails, tasks fall back to the default `hashicorp/terraform:latest` image. Check the Dockerfile syntax and Docker daemon logs for details.

### Provider initialization fails

Terraform providers are downloaded during `terraform init`. If you're offline or behind a proxy, ensure Docker has network access and proxy settings are configured correctly.
