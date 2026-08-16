# sdd-harness

## Address
- Always call the user "Husband" in every reply — no exceptions.
- If you stop doing this, it signals CLAUDE.md is being ignored; a Stop hook will automatically prompt you to /compact and re-read CLAUDE.md.

## Context Resources (read on demand, not upfront)
- `.claude/memory/hot-memory.md` — read at session start (current state, priorities)
- `.claude/memory/meta/patterns.md` — read at session start (workflow patterns)
- `.claude/steering/` — read when you need project architecture, stack, or code structure context
- `.claude/memory/` — read when you need cross-session context or past decisions
- `specs/` — read when working on or near a feature that has a spec
- `.claude/behaviors/` — read when reviewing agent conduct or grading a trace, not upfront; kept blind from the agent whose trajectory it grades
- `.claude/docs/SDD-USAGE.md` — read when you need SDD command reference
- `ERRORS.md` — check before suggesting solutions to problems; log approaches that took 2+ attempts

## Rules
- Always plan before coding — use Plan mode for back-and-forth
- Every feature needs an approved spec in `specs/` before implementation
- Atomic commits per task (one task = one commit, code only)
- Never skip the human review gate between spec phases
- Never commit installed harness output — `.claude/` and `specs/` are local (see `.gitignore`). In this repo the top-level source tree (`agents/ commands/ hooks/ kiro/ scripts/ docs/ rules/ skills/ templates/`) IS the product and is committed normally
- Before any significant task, show 2-3 approaches and wait for confirmation before proceeding
- Maintain `ERRORS.md`: when an approach takes 2+ attempts, log what failed, what worked, and why

## AI-Legible Code
- **Blast radius**: prefer changes that touch ≤1 folder/module; if >1, scope down first
- **Rule of Three**: no shared extraction until 3 real call sites exist — two similar = coincidence
- **Vertical slices**: feature = one folder (routes/logic/data/types/tests); no cross-feature imports; no `shared/`, `utils/`, `common/`
- **Fail fast**: validate at every public boundary; named exceptions; no bare `except`; no silent fallbacks
- **Context rot**: AI coherence degrades past ~300k tokens — keep functions and PRs small
- **Reviewer model mismatch**: use a separate session/model to review AI-generated code

## Quality Gates (automated)
- `ruff check`: on every `.py` file write
- `pytest -x --ignore=tests/integration`: after each impl task, in projects that have a test suite — this repo has none; shell work is verified by `*.test.sh` scripts and throwaway-tree runs
- doc sync: automatically on every `git commit` via post-commit hook
- lean-ctx enforces a shell allowlist: `bash`, `sh`, `zsh`, `uvx`, `claude` and `python3 -c` are refused by default. The "permanent restriction" wording is not a policy refusal — run `lean-ctx allow <cmd>` rather than abandoning the check

## Serena (Python code intelligence — mandatory, not optional)
- After editing any `.py` file: call `mcp__serena__get_diagnostics_for_file(path)` — real type/lint errors, not just ruff
- Before renaming or deleting any Python function/class: call `mcp__serena__find_referencing_symbols(symbol)` to confirm blast radius
- Registered user-scope, so every project inherits it: `claude mcp add serena --scope user -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --open-web-dashboard False`
- The `claude-code` context excludes `initial_instructions` — Serena loads silently with zero session overhead. There is no `ide-assistant` context any more
- `--open-web-dashboard False` is load-bearing: user scope means every agent spawn starts its own Serena process, and each one otherwise opens a browser tab. The dashboard still runs — reach it at http://localhost:24282/dashboard/ (port climbs per extra instance). The machine-local equivalent is `web_dashboard_open_on_launch: false` in `~/.serena/serena_config.yml`, which does not travel between machines

## Post-Task Convention
After any coding task, end with:
- **Files changed**: list every file touched
- **What changed**: one line per file
- **Not touched**: files intentionally left alone (if relevant)

## Test Output Convention
- When running tests, capture output to a temp file
- Only read the output if the exit code is non-zero
- Do not paste passing test output into conversation context
