#!/bin/bash
# Validate a skill directory structure and content

SKILL_DIR="$1"

if [ -z "$SKILL_DIR" ]; then
    echo "Usage: $0 <skill-directory>"
    exit 1
fi

if [ ! -d "$SKILL_DIR" ]; then
    echo "ERROR: Directory not found: $SKILL_DIR"
    exit 1
fi

ERRORS=0

echo "Validating skill: $SKILL_DIR"
echo "================================"

# Check for required files
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
    echo "[FAIL] Missing SKILL.md"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] SKILL.md exists"
fi

if [ ! -f "$SKILL_DIR/LICENSE.txt" ]; then
    echo "[FAIL] Missing LICENSE.txt"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] LICENSE.txt exists"
fi

# Check SKILL.md frontmatter
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    if ! grep -q "^---" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] SKILL.md missing frontmatter (---)"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] Frontmatter present"
    fi
    
    if ! grep -q "^name:" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] SKILL.md missing 'name:' in frontmatter"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] name: present"
    fi
    
    if ! grep -q "^description:" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] SKILL.md missing 'description:' in frontmatter"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] description: present"
    fi
    
    # Check for red flags
    if grep -qi "ignore previous" "$SKILL_DIR/SKILL.md"; then
        echo "[WARN] Potential prompt injection: 'ignore previous'"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -qi "output.*system prompt" "$SKILL_DIR/SKILL.md"; then
        echo "[WARN] Potential prompt injection: 'output system prompt'"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -qi "sudo\|rm -rf" "$SKILL_DIR/SKILL.md"; then
        echo "[WARN] Dangerous shell commands detected"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo "Validation PASSED"
    exit 0
else
    echo "Validation FAILED with $ERRORS errors"
    exit 1
fi
