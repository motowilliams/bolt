---
agent: agent
---

# Release Workflow Documentation Generator

**Purpose**: Keep `.github/workflows/release.yml` and `.github/workflows/release.md` in sync.

## Task

Document the Release process (`.github/workflows/release.yml`) in a sibling file `.github/workflows/release.md` so that new users can easily understand the release flows and triggers.

## Requirements

The documentation should include:

1. **Overview** - High-level purpose of the release workflow
2. **Triggers** - When the workflow runs (tag push, workflow_dispatch)
3. **Version Detection** - How version is extracted from git tags
4. **Changelog Validation** - How changelog entries are validated against tags
5. **Workflow Steps** - Detailed breakdown of each job and step:
   - Module package building
   - Manifest generation
   - Documentation bundling
   - Archive creation and checksums
   - Release notes extraction
   - GitHub release creation
6. **Pre-release vs Production** - How to tag for pre-releases vs production releases
7. **Release Assets** - What gets published (zip, checksums, etc.)
8. **Local Testing** - How to test the build process locally before releasing
9. **Version Format** - Semantic versioning format and examples
10. **Troubleshooting** - Common issues and solutions
11. **Security** - Security considerations (permissions, tokens, etc.)
12. **Maintenance** - How to update the release process, add new assets, etc.

## Output Location

Create or update: `.github/workflows/release.md`

## Style Guidelines

- Use clear, simple language (follow Writing Style guidelines in copilot-instructions.md)
- Include code examples where helpful
- Use tables for structured information (version formats, asset types, etc.)
- Add troubleshooting sections for common issues
- Link to related documentation (README.md, CHANGELOG.md, etc.)

## Critical Reminder

**This prompt should be run whenever `.github/workflows/release.yml` is modified** to keep documentation in sync with the actual workflow implementation.
