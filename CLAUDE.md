# {{PROJECT_NAME}}

## Context Resources (read on demand, not upfront)
- `.claude/memory/hot-memory.md` — read at session start (current state, priorities)
- `.claude/memory/meta/patterns.md` — read at session start (workflow patterns)
- `.claude/steering/` — read when you need project architecture, stack, or code structure context
- `.claude/memory/` — read when you need cross-session context or past decisions
- `specs/` — read when working on or near a feature that has a spec
- `.claude/docs/SDD-USAGE.md` — read when you need SDD command reference

## Rules
- Always plan before coding — use Plan mode for back-and-forth
- Every feature needs an approved spec in `specs/` before implementation
- Atomic commits per task (one task = one commit, code only)
- Never skip the human review gate between spec phases
- Never commit SDD files — harness is local only

## Quality Gates (automated)
- `ruff check`: on every `.py` file write
- `pytest -x --ignore=tests/integration`: after each impl task
- doc sync: automatically on every `git commit` via post-commit hook

## Test Output Convention
- When running tests, capture output to a temp file
- Only read the output if the exit code is non-zero
- Do not paste passing test output into conversation context
