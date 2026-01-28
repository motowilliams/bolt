# TypeScript Starter Package for Bolt

TypeScript application development tasks for building, testing, linting, and formatting TypeScript code.

## Included Tasks

- **`format`** (alias: `fmt`) - Formats TypeScript files using Prettier
- **`lint`** - Validates TypeScript code using ESLint
- **`test`** - Runs TypeScript tests using Jest
- **`build`** - Compiles TypeScript to JavaScript (depends on format, lint, test)

## Requirements

- Node.js 18+ with npm: https://nodejs.org/
- PowerShell 7.0+

**OR**

- Docker: https://docs.docker.com/get-docker/ (automatic fallback if Node.js not installed)

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
Copy-Item -Path "packages/.build-typescript/Invoke-*.ps1" -Destination ".build/" -Force
```

**Multi-Package (Namespaced):**
```powershell
# Create namespace subdirectory
New-Item -ItemType Directory -Path ".build/typescript" -Force

# Copy tasks to namespace subdirectory
Copy-Item -Path "packages/.build-typescript/Invoke-*.ps1" -Destination ".build/typescript/" -Force
```

With namespaced installation, tasks are prefixed: `typescript-format`, `typescript-lint`, `typescript-test`, `typescript-build`. This allows using multiple package starters without conflicts.

## Configuration

By default, tasks look for TypeScript code in `tests/app/` directory. To use a custom path, create a `bolt.config.json` in your project root:

```json
{
  "TypeScriptPath": "src/"
}
```

Or for a different project structure:

```json
{
  "TypeScriptPath": "packages/my-app/"
}
```

## Usage

### Format all TypeScript files

```powershell
.\bolt.ps1 format
# or using alias
.\bolt.ps1 fmt
```

### Lint TypeScript code

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

Uses Prettier to format TypeScript source files according to project configuration.

- Formats all `.ts` files in the configured path
- Reads configuration from `.prettierrc` or `package.json`
- Exit code 0 on success, 1 on failure

### Lint Task

Uses ESLint to examine TypeScript code and report code quality issues.

- Checks for code style violations and potential errors
- Reads configuration from `.eslintrc.js` or `package.json`
- Exit code 0 on success, 1 on errors

### Test Task

Runs TypeScript tests using Jest test runner.

- Executes all tests matching `*.test.ts` or `*.spec.ts`
- Uses configuration from `jest.config.js` or `package.json`
- Supports TypeScript via `ts-jest` preset
- Exit code 0 if all tests pass, 1 if any fail

### Build Task

Compiles TypeScript files to JavaScript using the TypeScript compiler.

- Dependencies: format, lint, test (run automatically)
- Output directory: `dist/` (configurable via `tsconfig.json`)
- Generates JavaScript files, type declarations, and source maps
- Reports number of generated files
- Exit code 0 on success, 1 on failure

## Configuration

### Custom TypeScript Project Directory

Configure the path to your TypeScript files using `bolt.config.json`:

```json
{
  "TypeScriptPath": "src/"
}
```

Or for a monorepo structure:

```json
{
  "TypeScriptPath": "packages/app/"
}
```

Tasks now require explicit configuration - no default fallback paths.

### Custom Tool Path

If Node.js is installed in a non-standard location, configure the executable path:

```json
{
  "NodeToolPath": "/usr/local/bin/node",
  "TypeScriptPath": "src/"
}
```

**Windows example:**
```json
{
  "NodeToolPath": "C:\\Program Files\\nodejs\\node.exe",
  "TypeScriptPath": "src/"
}
```

If `NodeToolPath` is not configured, Bolt searches for `node` in your system PATH or falls back to Docker. npm path is automatically derived from the Node.js path.

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
├── package.json               # npm dependencies
├── tsconfig.json              # TypeScript config
├── jest.config.js             # Jest test config
├── .eslintrc.js               # ESLint config
├── .prettierrc                # Prettier config
└── src/                       # Your TypeScript code (configurable)
    ├── index.ts
    └── index.test.ts
```

## Docker Fallback

If Node.js/npm is not installed, tasks automatically use Docker with the `node:22-alpine` image:

- All tasks work identically with Docker
- No local Node.js installation required
- Volume mounts preserve file changes
- Slightly slower than native npm due to container overhead

**Note**: Docker must be installed and running. See https://docs.docker.com/get-docker/

## Testing

This package includes comprehensive tests:

- `tests/Tasks.Tests.ps1` - Task structure validation
- `tests/Integration.Tests.ps1` - End-to-end integration tests
- `tests/app/` - Example TypeScript application with Jest tests

Run tests with:

```powershell
Invoke-Pester -Path packages/.build-typescript/tests/ -Tag TypeScript-Tasks
```

## Troubleshooting

### Node.js/npm not found

Error: `Node.js/npm not found and Docker is not available.`

**Solution**: Install Node.js from https://nodejs.org/ and ensure it's in your PATH, or install Docker.

### No package.json found

Warning: `No package.json found in <path>`

**Solution**: 
1. Ensure your project has a `package.json` file
2. Check your `bolt.config.json` if using a custom path
3. Verify the path is relative to your project root

### npm install fails

If dependency installation fails:
1. Delete `node_modules/` and `package-lock.json`
2. Run `npm cache clean --force`
3. Try again

### Tests not running

If Jest tests don't execute:
1. Ensure `jest` is in `devDependencies`
2. Check `jest.config.js` configuration
3. Verify test files match `*.test.ts` or `*.spec.ts` pattern

### Docker on Windows

On Windows, ensure Docker Desktop is running and configured for Linux containers.

## Contributing

Contributions are welcome! See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.
