---
agent: agent
---

# Prepare Release for Bolt

You are tasked with preparing a new release of the Bolt build system. This involves updating the CHANGELOG.md file and ensuring all version information is correct.

## Context

The Bolt project follows:
- [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/) format for CHANGELOG.md
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for version numbers

Review the detailed release process instructions at `.github/copilot-instructions.md` in the "Changelog Maintenance" → "Release Process" section (starting around line 1529).

## Your Task

Prepare a new release by updating CHANGELOG.md with the appropriate version number and date.

## Steps to Follow

**CRITICAL**: You must ACTUALLY UPDATE the CHANGELOG.md file with the version number and date, not just stage the content.

1. **Analyze commits since last tag** to determine the version number:
   - Run: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
   - Suggest version number based on changes using Semantic Versioning:
     - **Major (X.0.0)**: Breaking changes to core functionality or task metadata format
     - **Minor (X.Y.0)**: New features, new parameters, backward-compatible enhancements
     - **Patch (X.Y.Z)**: Bug fixes, documentation updates, minor improvements
   - If unclear, ask the operator what version to use

2. **Get the current date** in ISO format (YYYY-MM-DD)

3. **Update CHANGELOG.md**:
   - Change `## [Unreleased]` header to `## [X.Y.Z] - YYYY-MM-DD`
   - Add a NEW empty `## [Unreleased]` section at the top (after the file header)
   - Update version comparison links at the bottom:
     - Update `[Unreleased]` link to compare from the new version
     - Add a new comparison link for the new version

4. **Verify the changes**:
   - Check that the version header includes the date: `## [X.Y.Z] - YYYY-MM-DD`
   - Check that a new empty `[Unreleased]` section exists at the top
   - Check that version comparison links are updated correctly

5. **Commit the changes** using the report_progress tool

## Example

For a 0.10.0 release on 2026-01-23:

**Before:**
```markdown
## [Unreleased]

### Added
- New feature

[Unreleased]: https://github.com/motowilliams/bolt/compare/v0.9.0...HEAD
```

**After:**
```markdown
## [Unreleased]

## [0.10.0] - 2026-01-23

### Added
- New feature

[Unreleased]: https://github.com/motowilliams/bolt/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/motowilliams/bolt/compare/v0.9.0...v0.10.0
```

## Reference

For complete details, see the "Release Process" section in `.github/copilot-instructions.md`.
