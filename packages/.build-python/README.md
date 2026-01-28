# Python Starter Package for Bolt

Pre-built task collection for Python application development workflows with Bolt build system.

## Features

- **Format**: Formats Python files using `black` (industry standard formatter)
- **Lint**: Validates Python code using `ruff` (fast, modern linter)
- **Test**: Runs tests using `pytest` (popular testing framework)
- **Build**: Installs dependencies and validates package structure
- **Docker Fallback**: Automatically uses Docker if Python is not installed locally
- **Cross-Platform**: Works on Windows, Linux, and macOS

## Requirements

**Option 1: Local Python Installation**
- Python 3.8+ (3.12 recommended): https://www.python.org/downloads/
  - **Windows**: `winget install Python.Python.3.12`
  - **Linux**: `sudo apt install python3 python3-pip` (Ubuntu/Debian)
  - **macOS**: `brew install python@3.12`

**Option 2: Docker (Automatic Fallback)**
- Docker Engine: https://docs.docker.com/get-docker/
- Tasks automatically use `python:3.12-slim` image when Python is not installed

## Installation

### Quick Install (Recommended)

```powershell
# Interactive script to download and install starter packages
irm https://raw.githubusercontent.com/motowilliams/bolt/main/Download-Starter.ps1 | iex
```

### Manual Install from Source

```powershell
# From your project root
Copy-Item -Path "packages/.build-python/Invoke-*.ps1" -Destination ".build/" -Force
```

### Multi-Namespace Install

```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/python" -Force

# Install Python tasks
Copy-Item -Path "packages/.build-python/Invoke-*.ps1" -Destination ".build/python/" -Force
```

## Configuration

Add to your `bolt.config.json`:

```json
{
  "PythonPath": "src",
  "PythonToolPath": "/usr/bin/python3"  // Optional: Explicit Python path
}
```

**Required:**
- `PythonPath`: Directory containing your Python source files

**Optional:**
- `PythonToolPath`: Explicit path to Python executable (overrides PATH search)

## Included Tasks

### format (alias: fmt)
Formats Python files using `black`.

```powershell
.\bolt.ps1 format
```

**What it does:**
- Installs `black` formatter
- Formats all `.py` files in configured `PythonPath`
- Excludes virtual environments (`__pycache__`, `.venv`, `venv`, etc.)
- Ensures consistent code style across your project

### lint
Validates Python code using `ruff` linter.

```powershell
.\bolt.ps1 lint
```

**What it does:**
- Installs `ruff` linter
- Checks all `.py` files for errors and style issues
- Enforces code quality standards
- Depends on `format` task

### test
Runs tests using `pytest`.

```powershell
.\bolt.ps1 test
```

**What it does:**
- Installs `pytest` test framework
- Installs dependencies from `requirements.txt` (if present)
- Runs all test files (`test_*.py` or `*_test.py`)
- Reports test results with detailed output
- Depends on `format` and `lint` tasks

### build
Installs dependencies and validates package structure.

```powershell
.\bolt.ps1 build
```

**What it does:**
- If `pyproject.toml` or `setup.py` exists: Builds distributable package using `python -m build`
- If `requirements.txt` exists: Installs all dependencies
- Creates artifacts in `dist/` directory (for packaged projects)
- Depends on `format`, `lint`, and `test` tasks

## Usage Examples

### Full Build Pipeline

```powershell
# Run complete workflow: format → lint → test → build
.\bolt.ps1 build
```

### Development Iteration

```powershell
# Format code
.\bolt.ps1 format

# Validate syntax
.\bolt.ps1 lint

# Run tests without re-formatting/linting
.\bolt.ps1 test -Only
```

### CI/CD Integration

```yaml
# GitHub Actions
- name: Build Python Project
  run: pwsh -File bolt.ps1 build
  shell: pwsh

# Azure DevOps
- task: PowerShell@2
  inputs:
    filePath: 'bolt.ps1'
    arguments: 'build'
    pwsh: true
```

## Task Dependencies

- `build` depends on: `format`, `lint`, `test`
- `test` depends on: `format`, `lint`
- `lint` depends on: `format`

**Dependency tree:**
```
build
├── format
├── lint
│   └── format
└── test
    ├── format
    └── lint
        └── format
```

## Project Structure

Your Python project should follow this structure:

```
your-project/
├── bolt.config.json           # Bolt configuration
├── .build/                    # Bolt tasks
│   ├── Invoke-Format.ps1
│   ├── Invoke-Lint.ps1
│   ├── Invoke-Test.ps1
│   └── Invoke-Build.ps1
├── src/                       # Python source files (configured as PythonPath)
│   ├── __init__.py
│   ├── module1.py
│   └── module2.py
├── tests/                     # Test files
│   ├── test_module1.py
│   └── test_module2.py
├── requirements.txt           # Dependencies (optional)
├── pyproject.toml            # Package metadata (optional)
└── setup.py                  # Legacy package setup (optional)
```

## Testing

Run the test suite for this package starter:

```powershell
# Install Pester if needed
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser

# Run package tests
Invoke-Pester -Tag Python-Tasks
```

**Test coverage:**
- Task structure validation (Tasks.Tests.ps1)
- End-to-end integration tests (Integration.Tests.ps1)
- Example Python calculator module with pytest tests

## Docker Fallback

If Python is not installed, tasks automatically use Docker:

```powershell
# No local Python? No problem!
.\bolt.ps1 format    # Uses Docker: python:3.12-slim
.\bolt.ps1 build     # Automatically falls back to Docker
```

**Docker behavior:**
- Installs required tools (`black`, `ruff`, `pytest`) in container
- Mounts your project directory as `/project`
- Executes tasks inside container
- Results appear in your local filesystem

## Troubleshooting

### Python Not Found

If you get "Python not found" error:
1. **Install Python**: https://www.python.org/downloads/
2. **Verify installation**: `python --version` or `python3 --version`
3. **Configure explicit path**: Add `PythonToolPath` to `bolt.config.json`
4. **Use Docker**: Install Docker for automatic fallback

### No Test Files Found

Ensure test files follow pytest conventions:
- Name files `test_*.py` or `*_test.py`
- Place in directory specified by `PythonPath` or subdirectories

### Package Build Fails

For package builds to work, you need either:
- `pyproject.toml` (modern, recommended)
- `setup.py` (legacy)

If neither exists, the build task will only install dependencies from `requirements.txt`.

### Docker Permission Issues (Linux/macOS)

If Docker creates files with wrong permissions:
```bash
# Fix ownership after Docker operations
sudo chown -R $USER:$USER .
```

## Contributing

Want to improve this package starter? Submit a pull request!

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
