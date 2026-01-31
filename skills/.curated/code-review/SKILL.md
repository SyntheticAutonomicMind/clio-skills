---
name: "code-review"
description: "Comprehensive code review focusing on bugs, security, and best practices"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations", "code_intelligence"]
---

# Code Review Skill

## When to Use

- Reviewing pull requests before merge
- Auditing existing code for issues
- Learning from code patterns (good and bad)
- Preparing code for production deployment

## Instructions

When performing a code review, follow this structured approach:

### 1. Understand Context
- Read the entire file/diff to understand the change
- Check related files if the change affects them
- Look at commit messages for intent

### 2. Review Categories

Check for issues in this order:

**Critical (Must Fix)**
- Security vulnerabilities (injection, XSS, CSRF, etc.)
- Data leaks (credentials, PII exposure)
- Race conditions and concurrency bugs
- Unhandled errors that could crash the system

**High Priority**
- Logic errors that cause incorrect behavior
- Missing input validation
- Resource leaks (memory, file handles, connections)
- Breaking API changes without deprecation

**Medium Priority**
- Performance issues (N+1 queries, unnecessary loops)
- Missing error handling (non-critical paths)
- Code that's hard to test
- Inconsistent patterns

**Low Priority (Suggestions)**
- Style inconsistencies
- Naming improvements
- Opportunities for abstraction
- Documentation gaps

### 3. Output Format

Present findings clearly:

```markdown
## Code Review: [filename]

### Critical Issues
- **Line X**: [Issue] - [Why it's critical] - [Suggested fix]

### High Priority
- **Line X**: [Issue] - [Explanation]

### Suggestions
- [General improvement idea]

### Positive Notes
- [What's done well]
```

### 4. Behavior Guidelines

- Be constructive, not critical
- Explain WHY something is an issue
- Provide concrete fix suggestions
- Acknowledge good patterns
- Don't nitpick unless asked to

## Examples

User: "Review this authentication code"

Good response:
```markdown
## Code Review: auth/login.py

### Critical Issues
- **Line 23**: SQL injection vulnerability - User input is concatenated directly into query
  ```python
  # Current (vulnerable)
  query = f"SELECT * FROM users WHERE email = '{email}'"
  
  # Fixed (parameterized)
  query = "SELECT * FROM users WHERE email = ?"
  cursor.execute(query, (email,))
  ```

### High Priority
- **Line 45**: Password compared with `==` - Use constant-time comparison to prevent timing attacks
  ```python
  # Use: secrets.compare_digest(hash1, hash2)
  ```

### Positive Notes
- Good use of bcrypt for password hashing
- Clean separation of concerns with the UserService class
```
