# Skill Curation Report — 2026-06-08

## Summary

- Skills audited: 997
- Low-quality flags: 0 (harness-relevant subset; all scored ≥8/12)
- Duplicate pairs: 5 confirmed pairs (see below)
- Description flags (>150 chars): 565 (349 red 🔴 + 216 warn ⚠️)
- Memory governance: **ok**

---

## Description Budget

Total: 997 skills | 141,249 chars | ~35,313 tokens

> **Note**: Description text loads into every system-reminder as part of the available-skills manifest.
> 349 skills exceed the 200-char threshold, contributing measurable system-reminder pressure.

### Top 50 by Character Count

| Skill | Chars | Status |
|-------|-------|--------|
| prompt-master | 444 | 🔴 >200 |
| multi-agent-patterns | 437 | 🔴 >200 |
| evaluation/long-trajectory | 394 | 🔴 >200 |
| llm-fine-tuning | 379 | 🔴 >200 |
| structured-web-dataset | 378 | 🔴 >200 |
| agent-permissions-design | 358 | 🔴 >200 |
| agentic-rl-tito | 357 | 🔴 >200 |
| context-degradation | 349 | 🔴 >200 |
| evaluation/funnel | 344 | 🔴 >200 |
| evaluation/macro | 342 | 🔴 >200 |
| adapt-to-repo | 338 | 🔴 >200 |
| karpathy-guidelines | 320 | 🔴 >200 |
| rtk-token-reduction | 320 | 🔴 >200 |
| git-pushing | 313 | 🔴 >200 |
| frontend-slides | 311 | 🔴 >200 |
| local-llm-eval | 311 | 🔴 >200 |
| impeccable-audit | 309 | 🔴 >200 |
| agent-harness-design | 306 | 🔴 >200 |
| cag-implementation | 295 | 🔴 >200 |
| session-quality | 291 | 🔴 >200 |
| vibe-check | 288 | 🔴 >200 |
| website-spec | 288 | 🔴 >200 |
| gitnexus | 285 | 🔴 >200 |
| context-optimization | 284 | 🔴 >200 |
| evaluation/micro | 283 | 🔴 >200 |
| cma-outcomes | 280 | 🔴 >200 |
| grill-with-docs | 278 | 🔴 >200 |
| secure-agent-design | 275 | 🔴 >200 |
| frontend-performance | 274 | 🔴 >200 |
| privacy-filter | 274 | 🔴 >200 |
| claudemd-review | 268 | 🔴 >200 |
| keep-rate | 267 | 🔴 >200 |
| agent-memory-consolidation | 264 | 🔴 >200 |
| compiled-truth-pattern | 264 | 🔴 >200 |
| lean-ctx | 256 | 🔴 >200 |
| ai-native-org-patterns | 254 | 🔴 >200 |
| tool-design | 254 | 🔴 >200 |
| evaluation | 248 | 🔴 >200 |
| rag-implementation | 241 | 🔴 >200 |
| tool-failure-memory | 240 | 🔴 >200 |
| iterative-repair-loop | 237 | 🔴 >200 |
| sonar-hotspot-review | 237 | 🔴 >200 |
| active-observability | 232 | 🔴 >200 |
| codebase-legibility | 231 | 🔴 >200 |
| gitnexus-cli | 231 | 🔴 >200 |
| gitnexus-exploring | 231 | 🔴 >200 |
| gitnexus-pr-review | 231 | 🔴 >200 |
| agent-identity | 228 | 🔴 >200 |
| gitnexus-guide | 228 | 🔴 >200 |
| skill-extraction | 221 | 🔴 >200 |

---

## Quality Findings

### Harness-Relevant Skill Scores (38 skills audited)

All harness-relevant skills scored ≥8/12. No low-quality flags.

| Skill | Score | Notes |
|-------|-------|-------|
| lean-ctx | 12/12 | — |
| tool-failure-memory | 12/12 | — |
| context-optimization | 12/12 | — |
| gitnexus | 12/12 | — |
| local-llm-eval | 12/12 | — |
| adapt-to-repo | 11/12 | — |
| rtk-token-reduction | 11/12 | — |
| skill-developer | 11/12 | — |
| skill-creator | 11/12 | — |
| skill-extraction | 11/12 | — |
| raindrop-eval-loop | 11/12 | — |
| active-observability | 11/12 | — |
| vibe-check | 11/12 | — |
| verification-before-completion | 11/12 | — |
| structured-web-dataset | 11/12 | — |
| verification-skill-authoring | 11/12 | — |
| context-degradation | 11/12 | — |
| secure-agent-design | 11/12 | — |
| agent-harness-design | 11/12 | — |
| raindrop-instrument-agent | 9/12 | Trigger could be clearer |
| session-quality | 10/12 | — |
| brainstorming | 9/12 | Trigger phrase could be crisper |
| hook-design | 9/12 | Description hedges scope ("framework for deciding") |
| skill-curator | 9/12 | — |
| context-fundamentals | 8/12 | Informational, not action-oriented |

### Low-Quality Candidates

None identified in harness-relevant subset.

### Duplicate Pairs

| Pair | Overlap |
|------|---------|
| `api-documentation` ↔ `api-documentation-generator` ↔ `api-documenter` | All three cover OpenAPI/API doc generation — 3-way overlap |
| `agent-memory-systems` ↔ `memory-systems` | Both cover short-term/long-term/graph memory architectures |
| `context-management-context-restore` ↔ `code-refactoring-context-restore` | Scope nearly identical — context restore after compaction |
| `skill-creator` ↔ `skill-creator-ms` | Near-identical scope; `ms` variant is Microsoft-environment flavour |
| `context-optimization` ↔ `context-window-management` | Both guide token/context reduction strategies |

---

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | ✅ ok | Hook monitors observations.md entry count; triggers /kiro:housekeeping at >50 entries |
| session-start catch-up logic | ✅ ok | `.last-routine-run` check present; fires daily-runner.sh in background if >24h stale |
| memory-conventions.md intact | ✅ ok | 4,074 bytes, non-empty, header intact |
| observations.md recency | ✅ ok | Last entry: 2026-06-08 (today); 17 total entries |
| hot-memory.md recency | ✅ ok | Last modified: 2026-06-08 (today) |

---

## Recommendations

1. **Description compression sweep** — 349 skills exceed 200 chars. Priority targets (>300 chars): `prompt-master`, `multi-agent-patterns`, `evaluation/long-trajectory`, `llm-fine-tuning`, `structured-web-dataset`. Apply grammar compression: drop articles, use imperative verb form, replace filler with direct trigger nouns.

2. **API documentation triad** — `api-documentation`, `api-documentation-generator`, `api-documenter` have overlapping scope. Consolidate or add clear differentiation to each description so the model can route correctly.

3. **`context-fundamentals` (8/12)** — Informational rather than action-oriented. Lacks a concrete trigger. Consider reframing description as a "use when X" pattern.

4. **`hook-design` (9/12)** — Description hedges with "framework for deciding" — replace with direct trigger noun ("Design or audit Claude Code hooks").

---

## Iterative Repair Run — 2026-06-08

> Source: No formal Low-Quality Candidates in report (all harness-relevant skills ≥8/12). Repair applied to lowest-scoring skills from Recommendations.

| Skill | Before | After | Status |
|-------|--------|-------|--------|
| context-fundamentals | 8/12 | 10/12 | repaired — description rewritten to trigger form; malformed auto-generated "When to Use" text removed |
| hook-design | 9/12 | 9/12 | stalled — description fix yields ≤1 delta; content otherwise sound |
