# Golang Starter Package for Bolt

Go application development tasks for building, testing, and formatting Go code.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats Go files using `go fmt`
- **`lint`** - Validates Go code using `go vet`
- **`test`** - Runs Go tests using `go test`
- **`build`** - Builds Go application (depends on format, lint, test)

## Requirements

- Go 1.21+ CLI: https://go.dev/doc/install
- PowerShell 7.0+

## Installation

### Option 1: Download from GitHub Releases (Recommended)

```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

### Option 2: Manual Copy from Source

```powershell
# From your project root
Copy-Item -Path "packages/.build-golang/Invoke-*.ps1" -Destination ".build/" -Force
```

## Configuration

By default, tasks look for Go code in `tests/app/` directory. To use a custom path, create a `bolt.config.json` in your project root:

```json
{
  "GoPath": "src/"
}
```

Or for a different project structure:

```json
{
  "GoPath": "cmd/myapp/"
}
```

## Usage

### Format all Go files

```powershell
.\bolt.ps1 format
# or using alias
.\bolt.ps1 fmt
```

### Lint Go code

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

### Preview execution plan

```powershell
.\bolt.ps1 build -Outline
```

## Task Details

### Format Task

Uses `go fmt` to format Go source files according to the standard Go formatting guidelines.

- Formats all `.go` files in the configured path
- Reports which files were formatted
- Exit code 0 on success, 1 on failure

### Lint Task

Uses `go vet` to examine Go code and report suspicious constructs.

- Checks for common programming errors
- Reports errors and warnings
- Exit code 0 on success, 1 on errors

### Test Task

Runs Go tests using `go test -v ./...`

- Executes all tests in the project
- Verbose output showing test results
- Exit code 0 if all tests pass, 1 if any fail

### Build Task

Builds the Go application into a binary.

- Dependencies: format, lint, test (run automatically)
- Output directory: `bin/` in the Go project path
- Binary name derived from `go.mod` module name
- Cross-platform binary extension handling (`.exe` on Windows)
- Displays binary size after successful build

## Example Project Structure

```
myproject/
├── .build/                    # Bolt task files
│   ├── Invoke-Format.ps1
│   ├── Invoke-Lint.ps1
│   ├── Invoke-Test.ps1
│   └── Invoke-Build.ps1
├── bolt.ps1                   # Bolt orchestrator
├── bolt.config.json           # Optional configuration
└── src/                       # Your Go code (configurable)
    ├── go.mod
    ├── main.go
    └── main_test.go
```

## Testing

This package includes comprehensive tests:

- `tests/Tasks.Tests.ps1` - Task structure validation
- `tests/Integration.Tests.ps1` - End-to-end integration tests
- `tests/app/` - Example Go application

Run tests with:

```powershell
Invoke-Pester -Path packages/.build-golang/tests/ -Tag Golang-Tasks
```

## Troubleshooting

### Go CLI not found

Error: `Go CLI not found. Please install: https://go.dev/doc/install`

**Solution**: Install Go from https://go.dev/doc/install and ensure it's in your PATH.

### No Go files found

Warning: `No Go files found to format/lint/test.`

**Solution**: 
1. Check your `bolt.config.json` if you're using a custom path
2. Ensure your Go files are in the expected directory
3. Verify the path is relative to your project root

### Tests not running

If `go test` doesn't show output, this is normal - Go buffers test output in PowerShell. The task will still report success/failure correctly.

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
