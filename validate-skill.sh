#!/bin/bash
# Validate a skill directory structure and content
# Exit codes:
#   0 = PASSED - Ready for human/AI review
#   1 = NEEDS CHANGES - Fixable issues (missing fields, format problems)
#   2 = REJECTED - Critical failures (security issues, missing required files)

SKILL_DIR="$1"

if [ -z "$SKILL_DIR" ]; then
    echo "Usage: $0 <skill-directory>"
    exit 1
fi

if [ ! -d "$SKILL_DIR" ]; then
    echo "ERROR: Directory not found: $SKILL_DIR"
    exit 1
fi

# Validation counters
CRITICAL_ERRORS=0  # Security issues, missing required files -> exit 2
FIXABLE_ERRORS=0   # Format issues, missing optional sections -> exit 1
WARNINGS=0         # Advisory only, doesn't block

echo "Validating skill: $SKILL_DIR"
echo "================================"

# ============================================================================
# CRITICAL CHECKS (will cause auto-reject)
# ============================================================================

echo ""
echo "CRITICAL CHECKS (Auto-Reject Failures)"
echo "---------------------------------------"

# Check for required files
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
    echo "[FAIL] Missing SKILL.md (CRITICAL)"
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
else
    echo "[OK] SKILL.md exists"
fi

if [ ! -f "$SKILL_DIR/LICENSE.txt" ]; then
    echo "[FAIL] Missing LICENSE.txt (CRITICAL)"
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
else
    echo "[OK] LICENSE.txt exists"
fi

# Security checks (only if SKILL.md exists)
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    # Prompt injection patterns
    if grep -qiE "ignore (previous|prior|earlier) (instructions?|prompts?|commands?)" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Security: Prompt injection detected - 'ignore previous instructions' (CRITICAL)"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
    
    if grep -qiE "(output|show|print|display).*(system prompt|system message|original prompt)" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Security: Prompt leak attempt detected (CRITICAL)"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
    
    if grep -qiE "disregard (previous|all|any)" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Security: Prompt injection detected - 'disregard' (CRITICAL)"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
    
    # Dangerous shell commands
    if grep -qE "sudo\s+rm\s+-rf|rm\s+-rf\s+/|:\(\)\{.*\}|eval\s+\\\$|curl.*\|\s*bash" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Security: Dangerous shell commands detected (CRITICAL)"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
    
    # Hardcoded credentials patterns
    if grep -qE "(password|api_key|secret|token)\s*=\s*['\"]?[a-zA-Z0-9_-]{20}" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Security: Possible hardcoded credentials detected (CRITICAL)"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
    
    # Executable code in skill files
    if head -1 "$SKILL_DIR/SKILL.md" | grep -q "^#!"; then
        echo "[FAIL] Security: Skill file has shebang (executable code not allowed) (CRITICAL)"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    fi
    
    if [ $CRITICAL_ERRORS -eq 0 ]; then
        echo "[OK] No security issues detected"
    fi
fi

# ============================================================================
# STRUCTURAL CHECKS (will request changes)
# ============================================================================

echo ""
echo "STRUCTURAL CHECKS (Fixable Issues)"
echo "-----------------------------------"

if [ -f "$SKILL_DIR/SKILL.md" ]; then
    # Check frontmatter exists
    if ! grep -q "^---" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] SKILL.md missing YAML frontmatter delimiters (---)"
        FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
    else
        echo "[OK] Frontmatter delimiters present"
        
        # Extract frontmatter (between first two ---)
        FRONTMATTER=$(awk '/^---/{if(++count==2)exit;next}count==1' "$SKILL_DIR/SKILL.md")
        
        # Check required fields
        if ! echo "$FRONTMATTER" | grep -q "^name:"; then
            echo "[FAIL] Missing required field: 'name:'"
            FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
        else
            echo "[OK] Field 'name:' present"
            
            # Validate name matches directory
            SKILL_NAME=$(echo "$FRONTMATTER" | grep "^name:" | sed 's/^name:\s*//' | tr -d '"' | tr -d "'" | xargs)
            DIR_NAME=$(basename "$SKILL_DIR")
            if [ "$SKILL_NAME" != "$DIR_NAME" ]; then
                echo "[FAIL] Name mismatch: frontmatter='$SKILL_NAME', directory='$DIR_NAME'"
                FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
            else
                echo "[OK] Name matches directory"
            fi
        fi
        
        if ! echo "$FRONTMATTER" | grep -q "^description:"; then
            echo "[FAIL] Missing required field: 'description:'"
            FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
        else
            echo "[OK] Field 'description:' present"
        fi
        
        if ! echo "$FRONTMATTER" | grep -q "^version:"; then
            echo "[FAIL] Missing required field: 'version:'"
            FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
        else
            echo "[OK] Field 'version:' present"
            
            # Validate semantic versioning
            VERSION=$(echo "$FRONTMATTER" | grep "^version:" | sed 's/^version:\s*//' | tr -d '"' | tr -d "'" | xargs)
            if ! echo "$VERSION" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+"; then
                echo "[FAIL] Invalid version format: '$VERSION' (expected semver: X.Y.Z)"
                FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
            else
                echo "[OK] Version format valid"
            fi
        fi
        
        if ! echo "$FRONTMATTER" | grep -q "^author:"; then
            echo "[FAIL] Missing required field: 'author:'"
            FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
        else
            echo "[OK] Field 'author:' present"
        fi
    fi
    
    # Check for required sections (case-insensitive headers)
    if ! grep -qiE "^##?\s+(When to Use|Usage|Use Cases)" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Missing 'When to Use' section"
        FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
    else
        echo "[OK] 'When to Use' section present"
    fi
    
    # For instructions, be flexible - look for instructional content sections
    # Accept "Instructions", "Guidelines", "Standards", or other operational headers
    if ! grep -qiE "^##?\s+(Instructions?|Guidelines?|Standards?|Development|Overview)" "$SKILL_DIR/SKILL.md"; then
        echo "[FAIL] Missing instructional content sections"
        FIXABLE_ERRORS=$((FIXABLE_ERRORS + 1))
    else
        echo "[OK] Instructional content sections present"
    fi
fi

# ============================================================================
# QUALITY CHECKS (warnings only, don't block)
# ============================================================================

echo ""
echo "QUALITY CHECKS (Advisory Warnings)"
echo "-----------------------------------"

if [ -f "$SKILL_DIR/SKILL.md" ]; then
    # Check for examples
    if ! grep -qiE "^##?\s+Examples?" "$SKILL_DIR/SKILL.md"; then
        echo "[WARN] No 'Examples' section found (recommended)"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "[OK] 'Examples' section present"
    fi
    
    # Check file size (too short might be incomplete)
    LINES=$(wc -l < "$SKILL_DIR/SKILL.md")
    if [ "$LINES" -lt 30 ]; then
        echo "[WARN] SKILL.md is very short ($LINES lines) - might be incomplete"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "[OK] SKILL.md has adequate content ($LINES lines)"
    fi
fi

# Check LICENSE.txt content
if [ -f "$SKILL_DIR/LICENSE.txt" ]; then
    if ! grep -q "Copyright\|LICENSE\|Permission" "$SKILL_DIR/LICENSE.txt"; then
        echo "[WARN] LICENSE.txt exists but doesn't look like a valid license"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "[OK] LICENSE.txt appears valid"
    fi
fi

# ============================================================================
# SUMMARY AND EXIT
# ============================================================================

echo ""
echo "================================"
echo "VALIDATION SUMMARY"
echo "================================"
echo "Critical Errors: $CRITICAL_ERRORS (security/missing files)"
echo "Fixable Errors:  $FIXABLE_ERRORS (format/structure)"
echo "Warnings:        $WARNINGS (advisory only)"
echo ""

if [ $CRITICAL_ERRORS -gt 0 ]; then
    echo "RESULT: REJECTED ❌"
    echo "Status: Auto-rejected due to critical failures"
    echo "Action: Fix critical issues before resubmitting"
    exit 2
elif [ $FIXABLE_ERRORS -gt 0 ]; then
    echo "RESULT: NEEDS CHANGES ⚠️"
    echo "Status: Validation failed with fixable issues"
    echo "Action: Fix structural/format errors and resubmit"
    exit 1
else
    echo "RESULT: PASSED ✅"
    if [ $WARNINGS -gt 0 ]; then
        echo "Status: Ready for review (with $WARNINGS advisory warnings)"
    else
        echo "Status: Ready for review"
    fi
    echo "Action: Approved for human/AI review"
    exit 0
fi
