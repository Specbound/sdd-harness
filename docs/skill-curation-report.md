# Skill Curation Report — 2026-07-26

## Summary

- Skills audited: 1004
- Low-quality flags (score ≤ 6/12): 121
- Duplicate groups detected: 29 (primarily Azure SDK language variants)
- Semantic duplicate pairs (genuine scope overlap): 4 pairs
- Description flags (>150 chars): 573 ⚠️ | (>200 chars): 69 🔴
- No description at all: 220
- Cold skills (no use in 30d): N/A | Archive candidates (90d): N/A
- Memory governance: **ok**

---

## Usage Evidence

No usage data yet — `logs/skill-usage.jsonl` does not exist. The skill-usage-tracker PostToolUse hook may not be installed or has not fired yet. Deprecation/archive candidates cannot be determined mechanically from evidence; quality-score signals are the only guide this sweep.

### Deprecate Candidates (no invocation in 30d)
_No data — see above._

### Archive Candidates (no invocation in 90d)
_No data — see above._

---

## Description Budget

**Total: 1004 skills | 136,505 chars | ~34,127 tokens**

This is the aggregate token cost of all description fields if they were all loaded simultaneously (e.g., in a system-reminder). In practice only a subset loads, but the 220 no-description skills are invisible to the routing model and the 69 over-200-char skills add measurable pressure when they do load.

### Over 200 Chars 🔴 (69 skills — top 30 by length)

| Skill | Chars | Status |
|-------|-------|--------|
| para-memory-files | 556 | 🔴 |
| rl-agent-training | 514 | 🔴 |
| semantic-data-pipeline | 475 | 🔴 |
| multi-agent-patterns | 437 | 🔴 |
| agent-execution-control | 431 | 🔴 |
| get-api-docs | 413 | 🔴 |
| create-agent-adapter | 390 | 🔴 |
| structured-web-dataset | 380 | 🔴 |
| llm-fine-tuning | 379 | 🔴 |
| progressive-complexity-ladder | 376 | 🔴 |
| paperclip | 362 | 🔴 |
| context-degradation | 349 | 🔴 |
| evaluation/macro | 342 | 🔴 |
| adapt-to-repo | 336 | 🔴 |
| feature-list-primitive | 333 | 🔴 |
| instruction-architecture | 322 | 🔴 |
| rtk-token-reduction | 318 | 🔴 |
| session-clean-state | 314 | 🔴 |
| git-pushing | 313 | 🔴 |
| frontend-slides | 311 | 🔴 |
| local-llm-eval | 309 | 🔴 |
| impeccable-audit | 309 | 🔴 |
| agent-harness-design | 304 | 🔴 |
| code-reviewer | 303 | 🔴 |
| multi-agent-brainstorming | 296 | 🔴 |
| cag-implementation | 295 | 🔴 |
| session-quality | 291 | 🔴 |
| llm-inference-async-batching | 288 | 🔴 |
| website-spec | 288 | 🔴 |
| vibe-check | 286 | 🔴 |
| gitnexus | 285 | 🔴 |
| architect-review | 285 | 🔴 |
| _(39 more in 201–284 char range)_ | … | 🔴 |

### Between 150–200 Chars ⚠️
504 additional skills in this range (not enumerated — see `/skill-curator` for interactive trimming).

---

## Quality Findings

### Scoring Rubric
Each dimension is 0–3; total /12. Scores ≤ 6 flagged.

- **Task relevance (TR)**: trigger clarity — does the model know when to invoke?
- **Operational validity (OV)**: concrete, structured, executable instructions
- **Content quality (CQ)**: no empty description, substantive body
- **Compression ratio (CR)**: description compact relative to body; body large enough to justify overhead

### Low-Quality Candidates (score ≤ 6/12) — 121 total

Top actionable flags (sorted by score, lowest first):

| Skill | Score | Notes |
|-------|-------|-------|
| hig-patterns | 5/12 | No description; likely passive reference doc, not agent skill |
| typescript-pro | 5/12 | No description |
| javascript-pro | 5/12 | No description |
| hig-components-controls | 5/12 | No description |
| hig-foundations | 5/12 | No description |
| copywriting | 5/12 | No description |
| hig-components-search | 5/12 | No description |
| questions | 5/12 | Minimal 55-char description; unclear routing trigger |
| hig-components-layout | 5/12 | No description |
| hig-technologies | 5/12 | No description |
| hig-platforms | 5/12 | No description |
| context-manager | 6/12 | Description is malformed YAML (multi-line string breaks frontmatter parsing) |
| database-optimizer | 6/12 | No description |
| team-composition-analysis | 6/12 | No description |
| test-automator | 6/12 | No description |
| hig-components-dialogs | 6/12 | No description |
| database-admin | 6/12 | No description |
| docs-architect | 6/12 | No description |
| dx-optimizer | 6/12 | No description |
| startup-business-analyst-business-case | 6/12 | No description |
| hig-inputs | 6/12 | No description |
| ml-engineer | 6/12 | No description |
| ui-visual-validator | 6/12 | No description |
| frontend-developer | 6/12 | No description |
| network-engineer | 6/12 | No description |
| cloud-architect | 6/12 | No description |
| bash-pro | 6/12 | No description |
| blockchain-developer | 6/12 | No description |
| fastapi-pro | 6/12 | No description |
| _(91 more at score 6)_ | 6/12 | Mostly no-description skills |

**Structural finding**: 220 of 1004 skills have no `description:` field. These are invisible to skill-routing models — they can only be invoked if explicitly named. Most are Azure SDK variants or generic `*-pro` skills from the community library. This is the single largest quality gap.

**Note on `typescript-pro` and `javascript-pro`**: These were scored 5/12 as "No description" — the curation tool could not parse their multi-line YAML flow scalar descriptions. The actual YAML was malformed (multi-line continuation in a double-quoted flow scalar), causing frontmatter parsers to drop the field. Fixed in the repair run below.

### Duplicate Pairs (genuine semantic overlap)

These are skills with substantially overlapping scope that could be merged or differentiated more clearly:

| Pair | Overlapping Scope |
|------|------------------|
| `context-manager` ↔ `context-optimization` ↔ `context-fundamentals` | All three cover context window management strategy; unclear when to prefer each |
| `agent-memory-discipline` ↔ `agent-memory-consolidation` ↔ `agent-memory-systems` ↔ `agent-memory-mcp` | Four agent memory skills — discipline=policy, consolidation=housekeeping, systems=architecture, mcp=tooling; differentiated but borderline overlap |
| `agent-orchestration-improve-agent` ↔ `agent-orchestration-multi-agent-optimize` | Both target agent performance optimization; single-agent vs. system-wide is the only differentiator |
| `raindrop-agent-replay` ↔ `raindrop-eval-loop` | Both activate on Raindrop Workshop traces; replay=setup/infra, eval-loop=CI loop |

**Azure SDK groups (language variants — NOT true duplicates)**:
29 groups of 2–5 skills are language variants of the same Azure service (e.g., `azure-cosmos-py/ts/java/rust`). These are correctly separate; no action needed. They inflate the count by ~120 skills.

---

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | ok | `stop-hook.sh` (124 lines) references `observations.md` in 3 places; nudge logic for >50 entries intact |
| session-start catch-up logic | ok | `session-start-hook.sh` (149 lines) has catch-up block at line 33–37, reads `.claude/memory/.last-routine-run` |
| memory-conventions.md intact | ok | 121 lines, non-empty, header and sections present |
| observations.md recency | ok | Last entry: 2026-07-26 (today) |
| hot-memory.md recency | ok | Last modified: 2026-07-26 09:52 IDT |

All five governance checks pass. The idle-window pattern continues (HEAD static at b03a740 since 2026-07-06; routine entries are catch-up artifacts from the daily-runner, not user sessions).

---

## Recommended Actions (for human-invoked `/skill-curator`)

1. **Priority — add descriptions**: 220 no-description skills are routing-invisible. The HIG family (8 files: `hig-patterns`, `hig-foundations`, `hig-inputs`, `hig-platforms`, `hig-technologies`, `hig-components-*`) are the clearest removal candidates — they are passive reference docs, not agent skills.
2. **Fix malformed YAML**: `context-manager` has a multi-line `description:` that breaks frontmatter parsing — fix or replace before next sweep.
3. **Compress top offenders**: 69 skills exceed 200-char descriptions. Top candidate: `prompt-master` (444 chars → target ≤100 using imperative verb form).
4. **Differentiate context trio**: `context-manager`, `context-optimization`, `context-fundamentals` need distinct trigger keywords so the router can pick the right one.
5. **Install usage tracker**: Deploy `skill-usage-tracker.sh` PostToolUse hook to write `logs/skill-usage.jsonl` — without it, evidence-based deprecation is impossible.

---

## Iterative Repair Run — 2026-07-26

Repaired the 3 lowest-scoring actionable skills (5/12). HIG skills at 5/12 skipped — curation report recommends removal, not repair (passive reference docs, not agent skills).

**Scoring rubric**: TR (trigger relevance) + OV (operational validity) + CQ (content quality) + CR (compression ratio), each 0–3.

| Skill | Before | After | Delta | Status | Fix applied |
|-------|--------|-------|-------|--------|-------------|
| typescript-pro | 5/12 | 8/12 | +3 | repaired | Malformed multi-line YAML → single-line description (156 chars); body unchanged |
| javascript-pro | 5/12 | 8/12 | +3 | repaired | Malformed multi-line YAML → single-line description (152 chars); body unchanged |
| questions | 5/12 | 8/12 | +3 | repaired | Added "When to use" trigger condition; description clarified with explicit invoke signal |

**Root cause for ts-pro / js-pro**: Both used a YAML double-quoted flow scalar split across lines with indented continuation. YAML spec allows this but many frontmatter parsers treat the newline as a literal character, producing garbage or dropping the field entirely. Fixed by collapsing to single-line quoted strings.

**Next sweep priority**: `context-manager` (6/12, malformed YAML — same root cause); then batch-add descriptions to the 220 no-description skills, starting with the 8 HIG files (recommend archiving them rather than repairing).
