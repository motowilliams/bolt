# Release Workflow Documentation

This document explains the Release workflow for Bolt, a PowerShell build orchestration system.

## Overview

The Release pipeline automates the publishing of Bolt PowerShell module to GitHub releases. It packages the module, generates manifests, bundles documentation, and creates release assets with checksums.

## Triggers

The release workflow runs automatically on:

- **Git tag pushes** matching `v*` pattern (e.g., `v0.1.0`, `v1.0.0-beta`)
- **Manual dispatch** - Can be triggered manually via GitHub Actions UI (`workflow_dispatch`)

### Version Format

**Production Releases**: `v1.0.0`, `v2.1.3`, etc.
- Stable, fully tested releases
- No pre-release suffix
- Recommended for production use

**Pre-Releases**: `v1.0.0-beta`, `v2.0.0-rc1`, etc.
- Early access to new features
- Include pre-release suffix (`-beta`, `-rc1`, `-alpha`)
- Automatically marked as pre-release in GitHub

## Platform Strategy

The workflow runs on **Ubuntu (Linux)** only for consistent release builds:

- **Platform**: `ubuntu-latest`
- **PowerShell**: 7.0+ required
- **Permissions**: `contents: write` (required for creating GitHub releases)

## Workflow Steps

### 1. Setup and Preparation

#### Checkout Code
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0  # Full history for changelog
```
Retrieves the repository code with complete git history for changelog extraction.

#### PowerShell Version Check
```powershell
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "OS: $($PSVersionTable.OS)"
```
Displays environment information. Bolt requires PowerShell 7.0+.

### 2. Version Extraction

The workflow extracts two versions from the git tag:

```bash
# Tag: v1.0.0-beta
FULL_VERSION="1.0.0-beta"         # For release tag and changelog
MANIFEST_VERSION="1.0.0"          # For .psd1 file (no suffix)
```

**Why two versions?**
PowerShell module manifests (`New-ModuleManifest`) don't support semantic versioning pre-release suffixes. The workflow strips the suffix for manifest generation while keeping the full version for the release tag.

**Version Variables**:
- `VERSION` - Full version with pre-release suffix (e.g., `1.0.0-beta`)
- `MANIFEST_VERSION` - Version without suffix for PowerShell manifest (e.g., `1.0.0`)

### 3. Changelog Validation

```powershell
$changelogContent = Get-Content -Path "CHANGELOG.md" -Raw
if ($changelogContent -match "## \[$version\]") {
  Write-Host "✓ Found changelog entry for version $version"
} else {
  Write-Error "❌ No changelog entry found for version $version"
  exit 1
}
```

Ensures the CHANGELOG.md has an entry for the version being released. This prevents accidental releases without documentation.

**Required Format**:
```markdown
## [0.1.0] - 2025-12-16

### Added
- Feature description
```

### 4. Module Package Building

```powershell
pwsh -File infra/New-BoltModule.ps1 -Install -NoImport -ModuleOutputPath $releaseDir
```

Uses the existing module installation script to create the module structure:
- Creates `Bolt.psm1` (module script)
- Copies `bolt-core.ps1` (orchestration engine)
- Generates module wrapper with upward directory search

**Output**: `release/Bolt/` directory with module files

### 5. Module Manifest Generation

```powershell
pwsh -File infra/generate-manifest.ps1 `
  -ModulePath $modulePath `
  -ModuleVersion $manifestVersion `
  -Tags "Build,Orchestration,Tasks,PowerShell,Cross-Platform,DevOps" `
  -ProjectUri "https://github.com/motowilliams/bolt" `
  -LicenseUri "https://github.com/motowilliams/bolt/blob/main/LICENSE"
```

Creates `Bolt.psd1` manifest with:
- Module version (without pre-release suffix)
- Exported functions and aliases
- Project metadata (URI, license, tags)
- PowerShell Gallery compatibility

**Validation**: `Test-ModuleManifest` ensures the manifest is valid.

### 6. Documentation Bundling

Copies essential documentation files to the module package:

```powershell
$docFiles = @(
  "README.md",
  "LICENSE",
  "CHANGELOG.md",
  "CONTRIBUTING.md",
  "SECURITY.md",
  "IMPLEMENTATION.md"
)
```

Also includes:
- `bolt.config.schema.json` - JSON schema for configuration
- `bolt.config.example.json` - Example configuration file

**Note**: Starter packages (e.g., `packages/.build-bicep`) are **excluded** from releases.

### 7. Release Archive Creation

```powershell
Compress-Archive -Path $moduleDir -DestinationPath $zipPath -Force
```

Creates `Bolt-{version}.zip` with all module files.

**Checksum Generation**:
```powershell
$hash = Get-FileHash -Path $zipPath -Algorithm SHA256
"$($hash.Hash)  $zipName" | Out-File -FilePath $checksumFile
```

Creates `Bolt-{version}.zip.sha256` for verification.

### 8. Release Notes Extraction

```powershell
$pattern = "(?s)## \[$version\].*?(?=## \[|\z)"
if ($changelogContent -match $pattern) {
  $releaseNotes = $Matches[0]
}
```

Extracts the relevant section from CHANGELOG.md for this version.

**Fallback**: If extraction fails, links to full CHANGELOG.md.

### 9. GitHub Release Creation

```yaml
- uses: softprops/action-gh-release@v2
  with:
    body_path: release-notes.md
    files: |
      release/Bolt-${{ steps.version.outputs.VERSION }}.zip
      release/Bolt-${{ steps.version.outputs.VERSION }}.zip.sha256
    draft: false
    prerelease: ${{ contains(steps.version.outputs.VERSION, '-') }}
```

Creates the GitHub release with:
- Release notes from CHANGELOG.md
- Module zip and checksum files
- Pre-release flag based on version format

**Pre-release Detection**: Versions containing `-` are marked as pre-releases.

## Release Assets

Each release includes:

| Asset | Description |
|-------|-------------|
| `Bolt-{version}.zip` | Complete module package with all files |
| `Bolt-{version}.zip.sha256` | SHA256 checksum for verification |

**Module Package Contents**:
- Core files: `Bolt.psm1`, `Bolt.psd1`, `bolt-core.ps1`
- Documentation: README, LICENSE, CHANGELOG, CONTRIBUTING, SECURITY, IMPLEMENTATION
- Config files: `bolt.config.schema.json`, `bolt.config.example.json`

**Package Size**: ~96 KB compressed

## Exit Codes

- **0** - Success (release created successfully)
- **1** - Failure (validation failed, build failed, or release creation failed)

## Local Testing

Test the release build process locally before creating a release:

### 1. Test Module Building

```powershell
pwsh -File infra/New-BoltModule.ps1 -Install -NoImport -ModuleOutputPath "./test-release"
```

Verifies module structure creation works correctly.

### 2. Test Manifest Generation

```powershell
pwsh -File infra/generate-manifest.ps1 `
  -ModulePath "./test-release/Bolt/Bolt.psm1" `
  -ModuleVersion "0.1.0" `
  -Tags "Build,Orchestration"
```

Verifies manifest generation with proper version format.

### 3. Verify Manifest

```powershell
Test-ModuleManifest -Path "./test-release/Bolt/Bolt.psd1"
```

Ensures the generated manifest is valid PowerShell.

### 4. Test Module Import

```powershell
Import-Module ./test-release/Bolt -Force
bolt -ListTasks
```

Verifies the module loads and functions correctly.

## Performance

Typical release workflow runtime:

| Step | Duration |
|------|----------|
| Setup | ~10s |
| Module Building | ~5s |
| Manifest Generation | ~5s |
| Documentation Bundling | ~1s |
| Archive Creation | ~2s |
| Release Publishing | ~10s |
| **Total** | **~35s** |

## Troubleshooting

### Changelog Validation Fails

**Error**: `No changelog entry found for version X.Y.Z`

**Solution**: Add entry to CHANGELOG.md:
```markdown
## [X.Y.Z] - 2025-12-16

### Added
- Your changes here
```

Commit and push, then re-tag.

### Manifest Generation Fails

**Error**: `Cannot convert value "1.0.0-beta" to type "System.Version"`

**Cause**: PowerShell manifests don't support semantic versioning suffixes.

**Solution**: The workflow handles this automatically by stripping suffixes. If testing locally, remove the suffix:
```powershell
# Use "1.0.0" instead of "1.0.0-beta"
-ModuleVersion "1.0.0"
```

### Module Import Fails After Release

**Error**: `The specified module 'Bolt.psd1' was not loaded`

**Solution**: 
1. Verify manifest with `Test-ModuleManifest`
2. Check module path is in `$env:PSModulePath`
3. Use full path: `Import-Module ./path/to/Bolt -Force`

### Duplicate Release

**Error**: Release already exists for this tag

**Solution**:
1. Delete the existing release and tag from GitHub
2. Delete local tag: `git tag -d vX.Y.Z`
3. Re-create and push: `git tag vX.Y.Z && git push origin vX.Y.Z`

## Security

### Permissions

The workflow requires `contents: write` permission to create releases. This is granted via:

```yaml
permissions:
  contents: write
```

This permission is **scoped to the workflow** and cannot be used to modify code or workflows.

### Checksum Verification

Users should verify checksums before installing:

```powershell
# Download both .zip and .sha256 files
$hash = Get-FileHash -Path "Bolt-0.1.0.zip" -Algorithm SHA256
$expected = Get-Content "Bolt-0.1.0.zip.sha256" | Select-String -Pattern "^[A-F0-9]+" | ForEach-Object { $_.Matches.Value }

if ($hash.Hash -eq $expected) {
  Write-Host "✓ Checksum verified" -ForegroundColor Green
} else {
  Write-Error "✗ Checksum mismatch!"
}
```

### Package Integrity

The release workflow:
- ✅ Validates changelog entries before releasing
- ✅ Tests manifest validity before packaging
- ✅ Generates SHA256 checksums for verification
- ✅ Excludes starter packages (reduces attack surface)
- ✅ Uses official GitHub Actions (no third-party code execution)

## Maintenance

### Updating Dependencies

The workflow uses these external actions:
- `actions/checkout@v4` - Repository checkout
- `actions/upload-artifact@v4` - Artifact uploading
- `softprops/action-gh-release@v2` - Release creation

**Update process**:
1. Check for new versions in GitHub Actions marketplace
2. Update version tags in `.github/workflows/release.yml`
3. Test with a pre-release tag
4. Update this documentation if behavior changes

### Adding New Assets

To include additional files in releases:

1. **Modify documentation bundling**:
   ```powershell
   # In .github/workflows/release.yml
   $docFiles = @(
     "README.md",
     "YOUR_NEW_FILE.md"  # Add here
   )
   ```

2. **Update documentation** (this file) with new asset information

3. **Test locally** before pushing changes

### Changing Package Structure

If module structure changes significantly:

1. Update `infra/New-BoltModule.ps1` (module builder)
2. Update `infra/generate-manifest.ps1` (manifest generator)
3. Test changes locally with test release
4. Update workflow if needed
5. Update this documentation

## Creating a Release

For maintainers creating a new release:

### 1. Update CHANGELOG.md

Add version entry with release date:

```markdown
## [0.2.0] - 2025-12-20

### Added
- New feature description

### Changed
- Change description

### Fixed
- Bug fix description
```

Add version comparison link at bottom:

```markdown
[0.2.0]: https://github.com/motowilliams/bolt/compare/v0.1.0...v0.2.0
```

### 2. Commit Changes

```bash
git add CHANGELOG.md
git commit -m "chore: Prepare v0.2.0 release"
git push origin main
```

### 3. Create and Push Tag

```bash
# Production release
git tag v0.2.0
git push origin v0.2.0

# Pre-release
git tag v0.2.0-beta
git push origin v0.2.0-beta
```

### 4. Verify Release

1. Check GitHub Actions workflow completes successfully
2. Verify release appears on [Releases page](https://github.com/motowilliams/bolt/releases)
3. Download and verify checksum
4. Test module installation from release

## Related Documentation

- [CI Workflow Documentation](.github/workflows/ci.md) - Continuous integration process
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution guidelines
- [CHANGELOG.md](../../CHANGELOG.md) - Version history
- [README.md](../../README.md) - Project overview and installation

## Workflow File

See [`.github/workflows/release.yml`](release.yml) for the complete workflow configuration.

---

**Last Updated**: 2025-12-16

**Maintained By**: Bolt project maintainers

**Questions?**: Open an issue on [GitHub](https://github.com/motowilliams/bolt/issues)
