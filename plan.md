## Title

Split package starters into docker and non-docker supported packages.

## Summary

Split starters so each package either uses local toolchains or docker only. This removes the mixed fallback logic that makes starter tasks verbose.

## Description

We have an issue where every time that callback is executed the base image invokes adding any necessary dependencies and then executing the command(s) required by that container.

In the end we will have the following starter packages:

- .build-bicep
- .build-dotnet
- .build-dotnet-docker
- .build-golang
- .build-golang-docker
- .build-python
- .build-python-docker
- .build-terraform
- .build-terraform-docker
- .build-typescript
- .build-typescript-docker

Note that bicep does not have a vendor or official project supported docker container.

## Decisions

- Replace docker fallback behavior with dedicated *-docker starters.
- Each *-docker starter ships with a sibling Dockerfile used by its tasks.
- **CRITICAL: Docker starters ALWAYS build and use their Dockerfile image** (not Docker Hub base images).
- **CRITICAL: Tool-specific env vars control Docker CACHE INVALIDATION, not whether to use Dockerfile**.
- Environment variable pattern: `BOLT_<TOOLCHAIN>_DOCKER_REBUILD=1` forces `docker build --no-cache`.
- Without env var set, Docker build uses cache for faster builds.
- On Windows, docker-only starters require Linux containers.
- **CRITICAL: The test and sample applications for the non-docker and docker start packages should be identical. This will prove the architecture of the starter. The docker versions will have an extra test file to cover the docker specific features. Another way to think about this is from a OO perspective the docker starter is a super-class of the non-docker version.

## Core Architecture Principle (CRITICAL)

**Docker and non-Docker packages must share IDENTICAL:**
1. **Sample application/IaC code** - exact file-by-file copy (tests/app/ or tests/iac/)
2. **Tasks.Tests.ps1** - copied verbatim from non-Docker version, no modifications
3. **Integration.Tests.ps1** - copied verbatim from non-Docker version, no modifications

**Docker packages add ONLY:**
1. **Dockerfile** - new file defining container environment
2. **Docker.Tests.ps1** - SEPARATE file for Docker-specific validation (not mixed into existing tests)
3. **Modified task scripts** - different tool invocation pattern (Docker execution)
4. **Updated README.md** - note Docker-specific requirements

**Validation requirement:** Use `Get-PesterTests.ps1` to programmatically prove identity before marking package complete.

**OO Analogy:** Think of Docker package as a subclass/extension of the non-Docker base class:
- Inherits all functionality (sample app + tests are unchanged)
- Adds specialized behavior (Dockerfile + Docker.Tests.ps1 + Docker task execution)
- Proves architecture correctness (same codebase works with both toolchain approaches)

## Implementation Outline

- Split existing starters into non-docker and docker-only variants.
- Remove docker fallback logic from non-docker starters.
- Non-docker starters should have zero references to docker.
- Non-docker do not need to implement any fall back patterns
- Add per-starter Dockerfiles for docker-only starters and reference them from task scripts.
- Think about the docker version as setting up the docker image and configuring a tool command that represents the installed tool of that respective package.
- Add documented, tool-specific env vars to force docker image rebuilds.
- Update Invoke-Tests.ps1 to have tags for the new set of tests
- update create-package-starter.prompt.md to handle creating future non-docker and docker supported packages
- update CONTRIBUTING.MD as well so that any forks pull requests know we now have a split pattern for non-docker and docker packages
- Update CHANGELOG.md with a new minor version

## Documentation Impact

- Update packages overview in [packages/README.md](packages/README.md).
- Update ecosystem docs in [docs/ecosystem.md](docs/ecosystem.md).
- Update implementation notes that describe docker fallback in [IMPLEMENTATION.md](IMPLEMENTATION.md).

## Implementation Checklist

Process packages in order. Run Phase 3 validation before ticking any package complete.

### DotNet

**Phase 1 - Non-Docker (`packages/.build-dotnet`)**
- [x] Remove `$useDocker` variable and all references from all task scripts
- [x] Remove Docker container execution blocks (`docker run --rm -v ...`) from all task scripts
- [x] Remove Docker-related error/info messages from all task scripts
- [x] Verify ZERO Docker references: `Select-String -Path "packages/.build-dotnet/*.ps1" -Pattern "docker"`
- [x] Verify syntax: `PSParser::Tokenize` on all `Invoke-*.ps1` files
- [x] Run tests: `Invoke-Pester -Path "packages/.build-dotnet/tests"`

**Phase 2 - Docker (`packages/.build-dotnet-docker`)**
- [x] Copy `tests/app` directory EXACTLY from non-Docker (no modifications)
- [x] Copy `tests/Tasks.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [x] Copy `tests/Integration.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [x] Verify test identity: `Get-PesterTests.ps1` comparison shows ZERO differences
- [x] Create `Dockerfile` (FROM mcr.microsoft.com/dotnet/sdk, WORKDIR /project)
- [x] Create all `Invoke-*.ps1` task scripts using Docker execution pattern
- [x] Create `tests/Docker.Tests.ps1` (SEPARATE file, not added to existing tests)
- [x] Copy and update `README.md` (add Docker installation requirements)
- [x] Verify `bolt.config.json` path points to `packages/.build-dotnet-docker/tests` (not `/tests/app`)

**Phase 3 - Validation**
- [x] Run Phase 3 validation script - ALL 6 checks pass

---

### Golang

**Phase 1 - Non-Docker (`packages/.build-golang`)**
- [ ] Remove `$useDocker` variable and all references from all task scripts
- [ ] Remove Docker container execution blocks from all task scripts
- [ ] Remove Docker-related error/info messages from all task scripts
- [ ] Verify ZERO Docker references: `Select-String -Path "packages/.build-golang/*.ps1" -Pattern "docker"`
- [ ] Verify syntax: check all `Invoke-*.ps1` files
- [ ] Run tests: `Invoke-Pester -Path "packages/.build-golang/tests"`

**Phase 2 - Docker (`packages/.build-golang-docker`)**
- [ ] Copy `tests/app` directory EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Tasks.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Integration.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Verify test identity: `Get-PesterTests.ps1` comparison shows ZERO differences
- [ ] Create `Dockerfile` (FROM golang, WORKDIR /project)
- [ ] Create all `Invoke-*.ps1` task scripts using Docker execution pattern (`BOLT_GOLANG_DOCKER_REBUILD`)
- [ ] Create `tests/Docker.Tests.ps1` (SEPARATE file)
- [ ] Copy and update `README.md`
- [ ] Verify `bolt.config.json` path points to `packages/.build-golang-docker/tests`

**Phase 3 - Validation**
- [ ] Run Phase 3 validation script - ALL 6 checks pass

---

### TypeScript

**Phase 1 - Non-Docker (`packages/.build-typescript`)**
- [ ] Remove `$useDocker` variable and all references from all task scripts
- [ ] Remove Docker container execution blocks from all task scripts
- [ ] Remove Docker-related error/info messages from all task scripts
- [ ] Verify ZERO Docker references: `Select-String -Path "packages/.build-typescript/*.ps1" -Pattern "docker"`
- [ ] Verify syntax: check all `Invoke-*.ps1` files
- [ ] Run tests: `Invoke-Pester -Path "packages/.build-typescript/tests"`

**Phase 2 - Docker (`packages/.build-typescript-docker`)**
- [ ] Copy `tests/app` directory EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Tasks.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Integration.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Verify test identity: `Get-PesterTests.ps1` comparison shows ZERO differences
- [ ] Create `Dockerfile` (FROM node, WORKDIR /project)
- [ ] Create all `Invoke-*.ps1` task scripts using Docker execution pattern (`BOLT_TYPESCRIPT_DOCKER_REBUILD`)
- [ ] Create `tests/Docker.Tests.ps1` (SEPARATE file)
- [ ] Copy and update `README.md`
- [ ] Verify `bolt.config.json` path points to `packages/.build-typescript-docker/tests`

**Phase 3 - Validation**
- [ ] Run Phase 3 validation script - ALL 6 checks pass

---

### Python

**Phase 1 - Non-Docker (`packages/.build-python`)**
- [ ] Remove `$useDocker` variable and all references from all task scripts
- [ ] Remove Docker container execution blocks from all task scripts
- [ ] Remove Docker-related error/info messages from all task scripts
- [ ] Verify ZERO Docker references: `Select-String -Path "packages/.build-python/*.ps1" -Pattern "docker"`
- [ ] Verify syntax: check all `Invoke-*.ps1` files
- [ ] Run tests: `Invoke-Pester -Path "packages/.build-python/tests"`

**Phase 2 - Docker (`packages/.build-python-docker`)**
- [ ] Copy `tests/app` directory EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Tasks.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Integration.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Verify test identity: `Get-PesterTests.ps1` comparison shows ZERO differences
- [ ] Create `Dockerfile` (FROM python, WORKDIR /project)
- [ ] Create all `Invoke-*.ps1` task scripts using Docker execution pattern (`BOLT_PYTHON_DOCKER_REBUILD`)
- [ ] Create `tests/Docker.Tests.ps1` (SEPARATE file)
- [ ] Copy and update `README.md`
- [ ] Verify `bolt.config.json` path points to `packages/.build-python-docker/tests`

**Phase 3 - Validation**
- [ ] Run Phase 3 validation script - ALL 6 checks pass

---

### Terraform

**Phase 1 - Non-Docker (`packages/.build-terraform`)**
- [ ] Remove `$useDocker` variable and all references from all task scripts
- [ ] Remove Docker container execution blocks from all task scripts
- [ ] Remove Docker-related error/info messages from all task scripts
- [ ] Verify ZERO Docker references: `Select-String -Path "packages/.build-terraform/*.ps1" -Pattern "docker"`
- [ ] Verify syntax: check all `Invoke-*.ps1` files
- [ ] Run tests: `Invoke-Pester -Path "packages/.build-terraform/tests"`

**Phase 2 - Docker (`packages/.build-terraform-docker`)**
- [ ] Copy `tests/iac` directory EXACTLY from non-Docker (no modifications) - note: iac not app
- [ ] Copy `tests/Tasks.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Copy `tests/Integration.Tests.ps1` EXACTLY from non-Docker (no modifications)
- [ ] Verify test identity: `Get-PesterTests.ps1` comparison shows ZERO differences
- [ ] Create `Dockerfile` (FROM hashicorp/terraform, WORKDIR /project)
- [ ] Create all `Invoke-*.ps1` task scripts using Docker execution pattern (`BOLT_TERRAFORM_DOCKER_REBUILD`)
- [ ] Create `tests/Docker.Tests.ps1` (SEPARATE file)
- [ ] Copy and update `README.md`
- [ ] Verify `bolt.config.json` path points to `packages/.build-terraform-docker/tests`

**Phase 3 - Validation**
- [ ] Run Phase 3 validation script - ALL 6 checks pass

---

### Cross-Cutting Concerns (after all packages complete)

**Testing**
- [-] Update `Invoke-Tests.ps1` to add tags for all new Docker package test files
  - [x] `DotNet-Docker` tag added, `packages/.build-dotnet-docker/tests` path added
  - [ ] `Golang-Docker` tag — add when Golang Phase 2 complete
  - [ ] `TypeScript-Docker` tag — add when TypeScript Phase 2 complete
  - [ ] `Python-Docker` tag — add when Python Phase 2 complete
  - [ ] `Terraform-Docker` tag — add when Terraform Phase 2 complete

**Documentation**
- [ ] Update [packages/README.md](packages/README.md) - list all 11 packages, explain Docker vs non-Docker split
- [ ] Update [docs/ecosystem.md](docs/ecosystem.md) - remove Docker fallback references, describe split pattern
- [ ] Update [IMPLEMENTATION.md](IMPLEMENTATION.md) - replace Docker fallback docs with split architecture docs
- [ ] Update [CONTRIBUTING.md](CONTRIBUTING.md) - explain split pattern for contributors/PRs

**Prompts**
- [ ] Update `.github/prompts/create-package-starter.prompt.md` - cover both non-Docker and Docker variants

**Release**
- [ ] Update `CHANGELOG.md` with new minor version entry

---

### Final All-Packages Validation

Run this after all packages and cross-cutting concerns are complete:

```powershell
$packages = @('dotnet', 'golang', 'typescript', 'python', 'terraform')
$allPass = $true

foreach ($pkg in $packages) {
    Write-Host "`n=== $pkg ===" -ForegroundColor Cyan

    $dockerRefs = Select-String -Path "packages/.build-$pkg/*.ps1" -Pattern "docker" -AllMatches
    $ndTests = .\Get-PesterTests.ps1 -Path "packages/.build-$pkg/tests" |
               Where-Object { $_.FilePath -notmatch "Docker\.Tests\.ps1" } |
               Select-Object TestName | Sort-Object TestName
    $dTests = .\Get-PesterTests.ps1 -Path "packages/.build-$pkg-docker/tests" |
              Where-Object { $_.FilePath -notmatch "Docker\.Tests\.ps1" } |
              Select-Object TestName | Sort-Object TestName
    $diff = Compare-Object $ndTests $dTests -Property TestName

    $c1 = $dockerRefs.Count -eq 0
    $c2 = $null -eq $diff
    $c3 = Test-Path "packages/.build-$pkg-docker/tests/Docker.Tests.ps1"
    $c4 = Test-Path "packages/.build-$pkg-docker/Dockerfile"

    Write-Host "$(if ($c1){'✅'}else{'❌'}) Non-Docker has zero Docker refs" -ForegroundColor $(if ($c1){'Green'}else{'Red'})
    Write-Host "$(if ($c2){'✅'}else{'❌'}) Core tests identical" -ForegroundColor $(if ($c2){'Green'}else{'Red'})
    Write-Host "$(if ($c3){'✅'}else{'❌'}) Docker.Tests.ps1 exists" -ForegroundColor $(if ($c3){'Green'}else{'Red'})
    Write-Host "$(if ($c4){'✅'}else{'❌'}) Dockerfile exists" -ForegroundColor $(if ($c4){'Green'}else{'Red'})

    $allPass = $allPass -and $c1 -and $c2 -and $c3 -and $c4
}

Write-Host "`n$(if ($allPass){'✅ ALL PACKAGES COMPLETE'}else{'❌ SOME PACKAGES NEED WORK'})" -ForegroundColor $(if ($allPass){'Green'}else{'Red'})
```

## Step-by-Step Implementation Workflow

**Execute these steps EXACTLY in order for EACH package. Do ONE package completely before starting the next.**

### Package Processing Order

1. **DotNet** (mature toolchain, clear task separation)
2. **Golang** (statically compiled, fewer runtime dependencies)
3. **TypeScript** (Node.js ecosystem, well-defined tasks)
4. **Python** (dynamic language, clear task structure)
5. **Terraform** (declarative IaC, unique task names but similar pattern)

---

### Phase 1: Remove Docker from Non-Docker Package

**Goal:** Clean non-Docker package of all Docker fallback logic.

1. **Audit current state:**
   ```powershell
   # Check for Docker references
   Select-String -Path "packages/.build-<pkg>/*.ps1" -Pattern "docker" -CaseSensitive
   
   # List all task scripts
   Get-ChildItem "packages/.build-<pkg>/Invoke-*.ps1" | Select-Object Name
   ```

2. **For each task script (Invoke-*.ps1):**
   - Read entire file
   - Identify Docker fallback block (usually `if (-not $toolCmdObj)` with Docker container invocation)
   - Remove: `$useDocker` variable and all references
   - Remove: Docker container execution logic (`docker run --rm -v ...`)
   - Remove: Docker-related error messages ("Using Docker container for...")
   - Keep: `$BoltConfig.<Tool>ToolPath` check (user-configured path override)
   - Keep: `Get-Command <tool>` check with direct failure if not found
   - Result: Tool invocation logic = config path → PATH search → fail (no Docker)

3. **Verify removal:**
   ```powershell
   # Should return ZERO matches
   Select-String -Path "packages/.build-<pkg>/*.ps1" -Pattern "docker" -AllMatches
   ```

4. **Verify syntax:**
   ```powershell
   # Check each task script parses correctly
   Get-ChildItem "packages/.build-<pkg>/Invoke-*.ps1" | ForEach-Object {
       $errors = $null
       [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$errors)
       if ($errors) { Write-Host "❌ $($_.Name): $($errors.Count) errors" -ForegroundColor Red }
       else { Write-Host "✅ $($_.Name): Valid syntax" -ForegroundColor Green }
   }
   ```

5. **Run tests:**
   ```powershell
   Invoke-Pester -Path "packages/.build-<pkg>/tests" -Output Detailed
   ```

**Success criteria:** Non-Docker package has ZERO Docker references, all tests pass.

---

### Phase 2: Create Docker Package with Identity

**Goal:** Build Docker package as extension of non-Docker base.

1. **Copy sample app/IaC EXACTLY:**
   ```powershell
   # DO NOT modify, recreate, or "clean up" - EXACT copy
   Copy-Item -Path "packages/.build-<pkg>/tests/app" `
             -Destination "packages/.build-<pkg>-docker/tests/app" `
             -Recurse -Force
   
   # Or for Terraform/Bicep packages:
   Copy-Item -Path "packages/.build-<pkg>/tests/iac" `
             -Destination "packages/.build-<pkg>-docker/tests/iac" `
             -Recurse -Force
   ```

2. **Copy test files EXACTLY:**
   ```powershell
   # Copy verbatim - DO NOT modify these files
   Copy-Item -Path "packages/.build-<pkg>/tests/Tasks.Tests.ps1" `
             -Destination "packages/.build-<pkg>-docker/tests/Tasks.Tests.ps1" -Force
   
   Copy-Item -Path "packages/.build-<pkg>/tests/Integration.Tests.ps1" `
             -Destination "packages/.build-<pkg>-docker/tests/Integration.Tests.ps1" -Force
   ```

3. **Verify identity IMMEDIATELY:**
   ```powershell
   # Compare test discovery - should show ZERO differences
   $ndTests = .\Get-PesterTests.ps1 -Path "packages/.build-<pkg>/tests" | 
              Select-Object TestName, Tags | Sort-Object TestName
   $dTests = .\Get-PesterTests.ps1 -Path "packages/.build-<pkg>-docker/tests" | 
             Select-Object TestName, Tags | Sort-Object TestName
   
   $diff = Compare-Object $ndTests $dTests -Property TestName, Tags
   
   if ($diff) {
       Write-Host "❌ IDENTITY VIOLATION - Tests differ between variants" -ForegroundColor Red
       $diff | Format-Table
       exit 1
   } else {
       Write-Host "✅ Identity confirmed - core tests are identical" -ForegroundColor Green
   }
   ```

4. **Create Dockerfile:**
   ```dockerfile
   # packages/.build-<tool>-docker/Dockerfile
   
   # Base: Official image for the tool (for documentation)
   FROM <official-image>:<version>
   
   # Add common utilities (git for version control, common dependencies)
   RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
   
   WORKDIR /project
   ENTRYPOINT ["<tool>"]
   ```

5. **Create task scripts with Docker execution pattern:**
   
   Each task script (`Invoke-Format.ps1`, `Invoke-Build.ps1`, etc.) follows this pattern:
   
   ```powershell
   #Requires -Version 7.0
   
   # TASK: <task-name>
   # DESCRIPTION: <task description>
   # DEPENDS: <dependencies>
   
   [CmdletBinding()]
   param()
   
   # 1. Check Docker availability
   $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
   if (-not $dockerCmd) {
       Write-Error "Docker not found. Install from: https://www.docker.com/get-started"
       exit 1
   }
   
   # 2. Build image from Dockerfile (ALWAYS use Dockerfile, not Docker Hub)
   $dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
   $imageName = "bolt-<tool>:latest"
   
   # Determine cache strategy (env var controls --no-cache flag)
   $buildArgs = @("-t", $imageName, "-f", $dockerfilePath, (Split-Path $dockerfilePath))
   if ($env:BOLT_<TOOL>_DOCKER_REBUILD -eq "1" -or $env:BOLT_<TOOL>_DOCKER_REBUILD -eq "true") {
       Write-Host "  Rebuilding Docker image from scratch (cache disabled)" -ForegroundColor Gray
       $buildArgs = @("--no-cache") + $buildArgs
   } else {
       Write-Host "  Building Docker image (using cache if available)" -ForegroundColor Gray
   }
   
   & docker build @buildArgs 2>&1 | Out-Null
   if ($LASTEXITCODE -ne 0) {
       Write-Error "Docker build failed"
       exit 1
   }
   
   # 3. Get project directory from bolt.config.json
   $projectDir = $BoltConfig.<Tool>Path
   if (-not $projectDir) {
       Write-Error "Project path not configured in bolt.config.json"
       exit 1
   }
   
   # 4. Execute tool via Docker container
   Write-Host "Running <tool> <command> in Docker container..." -ForegroundColor Cyan
   
   $absolutePath = [System.IO.Path]::GetFullPath($projectDir)
   $output = & docker run --rm `
       -v "${absolutePath}:/project" `
       -w /project `
       $imageName <tool-command> 2>&1
   
   # 5. Check exit code and report
   if ($LASTEXITCODE -ne 0) {
       Write-Host "✗ Task failed" -ForegroundColor Red
       Write-Host $output
       exit 1
   }
   
   Write-Host "✓ Task completed successfully" -ForegroundColor Green
   exit 0
   ```

6. **Create Docker.Tests.ps1 (SEPARATE file for Docker-specific tests):**
   
   ```powershell
   #Requires -Version 7.0
   
   Describe "Docker Package - <Tool>" -Tag "Package-<Tool>-Docker-Specific" {
       BeforeAll {
           $script:PackageRoot = Split-Path $PSScriptRoot
           $script:DockerfilePath = Join-Path $PackageRoot "Dockerfile"
       }
       
       Context "Dockerfile" {
           It "Should exist in package root" {
               $script:DockerfilePath | Should -Exist
           }
           
           It "Should have valid FROM instruction" {
               $content = Get-Content $script:DockerfilePath -Raw
               $content | Should -Match "FROM\s+\S+:\S+"
           }
           
           It "Should set working directory to /project" {
               $content = Get-Content $script:DockerfilePath -Raw
               $content | Should -Match "WORKDIR\s+/project"
           }
       }
       
       Context "Environment Variables" {
           It "Should support BOLT_<TOOL>_DOCKER_REBUILD for cache invalidation" {
               $taskScripts = Get-ChildItem -Path (Join-Path $PackageRoot "Invoke-*.ps1")
               $found = $false
               foreach ($script in $taskScripts) {
                   $content = Get-Content $script.FullName -Raw
                   if ($content -match '\$env:BOLT_\w+_DOCKER_REBUILD') {
                       $found = $true
                       break
                   }
               }
               $found | Should -BeTrue -Because "Task scripts should check BOLT_*_DOCKER_REBUILD env var"
           }
       }
       
       Context "Docker Execution Pattern" {
           It "Should check for Docker availability in all task scripts" {
               $taskScripts = Get-ChildItem -Path (Join-Path $PackageRoot "Invoke-*.ps1")
               foreach ($script in $taskScripts) {
                   $content = Get-Content $script.FullName -Raw
                   $content | Should -Match 'Get-Command\s+docker' -Because "$($script.Name) should verify Docker is available"
               }
           }
           
           It "Should build from Dockerfile (not pull base image)" {
               $taskScripts = Get-ChildItem -Path (Join-Path $PackageRoot "Invoke-*.ps1")
               $found = $false
               foreach ($script in $taskScripts) {
                   $content = Get-Content $script.FullName -Raw
                   if ($content -match 'docker\s+build.*-f.*Dockerfile') {
                       $found = $true
                       break
                   }
               }
               $found | Should -BeTrue -Because "Tasks should build from Dockerfile, not use Docker Hub directly"
           }
           
           It "Should use volume mounting for project directory" {
               $taskScripts = Get-ChildItem -Path (Join-Path $PackageRoot "Invoke-*.ps1")
               $found = $false
               foreach ($script in $taskScripts) {
                   $content = Get-Content $script.FullName -Raw
                   if ($content -match 'docker\s+run.*-v.*:/project') {
                       $found = $true
                       break
                   }
               }
               $found | Should -BeTrue -Because "Tasks should mount project directory as volume"
           }
       }
   }
   ```

7. **Copy and update README.md:**
   ```powershell
   Copy-Item -Path "packages/.build-<pkg>/README.md" `
             -Destination "packages/.build-<pkg>-docker/README.md" -Force
   
   # Add Docker-specific requirements section to README
   # (Add note about Docker installation, Linux containers on Windows, etc.)
   ```

---

### Phase 3: Mandatory Validation

**Run these validation commands BEFORE declaring package complete:**

```powershell
$pkg = "<package-name>"  # e.g., "dotnet", "golang", "typescript"

Write-Host "`n=== Validation Report for $pkg ===" -ForegroundColor Cyan

# Check 1: Non-Docker has zero Docker references
Write-Host "`nCheck 1: Non-Docker Docker references" -ForegroundColor Yellow
$dockerRefs = Select-String -Path "packages/.build-$pkg/*.ps1" -Pattern "docker" -AllMatches
if ($dockerRefs.Count -eq 0) {
    Write-Host "✅ PASS: Zero Docker references in non-Docker package" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: Found $($dockerRefs.Count) Docker references" -ForegroundColor Red
    $dockerRefs | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

# Check 2: Test identity (core tests must be identical)
Write-Host "`nCheck 2: Test identity between variants" -ForegroundColor Yellow
$ndTests = .\Get-PesterTests.ps1 -Path "packages/.build-$pkg/tests" | 
           Where-Object { $_.FilePath -notmatch "Docker\.Tests\.ps1" } |
           Select-Object TestName, Tags | Sort-Object TestName

$dTests = .\Get-PesterTests.ps1 -Path "packages/.build-$pkg-docker/tests" | 
          Where-Object { $_.FilePath -notmatch "Docker\.Tests\.ps1" } |
          Select-Object TestName, Tags | Sort-Object TestName

$diff = Compare-Object $ndTests $dTests -Property TestName, Tags

if (-not $diff) {
    Write-Host "✅ PASS: Core tests are identical ($($ndTests.Count) tests)" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: Tests differ between variants" -ForegroundColor Red
    $diff | Format-Table -AutoSize
}

# Check 3: Docker.Tests.ps1 exists
Write-Host "`nCheck 3: Docker-specific test file" -ForegroundColor Yellow
$dockerTestFile = "packages/.build-$pkg-docker/tests/Docker.Tests.ps1"
if (Test-Path $dockerTestFile) {
    $dockerSpecificCount = (.\Get-PesterTests.ps1 -Path $dockerTestFile).Count
    Write-Host "✅ PASS: Docker.Tests.ps1 exists with $dockerSpecificCount tests" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: Docker.Tests.ps1 does not exist" -ForegroundColor Red
}

# Check 4: Dockerfile exists and has required structure
Write-Host "`nCheck 4: Dockerfile structure" -ForegroundColor Yellow
$dockerfilePath = "packages/.build-$pkg-docker/Dockerfile"
if (Test-Path $dockerfilePath) {
    $dockerfileContent = Get-Content $dockerfilePath -Raw
    $hasFrom = $dockerfileContent -match "FROM\s+\S+:\S+"
    $hasWorkdir = $dockerfileContent -match "WORKDIR\s+/project"
    
    if ($hasFrom -and $hasWorkdir) {
        Write-Host "✅ PASS: Dockerfile has valid structure" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL: Dockerfile missing required directives" -ForegroundColor Red
        if (-not $hasFrom) { Write-Host "  - Missing FROM instruction" -ForegroundColor Red }
        if (-not $hasWorkdir) { Write-Host "  - Missing WORKDIR /project" -ForegroundColor Red }
    }
} else {
    Write-Host "❌ FAIL: Dockerfile does not exist" -ForegroundColor Red
}

# Check 5: Sample app identity (file-by-file comparison)
Write-Host "`nCheck 5: Sample application identity" -ForegroundColor Yellow
$ndAppPath = "packages/.build-$pkg/tests/app"
$dAppPath = "packages/.build-$pkg-docker/tests/app"

# Adjust for Terraform/Bicep packages that use tests/iac
if (-not (Test-Path $ndAppPath)) {
    $ndAppPath = "packages/.build-$pkg/tests/iac"
    $dAppPath = "packages/.build-$pkg-docker/tests/iac"
}

if ((Test-Path $ndAppPath) -and (Test-Path $dAppPath)) {
    $ndFiles = Get-ChildItem -Path $ndAppPath -Recurse -File | Select-Object -ExpandProperty Name | Sort-Object
    $dFiles = Get-ChildItem -Path $dAppPath -Recurse -File | Select-Object -ExpandProperty Name | Sort-Object
    
    $fileDiff = Compare-Object $ndFiles $dFiles
    
    if (-not $fileDiff) {
        Write-Host "✅ PASS: Sample app files are identical ($($ndFiles.Count) files)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL: Sample app files differ" -ForegroundColor Red
        $fileDiff | Format-Table -AutoSize
    }
} else {
    Write-Host "⚠️  WARN: Could not find sample app directories" -ForegroundColor Yellow
}

# Check 6: Run all tests
Write-Host "`nCheck 6: Test execution" -ForegroundColor Yellow
Write-Host "Running non-Docker tests..." -ForegroundColor Gray
$ndResult = Invoke-Pester -Path "packages/.build-$pkg/tests" -PassThru -Output Minimal

Write-Host "Running Docker tests..." -ForegroundColor Gray
$dResult = Invoke-Pester -Path "packages/.build-$pkg-docker/tests" -PassThru -Output Minimal

$ndPass = $ndResult.FailedCount -eq 0
$dPass = $dResult.FailedCount -eq 0

if ($ndPass -and $dPass) {
    Write-Host "✅ PASS: All tests passed" -ForegroundColor Green
    Write-Host "  Non-Docker: $($ndResult.PassedCount)/$($ndResult.TotalCount) passed" -ForegroundColor Green
    Write-Host "  Docker: $($dResult.PassedCount)/$($dResult.TotalCount) passed" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: Some tests failed" -ForegroundColor Red
    if (-not $ndPass) { Write-Host "  Non-Docker: $($ndResult.FailedCount) failed" -ForegroundColor Red }
    if (-not $dPass) { Write-Host "  Docker: $($dResult.FailedCount) failed" -ForegroundColor Red }
}

# Final summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
$allChecks = ($dockerRefs.Count -eq 0) -and (-not $diff) -and (Test-Path $dockerTestFile) -and 
             (Test-Path $dockerfilePath) -and $ndPass -and $dPass

if ($allChecks) {
    Write-Host "✅ ALL CHECKS PASSED - Package $pkg is complete" -ForegroundColor Green
} else {
    Write-Host "❌ VALIDATION FAILED - Review failures above" -ForegroundColor Red
}
```

**ALL checks must pass before moving to next package.**

---

## Anti-Patterns That Cause Agent Failures

**These are the mistakes that cause agents to finish but produce incorrect results:**

### ❌ Modifying Sample Apps When Creating Docker Version

**Problem:** Agents "clean up" or "improve" sample apps during docker package creation

**Impact:** Sample apps differ between variants, violating identity principle

**Solution:** Use `Copy-Item -Force` with exact paths, never modify files after copying

**Validation:**
```powershell
# File names must match exactly
Compare-Object `
    (Get-ChildItem "packages/.build-<pkg>/tests/app" -Recurse -File | Select-Object Name) `
    (Get-ChildItem "packages/.build-<pkg>-docker/tests/app" -Recurse -File | Select-Object Name)
# Should return: No differences
```

---

### ❌ Adding Docker Tests to Existing Tasks.Tests.ps1

**Problem:** Agents add Docker-specific tests to Tasks.Tests.ps1 or Integration.Tests.ps1

**Impact:** Test files differ between variants, breaks identity validation

**Solution:** Create SEPARATE `Docker.Tests.ps1` file for all Docker-specific tests

**Validation:**
```powershell
# Tasks.Tests.ps1 should be byte-for-byte identical
$nd = Get-FileHash "packages/.build-<pkg>/tests/Tasks.Tests.ps1"
$d = Get-FileHash "packages/.build-<pkg>-docker/tests/Tasks.Tests.ps1"
$nd.Hash -eq $d.Hash  # Should be: True
```

---

### ❌ Incomplete Docker Logic Removal from Non-Docker Packages

**Problem:** Agents leave remnants of Docker fallback logic (commented code, unused variables)

**Impact:** Non-Docker packages still reference Docker concepts

**Solution:** Use `Select-String` to verify ZERO Docker references after removal

**Validation:**
```powershell
Select-String -Path "packages/.build-<pkg>/*.ps1" -Pattern "docker" -AllMatches
# Should return: Zero matches (empty result)
```

---

### ❌ Not Running Validation Commands

**Problem:** Agents declare "done" without proving test identity or running validation

**Impact:** Appears complete but fails identity checks

**Solution:** Run Phase 3 validation commands BEFORE marking package complete (all checks must pass)

**Required validation:**
- Zero Docker references in non-Docker
- Test identity confirmed via Get-PesterTests.ps1
- Docker.Tests.ps1 exists
- Dockerfile exists and valid
- Sample app files identical
- All tests pass (both variants)

---

### ❌ Using Docker Hub Base Images Instead of Building from Dockerfile

**Problem:** Task scripts use `docker run mcr.microsoft.com/dotnet/sdk:10.0` directly

**Impact:** Dockerfile is ignored, custom environment not used

**Solution:** ALWAYS build from Dockerfile first, then use built image

**Pattern:**
```powershell
# ✅ CORRECT
docker build -t bolt-dotnet:latest -f Dockerfile .
docker run --rm -v "${pwd}:/project" bolt-dotnet:latest dotnet build

# ❌ WRONG
docker run --rm -v "${pwd}:/project" mcr.microsoft.com/dotnet/sdk:10.0 dotnet build
```

---

### ❌ Treating BOLT_*_DOCKER_REBUILD as "Whether to Use Dockerfile"

**Problem:** Agents only build from Dockerfile when env var is set

**Impact:** Default behavior uses Docker Hub, not Dockerfile

**Solution:** ALWAYS build from Dockerfile; env var controls cache invalidation only

**Pattern:**
```powershell
# ✅ CORRECT: Always build, env var controls --no-cache flag
$buildArgs = @("-t", "bolt-tool:latest", "-f", "Dockerfile", ".")
if ($env:BOLT_TOOL_DOCKER_REBUILD -eq "1") {
    $buildArgs = @("--no-cache") + $buildArgs  # Forces rebuild all layers
}
docker build @buildArgs

# ❌ WRONG: Only builds from Dockerfile if env var set
if ($env:BOLT_TOOL_DOCKER_REBUILD -eq "1") {
    docker build -t bolt-tool:latest -f Dockerfile .
    $image = "bolt-tool:latest"
} else {
    $image = "mcr.microsoft.com/dotnet/sdk:10.0"  # Uses Docker Hub instead
}
```

---

## Implementation Notes

### Docker Image Pattern (CORRECTED)

**Initial Implementation (INCORRECT):**
- ❌ Used Docker Hub base images by default (e.g., `mcr.microsoft.com/dotnet/sdk:10.0`)
- ❌ Only built from Dockerfile if `BOLT_*_DOCKER_REBUILD=1`
- ❌ Treated env var as "whether to use Dockerfile" toggle

**Correct Pattern:**
- ✅ Docker starters ALWAYS build and use their Dockerfile
- ✅ `BOLT_*_DOCKER_REBUILD=1` controls Docker cache invalidation (forces `--no-cache`)
- ✅ Without env var: builds use Docker cache for speed
- ✅ With env var set: rebuilds all layers from scratch (ignores cache)

**Rationale:**
- Dockerfiles provide customized environments (e.g., git, additional tools)
- Base images are for documentation only (show what Dockerfile extends)
- Cache control is needed for testing changes to Dockerfiles
- Consistent behavior: tests and tasks always use same image

**Implementation Pattern:**
```powershell
# Build from Dockerfile (always)
$dockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "Dockerfile"
$imageName = "bolt-<toolchain>:latest"

# Determine cache strategy
$buildArgs = @("-t", $imageName, "-f", $dockerfilePath, $PSScriptRoot)
if ($env:BOLT_<TOOLCHAIN>_DOCKER_REBUILD -eq "1" -or $env:BOLT_<TOOLCHAIN>_DOCKER_REBUILD -eq "true") {
    $buildArgs = @("--no-cache") + $buildArgs
}

& docker build @buildArgs 2>&1
$dockerImage = $imageName
```

```powershell
# tool execution example

$toolCmd = {
    param([string[]]$Arguments)
    & docker run --rm `
        --volume "${pwd}:/workspace" `
        --workdir /workspace `
        mcr.microsoft.com/dotnet/sdk:10.0 `
        dotnet @Arguments
}

& $toolCmd build HelloWorld.csproj


```

### Issues Encountered

**Issue 1: bolt.config.json Path Mismatch**
- Problem: Docker packages had `DotNetPath: "packages/.build-dotnet-docker/tests/app"` (pointed only to SUT)
- Impact: Test projects in sibling directories not discovered
- Solution: Changed to `"packages/.build-dotnet-docker/tests"` (scans entire directory tree)
- Affects: dotnet-docker, python-docker, golang-docker, typescript-docker, terraform-docker

**Issue 2: PowerShell Syntax Errors in Golang Non-Docker**
- Problem: Extra closing braces in try/finally blocks (Invoke-Lint.ps1, Invoke-Build.ps1)
- Impact: Parse errors prevented task execution
- Solution: Corrected brace matching in try/finally/Pop-Location blocks

**Issue 3: .NET Test Project Structure**
- Problem: Duplicate test project created inside `app/HelloWorld.Tests/` instead of sibling
- Correct structure: `tests/app/` (SUT) and `tests/HelloWorld.Tests/` (test project) as siblings
- Solution: Removed nested copy, kept sibling structure with `<ProjectReference Include="..\app\HelloWorld.csproj" />`

**Issue 4: Docker Package Missing lint Task**
- Problem: DotNet-Docker tests referenced non-existent `Invoke-Lint.ps1`
- Reality: .NET uses `dotnet format` for both formatting and linting (no separate lint task)
- Solution: Removed lint references from Tasks.Tests.ps1 and Integration.Tests.ps1

**Issue 5: Terraform Validate Task Missing Dependency**
- Problem: `Invoke-Validate.ps1` had empty `DEPENDS:` field
- Impact: Tests expected `# DEPENDS:.*format` pattern
- Solution: Added `format` as dependency: `# DEPENDS: format`

## Learnings from Test Standardization

**Successfully standardized all 6 non-Docker packages to 28-test template (February 2026).**

### Final Test Counts

All packages now have **exactly 28 tests** (23 Tasks + 5 Integration):

| Package | Original | Final | Status |
|---------|----------|-------|--------|
| DotNet | 31 | 28 | ✅ Removed 3 filesystem artifact tests |
| TypeScript | 21 | 28 | ✅ Added 7 (tool availability + config) |
| Terraform | 21 | 28 | ✅ Added 7 (tool availability + config) |
| Golang | 19 | 28 | ✅ Added 9 + fixed DEPENDS metadata |
| Python | 17 | 28 | ✅ Complete file rewrite from looped to standard format |
| Bicep | 16 | 28 | ✅ Added 12 (unique 3-task structure) |

### Standard Test Template Structure

**Tasks.Tests.ps1 (23 tests)**:
- Per-task tests: exist, syntax, metadata, alias (if applicable), dependencies, tool availability
- Configuration tests: project files, config files, module/package structure

**Integration.Tests.ps1 (5 tests)**:
- Individual task execution: format, lint/validate, test (if applicable), build
- Full pipeline test: verifies dependency chain

### Bicep-Specific Patterns (Unique)

**Critical differences from other packages:**
1. **Only 3 tasks**: Format, Lint, Build (no Test task - Bicep is declarative IaC)
2. **No dependencies in Format/Lint**: Users run format manually (intentional design)
3. **Test project location**: `tests/iac/` (not `tests/app/` like others)
4. **Lint task alias**: No "validate" alias (just "lint")
5. **Build task alias**: No "compile" alias (just "build")
6. **File extensions**: `.bicep` (source), `.json` (compiled ARM), `.parameters.json` (params)

**Bicep test structure (23 tests)**:
- Format Task: 6 tests (including "no dependencies" check)
- Lint Task: 6 tests (including "validates Bicep syntax", no dependencies)
- Build Task: 6 tests (including "compiles Bicep to ARM templates")
- Configuration: 5 tests (Bicep files, main files, modules, parameters, module directory)

### File Corruption Recovery Pattern

**Problem**: Sequential `replace_string_in_file` operations caused file corruption:
- Multiple edits changed whitespace/structure
- Exact string matching became impossible
- Duplicate content appeared in file
- Tests failed with parse errors

**Solution**: Complete file replacement strategy:
1. Create clean file with `create_file` tool (as `.NEW.ps1` temporary name)
2. Verify test count: `Select-String -Pattern "^\s*It ['`"]"` to count tests
3. Replace original: `Move-Item -Force` to overwrite corrupted file
4. Run tests to verify: ensure all tests pass

**When to use**: After 3-5 sequential edits to same file, or when parse errors occur.

### Quote Style Consistency

**Single quotes** (`It 'description'`):
- TypeScript, Golang, Terraform, Bicep

**Double quotes** (`It "description"`):
- DotNet, Python

**Maintain consistency within each package** - don't mix quote styles in same file.

### Tool Availability Pattern

All task tests should verify tool detection:
```powershell
It 'Should check for tool availability' {
    $content = Get-Content $script:TaskPath -Raw
    $content | Should -Match '(Get-Command|Test-Path|<tool-name>)'
}
```

**Examples**:
- Bicep: `'(Get-Command|Test-Path|bicep)'`
- TypeScript: `'(Get-Command|Test-Path|npm|node)'`
- Golang: `'(Get-Command|Test-Path|go)'`
- Python: `'(Get-Command|Test-Path|python|pip)'`

### Configuration Test Importance

**Configuration context validates project structure**:
- Package manager files: `package.json`, `go.mod`, `requirements.txt`, `*.csproj`
- Config files: `tsconfig.json`, `.terraform/`, `bicepconfig.json`
- Source structure: `*.ts`, `*.go`, `*.py`, `*.bicep` files exist
- Module/package organization: proper directory layout

**Use `Set-ItResult -Skipped`** for optional files (e.g., Bicep parameter files not required for all projects).

### Golang DEPENDS Metadata Fix

**Issue**: Golang non-Docker had empty DEPENDS fields in:
- `Invoke-Lint.ps1`: Changed from empty to `# DEPENDS: format`
- `Invoke-Test.ps1`: Changed from empty to `# DEPENDS: format, lint`

**Lesson**: Always verify DEPENDS metadata matches actual dependency chain:
- Format: no dependencies
- Lint: depends on format
- Test: depends on format, lint
- Build: depends on format, lint, test (or just format, lint for packages without test task)

### Python Complete Rewrite Approach

**Original**: 17 tests with compact looped structure checking multiple conditions per test
**Problem**: Didn't match standard template format, hard to maintain
**Solution**: Complete file replacement with 23-test standard format

**Lesson**: When structure differs significantly, rewrite entire file vs incremental edits:
- Clearer intent
- Consistent with other packages
- Easier to maintain
- Less risk of file corruption

### Test Execution Validation

**Always verify test execution after standardization**:
1. Count tests: `Select-String -Pattern "^\s*It ['`"]" | Measure-Object`
2. Run tests: `Invoke-Pester -Path "package/.../tests"`
3. Check results: Total=28, Passed=27-28, Skipped=0-1, Failed=0
4. Expected skips: Optional configuration tests (Bicep parameter files, etc.)

**Command template**:
```powershell
$tasks = (Select-String -Path "Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$integration = (Select-String -Path "Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$total = $tasks + $integration
# Expected: $tasks=23, $integration=5, $total=28
```

### Key Success Factors

1. **Maintain consistency**: Same structure across all packages (with documented exceptions like Bicep)
2. **Test early**: Run tests after each major change to catch issues quickly
3. **Use templates**: TypeScript/Golang/Terraform share same structure, copy working patterns
4. **Document differences**: Bicep's 3-task structure is intentional, not an error
5. **Verify tool patterns**: Check actual task implementation before writing regex tests
6. **Complete replacement over incremental edits**: When corruption occurs, rewrite cleanly

## Future Agent Implementation Guide

**Use this section if reimplementing package standardization or creating new packages.**

### Pre-Implementation Checklist

**Before starting any package standardization:**

1. **Inventory current state**:
   ```powershell
   # Count tests in all packages
   $packages = @('dotnet', 'typescript', 'terraform', 'golang', 'python', 'bicep')
   foreach ($pkg in $packages) {
       $tasks = (Select-String -Path "packages\.build-$pkg\tests\Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
       $integration = (Select-String -Path "packages\.build-$pkg\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
       Write-Host "$pkg : Tasks=$tasks, Integration=$integration, Total=$($tasks + $integration)"
   }
   ```

2. **Identify quote style** (single vs double quotes):
   ```powershell
   # Check quote style used in existing tests
   Select-String -Path "packages\.build-<pkg>\tests\Tasks.Tests.ps1" -Pattern "It ['`"]" | Select-Object -First 1
   ```

3. **Map task structure**:
   ```powershell
   # List all task files in package
   Get-ChildItem "packages\.build-<pkg>\Invoke-*.ps1" | Select-Object Name
   
   # Check dependencies in each task
   Select-String -Path "packages\.build-<pkg>\Invoke-*.ps1" -Pattern "# DEPENDS:"
   ```

4. **Verify tool availability checks**:
   ```powershell
   # Find tool detection patterns
   Select-String -Path "packages\.build-<pkg>\Invoke-*.ps1" -Pattern "(Get-Command|Test-Path)" -Context 1
   ```

### Standardization Workflow (Per Package)

**Follow this sequence for each package standardization:**

#### Step 1: Read Reference Package
```powershell
# Use TypeScript as reference for standard 4-task structure (Format, Lint, Test, Build)
# Or use Terraform/Golang if similar toolchain
$reference = "packages\.build-typescript\tests\Tasks.Tests.ps1"
Get-Content $reference | Select-Object -First 50
```

#### Step 2: Count Current Tests
```powershell
$current = "packages\.build-<pkg>\tests\Tasks.Tests.ps1"
$taskTests = (Select-String -Path $current -Pattern "^\s*It ['`"]").Count
$integTests = (Select-String -Path "packages\.build-<pkg>\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
Write-Host "Current: Tasks=$taskTests, Integration=$integTests, Total=$($taskTests + $integTests)"
Write-Host "Gap: Need $($taskTests - 23) tasks tests, $($integTests - 5) integration tests"
```

#### Step 3: Identify Missing Tests

**Standard task test pattern (6 tests per task)**:
- `Should exist`
- `Should have valid PowerShell syntax`
- `Should have proper task metadata`
- `Should have [task-specific alias]` (if applicable)
- `Should depend on [dependencies]` (if applicable)
- `Should check for tool availability`

**Standard configuration tests (3-5 tests)**:
- Package manager file exists (`package.json`, `go.mod`, etc.)
- Config file exists (`tsconfig.json`, `.terraform/`, etc.)
- Source files present (`*.ts`, `*.go`, etc.)
- Optional: Module/package structure validation

**Standard integration tests (5 tests)**:
- Format task execution
- Lint/validate task execution
- Test task execution (if applicable)
- Build task execution
- Full pipeline test (verifies dependency chain)

#### Step 4: Add Missing Tests Incrementally

**Strategy for adding tests:**

1. **Add 1-3 tests at a time** (avoid file corruption from too many edits)
2. **Read file before each edit** to verify current structure
3. **Run tests after each addition** to catch issues early
4. **Use multi_replace if adding to different contexts** (Format, Lint, Build)

**Example - Adding tool availability test**:
```powershell
# Pattern to add (adjust quote style per package):
It 'Should check for tool availability' {
    if (Test-Path $script:TaskPath) {
        $content = Get-Content $script:TaskPath -Raw -ErrorAction Stop
        # Should check for <tool> availability
        $content | Should -Match '(Get-Command|Test-Path|<tool-name>)'
    }
}
```

#### Step 5: Validate After Each Change

```powershell
# Quick validation script
$pkg = "<package-name>"
Write-Host "`nValidating $pkg..." -ForegroundColor Cyan

# Count tests
$tasks = (Select-String -Path "packages\.build-$pkg\tests\Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$integration = (Select-String -Path "packages\.build-$pkg\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$total = $tasks + $integration

Write-Host "Test count: Tasks=$tasks, Integration=$integration, Total=$total"

# Run tests
Invoke-Pester -Path "packages\.build-$pkg\tests" -Output Normal

# Check for errors
if ($LASTEXITCODE -ne 0) {
    Write-Host "Tests failed - review output" -ForegroundColor Red
} else {
    Write-Host "Tests passed" -ForegroundColor Green
}
```

### Common Scenarios and Solutions

#### Scenario 1: Package Has Fewer Than 4 Tasks

**Example**: Bicep has only 3 tasks (Format, Lint, Build - no Test task)

**Solution**:
- Add 6 tests per task (3 tasks × 6 = 18 tests)
- Add 5 configuration tests
- Keep 5 integration tests
- Total: 23 + 5 = 28 tests

**Note**: Don't artificially create a Test task - respect the package's design.

#### Scenario 2: Need to Remove Excess Tests

**Example**: DotNet had 31 tests (3 too many)

**Solution**:
- Identify tests that don't fit standard template
- Remove filesystem/artifact validation tests (Docker standardization made these obsolete)
- Keep: metadata validation, dependency checks, tool availability, configuration structure

**Command to compare tests**:
```powershell
# See what tests are different
diff (Select-String "It ['`"]" "packages\.build-dotnet\tests\Tasks.Tests.ps1") `
     (Select-String "It ['`"]" "packages\.build-typescript\tests\Tasks.Tests.ps1")
```

#### Scenario 3: File Corruption After Multiple Edits

**Symptoms**:
- `replace_string_in_file` fails with "Could not find matching text"
- Parse errors when running tests
- Duplicate content in file

**Recovery procedure**:
1. **Create clean file**:
   ```powershell
   # Use create_file tool to write complete, clean content
   # Save as: packages\.build-<pkg>\tests\Tasks.Tests.NEW.ps1
   ```

2. **Verify test count**:
   ```powershell
   $count = (Select-String -Path "Tasks.Tests.NEW.ps1" -Pattern "^\s*It ['`"]").Count
   Write-Host "New file has $count tests (expected: 23)"
   ```

3. **Replace corrupted file**:
   ```powershell
   Move-Item -Path "Tasks.Tests.NEW.ps1" -Destination "Tasks.Tests.ps1" -Force
   ```

4. **Run tests to verify**:
   ```powershell
   Invoke-Pester -Path "packages\.build-<pkg>\tests\Tasks.Tests.ps1"
   ```

#### Scenario 4: Python Package Needs Different Quote Style

**Challenge**: Python uses double quotes (`It "description"`), not single quotes

**Solution**:
- Check existing test style: `Select-String -Pattern 'It ["'`"]' -Path Tasks.Tests.ps1 | Select-Object -First 1`
- Match the package's style consistently
- Don't mix quote styles in same file

#### Scenario 5: Task Has Empty DEPENDS Field

**Example**: Golang Lint and Test tasks had `# DEPENDS:` with nothing after

**Fix**:
```powershell
# Lint task should depend on format
# Old: # DEPENDS:
# New: # DEPENDS: format

# Test task should depend on format, lint
# Old: # DEPENDS:
# New: # DEPENDS: format, lint
```

**Verify dependency chain logic**:
- Format: no dependencies (always first)
- Lint: depends on format
- Test: depends on format, lint
- Build: depends on format, lint, test (or just format, lint if no test task)

### Testing Automation Commands

**Run all package tests with summary**:
```powershell
$packages = @('dotnet', 'typescript', 'terraform', 'golang', 'python', 'bicep')
Write-Host "`n=== Package Test Results ===" -ForegroundColor Cyan
foreach ($pkg in $packages) {
    Write-Host "`n$pkg Package:" -ForegroundColor Yellow
    $result = Invoke-Pester -Path "packages\.build-$pkg\tests" -PassThru
    $status = if ($result.FailedCount -eq 0) { "✅ PASS" } else { "❌ FAIL" }
    Write-Host "$status - Total: $($result.TotalCount), Passed: $($result.PassedCount), Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })
}
```

**Quick test count validation**:
```powershell
# Run this to verify all packages have 28 tests
$packages = @('dotnet', 'typescript', 'terraform', 'golang', 'python', 'bicep')
$allCorrect = $true
foreach ($pkg in $packages) {
    $tasks = (Select-String -Path "packages\.build-$pkg\tests\Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
    $integration = (Select-String -Path "packages\.build-$pkg\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
    $total = $tasks + $integration
    $status = if ($total -eq 28) { "✅" } else { "❌" }
    $allCorrect = $allCorrect -and ($total -eq 28)
    Write-Host "$status $($pkg.PadRight(12)): $total tests" -ForegroundColor $(if ($total -eq 28) { 'Green' } else { 'Red' })
}
if ($allCorrect) {
    Write-Host "`n✅ All packages standardized to 28 tests" -ForegroundColor Green
} else {
    Write-Host "`n❌ Some packages need adjustment" -ForegroundColor Red
}
```

### Docker Package Test Parity Validation

**CRITICAL**: Docker packages must include ALL tests from their non-Docker counterparts PLUS Docker-specific tests.

**Principle**: A Docker package test suite should be a **superset** of the non-Docker version:
- All base functionality tests (task existence, metadata, dependencies, syntax)
- All configuration tests (project files, structure)
- All integration tests (task execution, pipeline)
- **PLUS** Docker-specific tests:
  - Dockerfile presence and validity
  - Docker image building and caching
  - Environment variable handling (`BOLT_*_DOCKER_REBUILD`)
  - Volume mounting for source files
  - Container execution patterns

**Example**: `dotnet-docker` should have all `dotnet` tests + Docker-specific additions.

#### Using Get-PesterTests.ps1 for Audit

**The `Get-PesterTests.ps1` script enables systematic test comparison between Docker and non-Docker packages.**

**Compare test descriptions between pairs**:
```powershell
# Get all test descriptions for comparison
.\Get-PesterTests.ps1 | Where-Object { $_.Tags -like "Package-Dotnet*" } | 
    Select-Object Tags, Describe, Context, Name | 
    Out-GridView -Title "DotNet Package Tests Comparison"

# Or export to CSV for detailed analysis
.\Get-PesterTests.ps1 | Where-Object { $_.Tags -like "Package-*-Docker-Tasks" } | 
    ConvertTo-Csv | Out-File -Encoding ascii docker-tests.csv
```

**Automated parity check script**:
```powershell
# Validate Docker package has all non-Docker tests plus extras
function Test-DockerPackageParity {
    param([string]$PackageName)  # e.g., "dotnet", "typescript", "golang"
    
    Write-Host "`n=== Testing $PackageName Docker Parity ===" -ForegroundColor Cyan
    
    # Get non-Docker tests
    $nonDockerTests = .\Get-PesterTests.ps1 | 
        Where-Object { $_.Tags -eq "Package-$PackageName-Tasks" } |
        Select-Object -ExpandProperty Name
    
    # Get Docker tests
    $dockerTests = .\Get-PesterTests.ps1 | 
        Where-Object { $_.Tags -eq "Package-$PackageName-Docker-Tasks" } |
        Select-Object -ExpandProperty Name
    
    # Check if all non-Docker tests exist in Docker
    $missing = @()
    foreach ($test in $nonDockerTests) {
        if ($test -notin $dockerTests) {
            $missing += $test
        }
    }
    
    # Report results
    Write-Host "Non-Docker tests: $($nonDockerTests.Count)" -ForegroundColor White
    Write-Host "Docker tests: $($dockerTests.Count)" -ForegroundColor White
    Write-Host "Expected minimum: $($nonDockerTests.Count) (should be more due to Docker-specific tests)" -ForegroundColor Yellow
    
    if ($missing.Count -eq 0) {
        Write-Host "✅ Parity check passed - all non-Docker tests present in Docker version" -ForegroundColor Green
        
        $extraTests = $dockerTests.Count - $nonDockerTests.Count
        if ($extraTests -gt 0) {
            Write-Host "✅ Plus $extraTests Docker-specific tests" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Warning: No Docker-specific tests found - should have extras for Docker features" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Parity check FAILED - missing tests in Docker version:" -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
    }
}

# Run parity checks for all Docker packages
@('dotnet', 'typescript', 'terraform', 'golang', 'python') | ForEach-Object {
    Test-DockerPackageParity -PackageName $_
}
```

**Manual comparison workflow**:
```powershell
# Step 1: Extract test names for a package pair
$nonDocker = .\Get-PesterTests.ps1 | Where-Object { $_.Tags -eq "Package-Golang-Tasks" } | Select-Object Name, Context
$docker = .\Get-PesterTests.ps1 | Where-Object { $_.Tags -eq "Package-Golang-Docker-Tasks" } | Select-Object Name, Context

# Step 2: Find tests in non-Docker but missing from Docker
$nonDockerNames = $nonDocker | Select-Object -ExpandProperty Name
$dockerNames = $docker | Select-Object -ExpandProperty Name
$missing = $nonDockerNames | Where-Object { $_ -notin $dockerNames }

# Step 3: Report
if ($missing) {
    Write-Host "❌ Missing tests in Docker version:" -ForegroundColor Red
    $missing
} else {
    Write-Host "✅ All non-Docker tests present in Docker version" -ForegroundColor Green
}

# Step 4: Find Docker-specific additions
$dockerSpecific = $dockerNames | Where-Object { $_ -notin $nonDockerNames }
Write-Host "`nDocker-specific tests:" -ForegroundColor Cyan
$dockerSpecific
```

#### Expected Docker-Specific Tests

**Every Docker package should add these test types:**

1. **Dockerfile validation**:
   - `Should have Dockerfile in package root`
   - `Should have valid Dockerfile syntax`
   - `Should specify base image in Dockerfile`

2. **Environment variable tests**:
   - `Should check for BOLT_*_DOCKER_REBUILD environment variable`
   - `Should use --no-cache when rebuild flag is set`
   - `Should use Docker cache when rebuild flag is not set`

3. **Volume mounting tests**:
   - `Should mount source directory as volume`
   - `Should preserve file permissions in mounted volumes`

4. **Image management tests**:
   - `Should build Docker image from Dockerfile`
   - `Should tag Docker image correctly`
   - `Should reuse existing image when available`

**Example test count expectation**:
- Non-Docker: 28 tests (23 Tasks + 5 Integration)
- Docker: 28+ tests (all 28 from non-Docker + 3-5 Docker-specific)
- Typical Docker package: **31-33 tests total**

#### Troubleshooting Docker Parity Issues

**Issue**: Docker package missing tests from non-Docker version

**Diagnosis**:
```powershell
# Compare test contexts between versions
.\Get-PesterTests.ps1 | 
    Where-Object { $_.Tags -like "Package-Dotnet*Tasks" } |
    Group-Object Tags, Context |
    Select-Object Count, @{N='Package';E={$_.Group[0].Tags}}, @{N='Context';E={$_.Group[0].Context}}
```

**Solution**:
1. Identify missing context (e.g., "Format Task", "Configuration")
2. Copy corresponding tests from non-Docker package
3. Adjust tool availability checks for containerized execution
4. Add Docker-specific tests to the context

**Issue**: Docker package has fewer tests than non-Docker

**Diagnosis**: Run parity check script above

**Solution**:
1. This is **always wrong** - Docker should have MORE tests, not fewer
2. Review non-Docker test file and identify missing tests
3. Copy missing tests to Docker version
4. Add Docker-specific tests afterwards

### Anti-Patterns to Avoid

**DON'T**:
- ❌ Make 5+ sequential edits to same file without reading current state
- ❌ Test aliases that don't exist (check actual task file first)
- ❌ Use regex patterns that don't match actual command invocation (e.g., `bicep build` when code uses `& $bicepCmd build`)
- ❌ Mix quote styles within same test file
- ❌ Add Test task to packages that don't have one (respect their design)
- ❌ Copy tests between packages without verifying tool-specific patterns
- ❌ Skip running tests after changes (catch issues early)
- ❌ **Create Docker package with fewer tests than non-Docker version** (Docker must be superset)
- ❌ **Forget to add Docker-specific tests** (Dockerfile validation, env vars, volume mounting)
- ❌ **Skip Docker parity validation** (always use Get-PesterTests.ps1 to audit)

**DO**:
- ✅ Read file before each edit operation
- ✅ Use working package as reference template
- ✅ Verify regex patterns against actual task code
- ✅ Maintain consistent quote style per package
- ✅ Run tests after every change
- ✅ Use `create_file` for complete rewrites when corruption occurs
- ✅ Check DEPENDS metadata matches actual dependency chain
- ✅ **Verify Docker packages include ALL non-Docker tests** (use Get-PesterTests.ps1)
- ✅ **Add Docker-specific tests for containerization features** (3-5 additional tests minimum)
- ✅ **Run parity check script before marking Docker package complete**

### Reference Templates

**Standard 4-task package (TypeScript, Golang, Terraform)**:
- Format Task: 6 tests
- Lint Task: 6 tests
- Test Task: 6 tests
- Build Task: 6 tests
- Configuration: 3-5 tests (totaling to 23)
- Integration: 5 tests
- **Total: 28 tests**

**3-task package (Bicep)**:
- Format Task: 6 tests
- Lint Task: 6 tests
- Build Task: 6 tests
- Configuration: 5 tests
- Integration: 5 tests
- **Total: 28 tests**

**Python package (uses double quotes)**:
- Format Task: 6 tests (black formatter)
- Lint Task: 6 tests (ruff linter)
- Test Task: 6 tests (pytest)
- Build Task: 5 tests (pip install)
- Configuration: 4 tests
- Integration: 5 tests
- **Total: 28 tests**

### Success Criteria

**Non-Docker package standardization is complete when**:
1. ✅ Test count: exactly 28 tests (23 Tasks + 5 Integration)
2. ✅ All tests pass (27-28 passing, 0-1 skipped, 0 failed)
3. ✅ Quote style consistent throughout file
4. ✅ Tool availability checks present for all tasks
5. ✅ DEPENDS metadata matches actual dependencies
6. ✅ Configuration tests validate project structure
7. ✅ Integration tests execute actual tasks and verify exit codes
8. ✅ No parse errors or corrupted file content

**Docker package standardization is complete when**:
1. ✅ **All non-Docker criteria above are met**
2. ✅ **Test count: minimum 31-33 tests** (28 from non-Docker + 3-5 Docker-specific)
3. ✅ **Parity check passes**: All non-Docker tests present in Docker version
4. ✅ **Docker-specific tests present**: Dockerfile validation, env var handling, volume mounting, image building
5. ✅ **Get-PesterTests.ps1 audit confirms parity**: No missing tests from non-Docker version
6. ✅ **BOLT_*_DOCKER_REBUILD environment variable tested** (both set and unset scenarios)

**Final validation command**:
```powershell
# Run this to confirm completion
$pkg = "<package-name>"
$tasks = (Select-String -Path "packages\.build-$pkg\tests\Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$integration = (Select-String -Path "packages\.build-$pkg\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$result = Invoke-Pester -Path "packages\.build-$pkg\tests" -PassThru

Write-Host "`n=== $pkg Standardization Status ===" -ForegroundColor Cyan
Write-Host "Test count: $tasks + $integration = $($tasks + $integration) (expected: 28)" -ForegroundColor $(if (($tasks + $integration) -eq 28) { 'Green' } else { 'Red' })
Write-Host "Passed: $($result.PassedCount), Failed: $($result.FailedCount), Skipped: $($result.SkippedCount)" -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "Status: $(if (($tasks + $integration -eq 28) -and ($result.FailedCount -eq 0)) { '✅ COMPLETE' } else { '❌ NEEDS WORK' })"
```

**Docker package validation command**:
```powershell
# Run this to confirm Docker package completion with parity check
$pkg = "<package-name>"  # e.g., "dotnet", "golang", "typescript"
$dockerPkg = "$pkg-docker"

# Step 1: Count tests in both versions
$nonDockerTasks = (Select-String -Path "packages\.build-$pkg\tests\Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$nonDockerInteg = (Select-String -Path "packages\.build-$pkg\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$nonDockerTotal = $nonDockerTasks + $nonDockerInteg

$dockerTasks = (Select-String -Path "packages\.build-$dockerPkg\tests\Tasks.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$dockerInteg = (Select-String -Path "packages\.build-$dockerPkg\tests\Integration.Tests.ps1" -Pattern "^\s*It ['`"]").Count
$dockerTotal = $dockerTasks + $dockerInteg

# Step 2: Run tests
$dockerResult = Invoke-Pester -Path "packages\.build-$dockerPkg\tests" -PassThru

# Step 3: Parity check
$nonDockerTests = .\Get-PesterTests.ps1 | Where-Object { $_.Tags -eq "Package-$pkg-Tasks" } | Select-Object -ExpandProperty Name
$dockerTests = .\Get-PesterTests.ps1 | Where-Object { $_.Tags -eq "Package-$dockerPkg-Tasks" } | Select-Object -ExpandProperty Name
$missing = $nonDockerTests | Where-Object { $_ -notin $dockerTests }

# Step 4: Report
Write-Host "`n=== $dockerPkg Standardization Status ===" -ForegroundColor Cyan
Write-Host "Non-Docker: $nonDockerTotal tests" -ForegroundColor White
Write-Host "Docker: $dockerTotal tests (expected: $nonDockerTotal + 3-5 = $($nonDockerTotal + 3)-$($nonDockerTotal + 5))" -ForegroundColor $(if ($dockerTotal -ge ($nonDockerTotal + 3)) { 'Green' } else { 'Red' })
Write-Host "Tests passed: $($dockerResult.PassedCount)/$($dockerResult.TotalCount)" -ForegroundColor $(if ($dockerResult.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "Parity check: $(if ($missing.Count -eq 0) { '✅ PASS' } else { '❌ FAIL - ' + $missing.Count + ' tests missing' })" -ForegroundColor $(if ($missing.Count -eq 0) { 'Green' } else { 'Red' })

if ($missing) {
    Write-Host "`nMissing tests from non-Docker version:" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

$status = ($dockerTotal -ge ($nonDockerTotal + 3)) -and ($dockerResult.FailedCount -eq 0) -and ($missing.Count -eq 0)
Write-Host "`nStatus: $(if ($status) { '✅ COMPLETE' } else { '❌ NEEDS WORK' })" -ForegroundColor $(if ($status) { 'Green' } else { 'Red' })
```
