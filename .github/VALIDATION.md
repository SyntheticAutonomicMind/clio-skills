# PR Validation Workflow

This repository uses automated validation to ensure skill quality and security.

## How It Works

When you submit a pull request that changes files in `skills/`, the validation workflow automatically runs and provides one of three outcomes:

### [OK] PASSED - Ready for Review
- All structural checks passed
- No security issues detected
- PR is ready for human/AI review
- **Action:** Maintainer will review skill content and quality

### [WARN]️  NEEDS CHANGES - Fixable Issues
- Structural or formatting problems found
- Examples: missing frontmatter fields, invalid version format, missing sections
- **Action:** Fix the identified issues and push updates
- Validation will run again automatically

### [FAIL] REJECTED - Critical Failures
- Security vulnerabilities detected
- Missing required files
- **Action:** Address critical issues immediately before re-submitting
- Cannot be merged until resolved

## Validation Criteria

### Critical (Auto-Reject)
- ❌ Missing `SKILL.md` or `LICENSE.txt`
- ❌ Security issues (prompt injection, dangerous commands)
- ❌ Hardcoded credentials
- ❌ Executable code in skill files

### Structural (Needs Changes)
- ⚠️  Missing YAML frontmatter
- ⚠️  Missing required fields: `name`, `description`, `version`, `author`
- ⚠️  Name mismatch (directory vs frontmatter)
- ⚠️  Invalid semantic version format
- ⚠️  Missing "When to Use" or "Instructions" sections

### Quality (Advisory Warnings)
- ℹ️  No examples section
- ℹ️  Very short skill content
- ℹ️  LICENSE.txt doesn't look like a valid license

## Testing Locally

Before submitting your PR, run the validator locally:

```bash
./validate-skill.sh skills/.experimental/your-skill
```

This will show you exactly what the automated workflow will check.

## Understanding Exit Codes

The `validate-skill.sh` script uses three exit codes:

- **Exit 0** = Passed (ready for review)
- **Exit 1** = Needs changes (fixable issues)
- **Exit 2** = Rejected (critical failures)

The GitHub Actions workflow interprets these codes to:
- Add appropriate labels (`validation-passed`, `needs-fixes`, `security-issue`)
- Post detailed comments with validation logs
- Set the PR status (pass/fail)

## Labels

| Label | Meaning |
|-------|---------|
| `validation-passed` | All automated checks passed |
| `needs-fixes` | Validation found issues to fix |
| `security-issue` | Critical security problem detected |

## Common Issues & Fixes

### Missing frontmatter
```yaml
---
name: "your-skill"
description: "Brief description"
version: "1.0.0"
author: "Your Name"
---
```

### Invalid version
Use semantic versioning: `1.0.0`, `2.1.3`, etc.

### Name mismatch
Directory name must match the `name:` field in frontmatter.

### Missing sections
Every skill needs:
- `## When to Use`
- `## Instructions`
- `## Examples` (recommended)

## Questions?

See [CONTRIBUTING.md](../CONTRIBUTING.md) for full contribution guidelines.
