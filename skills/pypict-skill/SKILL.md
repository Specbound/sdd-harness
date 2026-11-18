---
name: pypict-skill
description: Use when a test matrix has too many parameter combinations to test exhaustively — generate a pairwise (all-pairs) combinatorial test set with PICT instead of hand-picking cases or testing every combination.
source: "https://github.com/omkamal/pypict-claude-skill/blob/main/SKILL.md"
risk: unknown
---

# Pypict Skill

## When to Use

- A feature has 4+ independent parameters (browser × OS × user role × plan tier, form fields, config flags) and full combinatorial coverage is impractically large
- You need a defensible "we tested the important combinations" answer without a hand-picked, potentially biased subset
- Skip this for 2-3 parameters with few values each — just enumerate them directly, PICT adds ceremony with no payoff

## Workflow

1. **Install** — `pip install pypict`, or use the Microsoft PICT CLI binary directly if the Python wrapper isn't available for your platform.
2. **Write the model file** (`model.txt`): one parameter per line, `Name: value1, value2, value3`. Example:
   ```
   Browser: Chrome, Firefox, Safari
   OS: Windows, macOS, Linux
   Role: Admin, Member, Guest
   ```
3. **Add constraints** for invalid combinations, using `IF...THEN` clauses appended after the parameter block:
   ```
   IF [OS] = "macOS" THEN [Browser] <> "Edge";
   ```
4. **Weight values** that need more coverage by appending a marker in parentheses after a value: `Chrome(3), Firefox, Safari` biases generation toward Chrome without hand-picking extra Chrome cases.
5. **Generate**:
   - CLI: `pict model.txt > cases.txt` (or `pict model.txt /o:3` for 3-wise instead of the pairwise default)
   - Python: `import pypict; cases = pypict.generate(model_path="model.txt")`
6. **Verify coverage** — the default is 2-way (pairwise): every pair of parameter values appears in at least one generated case, not every combination. Confirm this is the coverage level you need before treating the output as your full test plan; higher-order interaction bugs (3-way+) need `/o:3` or higher, at the cost of more cases.

## Common patterns

| Scenario | Parameters | Notes |
|---|---|---|
| Web UI cross-browser | Browser, OS, viewport, zoom level | Constrain combinations the CI matrix can't actually run (e.g. Safari on Windows) |
| API contract | auth method, content-type, HTTP verb, param presence | Constrain invalid pairs (e.g. GET with a body) rather than filtering after generation |
| Config matrix | feature flags, env, region | Weight the production-like combination higher so it's never dropped from a smaller run |
| Form validation | field length, charset, required/optional | Pair boundary values (empty, max-length, invalid-charset) explicitly rather than relying on random sampling |

## Anti-patterns

- Treating pairwise-generated cases as exhaustive — they guarantee pairwise coverage, not full coverage. State the order (`/o:2`, `/o:3`) when reporting what was tested.
- Skipping constraints and filtering invalid cases after generation — constraints keep the solver from wasting cases on combinations that can't occur, so filtering after the fact under-covers the valid space.
