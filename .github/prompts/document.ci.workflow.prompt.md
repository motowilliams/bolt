---
agent: agent
---

# CI Workflow Documentation Generator

**Purpose**: Keep `.github/workflows/ci.yml` and `.github/workflows/ci.md` in sync.

## Task

Document the CI process (`.github/workflows/ci.yml`) in a sibling file `.github/workflows/ci.md` so that new users can easily understand the flows and triggers.

## Requirements

The documentation should include:

1. **Overview** - High-level purpose of the CI workflow
2. **Triggers** - When the workflow runs (push, PR, manual)
3. **Platform Strategy** - Which platforms are tested (Ubuntu, Windows, etc.)
4. **Workflow Steps** - Detailed breakdown of each job and step:
   - Setup and dependency installation
   - Test execution stages (Core, Bicep Tasks, Full Suite)
   - Build verification
   - Artifact generation
5. **Exit Codes** - Success/failure handling
6. **Test Organization** - Tags, file locations, dependencies
7. **Build Artifacts** - What gets generated and where
8. **Local Development** - How to run the same checks locally
9. **Performance** - Typical build times per platform
10. **Troubleshooting** - Common issues and solutions
11. **Security** - Security considerations (secrets, permissions, etc.)
12. **Maintenance** - How to update dependencies, add platforms, etc.

## Output Location

Create or update: `.github/workflows/ci.md`

## Style Guidelines

- Use clear, simple language (follow Writing Style guidelines in copilot-instructions.md)
- Include code examples where helpful
- Use tables for structured information (platforms, timings, etc.)
- Add troubleshooting sections for common issues
- Link to related documentation (README.md, CONTRIBUTING.md, etc.)

## Critical Reminder

**This prompt should be run whenever `.github/workflows/ci.yml` is modified** to keep documentation in sync with the actual workflow implementation.
