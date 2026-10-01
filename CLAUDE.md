# sdd-harness

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
- Never commit installed harness output — `.claude/`, `specs/`, `AGENTS.md` and `ERRORS.md` are local (see `.gitignore`). In this repo the top-level source tree (`agents/ commands/ hooks/ kiro/ scripts/ docs/ rules/ skills/ templates/`) IS the product and is committed normally, and so is this `CLAUDE.md` — a shared reference, so keep personal preferences in `CLAUDE.local.md`. Downstream projects keep their own `CLAUDE.md` local (`SDD_GITIGNORE_ENTRIES` in `scripts/lib/project-gitignore.sh`)
- Maintain `ERRORS.md`: when an approach takes 2+ attempts, log what failed, what worked, and why

## AI-Legible Code
- **Blast radius**: prefer changes that touch ≤1 folder/module; if >1, scope down first
- **Rule of Three**: no shared extraction until 3 real call sites exist — two similar = coincidence
- **Vertical slices**: feature = one folder (routes/logic/data/types/tests); no cross-feature imports; no `shared/`, `utils/`, `common/`
- **Fail fast**: validate at every public boundary; named exceptions; no bare `except`; no silent fallbacks
- **Context rot**: AI coherence degrades past ~300k tokens — keep functions and PRs small
- **Reviewer model mismatch**: use a separate session/model to review AI-generated code
- **3rd patch, same function**: on a third patch to the same function, regenerate it from spec instead of layering another fix — patches stacking past two is how blast radius quietly outgrows the original ≤1-folder scope (kiro.dev — Frontier Engineering)
- **Boundary tests outlive the code they check**: e2e, property, and load tests are the stable spec — when code under them gets regenerated (see the 3rd-patch rule above), the tests are what proves the regenerated version still behaves the same. Write boundary tests before regenerating, not after (kiro.dev — Frontier Engineering)

## Quality Gates (automated)
- `ruff check`: on every `.py` file write
- `oxlint` (or `eslint`): on every `.ts`/`.tsx`/`.js`/`.jsx` file write, when one is installed. A finding naming an anti-slop rule (`no-unknown-parameters`, `no-unsafe-dictionary-type`, `no-chained-type-assertions`, …) means type evidence was thrown away — recover the real type, never silence the rule
- No pytest suite; verify shell via `*.test.sh` + throwaway-tree runs
- doc sync: automatically on every `git commit` via post-commit hook
- lean-ctx enforces a shell allowlist: `bash`, `sh`, `zsh`, `uvx`, `claude` and `python3 -c` are refused by default. The "permanent restriction" wording is not a policy refusal — run `lean-ctx allow <cmd>` rather than abandoning the check

## Blast Radius
The Risk Gate table in `.claude/rules/lean-ctx.md` is the one check, in order. It takes
precedence over the auto-generated GitNexus block below, which states its own rule without
knowing about Serena or lean-ctx.

## Serena (Python code intelligence — mandatory, not optional)
- After editing any `.py` file: call `mcp__serena__get_diagnostics_for_file(path)` — real type/lint errors, not just ruff
- Skip Serena's `initial_instructions` prompt — CLAUDE.md is the manual here
- Install and dashboard flags: see `SDD-SETUP-GUIDE.md` (Serena entry)

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

Indexed as **sdd-harness**. Tools below are MCP; if MCP is down, use the CLI with kebab-case verbs and flags, e.g. `node .gitnexus/run.cjs detect-changes --scope all --repo .`. Stale index: `node .gitnexus/run.cjs analyze --index-only`.

- **MUST run `impact({target, direction: "upstream"})` before editing any function, class or method**; report callers, processes, risk.
- **MUST run `detect_changes({scope: "all"})` before committing.** `partial: true` / `truncated: true` is not clean — a zero means unseen; re-run. Regression review: `scope: "compare", base_ref: "<default branch>"`.
- **HIGH/CRITICAL risk: warn before editing, never proceed silently.** `riskSharedAxes` never waives it (MCP File omits axes; Graph-RAG expands File).
- **`risk: UNKNOWN` is unresolved, not low.** Empty callers can mean unresolvable callers (dynamic dispatch, property access, cross-language) — confirm with text search before changing or deleting.
- Read-only questions — graph first: `query({search_query})` for concepts/flows, `context({name})` for a symbol, `impact` for blast radius. Text search only for empty/UNKNOWN results or literals.
- **NEVER rename with find-and-replace** — use `rename`.
- Security review: `explain({target})` lists taint flows (needs `analyze --pdg`).
- How-to detail: skills `gitnexus-exploring`, `gitnexus-impact-analysis`, `gitnexus-debugging`, `gitnexus-refactoring`, `gitnexus-guide`, `gitnexus-cli`.
<!-- gitnexus:end -->
