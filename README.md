# CLIO Skills

A curated collection of skills for CLIO (Command Line Intelligence Orchestrator).

## What are Skills?

Skills are prompt templates that give CLIO specialized knowledge and behavior for specific tasks. They're like "modes" that help the AI assistant excel at particular types of work.

## Skill Categories

### `.curated/`
Reviewed and approved skills for general use. These have been tested for quality and safety.

### `.experimental/`
Community-contributed skills that haven't been fully reviewed. Use with appropriate caution.

## Installing Skills

CLIO can download and install skills from this repository:

```bash
# List available skills
/skills search

# Download and install a skill
/skills install <skill-name>

# Or from experimental
/skills install <skill-name> --experimental
```

## Creating Skills

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on creating and submitting skills.

### Skill Structure

Each skill is a directory containing:

```
skill-name/
├── SKILL.md        # Required: Skill definition and instructions
├── LICENSE.txt     # Required: License (MIT recommended)
├── agents/         # Optional: Agent configurations
├── scripts/        # Optional: Helper scripts
└── assets/         # Optional: Templates, examples, etc.
```

### SKILL.md Format

```markdown
---
name: "skill-name"
description: "Brief description (shown in /skills list)"
version: "1.0.0"
author: "Your Name"
tools: ["file_operations", "terminal_operations"]  # Optional: Tools this skill uses
---

# Skill Name

## When to Use
- Scenario 1
- Scenario 2

## Instructions
Detailed instructions for the AI to follow...

## Examples
Example usage patterns...
```

## Security

All curated skills are reviewed for:
- Prompt injection risks
- Sensitive data handling
- Tool usage safety
- Code execution patterns

**Never run skills from untrusted sources.**

## License

Individual skills contain their own LICENSE.txt files. The repository structure is MIT licensed.
