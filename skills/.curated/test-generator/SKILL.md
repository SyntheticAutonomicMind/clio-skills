---
name: "test-generator"
description: "Generate comprehensive tests for code with edge cases and best practices"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations", "code_intelligence"]
---

# Test Generator Skill

## When to Use

- Creating tests for new code
- Adding tests to existing untested code
- Improving test coverage
- Learning testing patterns

## Instructions

When generating tests, follow these principles:

### 1. Analyze the Code

Before writing tests:
- Understand what the code does
- Identify inputs, outputs, and side effects
- Find edge cases and boundary conditions
- Note dependencies that may need mocking

### 2. Test Structure

Use the AAA pattern:
```
Arrange: Set up test data and preconditions
Act: Execute the code under test
Assert: Verify the expected outcome
```

### 3. Categories of Tests

**Happy Path**
- Normal, expected usage
- Valid inputs producing expected outputs

**Edge Cases**
- Empty inputs (null, empty string, empty array)
- Boundary values (0, -1, MAX_INT)
- Single-element collections
- Very large inputs

**Error Cases**
- Invalid inputs
- Network failures (if applicable)
- File not found (if applicable)
- Permission denied

**Integration Points**
- Database interactions
- External API calls
- File system operations

### 4. Best Practices

- One assertion concept per test (can have multiple asserts for same concept)
- Descriptive test names: `test_add_returns_sum_of_two_positive_numbers`
- Independent tests (no shared mutable state)
- Fast execution (mock expensive operations)
- Deterministic (no random/time-dependent behavior)

### 5. Framework Detection

Detect and use the project's existing test framework:
- Python: pytest, unittest
- JavaScript: Jest, Mocha, Vitest
- Perl: Test::More, Test2
- Go: testing package
- Rust: built-in test

### 6. Output Format

```[language]
# Tests for: [filename]

# Happy Path Tests
def test_function_name_with_valid_input():
    ...

# Edge Case Tests  
def test_function_name_with_empty_input():
    ...

# Error Tests
def test_function_name_raises_on_invalid_input():
    ...
```

## Examples

User: "Write tests for this function"
```python
def calculate_discount(price, discount_percent):
    if discount_percent < 0 or discount_percent > 100:
        raise ValueError("Discount must be between 0 and 100")
    return price * (1 - discount_percent / 100)
```

Response:
```python
import pytest

class TestCalculateDiscount:
    # Happy Path
    def test_zero_discount_returns_original_price(self):
        assert calculate_discount(100, 0) == 100

    def test_50_percent_discount_halves_price(self):
        assert calculate_discount(100, 50) == 50

    def test_100_percent_discount_returns_zero(self):
        assert calculate_discount(100, 100) == 0

    # Edge Cases
    def test_handles_decimal_prices(self):
        assert calculate_discount(99.99, 10) == pytest.approx(89.991)

    def test_handles_decimal_discount(self):
        assert calculate_discount(100, 33.33) == pytest.approx(66.67)

    # Error Cases
    def test_raises_on_negative_discount(self):
        with pytest.raises(ValueError, match="must be between"):
            calculate_discount(100, -1)

    def test_raises_on_discount_over_100(self):
        with pytest.raises(ValueError, match="must be between"):
            calculate_discount(100, 101)
```
