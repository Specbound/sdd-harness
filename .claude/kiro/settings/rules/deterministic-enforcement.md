# Deterministic Enforcement — Prefer Linters Over Documentation

Conventions that can be mechanically checked should be enforced by linter rules, not just documented in steering or markdown rules. Documentation is probabilistic (a suggestion agents may ignore); linter rules are deterministic (violations block progress).

## Principle

**If a convention can be expressed as a linter rule, the linter rule is the source of truth.** The markdown documentation becomes the rationale — explaining *why* the rule exists — while the linter prevents violations regardless of whether the agent reads the docs.

## When Writing Code

Before implementing, check whether the project has linter complexity rules configured:
- If complexity rules exist: respect them as hard constraints
- If no complexity rules exist: note this as a `[friction][enforceable]` observation

## Recommended Complexity Baselines

These are the minimum complexity guardrails every project should have:

| Ecosystem | Rules | Tool |
|-----------|-------|------|
| JS/TS | `max-lines-per-function: 40`, `complexity: 10`, `max-depth: 3`, `max-params: 4`, `max-statements: 15`, `@sonarjs/cognitive-complexity` | ESLint |
| Python | `max-complexity = 10`, `max-args = 5`, `C901` (McCabe), line length | ruff |
| Rust | `cognitive_complexity` threshold, `too_many_arguments` | clippy |
| Go | `gocyclo` threshold, `funlen` limits | golangci-lint |

All linters should run with **zero-warning tolerance** (`--max-warnings=0` or equivalent).

## Graduation Path

Conventions follow a maturity path from probabilistic to deterministic:

1. **Observation**: A convention violation is noticed and tagged `[friction]`
2. **Pattern**: The violation recurs (3+ observations on the same theme)
3. **Documentation**: The convention is written into steering or a markdown rule
4. **Graduation**: The convention is encoded as a linter rule (deterministic enforcement)
5. **Rationale**: The markdown doc remains as the *why*; the linter is the *what*

The `/kiro:evolve` command identifies graduation candidates. The `/kiro:guardrails` command applies them.

## Relationship to Other Rules

- **steering-principles.md**: Steering documents conventions; this rule says enforceable conventions should also become linter rules
- **quality-gates.md**: Gate 1 (`/kiro:verify`) runs linters; this rule ensures linter configs are comprehensive
- **self-tightening.md**: Formalizes the loop that feeds friction into deterministic enforcement
