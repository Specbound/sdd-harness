# Skill Curation Report — 2026-06-28

## Summary
- Skills audited: 980
- Low-quality flags: 3 stubs + 218 malformed-frontmatter (operational-validity)
- Duplicate pairs: 10 (true exact-description matches)
- Description flags (>150 chars): 577 (71 over 200, 506 in 150–200)
- Cold skills (no use in 30d): n/a — no usage data | Archive candidates (90d): n/a
- Memory governance: **ok**

> **Scope note.** `~/.claude/skills/` holds **980** skills — a bulk marketplace install, not a hand-curated set. Per-skill 4-dimension deep reads across 980 files is neither tractable nor useful in a weekly sweep, so the quality audit below is **mechanical**: frontmatter validity, stub detection, exact-duplicate descriptions, and the description budget. Subjective scoring is reserved for the human-invoked `/skill-curator`, which can target the harness's own ~40 skills.

## Usage Evidence
**No usage data yet** — `logs/skill-usage.jsonl` does not exist. The `skill-usage-tracker.sh` PostToolUse hook appears not to be installed/firing yet. Until it produces data, cold/archive deprecation cannot be evidence-based; deprecation is suspended.

### Deprecate Candidates (no invocation in 30d)
None determinable — no usage log.

### Archive Candidates (no invocation in 90d)
None determinable — no usage log.

## Description Budget

Total: 980 skills | 142,330 chars | ~35,583 tokens

> Block-scalar parsing caveat: the 218 malformed-frontmatter skills (see Quality Findings) undercount slightly because only their first description line is measurable. The real total is somewhat higher than 35.6k tokens.

| Bucket | Count | Status |
|--------|-------|--------|
| > 200 chars | 71 | 🔴 measurable system-reminder pressure |
| 150–200 chars | 506 | ⚠️ consider compression |
| ≤ 150 chars | 403 | ok |

### Longest descriptions (top 15 — compression targets)
| Skill | Chars | Status |
|-------|-------|--------|
| prompt-master | 444 | 🔴 |
| multi-agent-patterns | 435 | 🔴 |
| agent-execution-control | 431 | 🔴 |
| performance-engineer | 416 | 🔴 |
| get-api-docs | 411 | 🔴 |
| llm-fine-tuning | 379 | 🔴 |
| structured-web-dataset | 378 | 🔴 |
| progressive-complexity-ladder | 376 | 🔴 |
| agent-permissions-design | 356 | 🔴 |
| agentic-rl-tito | 355 | 🔴 |
| context-degradation | 349 | 🔴 |
| adapt-to-repo | 336 | 🔴 |
| feature-list-primitive | 332 | 🔴 |
| setup-agent-replay | 332 | 🔴 |
| instruction-architecture | 321 | 🔴 |

## Quality Findings

### Low-Quality Candidates
**Stubs (<200 char body — replace less context than they consume):**
- `cc-skill-continuous-learning` — 159-char body — near-empty, also a duplicate-description (see below)
- `cc-skill-strategic-compact` — 157-char body — near-empty, also a duplicate-description
- `questions` — 170-char body — minimal content

**Malformed YAML frontmatter (218 skills — operational-validity risk):**
22% of installed skills have a multi-line `description:` written as a closed quoted string followed by un-quoted continuation lines (213 `ParserError`, 5 `ScannerError`). Example (`ai-engineer`):
```yaml
description: "Build production-ready LLM applications, advanced RAG systems, and"
  intelligent agents. Implements vector search, ...
```
The Claude Code loader tolerates this, but any strict-YAML tooling (and accurate budget accounting) breaks on it. These are community-source bulk imports. Not urgent, but a portability/hygiene liability — a one-time `>-` block-scalar rewrite would fix all 218.

### Duplicate Pairs
True exact-description matches (the `azure-*`/`hig-*` mega-groups reported by naive parsing were false positives from block-scalar indicators, not real duplicates):

| Pair | Overlapping scope |
|------|-------------------|
| `code-documentation-doc-generate` ↔ `documentation-generation-doc-generate` | Identical doc-generation expert prompt |
| `code-refactoring-refactor-clean` ↔ `codebase-cleanup-refactor-clean` | Identical clean-code refactoring prompt |
| `code-refactoring-tech-debt` ↔ `codebase-cleanup-tech-debt` | Identical tech-debt expert prompt |
| `code-review-ai-ai-review` ↔ `performance-testing-review-ai-review` | Identical AI code-review prompt |
| `codebase-cleanup-deps-audit` ↔ `dependency-management-deps-audit` | Identical dependency-security prompt |
| `error-debugging-error-analysis` ↔ `error-diagnostics-error-analysis` | Identical error-analysis prompt |
| `mcp-builder-ms` ↔ `mcp-builder` | Both: high-quality MCP server build guide |
| `brand-guidelines-anthropic` ↔ `brand-guidelines-community` | Both: Anthropic brand colors/typography |
| `internal-comms-anthropic` ↔ `internal-comms-community` | Both: internal-comms writing resources |
| `cc-skill-continuous-learning` ↔ `cc-skill-strategic-compact` | Both: generic "development skill from everything-claude-code" stub |

Each pair collapses to one with no capability loss. Resolution belongs to human-invoked `/skill-curator`.

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | ok | References `.claude/memory/observations.md`, counts entries, nudges `/kiro:housekeeping` at >50. Hook manages the file (reflect/housekeeping agents write entries — by design). No `memory-conventions` string in stop-hook, but rule file is intact (next row). |
| session-start catch-up logic | ok | Daily-maintenance catch-up present; reads `STATE_FILE=.claude/memory/.last-routine-run`, fires if >24h stale. |
| memory-conventions.md intact | ok | `kiro/settings/rules/memory-conventions.md` present, 121 lines — not emptied/truncated. |
| observations.md recency | ok | Last entry: 2026-06-28 (today); mtime 2026-06-28 08:56. |
| hot-memory.md recency | ok | Last modified: 2026-06-28 08:55 (today). |

## Recommended Actions (for human-invoked `/skill-curator`)
1. **Install/verify** `skill-usage-tracker.sh` PostToolUse hook — without it, no deprecation evidence accrues and every weekly sweep stays blind on cold-skill detection.
2. **Dedupe** the 10 exact pairs → keep one each.
3. **Delete or fill** the 3 stubs (`cc-skill-continuous-learning`, `cc-skill-strategic-compact`, `questions`).
4. **Batch-fix** the 218 malformed-YAML frontmatters with a `>-` block-scalar rewrite script.
5. **Compress** the 71 descriptions over 200 chars (start with the top-15 table) — recovers system-reminder budget on every session.
