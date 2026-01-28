# Bicep Starter Package for Bolt

Infrastructure-as-Code tasks for Azure Bicep workflows.

## Included Tasks

- **`format`** - Formats Bicep files using `bicep format`
- **`lint`** - Validates Bicep syntax using `bicep lint`
- **`build`** - Compiles Bicep files to ARM JSON templates

## Requirements

- Azure Bicep CLI
  - **Windows**: `winget install Microsoft.Bicep`
  - **Linux/macOS**: https://aka.ms/bicep-install
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
Copy-Item -Path "packages/.build-bicep/Invoke-*.ps1" -Destination ".build/" -Force
```

**Multi-Package (Namespaced) - New in Bolt v0.6.0:**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/bicep" -Force

# Copy tasks to namespace subdirectory
Copy-Item -Path "packages/.build-bicep/Invoke-*.ps1" -Destination ".build/bicep/" -Force
```

With namespaced installation, tasks are prefixed: `bicep-format`, `bicep-lint`, `bicep-build`. This allows using multiple package starters (e.g., Bicep + Golang) without conflicts.

## Usage

### Format all Bicep files

```powershell
.\bolt.ps1 format
```

### Lint Bicep files

```powershell
.\bolt.ps1 lint
```

### Full build pipeline

Runs format → lint → build:

```powershell
.\bolt.ps1 build
```

### Skip dependencies (faster iteration)

```powershell
.\bolt.ps1 build -Only
```

### Preview execution plan

```powershell
.\bolt.ps1 build -Outline
```

## Configuration

### Custom Bicep Directory

Configure the path to your Bicep files using `bolt.config.json`:

```json
{
  "BicepPath": "infrastructure/bicep"
}
```

Tasks now require explicit configuration - no default fallback paths.

### Custom Tool Path

If Bicep CLI is installed in a non-standard location, configure the executable path:

```json
{
  "BicepToolPath": "/usr/local/bin/bicep",
  "BicepPath": "infrastructure/bicep"
}
```

**Windows example:**
```json
{
  "BicepToolPath": "C:\\tools\\bicep\\bicep.exe",
  "BicepPath": "infrastructure/bicep"
}
```

If `BicepToolPath` is not configured, Bolt searches for `bicep` in your system PATH.

## Task Details

### Format Task

Uses `bicep format` to format Bicep files according to standard conventions.

- Formats all `.bicep` files recursively
- Reports which files were formatted
- Exit code 0 on success, 1 on failure

### Lint Task

Uses `bicep lint` to validate Bicep syntax and detect errors.

- Validates all `.bicep` files recursively
- Reports errors and warnings with file locations
- Exit code 0 on success, 1 on errors

### Build Task

Compiles Bicep templates to ARM JSON.

- Dependencies: format, lint (run automatically)
- Only compiles `main*.bicep` files (e.g., `main.bicep`, `main.dev.bicep`)
- Module files are referenced, not compiled directly
- Output: `.json` files alongside `.bicep` sources
- Exit code 0 on success, 1 on compilation errors

## Example Project Structure

```
myproject/
├── .build/                    # Bolt task files
│   ├── Invoke-Format.ps1
│   ├── Invoke-Lint.ps1
│   └── Invoke-Build.ps1
├── bolt.ps1                   # Bolt orchestrator
└── infra/                     # Your Bicep code
    ├── main.bicep
    ├── main.parameters.json
    └── modules/
        ├── app-service.bicep
        └── sql-server.bicep
```

## Testing

This package includes comprehensive tests:

- `tests/Tasks.Tests.ps1` - Task structure validation
- `tests/Integration.Tests.ps1` - End-to-end integration tests
- `tests/iac/` - Example Bicep infrastructure templates

Run tests with:

```powershell
Invoke-Pester -Path packages/.build-bicep/tests/ -Tag Bicep-Tasks
```

## Troubleshooting

### Bicep CLI not found

Error: `Bicep CLI not found. Please install: https://aka.ms/bicep-install`

**Solution**: Install Bicep CLI:
- Windows: `winget install Microsoft.Bicep`
- Linux/macOS: https://aka.ms/bicep-install

Verify installation: `bicep --version`

### No Bicep files found

Warning: `No Bicep files found to format/lint/build.`

**Solution**: 
1. Ensure your `.bicep` files are in the project directory
2. Check that files have the `.bicep` extension
3. For build task, ensure you have `main*.bicep` files

### Linting errors

If you see linting errors, review the error messages for specific issues. Common problems:
- Missing required properties
- Invalid resource types
- Syntax errors

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
