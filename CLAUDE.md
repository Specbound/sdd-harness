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

This project is indexed by GitNexus as **sdd-harness** (49128 symbols, 53926 relationships, 314 execution flows).

> Index stale? Run `node .gitnexus/run.cjs analyze --index-only` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? Bootstrap with `npx`, `bunx`, or `pnpm dlx` — e.g. `bunx gitnexus@latest analyze` (npm 11 npx crash; #1939).

## Always Do

- **MUST run impact before editing.** Use `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`; report callers, processes, and risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing.** Use `detect_changes({scope: "all"})` (MCP) or `node .gitnexus/run.cjs detect-changes --scope all --repo .` (CLI fallback). `partial: true` or `truncated: true` is not a clean check — a zero means unseen, not unaffected; re-run it. For regression review: `detect_changes({scope: "compare", base_ref: "master"})` or `node .gitnexus/run.cjs detect-changes --scope compare --base-ref "master" --repo .`.
- MUST warn on HIGH/CRITICAL `risk` pre-edit; never use `riskSharedAxes` to waive a HIGH/CRITICAL `risk` warning. Compare File/symbol: MCP File omits axes; Graph-RAG expands File.
- **MUST treat `risk: UNKNOWN` as unresolved, not as low.** An empty caller set is not evidence the symbol is unused — it can also mean the callers are not resolvable by the index (plain-object property access, dynamic dispatch, cross-language calls). `impact` pairs `UNKNOWN` with a `riskNote` saying so. Confirm with a text search before treating the symbol as safe to change or delete; do not proceed on the strength of a zero.
- **MUST use `query({search_query: "concept"})` for concepts/flows, `context({name: "symbolName"})` for a named symbol, or `impact` for blast radius, on read-only callers, dependencies, imports, or execution flow.** Graph first; text search only for empty/`UNKNOWN`/literals.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method before MCP/CLI impact analysis.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis, and never read `UNKNOWN` as an all-clear — it means the walk could not answer, which is the one verdict that requires confirming by other means.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit before MCP/CLI graph change analysis.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/sdd-harness/context` | Codebase overview, check index freshness |
| `gitnexus://repo/sdd-harness/clusters` | All functional areas |
| `gitnexus://repo/sdd-harness/processes` | All execution flows |
| `gitnexus://repo/sdd-harness/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
| --- | --- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
