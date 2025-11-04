# No Hallucinations Policy

**CRITICAL POLICY: ZERO TOLERANCE FOR FICTIONAL INFORMATION**

This policy applies to all AI agents, documentation updates, and content generation for the Gosh project.

## Core Principle

**Never create, reference, or document anything that doesn't actually exist.**

## Strict Prohibitions

### URLs and Endpoints
- ❌ **NEVER** create fictional URLs (e.g., `/security/advisories/new`)
- ❌ **NEVER** reference non-existent GitHub endpoints
- ❌ **NEVER** make up API endpoints or documentation URLs
- ❌ **NEVER** invent contact information or support channels

### Code Features and Functions
- ❌ **NEVER** document functions that don't exist in the codebase
- ❌ **NEVER** reference parameters that aren't implemented
- ❌ **NEVER** describe features that aren't built
- ❌ **NEVER** invent configuration options

### File Paths and Structure
- ❌ **NEVER** reference files that don't exist
- ❌ **NEVER** create fictional directory structures
- ❌ **NEVER** document non-existent scripts or tools

## Required Verification Process

Before documenting or referencing ANYTHING:

1. **URLs**: Use tools to verify they exist or are standard patterns
2. **Features**: Use available search tools (e.g., `bash` with `grep`) to confirm implementation
3. **Files**: Use available file tools (e.g., `view`, `bash` with `ls` or `find`) to verify existence
4. **Contact Info**: Verify the target actually accepts the intended type of communication

## Examples of Past Violations

These specific examples must NEVER be repeated:

- `https://github.com/motowilliams/gosh/security/advisories/new` ❌
- `https://github.com/motowilliams/gosh/security/advisories` ❌
- Documenting features before verifying they exist ❌
- Creating contact URLs without checking validity ❌

## Correct Approach

### When Uncertain
- **SAY**: "I need to verify this exists before documenting it"
- **DO**: Use available tools to check
- **ASK**: User for clarification if verification isn't possible

### When Documenting
- **ALWAYS**: Use tools to verify information first
- **REFERENCE**: Only actual, existing code/files/URLs
- **CONFIRM**: Features exist before documenting them

### When Creating Contact Information
- **USE**: Only verified, working contact methods
- **PREFER**: Established channels like GitHub issues
- **AVOID**: Specialized endpoints unless confirmed to exist

## Implementation Guidelines

### For AI Agents
1. Read this policy before every documentation task
2. Use verification tools liberally
3. When in doubt, ask or state uncertainty
4. Remember: accuracy is more important than completeness

### For Humans
1. Review all AI-generated content for fictional elements
2. Verify URLs and references before approving changes
3. Report violations to improve the system
4. Maintain this policy as the codebase evolves

## Enforcement

- **All documentation updates** must follow this policy
- **All URL references** must be verified
- **All feature documentation** must reference actual implementation
- **Violations** must be corrected immediately

## Remember

**It's better to say "I need to verify this" than to provide incorrect information.**

Accuracy and truthfulness are non-negotiable requirements for this project.