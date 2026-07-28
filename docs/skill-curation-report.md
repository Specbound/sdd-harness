# Skill Curation Report — 2026-07-16

## Summary
- Skills audited: 72
- Low-quality flags (≤6/12): 0 (see methodology note)
- Duplicate pairs: 4 (+ 2 adjacent families flagged for review)
- Description flags (>150 chars): 67 (of which 🔴 >200: 55)
- Cold skills (no use in 30d): — | Archive candidates (90d): — (no usage data)
- Memory governance: ok

## Usage Evidence

No usage data yet — `logs/skill-usage.jsonl` does not exist. The `skill-usage-tracker.sh`
PostToolUse hook is either freshly installed or not yet registered in `settings.json`.
Deprecation/archive candidate lists cannot be computed this cycle. Deprecation decisions
must wait until real invocation evidence accumulates.

### Deprecate Candidates (no invocation in 30d)
None — no evidence layer available.

### Archive Candidates (no invocation in 90d)
None — no evidence layer available.

> **Action for the harness owner:** confirm `skill-usage-tracker.sh` is wired as a
> PostToolUse hook in `.claude/settings.json`. Until it fires, every weekly sweep will
> report "no usage data" and cold-skill pruning stays blind.

## Description Budget

Total: 72 skills | 18,602 chars | ~4,650 tokens | avg 258 chars/skill

This is resident system-reminder pressure — ~4.6k tokens of skill descriptions load on
every session. 55 of 72 descriptions (76%) exceed the 200-char 🔴 threshold. The budget
is the single largest mechanical win available; the human `/skill-curator` should
prioritize compressing the top of this table.

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
| adapt-to-repo | 338 | 🔴 |
| feature-list-primitive | 334 | 🔴 |
| setup-agent-replay | 332 | 🔴 |
| instruction-architecture | 325 | 🔴 |
| session-clean-state | 313 | 🔴 |
| local-llm-eval | 311 | 🔴 |
| frontend-slides | 311 | 🔴 |
| agent-harness-design | 306 | 🔴 |
| cag-implementation | 297 | 🔴 |
| pr-report | 296 | 🔴 |
| karpathy-guidelines | 294 | 🔴 |
| context-optimization | 284 | 🔴 |
| cma-outcomes | 280 | 🔴 |
| grill-with-docs | 278 | 🔴 |
| frontend-performance | 276 | 🔴 |
| secure-agent-design | 275 | 🔴 |
| git-safe-pull | 273 | 🔴 |
| ai-native-org-patterns | 256 | 🔴 |
| tool-design | 254 | 🔴 |
| evaluation | 250 | 🔴 |
| tool-failure-memory | 244 | 🔴 |
| rag-implementation | 241 | 🔴 |
| rtk-token-reduction | 238 | 🔴 |
| active-observability | 234 | 🔴 |
| better-call | 233 | 🔴 |
| gitnexus-pr-review | 231 | 🔴 |
| gitnexus-exploring | 231 | 🔴 |
| gitnexus-cli | 231 | 🔴 |
| gitnexus-guide | 230 | 🔴 |
| agent-identity | 230 | 🔴 |
| skill-creator | 219 | 🔴 |
| frontend-code-quality | 218 | 🔴 |
| prompt-engineering | 217 | 🔴 |
| skill-extraction | 215 | 🔴 |
| loop-patterns | 215 | 🔴 |
| csv-data-summarizer | 213 | 🔴 |
| paperclip-create-agent | 212 | 🔴 |
| gitnexus-refactoring | 212 | 🔴 |
| release | 210 | 🔴 |
| gitnexus-impact-analysis | 208 | 🔴 |
| ai-security-workflow | 206 | 🔴 |
| issue-triage-routing | 203 | 🔴 |
| ktx-data-context | 201 | 🔴 |
| storm-research | 197 | ⚠️ |
| proof-collaborative-review | 195 | ⚠️ |
| document-parsing | 193 | ⚠️ |
| hook-design | 185 | ⚠️ |
| model-tiers | 184 | ⚠️ |
| verification-skill-authoring | 181 | ⚠️ |
| gitnexus-debugging | 178 | ⚠️ |
| rag-architect | 168 | ⚠️ |
| ui-skills | 166 | ⚠️ |
| git-pushing | 160 | ⚠️ |
| prompt-quality-assess | 158 | ⚠️ |
| release-changelog | 154 | ⚠️ |
| skill-curator | 129 | ok |
| refactoring-safely | 109 | ok |
| test-driven-development | 79 | ok |
| instrument-agent | 74 | ok |
| questions | 55 | ok |

## Quality Findings

### Methodology note
This weekly sweep scored the four SkillOS dimensions at **frontmatter depth** —
trigger clarity, description budget, and file-size compression proxy — without a full
read of all 72 skill bodies (that read is the compression realism of an automated
weekly pass and belongs to the human-invoked `/skill-curator`). On the trigger-clarity
heuristic **no skill scored ≤6/12**: every description carries a clear "use when"
trigger with load-bearing nouns. The actionable signal this cycle is the duplicate
pairs and the description budget, not individual low scorers.

### Low-Quality Candidates
None flagged at ≤6/12. Watch items for the human deep-read pass (thin body or
narrowest scope — not yet failures): `questions` (5 lines, utility stub),
`instrument-agent` (74-char description, verify trigger discrimination vs
`setup-agent-replay`).

### Duplicate Pairs
- **adapt-to-repo ↔ skill-extraction** — strongest overlap. Both ingest an external
  link / article / post / idea and decide what (if anything) to apply to the repo, and
  both explicitly "filter redundancies." Routing between them is ambiguous; a model
  seeing a shared link could invoke either. Candidate for merge or a sharp boundary
  ("adapt = plan for *this* repo" vs "extract = install harness artifacts").
- **rag-architect ↔ rag-implementation** — design-a-RAG-pipeline vs build-a-RAG-system.
  The design/build split is real but the triggers overlap heavily ("design RAG
  pipelines" vs "implementing knowledge-grounded AI"). Review for merge into one skill
  with a design→build progression.
- **context-optimization ↔ context-degradation** — both own the "context" trigger
  surface. optimize-tokens/KV-cache vs diagnose-lost-in-middle/poisoning. Adjacent
  enough to co-fire; confirm the trigger nouns are disjoint.
- **prompt-engineering ↔ prompt-quality-assess** — quality-assess is a narrow
  pre-flight rubric that sits inside prompt-engineering's broad scope. Keep both only
  if the pre-flight gate is genuinely invoked on its own; otherwise fold into
  prompt-engineering.

### Adjacent Families (flagged for review, not dup pairs)
- **gitnexus-*** (7 skills: cli, debugging, exploring, guide, impact-analysis,
  pr-review, refactoring) — intentional task-split but 7 near-identical descriptions
  consume ~1,500 chars of budget. Consider whether `gitnexus-guide` can route to the
  others, letting the six task skills drop their descriptions to a one-liner.
- **agent-design cluster** (agent-harness-design / multi-agent-patterns /
  agent-execution-control) — three large agentic-design skills with overlapping
  activation ("designing an agentic system"). Boundaries are documented in the bodies;
  verify they don't co-fire on generic "design an agent" prompts.

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | ok | 3 `observations` refs in stop-hook.sh; observations.md appended today |
| session-start catch-up logic | ok | `.last-routine-run` catch-up trigger present (3 refs) |
| memory-conventions.md intact | ok | `kiro/settings/rules/memory-conventions.md` present, 121 lines |
| observations.md recency | ok | last entry: 2026-07-16 (today) |
| hot-memory.md recency | ok | last modified: 2026-07-16 (today) |

Minor note: `stop-hook.sh` contains no literal `memory-conventions` string — the rule
reference lives outside the hook (routine/settings layer). Observation-writing itself is
verified working (fresh entries today), so governance is **ok**, not warn.

## Iterative Repair Run — 2026-07-16

No repairs performed. The Low-Quality Candidates list (see § above) reads
**"None flagged at ≤6/12"** — this cycle's sweep scored at frontmatter depth and
found no skill below the repair threshold, so the Review→Repair→Validate loop had
no input. The four "watch items" noted for the human deep-read pass are triager
boundary/merge concerns, not low-quality bodies, and are out of scope for automated
repair.

| Skill | Before | After | Status |
|-------|--------|-------|--------|
| — | — | — | no candidates below ≤6/12 threshold |

Next repair run has input only if a future curation sweep does a full-body deep-read
and scores a skill ≤6/12.

## Iterative Repair Run — 2026-07-26

Re-checked the Low-Quality Candidates list before running the Review→Repair→Validate
loop: still **"None flagged at ≤6/12"** — no curation sweep between 2026-07-16 and
today re-scored any skill's full body, so there is no new input for Phase 2. Skipped
repair entirely rather than repairing against the stale frontmatter-depth scores from
the last full sweep.

| Skill | Before | After | Status |
|-------|--------|-------|--------|
| — | — | — | no candidates below ≤6/12 threshold |

Next repair run has input only once a curation sweep does a full-body deep-read and
scores a skill ≤6/12.
