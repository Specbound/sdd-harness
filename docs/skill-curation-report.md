# Skill Curation Report — 2026-06-21

## Summary
- Skills audited: 980
- Low-quality flags: 112 (malformed description frontmatter)
- Duplicate pairs: 8 strong (cross-import-source, identical command scope)
- Description flags (>150 chars): 570 (353 RED >200, 217 WARN 151–200)
- Cold skills (no use in 30d): N/A — no usage data yet | Archive candidates (90d): N/A
- Memory governance: **ok**

> Scope note: `~/.claude/skills/` holds **980** skills (mostly bulk-imported plugin
> families — azure=116, *-automation=83). This is a global skill library, not a
> per-repo set. The weekly sweep reports only; deletion/edits are human-gated via
> `/skill-curator`.

## Usage Evidence

No usage data yet — `logs/skill-usage.jsonl` does not exist in this repo or under
`~/.claude/`. The `skill-usage-tracker.sh` PostToolUse hook appears not yet installed
or has not fired. **Deprecate/Archive candidate detection is blocked until the tracker
logs real invocations.** Install the tracker hook to enable evidence-based deprecation.

### Deprecate Candidates (no invocation in 30d)
None computable — no usage log.

### Archive Candidates (no invocation in 90d)
None computable — no usage log.

## Description Budget

Total: 980 skills | ~160,085 desc chars | **~40,000 tokens** of system-reminder pressure
(floor estimate ~35k single-line; upper bound inflated by 3 block-scalar over-captures — see caveat).

| Skill | Chars | Status |
|-------|-------|--------|
| agent-execution-control | 9420* | 🔴 parse caveat — unquoted folded block scalar, verify frontmatter manually |
| skill-creator-ms | 7391* | 🔴 parse caveat — same |
| get-api-docs | 2898* | 🔴 parse caveat — same |
| progressive-complexity-ladder | 594 | 🔴 real — compress |
| prompt-master | 444 | 🔴 real — compress |
| multi-agent-patterns | 437 | 🔴 real — compress |
| llm-fine-tuning | 379 | 🔴 real — compress |
| structured-web-dataset | 378 | 🔴 real — compress |
| agent-permissions-design | 358 | 🔴 real — compress |
| agentic-rl-tito | 357 | 🔴 real — compress |
| context-degradation | 349 | 🔴 real — compress |
| adapt-to-repo | 338 | 🔴 real — compress |
| setup-agent-replay | 332 | 🔴 real — compress |
| feature-list-primitive | 332 | 🔴 real — compress |
| instruction-architecture | 321 | 🔴 real — compress |

\* Char counts marked `*` are parser over-captures: these skills use an unquoted
`description: >` folded block scalar and the extractor slurped body text past the
description. Real description length is unknown — needs manual frontmatter inspection.

**Aggregate:** 353 skills exceed 200 chars (🔴 measurable pressure), 217 in the
151–200 WARN band. Compressing the 353 RED descriptions to ≤150 chars would reclaim
an estimated 8–12k tokens of standing system-reminder budget.

## Quality Findings

### Low-Quality Candidates

**112 skills — malformed description frontmatter (broken).** These use a *quoted*
block-scalar marker: `description: ">-"` (or `">"`, `"|"`). The author meant the
unquoted form `description: >-`; quoting it makes the value the literal 2-char string
`>-`, with the intended description orphaned on following indented lines. A standard
YAML loader resolves these to a useless 2-char description → broken skill routing.

Almost all are bulk-imported azure SDK skills. Sample:
- azure-ai-contentsafety-py
- azure-ai-textanalytics-py
- azure-appconfiguration-py
- azure-cosmos-rust
- azure-cosmos-java
- azure-ai-voicelive-ts
- (…107 more — `grep -lE '^description:[ ]*"(>-?|\|-?)"[ ]*$' ~/.claude/skills/*/SKILL.md`)

Recommended fix (human-gated, mechanical): strip the surrounding quotes so the marker
becomes a real YAML block scalar. One-line sed candidate per file, but verify a sample
first.

> Per-skill 0–12 scoring across all 980 skills is not performed in the automated weekly
> sweep (cost-prohibitive and judgment-heavy). The malformed-frontmatter set above is
> the highest-confidence mechanical low-quality signal. Run `/skill-curator` for
> interactive deep scoring of specific candidates.

### Duplicate Pairs

Strong duplicates — same command scope, different prefix from separate import sources:

| Skill A | Skill B | Overlap |
|---------|---------|---------|
| code-refactoring-tech-debt | codebase-cleanup-tech-debt | identical tech-debt scope |
| code-refactoring-refactor-clean | codebase-cleanup-refactor-clean | identical refactor scope |
| comprehensive-review-pr-enhance | git-pr-workflows-pr-enhance | identical PR-enhance scope |
| debugging-toolkit-smart-debug | error-diagnostics-smart-debug | identical smart-debug scope |
| parallel-agents | dispatching-parallel-agents | parallel-agent dispatch |
| memory-systems | agent-memory-systems | agent memory overlap |
| instrument-agent | raindrop-instrument-agent | agent instrumentation overlap |
| dependency-management-deps-audit | codebase-cleanup-deps-audit | deps-audit scope |

Borderline (generic-vs-specific, keep both): `testing-patterns` vs per-lang
`*-testing-patterns`; `security-audit` vs `laravel-security-audit`;
`skill-creator` vs `skill-creator-ms`; `mcp-builder` vs `mcp-builder-ms`.

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | ok | 3 `observations.md` write refs present |
| stop-hook memory-conventions ref | note | 0 refs — by design; PreToolUse memory gate enforces conventions, not the stop hook |
| session-start catch-up logic | ok | reads `.last-routine-run` (2 refs) |
| memory-conventions.md intact | ok | 121 lines, not truncated |
| observations.md recency | ok | last entry: 2026-06-21 (today) |
| hot-memory.md recency | ok | last modified: 2026-06-21 (today) |

**Overall: ok.**

## Action Items (for human-invoked `/skill-curator`)
1. **Install `skill-usage-tracker.sh`** PostToolUse hook → unblocks deprecation evidence.
2. **Fix 112 malformed `description:` frontmatter** (quoted block-scalar markers).
3. **Compress 353 RED descriptions** (>200 chars) → reclaim ~8–12k tokens.
4. **Resolve 8 duplicate pairs** — pick the canonical skill per pair, delete the other.
5. **Manual-check 3 parse-caveat skills** (agent-execution-control, skill-creator-ms, get-api-docs).
