# CLAUDE.md Review Report — 2026-06-22

## Summary
- Repos checked: 4
- Inaccessible: 0
- Clean: 0
- Minor issues: 2
- Needs update: 2

## Since Last Review (2026-06-08)
- **Resolved:** `aiq-zora-ai-engine` no longer carries the `Keep context under 40%`
  rule or the duplicated "read hot-memory at session start" line that the prior
  run flagged. Engine CLAUDE.md is now a clean 35-line subset.
- **New this run:** stale `.claude/docs/SDD-USAGE.md` path detected in two repos
  (the file moved to `.claude/docs/harness-documentation/SDD-USAGE.md`).
- **Still open:** the blanket `show 2-3 approaches` over-constraint, and the
  `## Address` ("Husband") section still missing from purina and skill-foundation.

## Cross-Repo Themes
- **Over-constraining handshake (pre-4.x habit).** Multiple repos carry
  `Before any significant task, show 2-3 approaches and wait for confirmation`
  plus `Always plan before coding — use Plan mode`. On Opus 4.x this judgment is
  reliable; a blanket mandate forces a confirmation round-trip on every
  non-trivial task. Recommend scoping to *ambiguous or high-blast-radius* work.
- **Stale SDD-USAGE.md path.** `sdd-harness` and `aiq-zora-ai-engine` point to
  `.claude/docs/SDD-USAGE.md`, which does not exist; correct path is
  `.claude/docs/harness-documentation/SDD-USAGE.md`. `skill-foundation` already
  uses the correct form — adopt it everywhere.
- **`ERRORS.md` referenced but absent** in 3 repos. Fine as a create-on-demand
  log, but only `skill-foundation` documents it as gitignored/local. Add that
  caveat to the others.

## Findings

### sdd-harness — needs-update
- **Stale path:** references `.claude/docs/SDD-USAGE.md` (does not exist).
  Correct: `.claude/docs/harness-documentation/SDD-USAGE.md`.
- **Steering not bootstrapped:** `.claude/steering/` is referenced and the dir
  exists, but the `.steering-bootstrap-pending` sentinel is still present
  (SessionStart flagged `[STEERING-BOOTSTRAP-DUE]`). The pointer resolves to an
  effectively empty resource — run `/kiro:steering` then clear the sentinel.
- **Over-constraining:** `show 2-3 approaches and wait for confirmation before
  proceeding` — scope to ambiguous/high-impact tasks.
- Otherwise strong: AI-legible code rules, quality gates, Serena integration,
  and conventions are accurate and current.

### aiq-zora-ai-engine — needs-update
- **Stale path:** references `.claude/docs/SDD-USAGE.md`; actual file is
  `.claude/docs/harness-documentation/SDD-USAGE.md`.
- **`ERRORS.md` missing** (referenced twice) with no create-on-demand caveat.
- **Over-constraining:** same `plan before coding` + `show 2-3 approaches` pair.
- Prior-run issues (40% context rule, duplicate memory-read) are now resolved.

### aiq-purina-salesorderintelligence-poc — minor
- **Pre-4.x threshold:** `Keep context under 40% before moving from planning to
  implementation` (line 24) is an arbitrary fixed budget that now misleads more
  than it helps. Drop the hard number or rephrase as "keep planning context lean."
- **GitNexus MUST/NEVER block (lines 49-91):** very prescriptive
  (`MUST run impact analysis before editing any symbol`). Auto-generated
  `gitnexus:start/end` block and intentional tooling — acceptable as-is; flag
  only if the per-edit mandate causes friction.
- **Missing `## Address` section** — "Husband" convention not enforced here
  (consistent with prior-run note).
- **`ERRORS.md` missing** (referenced) without a local-only caveat.
- The no-lazy-imports rule is a legitimate, well-justified project rule.

### aiq-zora-agent-skill-foundation — minor
- **Correct paths throughout** — uses the proper `harness-documentation/SDD-USAGE.md`
  path and caveats `ERRORS.md` as gitignored/local. Use as the template for the
  other repos' fixes.
- Architecture, testing (100% coverage), and command docs are accurate and
  detailed — no staleness.
- **Missing `## Address` section** — "Husband" convention not enforced.
- **Over-constraining:** shared `plan before coding` + `show 2-3 approaches` pair
  (lines 112, 117). Scope down.

## Proposed Changes (proposals only — not auto-applied)

### 1. sdd-harness/CLAUDE.md
```diff
- - `.claude/docs/SDD-USAGE.md` — read when you need SDD command reference
+ - `.claude/docs/harness-documentation/SDD-USAGE.md` — read when you need SDD command reference
```

### 2. aiq-zora-ai-engine/CLAUDE.md
```diff
- - `.claude/docs/SDD-USAGE.md` — read when you need SDD command reference
+ - `.claude/docs/harness-documentation/SDD-USAGE.md` — read when you need SDD command reference
- - `ERRORS.md` — check before suggesting solutions to problems; log approaches that took 2+ attempts
+ - `ERRORS.md` — check before suggesting solutions; log 2+-attempt approaches (gitignored — local only, created on demand)
```

### 3. aiq-purina-salesorderintelligence-poc/CLAUDE.md
```diff
- - Keep context under 40% before moving from planning to implementation
+ - Keep planning context lean; /compact when coherence degrades, not at a fixed %
```

### 4. Shared over-constraint (sdd-harness + skill-foundation)
```diff
- Before any significant task, show 2-3 approaches and wait for confirmation before proceeding
+ For ambiguous or high-blast-radius tasks, present 2-3 approaches before proceeding
```

## Stamp
```bash
echo "2026-06-22" > /home/dalesser/.claude/sdd-harness/.claude/memory/.last-claudemd-review
```
