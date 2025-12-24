---
agent: agent
---

Analyze the commits since the last tag and update the CHANGELOG.md document with the relevant information. Create a new release branch that once merged will be tagged with this next version. We are using SemVer so suggest a new version number based on the diff from the last tag. If it is not clear ask the operator what to use.
