# Skill Curation Report — 2026-08-06

## Summary
- Skills audited: 991
- Low-quality flags (score ≤6/12): 47
- Duplicate pairs: 10 (carried forward from last week, existence re-verified)
- Dependency flags: 17
- Description flags: >150 chars 579 total (509 ⚠️ 150–200 chars, 70 🔴 >200 chars)
- Structural YAML defect (`description: ">"` quoted instead of bare `>`): 19
- Cold skills (no use in 30d): N/A — no usage data yet | Archive candidates (90d): N/A
- Memory governance: **warn**

## Methodology note
Quality scores are heuristic, computed in bulk (not a per-skill manual read of all 991 bodies):
- **Task relevance (0–3)**: description non-empty/non-malformed + presence of explicit trigger cues ("use when", "trigger", "whenever", etc.)
- **Operational validity (0–3)**: body word count as a substance proxy (can't verify command-level accuracy at this scale without executing each skill)
- **Content quality (0–3)**: body word count, stricter buckets (penalizes very thin bodies)
- **Compression ratio (0–3)**: body words vs. description token cost — approximates "value delivered on invocation" vs. "tax paid on every load"

This diverges from a fully manual read-through and will disagree with any prior report that scored individual bodies by hand — treat both as directional, not authoritative pixel-for-pixel.

**Discrepancy vs. last week's numbers**: total description chars (143,684 vs. 205,918) and the bucket split (412/509/70 vs. 198/242/551) differ substantially from the 2026-08-04 report despite scoring the same 991-skill corpus. The low-quality count also differs (47 vs. 27). This run's script parses folded (`>`/`|`) multi-line YAML descriptions with a stricter continuation-join than whatever approach produced last week's figures (undocumented in that report). The structural-defect count (19) matches exactly both weeks, which is the one hard check both methodologies agree on — treat the other deltas as a methodology shift, not a real week-over-week trend in the underlying skills.

## Usage Evidence

No usage data yet — tracker hook (`skill-usage-tracker.sh`) is present at `.claude/hooks/` and correctly targets `logs/skill-usage.jsonl`, but that file does not exist yet, meaning zero fires have been logged since install. Re-run this phase next week once real invocations accumulate.

### Deprecate Candidates (no invocation in 30d)
N/A — no usage log to evaluate against.

### Archive Candidates (no invocation in 90d)
N/A — no usage log to evaluate against.

## Description Budget

Total: 991 skills | ~143,684 reliable chars | ~35,921 est. tokens (description frontmatter alone, always resident in the system-reminder skill listing)

| Bucket | Count |
|--------|-------|
| ≤150 chars (ok) | 412 |
| 150–200 chars ⚠️ | 509 |
| >200 chars 🔴 | 70 |

**Top 12 longest descriptions:**

| Skill | Chars |
|-------|-------|
| semantic-data-pipeline | 473 |
| stacking-pull-requests | 466 |
| prompt-master | 444 |
| multi-agent-patterns | 435 |
| agent-execution-control | 431 |
| writing-behavior-specs | 429 |
| get-api-docs | 411 |
| llm-fine-tuning | 379 |
| structured-web-dataset | 378 |
| progressive-complexity-ladder | 376 |
| agent-permissions-design | 356 |
| agentic-rl-tito | 355 |

**Structural defect — 19 skills use `description: ">"` (quoted) instead of the bare YAML fold indicator `description: >`.** Confirmed by direct inspection this week (`hig-patterns/SKILL.md`): the frontmatter reads `description: ">"` followed by 9 indented lines of intended paragraph content. A strict YAML parser reads the quoted form as the literal 2-character string `">"` and treats the following indented lines as orphaned — meaning the router-visible description for these skills may resolve to just `">"` rather than the intended paragraph, silently breaking trigger matching. Affected: `analytics-tracking`, `arm-cortex-expert`, `copywriting`, `crypto-bd-agent`, `form-cro`, `hig-components-content`, `hig-components-layout`, `hig-components-status`, `hig-components-system`, `hig-foundations`, `hig-inputs`, `hig-patterns`, `hig-platforms`, `hig-technologies`, `page-cro`, `programmatic-seo`, `schema-markup`, `seo-audit`, `seo-fundamentals`. Same 19, same set composition as last week. Fix is mechanical: replace `description: ">"` with `description: >` (drop the quotes) — flag for human-invoked `/skill-curator` to batch-apply, do not auto-fix here.

## Quality Findings

### Low-Quality Candidates (47 total, score ≤6/12)

Weakest first:
- `cc-skill-continuous-learning`, `cc-skill-strategic-compact` — 3/12 — thin description (45 chars, no trigger cue), thin body (23 words)
- `claude-scientific-skills` — 3/12 — 39-char description, 52-word body
- `questions` — 3/12 — generic name/description (55 chars), minimal body (29 words) — see Dependency Flags below, this one is heavily grep-referenced but likely a false-positive coupling
- `superpowers-lab` — 3/12 — 38-char description, 51-word body
- `claude-win11-speckit-update-skill`, `fal-audio`, `ffuf-claude-skill`, `pypict-skill`, `security-bluebook-builder`, `x-article-publisher-skill` — 4/12 — short descriptions (21–59 chars), thin bodies (45–58 words)
- `agent-manager-skill`, `aws-skills`, `beautiful-prose`, `clarity-gate`, `claude-ally-health`, `claude-speed-reader`, `codex-review`, `exa-search`, `fal-generate`, `fal-image-edit`, `fal-platform`, `fal-upscale`, `fal-workflow`, `firecrawl-scraper`, `infinite-gratitude`, `makepad-skills`, `nanobanana-ppt-skills`, `skill-seekers`, `tavily-web`, `varlock-claude-skill`, `vexor` — 5/12 — descriptions 49–125 chars, bodies 60–119 words
- `context7-auto-research`, `file-uploads`, `go-concurrency-patterns`, `llm-application-dev-prompt-optimize`, `memory-safety-patterns`, `modern-javascript-patterns`, `nerdzao-elite`, `projection-patterns`, `protocol-reverse-engineering`, `risk-metrics-calculation`, `screen-reader-testing`, `security-requirement-extraction`, `similarity-search-patterns`, `stride-analysis-patterns`, `threat-mitigation-mapping` — 6/12 — descriptions at or near the 200-char cap but with thinner bodies (107–147 words) relative to their description tax

The `fal-*` cluster (audio/generate/image-edit/platform/upscale/workflow) is the largest single low-quality group — six near-identical thin skills for one product family. Worth a merge-or-flesh-out decision, not necessarily deletion, since the trigger space (fal.ai operations) is real. Note also the `codex-review` / `context7-auto-research` / `exa-search` / `firecrawl-scraper` / `tavily-web` cluster — five research/search-tool skills that all reference each other (see Dependency Flags) and are all individually thin; likely candidates for one consolidated "research-tools" skill rather than five separate low-scoring ones.

### Duplicate Pairs (10, re-verified as existing directories this week — not re-derived from scratch)

1. `error-debugging-error-trace` ↔ `error-diagnostics-error-trace`
2. `error-debugging-error-analysis` ↔ `error-diagnostics-error-analysis`
3. `error-debugging-multi-agent-review` ↔ `performance-testing-review-multi-agent-review`
4. `debugging-toolkit-smart-debug` ↔ `error-diagnostics-smart-debug`
5. `codebase-cleanup-deps-audit` ↔ `dependency-management-deps-audit`
6. `codebase-cleanup-tech-debt` ↔ `code-refactoring-tech-debt`
7. `codebase-cleanup-refactor-clean` ↔ `code-refactoring-refactor-clean`
8. `code-refactoring-context-restore` ↔ `context-management-context-restore`
9. `slo-implementation` ↔ `observability-monitoring-slo-implement`
10. `framework-migration-legacy-modernize` ↔ `legacy-modernizer`

These read as a faceted skill-pack matrix (topic-prefix × shared task-suffix) rather than accidental copies. Two of these pairs now also carry Dependency Flags on one side (`code-refactoring-context-restore`, `legacy-modernizer` — see below), which raises the stakes of any future merge decision: collapsing the pair means updating those referrers too, not a bare delete. Worth a human pass to decide: keep both (different topic framing) or collapse into one canonical skill per task.

## Dependency Flags

Generated deterministically by `scripts/utils/skill-dependency-scan.sh` (word-boundary grep across all other skills' `SKILL.md` bodies, plus `hooks/`, `agents/`, `commands/`, `kiro/settings/rules/`, `scripts/routines/`, and `CLAUDE.md`), then intersected against this week's Low-Quality and Duplicate-Pair candidates. 17 candidates have at least one live referrer — none of these should be bare-deleted or merged-out without updating or removing each listed referrer first (per the `skill-curator` skill's "Delete + migrate references" action type).

| Skill | Candidate type | Referenced by |
|-------|----------------|----------------|
| `questions` | low-quality (3/12) | `active-observability`, `agent-harness-design` (7 hits) + 194 more — ⚠️ likely false positive, see caveat below |
| `codex-review` | low-quality (5/12) | `context7-auto-research`, `exa-search`, `firecrawl-scraper`, `tavily-web` |
| `context7-auto-research` | low-quality (6/12) | `codex-review`, `exa-search`, `firecrawl-scraper`, `tavily-web` |
| `exa-search` | low-quality (5/12) | `codex-review`, `context7-auto-research`, `firecrawl-scraper`, `tavily-web` |
| `firecrawl-scraper` | low-quality (5/12) | `codex-review`, `context7-auto-research`, `exa-search`, `tavily-web` |
| `tavily-web` | low-quality (5/12) | `codex-review`, `context7-auto-research`, `exa-search`, `firecrawl-scraper` |
| `aws-skills` | low-quality (5/12) | `cloud-devops` skill (2 hits) |
| `nanobanana-ppt-skills` | low-quality (5/12) | `office-productivity` skill |
| `nerdzao-elite` | low-quality (6/12) | `nerdzao-elite-gemini-high` skill (2 hits) |
| `screen-reader-testing` | low-quality (6/12) | `ui-skills` skill |
| `llm-application-dev-prompt-optimize` | low-quality (6/12) | `ai-ml` skill (2 hits) |
| `similarity-search-patterns` | low-quality (6/12) | `ai-ml` skill |
| `projection-patterns` | low-quality (6/12) | `domain-driven-design` skill |
| `code-refactoring-context-restore` | duplicate pair #8 | `agents/kiro/skill-augment-agent.md:58` |
| `code-refactoring-refactor-clean` | duplicate pair #7 | `goal-mode` skill |
| `legacy-modernizer` | duplicate pair #10 | `comprehensive-review-full-review`, `framework-migration-legacy-modernize` (2 hits) |
| `slo-implementation` | duplicate pair #9 | `distributed-tracing`, `grafana-dashboards`, `prometheus-configuration` |

**False-positive caveat**: `questions` is a common English word, so the word-boundary grep matches it inside ordinary prose ("... asks questions about ...") in 200+ other skill bodies, not genuine intentional references to the `questions` skill. This is a scan artifact, not real coupling — treat `questions` as an ordinary low-quality candidate, not a dependency-blocked one. The other 16 flags read as genuine (skill names, not common words, matched in "related skills" / "works well with" cross-reference lists or hook/agent code).

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | warn | Confirmed — `stop-hook.sh` now 271 lines (grown from last week) and appends to `observations.md` at multiple points (lines 45–54, 104–136, 183–213, 215–270, covering harness-update/loop-debt/learnings-promotion/stale-action/cache-cost checks). Still **zero reference** anywhere in the file to `memory-conventions.md` or any `rules/` path — same gap as last week, unchanged despite the file's growth |
| session-start catch-up logic | ok | `.claude/hooks/session-start-hook.sh` lines 33–37 read `.last-routine-run` and gate the daily catch-up correctly |
| memory-conventions.md intact | ok | 129 lines, not empty/truncated — but still exists as **two copies**: `kiro/settings/rules/memory-conventions.md` (mtime 2026-07-30) and `.claude/kiro/settings/rules/memory-conventions.md` (mtime 2026-08-04, newer). Same duplicate source-of-truth risk flagged last week, still unresolved |
| observations.md recency | ok | 19,780 bytes, mtime 2026-08-06 13:31 (today); last 3 entries all dated 2026-08-06 (`[keep-rate]`, `[friction, loop-debt]`, `[routine-note]`) |
| hot-memory.md recency | ok | mtime 2026-08-06 13:31 (today), well within the 14-day window |

Overall: **warn** — unchanged from last week. Nothing broken outright, but the same two issues persist one week later with no fix applied: `stop-hook.sh`'s missing conventions cross-reference, and the duplicate `memory-conventions.md` path. Worth escalating if a third consecutive week shows no movement.

---

Skill curator sweep complete: 991 skills audited, 74 flags, governance=warn
