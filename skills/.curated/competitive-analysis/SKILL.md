---
name: "competitive-analysis"
description: "Deep comparative analysis between a base product and reference products"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations", "terminal_operations", "web_operations", "code_intelligence"]
note: "Use when evaluating external software against the product in the current working directory"
---

# Competitive Analysis Skill

## When to Use

- Evaluating an external tool, library, or product against the base product
- Comparing feature sets between two codebases
- Determining which features from a reference product could enhance the base product
- Performing technology due diligence on potential integrations
- Assessing whether to adopt, adapt, or ignore external approaches

## Instructions

Follow the five phases below in order. The most critical rule: **assume nothing about either product's capabilities** - trace the actual code paths before concluding either product lacks or has a feature.

### Terminology

- **Base product**: The product in the current working directory (the one being potentially enhanced)
- **Reference product**: The external product being evaluated (may be a local repo, URL, or remote git repo)

---

## Phase 1: Locate and Map the Reference Product

### Step 1: Obtain the Source

- Check for local copies first (e.g., `reference/` directory, sibling directories)
- If not local, clone or fetch from git/web as needed
- Read the README for high-level orientation only - **do not trust marketing claims**

### Step 2: Map the Architecture

Read the actual source code, not just documentation:

```
Priority reading order:
1. Entry point / main executable
2. Core orchestration logic (how does it coordinate work?)
3. Worker/agent/plugin implementation (what does each unit actually do?)
4. Communication layer (how do components talk to each other?)
5. Error handling / recovery (what happens when things fail?)
6. Configuration / extensibility (how flexible is it?)
```

### Step 3: Catalog Actual Capabilities

For each feature you identify, document:
- **What it does** (concrete behavior, not marketing)
- **How it works** (actual implementation approach)
- **Approximate size** (lines of code - rough effort indicator)
- **Dependencies** (what external libraries/services it requires)
- **Limitations** (what it can't do, edge cases it doesn't handle)

---

## Phase 2: Deep Investigation of the Base Product

### Why This Phase Is Critical

This is where most comparative analyses fail. It's easy to read module names and assume you understand what a product does. You MUST trace actual execution paths.

### Step 1: Build an Architecture Map

Before comparing features, understand the base product's structure:

```
For each major directory/module area:
1. What is its purpose?
2. How many files/lines of code?
3. What are the key modules and their responsibilities?
4. How do they interact with other parts of the system?
```

Use code intelligence tools to trace call chains, not just read file headers.

### Step 2: Trace Key Execution Paths

For each feature area that will be compared, trace the **actual code path**:

- Don't just read the module that sounds related - follow the execution flow
- Check for error handling, retry logic, fallback behavior (often hidden in deep code)
- Look for configuration that enables/disables features
- Check for multi-layered implementations where behavior spans several modules

### Step 3: Document Hidden Capabilities

Many mature products have capabilities buried in implementation details:
- Error recovery logic that's more sophisticated than it appears
- Adaptive behavior triggered by runtime conditions
- Integration points that enable features not obvious from module names
- Fallback chains that provide resilience

**Rule:** If you're about to write "the base product lacks X", first search the entire codebase for keywords related to X. Grep for the concept, not just the feature name.

---

## Phase 3: Comparative Analysis

### Side-by-Side Feature Matrix

For each feature area, create a comparison:

```markdown
| Feature | Base Product | Reference Product | Winner | Notes |
|---------|-------------|-------------------|--------|-------|
| Feature A | [How base does it] | [How reference does it] | Base/Ref/Tie | [Why] |
```

### Categories to Compare

Adapt these to the specific products, but common categories include:

1. **Core capability** - What is each product's primary function and how well does it do it?
2. **Error recovery** - What happens when things go wrong?
3. **Scalability** - How does it handle increased load/complexity?
4. **Extensibility** - How easy is it to add new capabilities?
5. **Integration** - How does it connect with external systems?
6. **User experience** - How does the user interact?
7. **Performance** - Speed, resource usage, efficiency
8. **Configuration** - How flexible and customizable is it?
9. **Persistence** - How is state/data retained?
10. **Testing/Verification** - How is correctness ensured?

### Honest Assessment Rules

- **Don't inflate the base product** - Be honest about what it can't do
- **Don't dismiss the reference product** - If they have something genuinely better, say so
- **Consider the usage context** - A feature designed for one paradigm may be irrelevant in another
- **Measure complexity vs. value** - Would adopting a feature add proportional value?
- **Distinguish architecture from features** - Different architectures make different features natural or unnatural

---

## Phase 4: Value Assessment

### For Each Potential Feature Adoption, Answer:

**1. What real scenario would this improve?**
- Write out the concrete before (current behavior) and after (with feature)
- If the "before" already works well, the feature may not be worth the complexity
- Be specific - "it would be better" is not an answer

**2. Does the base product's design philosophy make this unnecessary?**
- Different products make different tradeoffs
- A feature critical for batch processing may be irrelevant for interactive use
- A feature needed at scale may not matter at current usage levels
- Sometimes the base product handles the same problem differently (and possibly better)

**3. What's the complexity cost?**
- Estimated lines of new code
- Integration points with existing modules
- Testing burden
- Maintenance burden
- Risk of regressions in existing functionality
- Dependencies introduced

**4. Could the base product already handle this differently?**
- Sometimes the existing architecture handles the same problem through a different mechanism
- Formalizing what already works ad-hoc may add complexity without improving outcomes
- Check if the feature gap is a real gap or a different-approach gap

### Decision Framework

| Question | If Yes | If No |
|----------|--------|-------|
| Does it solve a problem the base product currently can't handle? | Strong candidate | Weak candidate |
| Is the improvement worth the implementation complexity? | Proceed carefully | Skip or simplify |
| Does it align with the base product's design philosophy? | Good fit | Likely poor fit |
| Would it benefit the common use case (not just edge cases)? | Relevant | Low priority |
| Does the base product already handle this through other means? | Probably skip | Good candidate |

---

## Phase 5: Report

### Required Output Sections

1. **Executive Summary** - 2-3 sentences on the bottom line
2. **Architecture Comparison** - How the two systems work differently at a fundamental level
3. **What the Base Product Already Has** - Corrected understanding of existing capabilities (this prevents false gap identification)
4. **Genuine Gaps** - Features the base product actually lacks (with evidence from code tracing)
5. **Value Assessment** - For each gap: concrete scenario, complexity cost, recommendation
6. **What NOT to Copy** - Features that don't fit the base product's paradigm (with reasoning)
7. **Honest Comparison Table** - Side-by-side with winner per category and justification

### Output Location

Write the full analysis to `scratch/` (gitignored working directory):
```
scratch/[REFERENCE_PRODUCT]_ANALYSIS.md
```

### Findings Format

For each feature comparison, use this structure:

```
Feature: [Feature name]
Reference: [How the reference product implements it]
Base: [How the base product handles this area - after deep code tracing]
Gap: Yes/No - [If yes, what exactly is missing]
Value: HIGH/MEDIUM/LOW - [Why]
Complexity: HIGH/MEDIUM/LOW - [Estimated effort and risk]
Recommendation: [Implement / Skip / Revisit when X]
```

---

## Key Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong | What to Do Instead |
|-------------|---------------|-------------------|
| **Surface-level comparison** | Misses hidden capabilities in both products | Trace actual execution paths |
| **README-to-README matching** | Marketing != implementation | Read source code |
| **Feature-list checking** | Doesn't capture quality of implementation | Compare how things actually work |
| **Assuming gaps exist** | The base product may handle it differently | Search and trace before concluding |
| **Complexity blindness** | Recommending features without counting the cost | Always estimate effort and risk |
| **Paradigm mismatch** | Applying batch-mode features to interactive products (or vice versa) | Consider whether the feature fits the design |
| **Recency bias** | Assuming newer = better | Judge by implementation quality, not age |
| **Scale projection** | Assuming current-scale features matter at different scale | Assess for actual usage patterns |

---

## Examples

### Example: User says "Compare reference/tool-xyz against this project"

**Phase 1:** Read reference/tool-xyz source (not README). Map architecture. Catalog features.
**Phase 2:** Deeply trace the base product's code for each feature area. Document hidden capabilities.
**Phase 3:** Build honest comparison matrix across relevant categories.
**Phase 4:** For each gap, assess: real scenario? design philosophy fit? complexity? already handled?
**Phase 5:** Write analysis to scratch/TOOL_XYZ_ANALYSIS.md. Present findings to user.

### Example: User says "Should we adopt X's approach to error handling?"

1. Read X's error handling code (not docs)
2. Trace the base product's error handling - all layers, not just the obvious ones
3. Compare: is X's approach actually better, or just different?
4. If better: what would it take to adopt? Is the value worth the complexity?
5. If different but equivalent: explain why copying would add complexity without improvement
