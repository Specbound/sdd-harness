---
name: adapt-to-repo
description: "Analyze a webpage, blog post, article, or idea and produce an actionable implementation plan tailored to the current repo. Filters out redundancies, identifies enhancements, and only recommends what adds real value. Use when: the user shares a link, article, post, technique, or idea and wants to know how (or whether) to apply it here."
allowed-tools: Read, Glob, Grep, Bash, Agent, WebFetch, WebSearch, TodoWrite
user-invocable: true
argument-hint: "<url, pasted content, or idea>"
risk: safe
---

# Adapt to Repo

Take an external source (webpage, blog post, conference talk summary, idea, technique) and produce a concrete, repo-specific implementation plan — but only for items that genuinely add value. Reject noise. Enhance what exists. Never duplicate.

## When to Use

- User shares a URL, article, or blog post and asks "how can we use this?"
- User describes a technique or pattern and wants to know if it fits
- User pastes content from an external source and wants an adoption plan
- User says "implement this in our repo" or "can we use this?"

## When NOT to Use

- User wants a summary of the article with no repo context (use deep-research or just summarize)
- User is asking about architecture from scratch (use architecture skill)
- The input has nothing to do with the current codebase

---

## Execution Protocol

### Phase 1: Ingest the Source

1. **If the input is a URL**: Fetch it with WebFetch. Extract the core ideas, techniques, patterns, tools, and recommendations. Ignore marketing fluff, author bios, and tangential asides.
2. **If the input is pasted text or a described idea**: Parse it directly. Identify the discrete, actionable items.
3. **Produce a Source Summary** — a bullet list of every concrete technique, pattern, tool, config change, or practice the source recommends. Each bullet should be one atomic item. Label each with a short tag (e.g., `[tool]`, `[pattern]`, `[config]`, `[practice]`, `[architecture]`, `[testing]`, `[CI/CD]`, `[observability]`).

### Phase 2: Map the Repo

Understand what the repo already has. This is the critical step — skip nothing.

1. **Read the project root**: README, CLAUDE.md, AGENTS.md, package.json / pyproject.toml / Cargo.toml / go.mod / etc. Understand the stack, framework, and tooling.
2. **Scan the structure**: Glob for key directories (src/, lib/, tests/, scripts/, .github/, .claude/, config/, docs/). Understand the shape.
3. **Identify existing patterns**: Grep for imports, configs, CI workflows, test frameworks, linters, formatters, and anything the source material touches on. Be specific — if the source recommends "use structured logging," check what logging already exists.
4. **Produce a Repo Snapshot** — a concise summary of:
   - Stack and frameworks
   - Existing tooling and practices relevant to the source material
   - Current gaps or weak spots that the source material could address
   - Any conventions or constraints (from CLAUDE.md, linter configs, CI, etc.)

### Phase 3: Gap Analysis (The Core)

For each item from the Source Summary, classify it into exactly one category:

| Category | Meaning | Action |
|----------|---------|--------|
| **REDUNDANT** | The repo already does this, at equivalent or better quality | Skip. Note what already covers it. |
| **ENHANCE** | The repo has something similar but the source offers a meaningful improvement | Plan the enhancement. Be specific about what changes and why it's better. |
| **NEW & VALUABLE** | The repo lacks this and it would genuinely help | Plan the addition. Explain the concrete benefit. |
| **NEW but NOT USEFUL** | The repo lacks this but it doesn't fit, isn't worth the cost, or solves a problem we don't have | Skip. Briefly explain why it doesn't apply. |

**Rules for classification:**
- Default stance is skeptical. The bar for "valuable" is: would a senior engineer on this project approve the PR?
- "Cool" is not "useful." If it doesn't solve a real problem or reduce real friction, it's NOT USEFUL.
- Enhancement must be more than cosmetic. Renaming things or swapping equivalent tools is not an enhancement.
- Consider maintenance cost. A technique that adds value but requires ongoing upkeep may not be worth it for a small team.
- If unsure, classify as NOT USEFUL and explain the uncertainty. Let the user promote it.

### Phase 4: Implementation Plan

For items classified as **ENHANCE** or **NEW & VALUABLE**, produce a plan:

**For each item:**

```
### [Tag] Item Name

**Category**: ENHANCE | NEW & VALUABLE
**What**: One-sentence description of the change
**Why**: What concrete problem this solves or what measurable improvement it brings
**Where**: Specific files/directories that would be created or modified
**How**:
1. Step-by-step implementation (specific enough to execute)
2. Include file paths, config keys, command examples
3. Note any dependencies or prerequisites
**Effort**: S (< 30 min) | M (1-3 hours) | L (half day+)
**Risk**: Low (isolated change) | Medium (touches shared code) | High (architectural shift)
```

**Order the plan by**: Risk ascending, then Value descending. Safe high-value items first.

### Phase 5: Present Results

Structure the output as:

```
## Source Analysis: [Title or URL]

### What the Source Recommends
[Source Summary from Phase 1]

### Repo Current State (Relevant Areas)
[Repo Snapshot from Phase 2, filtered to only areas the source touches]

### Gap Analysis

#### REDUNDANT (already covered)
- [item]: covered by [existing thing]
- ...

#### NOT USEFUL (doesn't apply)
- [item]: [brief reason]
- ...

#### Implementation Plan

[Phase 4 output — only ENHANCE and NEW & VALUABLE items]

### Summary
- X items analyzed
- Y redundant (already have it)
- Z not applicable
- N actionable items planned
- Estimated total effort: [S/M/L]
```

---

## Anti-Patterns to Avoid

- **Kitchen-sink plans**: Do not recommend everything from the source. Most articles recommend 10 things; maybe 2 matter here.
- **Vague recommendations**: "Consider adopting structured logging" is useless. Specify which library, which files, what format.
- **Ignoring existing work**: If the repo already has a CI pipeline, do not recommend "set up CI." Check what's there first.
- **Tool-chasing**: Do not recommend swapping tools for equivalent tools. Moving from Tool A to Tool B when both work fine is churn, not value.
- **Premature architecture**: Do not recommend architectural patterns for problems that don't exist yet.
- **Copy-paste adoption**: Adapt the ideas to this repo's conventions, stack, and scale. Do not cargo-cult.

## Tool Guidance

- **WebFetch**: For reading URLs. If the page is behind a paywall or returns garbage, ask the user to paste the content.
- **Agent (Explore)**: For deep repo exploration when initial Glob/Grep isn't enough.
- **Grep**: For finding existing implementations of patterns the source recommends.
- **Glob**: For understanding project structure.
- **Read**: For understanding specific files identified during mapping.

## Example Interaction

**User**: Can we use anything from this? https://example.com/blog/10-pytest-best-practices

**Response**:

> ## Source Analysis: 10 Pytest Best Practices
>
> ### What the Source Recommends
> - [testing] Use `conftest.py` for shared fixtures
> - [testing] Use `pytest-xdist` for parallel test execution
> - [testing] Use `pytest.mark.parametrize` for data-driven tests
> - [config] Configure pytest in `pyproject.toml` instead of `pytest.ini`
> - [practice] Use `tmp_path` fixture instead of `tempfile`
> - ... (remaining items)
>
> ### Gap Analysis
>
> #### REDUNDANT
> - `conftest.py` for shared fixtures: already using this pattern in `tests/conftest.py`
> - pytest config in `pyproject.toml`: already configured there (line 42)
>
> #### NOT USEFUL
> - `pytest-xdist` parallel execution: test suite runs in 8 seconds, parallelization overhead would negate gains
>
> #### Implementation Plan
>
> ### [testing] Add parametrized tests for validation functions
> **Category**: ENHANCE
> **What**: Replace 12 near-identical test functions with parametrized equivalents
> **Why**: Reduces test code by ~60 lines, makes adding new test cases trivial
> **Where**: `tests/test_validators.py`
> **How**:
> 1. Identify repetitive test functions in `tests/test_validators.py` (lines 45-120)
> 2. Group by the function under test
> 3. Convert each group to `@pytest.mark.parametrize` with a list of (input, expected) tuples
> **Effort**: S
> **Risk**: Low
