# Terraform Starter Package for Bolt

Infrastructure-as-Code tasks for Terraform workflows with Docker fallback support.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats Terraform files using `terraform fmt`
- **`validate`** - Validates Terraform configuration syntax
- **`plan`** - Generates Terraform execution plan
- **`apply`** (alias: `deploy`) - Applies Terraform changes (WARNING: modifies infrastructure)

## Requirements

**Option 1: Local Terraform CLI** (Recommended)
- Terraform 1.0+ CLI: https://developer.hashicorp.com/terraform/downloads
  - **Windows**: `winget install Hashicorp.Terraform`
  - **macOS**: `brew install terraform`
  - **Linux**: Download from https://developer.hashicorp.com/terraform/downloads

**Option 2: Docker Fallback**
- Docker Engine: https://docs.docker.com/get-docker/
- If Terraform CLI is not found, tasks automatically use `hashicorp/terraform:latest` Docker image
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
Copy-Item -Path "packages/.build-terraform/Invoke-*.ps1" -Destination ".build/" -Force
```

**Multi-Package (Namespaced) - New in Bolt v0.6.0:**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/terraform" -Force

# Copy tasks to namespace subdirectory
Copy-Item -Path "packages/.build-terraform/Invoke-*.ps1" -Destination ".build/terraform/" -Force
```

With namespaced installation, tasks are prefixed: `terraform-format`, `terraform-validate`, `terraform-plan`, `terraform-apply`. This allows using multiple package starters (e.g., Terraform + Bicep) without conflicts.

## Usage

### Format all Terraform files

```powershell
.\bolt.ps1 format
```

### Validate Terraform configuration

```powershell
.\bolt.ps1 validate
```

### Generate execution plan

```powershell
.\bolt.ps1 plan
```

### Apply changes (with dependencies)

Runs format → validate → plan → apply:

```powershell
.\bolt.ps1 apply
```

**Note:** Apply task includes a 5-second safety delay before executing changes.

### Skip dependencies (faster iteration)

```powershell
.\bolt.ps1 plan -Only         # Plan without format/validate
.\bolt.ps1 validate -Only     # Validate without format
```

### Preview execution plan

```powershell
.\bolt.ps1 apply -Outline     # Show dependency tree without executing
```

## Docker Fallback Mode

If Terraform CLI is not installed locally, tasks automatically detect and use Docker:

```powershell
# No local Terraform CLI? No problem!
# Tasks will automatically use: docker run hashicorp/terraform:latest

.\bolt.ps1 format    # Uses Docker if terraform command not found
.\bolt.ps1 validate  # Uses Docker if terraform command not found
```

**Docker Requirements:**
- Docker must be running
- Tasks use volume mounts to access Terraform files
- Cross-platform path handling is automatic

**Example output when using Docker:**
```
Formatting Terraform files...
  Using Docker container for Terraform (local CLI not found)
Found 3 Terraform file(s)
```

## Task Details

### Format Task

Uses `terraform fmt` to format Terraform files according to standard conventions.

- Formats all `.tf` files recursively
- Formats by directory for efficiency
- Reports which directories were formatted
- Exit code 0 on success, 1 on failure

### Validate Task

Uses `terraform validate` to check Terraform configuration syntax.

- Validates all Terraform modules (directories with `.tf` files)
- Runs `terraform init -backend=false` before validation
- Reports validation errors with details
- Exit code 0 on success, 1 on errors

### Plan Task

Generates Terraform execution plan showing proposed changes.

- Dependencies: format, validate (run automatically)
- Initializes Terraform modules
- Generates plan file (`terraform.tfplan`)
- Shows resource change summary
- Exit code 0 on success, 1 on errors

**Note:** Plan files are not applied automatically. Use `apply` task to apply changes.

### Apply Task

Applies Terraform changes to infrastructure.

- Dependencies: format, validate, plan (run automatically)
- **WARNING:** This task modifies infrastructure
- 5-second safety delay before execution
- Uses existing plan file if available, otherwise generates new plan
- Auto-approves changes (use with caution)
- Exit code 0 on success, 1 on errors

## Configuration

### Custom Terraform Directory

Configure the path to your Terraform files using `bolt.config.json`:

```json
{
  "TerraformPath": "infrastructure/terraform"
}
```

Tasks now require explicit configuration - no default fallback paths.

### Custom Tool Path

If Terraform CLI is installed in a non-standard location, configure the executable path:

```json
{
  "TerraformToolPath": "/usr/local/bin/terraform",
  "TerraformPath": "infrastructure/terraform"
}
```

**Windows example:**
```json
{
  "TerraformToolPath": "C:\\tools\\terraform\\terraform.exe",
  "TerraformPath": "infrastructure/terraform"
}
```

If `TerraformToolPath` is not configured, Bolt searches for `terraform` in your system PATH or falls back to Docker.

## Example Project Structure

```
myproject/
├── .build/                    # Bolt task files
│   ├── Invoke-Format.ps1
│   ├── Invoke-Validate.ps1
│   ├── Invoke-Plan.ps1
│   └── Invoke-Apply.ps1
├── bolt.ps1                   # Bolt orchestrator
├── bolt.config.json           # Optional configuration
└── infrastructure/            # Your Terraform code
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── modules/
        ├── networking/
        │   ├── main.tf
        │   └── variables.tf
        └── compute/
            ├── main.tf
            └── variables.tf
```

## Testing

This package includes comprehensive tests:

- `tests/Tasks.Tests.ps1` - Task structure validation
- `tests/Integration.Tests.ps1` - End-to-end integration tests
- `tests/tf/` - Example Terraform configuration

Run tests with:

```powershell
# Requires Pester 5.0+ and either Terraform CLI or Docker
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run all Terraform tests
Invoke-Pester -Path packages/.build-terraform/tests/ -Tag Terraform-Tasks
```

## Troubleshooting

### Terraform CLI not found and Docker not available

Error: `Terraform CLI not found and Docker is not available. Please install...`

**Solution**: Install either Terraform CLI or Docker:
- Terraform: https://developer.hashicorp.com/terraform/downloads
- Docker: https://docs.docker.com/get-docker/

Verify installation:
- Terraform: `terraform --version`
- Docker: `docker --version`

### No Terraform files found

Warning: `No Terraform files found to format/validate/plan.`

**Solution**: 
1. Ensure your `.tf` files are in the expected directory
2. Configure custom path in `bolt.config.json`:
   ```json
   {
     "IacPath": "your/terraform/path"
   }
   ```
3. Check that files have the `.tf` extension

### Validation or Plan fails

If you see validation errors:
- Review error messages for specific issues
- Common problems:
  - Missing required variables
  - Invalid resource configurations
  - Provider version mismatches
  - Missing provider requirements

### Docker volume mount issues

If using Docker fallback and getting path errors:
- Ensure Docker has access to your project directory
- On Windows: Check Docker Desktop file sharing settings
- On Linux/macOS: Verify Docker has permission to mount paths

### Plan file not found during apply

Warning: Tasks will generate a new plan if `terraform.tfplan` is not found.

**Solution**: Run `plan` task before `apply`:
```powershell
.\bolt.ps1 plan   # Generate plan file
.\bolt.ps1 apply  # Use existing plan file
```

## Security Considerations

### Apply Task Safety

The `apply` task includes safety features:
- 5-second delay before execution
- Press Ctrl+C to cancel during delay
- Use `-Outline` flag to preview without executing
- Review plan output before running apply

### Docker Security

When using Docker fallback:
- Docker container runs with current user permissions
- Volume mounts grant container access to Terraform files
- Uses official HashiCorp Terraform image
- Container is removed after execution (--rm flag)

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
