---
name: "documentation"
description: "Generate clear, comprehensive documentation for code and APIs"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations", "code_intelligence"]
---

# Documentation Skill

## When to Use

- Documenting new code or APIs
- Improving existing documentation
- Creating README files
- Writing inline code comments
- Generating API references

## Instructions

### 1. Understand the Audience

Before writing:
- Who will read this? (developers, users, ops?)
- What's their skill level?
- What do they need to accomplish?

### 2. Documentation Types

**Code Comments**
- Explain WHY, not WHAT (the code shows what)
- Document non-obvious decisions
- Mark TODOs with context

**Function/Method Docs**
- Purpose: What does it do?
- Parameters: Type, description, constraints
- Returns: Type, description
- Raises/Throws: What errors and when
- Example: Show typical usage

**README Files**
- Project purpose (what problem it solves)
- Quick start (get running in <5 min)
- Installation (dependencies, platforms)
- Usage examples (common scenarios)
- Configuration options
- Contributing guidelines

**API Documentation**
- Endpoint: method, path, description
- Request: headers, parameters, body schema
- Response: status codes, body schema
- Examples: curl commands, response samples
- Errors: common error codes and causes

### 3. Writing Guidelines

- Use active voice ("Returns the sum" not "The sum is returned")
- Be concise but complete
- Include examples for complex features
- Use consistent terminology
- Format code samples properly
- Keep up-to-date with code changes

### 4. Format Templates

**Function Documentation (Python/docstring style)**
```python
def function_name(param1: Type, param2: Type) -> ReturnType:
    """Brief one-line description.
    
    Longer description if needed, explaining the purpose
    and any important details about the function's behavior.
    
    Args:
        param1: Description of first parameter.
        param2: Description of second parameter.
    
    Returns:
        Description of what is returned.
    
    Raises:
        ValueError: When input is invalid.
        ConnectionError: When network is unavailable.
    
    Example:
        >>> result = function_name("input", 42)
        >>> print(result)
        "expected output"
    """
```

**README Structure**
```markdown
# Project Name

Brief description (1-2 sentences).

## Quick Start

\`\`\`bash
# Minimal steps to run
\`\`\`

## Installation

Prerequisites and installation steps.

## Usage

### Basic Example
\`\`\`python
# Code example
\`\`\`

### Advanced Features
Description of advanced usage.

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `opt1` | str  | "value" | What it does |

## API Reference

Link to detailed API docs.

## Contributing

How to contribute.

## License

License information.
```

## Examples

User: "Document this class"

Good response includes:
- Class purpose
- Constructor parameters
- Method documentation
- Usage example
- Any important warnings or notes
