# sdd-harness

## Address
- Always call the user "Husband" in every reply — no exceptions.
- If you stop doing this, it signals CLAUDE.md is being ignored. A Stop hook (`address-check-hook.sh`) logs `[address-check] husband not found — compact needed` when the term is missing, but it no longer blocks the stop or feeds anything back to you — it is a passive signal for a human to act on, so /compact and re-read CLAUDE.md on your own.

## Context Resources (read on demand, not upfront)
- `.claude/memory/hot-memory.md` — read at session start (current state, priorities)
- `.claude/memory/meta/patterns.md` — read at session start (workflow patterns)
- `.claude/steering/` — read when you need project architecture, stack, or code structure context
- `.claude/memory/` — read when you need cross-session context or past decisions
- `specs/` — read when working on or near a feature that has a spec
- `.claude/behaviors/` — read when reviewing agent conduct or grading a trace, not upfront; kept blind from the agent whose trajectory it grades
- `.claude/docs/harness-documentation/SDD-USAGE.md` — read when you need SDD command reference
- `ERRORS.md` — check before suggesting solutions to problems; log approaches that took 2+ attempts

## Rules
- Plan before multi-file or design-affecting changes — use Plan mode for back-and-forth. Sketch 2-3 approaches when the design is genuinely open; otherwise pick one and say why.
- Features with clear correctness criteria need an approved spec in `specs/` before implementation — prefer an executable spec (failing test suite) or reference implementation over plain markdown. Markdown stays the default for open-ended/UX work. Bugfixes, perf work, and tooling do not need a spec.
- Atomic commits per task (one task = one commit, code only)
- Never skip the human review gate between spec phases
- Never commit installed harness output — `.claude/`, `specs/`, `CLAUDE.md`, `AGENTS.md` and `ERRORS.md` are local (see `.gitignore`; the list is `SDD_GITIGNORE_ENTRIES` in `scripts/lib/project-gitignore.sh`). In this repo the top-level source tree (`agents/ commands/ hooks/ kiro/ scripts/ docs/ rules/ skills/ templates/`) IS the product and is committed normally
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

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **sdd-harness** (48505 symbols, 52417 relationships, 290 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "master"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/sdd-harness/context` | Codebase overview, check index freshness |
| `gitnexus://repo/sdd-harness/clusters` | All functional areas |
| `gitnexus://repo/sdd-harness/processes` | All execution flows |
| `gitnexus://repo/sdd-harness/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
