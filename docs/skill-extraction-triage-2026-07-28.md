# Skill-Extraction Triage — 28 Sources

**Date:** 2026-07-28
**Method:** Parallel fetch (5 subagents, batched by theme) → harness cross-reference → value-critic gate
**Default posture:** skip. Only items that fill a real gap and earn maintenance cost are proposed.
**Status:** ✅ IMPLEMENTED 2026-07-28 — Tier 1 + all Tier 2 landed (14 of 15 approved items; item 28/Flint was found already covered by a prior pass, no new edit needed). See "Implementation Results" at the bottom.

---

## Verdict Summary

| # | Source | Type | Verdict | Best home |
|---|--------|------|---------|-----------|
| 24 | Anthropic — Agent Skills Best Practices (official docs) | docs | **INGEST** | reconcile `skill-creator` + `skill-extraction` SkillOS gates |
| 26 | SkillsBench (paper, 2602.12670) | paper | **INGEST** | augment `skill-creator`/`skill-curator` (≤3-module cap) + `model-tiers` |
| 8 | cursor/plugins — show-me-your-work SKILL.md | repo | **INGEST** | augment `verification-skill-authoring` (decision log + cross-model review gate) |
| 21 | "When is Routing Meaningful?" (paper, 2607.09197) | paper | **INGEST** | augment `multi-agent-patterns` + `evaluation` (agent-count cap, perturbation-robustness test) |
| 5 | Graph Engineering vs Loop Engineering | article | **MINE** | 4-question loop→graph gut-check → `loop-patterns` |
| 7 | AI-Native Code Review (agentfield.ai) | article | **MINE** | risk-telescope + adversarial FP suppression → `code-review-excellence` |
| 15 | Designing APIs for Agents (freestyle.sh) | article | **MINE** | 4 naming/error/explicitness principles → `api-design-principles`/`tool-design` |
| 2 | raptor-loop-hunt | repo | **MINE** | disposition ledger + monotonic KB → `verify`/`loop-patterns` |
| 4 | fractal | repo | **MINE** | per-node resource caps at spawn → `dispatching-parallel-agents`/`parallel-agents` |
| 16 | 3 Techniques to Reduce Token Consumption | article | **MINE** | code-graph-before-grep + subagent token-cap → `rtk-token-reduction` |
| 25 | Self-Improvements in Modern Agentic Systems (paper, 2607.13104) | paper | **MINE** | update-target/change-signal taxonomy → formalize `skill-curator`/memory-consolidation loop |
| 22 | Generative Skill Composition (paper, 2606.32025) | paper | **MINE** | joint skill-selection-in-one-pass principle → `skill-extraction`/`using-superpowers` |
| 10 | 12-factor-agents (humanlayer) | repo | **MINE (verify-only)** | confirm factors 5/9/12 already in `agent-harness-design`/`agent-execution-control` |
| 28 | Flint (Microsoft Research) | article | **MINE (one-liner)** | semantic-type-first chart-spec principle → `dataviz` |
| 6 | Thariq — Claude Code workflow (YouTube) | video | **MINE (low-confidence)** | verify `goal-mode` already covers `/goal`; search-derived summary only |
| 1 | OpenAI — How AI is Expanding What People Do at Work | article | **SKIP** | labor-economics finding, no technique |
| 3 | AI Agents 101 (aibuilderclub) | article | **SKIP** | fully redundant with existing agent-* skill family |
| 12 | block/buzz | repo | **SKIP** | full heavyweight platform (Nostr relay + DB + clients), not a lightweight technique |
| 14 | topoteretes/cognee | repo | **SKIP** | redundant with `memory-systems`/`agent-memory-*` family |
| 11 | ion-design/ditto.site | repo | **SKIP** | full infra product (browser-automation service), not extractable |
| 19 | rohitg00/ai-engineering-from-scratch | repo | **SKIP** | curriculum, not a technique source |
| 20 | claude.ai artifact bfdfaef9... | artifact | **SKIP** | inaccessible — public-reader mode not enabled, could not load |
| 9 | 4 Free Repos That Cut Token Usage (YouTube) | video | **SKIP** | inaccessible — no transcript/description retrievable |
| 18 | jarrodwatts/claude-hud | repo | **SKIP** | real, install-directly tool — not a technique to re-encode |
| 22b | Shubhamsaboo/awesome-llm-apps | repo | **SKIP** | generic idea catalog; no active RAG-building work in this harness to justify mining it |
| 23 | Houseofmvps/codesight | repo | **SKIP** | blast-radius/precompiled-context already covered by existing `gitnexus-*` family |
| 25b | benchflow-ai/skillsbench (repo) | repo | **SKIP** | duplicates the SkillsBench *paper*'s actionable point — don't double-count |
| 17 | oliver-kriska/scribe | repo | **SKIP** | density-prefilter idea is marginal; whole tool redundant with `agent-memory-consolidation` |

**Tally:** 4 INGEST · 11 MINE · 13 SKIP

---

## TIER 1 — INGEST (clear gap, worth full implementation)

### 24. Anthropic — Agent Skills Best Practices (official docs)
The canonical source the harness's own skill-authoring gates should be reconciled against. Concrete, checkable rules that appear to be gaps in `skill-creator`/`skill-extraction`'s SkillOS Quality Gate:
- **Gerund-form naming** (`processing-pdfs`, not `pdf-tools`) — not confirmed as an enforced rule.
- **Third-person description mandate** ("Processes X," never "I can help..."/"You can use...").
- **"One level deep" reference rule** — SKILL.md → ref files must link directly, no nested chains (avoids partial `head -100` reads). The current ≤5000-word gate checks length, not reference depth.
- **Table-of-contents requirement** for any reference file >100 lines.
- **Eval-driven development**: build ≥3 evaluation scenarios *before* writing the skill, establish a no-skill baseline, iterate against it.
- **Explicit per-model-tier testing** (Haiku/Sonnet/Opus) with distinct pass criteria.
- **"Solve, don't defer" / no voodoo constants** for bundled scripts — justify every magic number/timeout.
- **MCP fully-qualified tool naming** (`ServerName:tool_name`) to avoid ambiguous lookups.

**Proposal:** augment `skill-creator` and `skill-extraction`'s Phase 5b (SkillOS Quality Gate) with a fifth dimension or checklist items covering the above. Small diff, high leverage — every future skill this harness creates benefits.

### 26. SkillsBench (arXiv 2602.12670)
87-task, 8-domain benchmark: curated skills lift pass rate 33.9%→50.5%, and **"Focused Skills with at most three modules outperform larger or exhaustive bundles."** Also: smaller model + good skill ≥ larger model, no skill.

**Proposal:** add the ≤3-module cap as an explicit constraint in `skill-creator`'s authoring checklist and `skill-curator`'s audit criteria (flag skills exceeding it). Add the "curated skill can substitute for a bigger model" framing to `model-tiers` as a routing consideration.

### 8. cursor/plugins — show-me-your-work SKILL.md
A small, fully-formed, directly adoptable Claude Code skill: append-only TSV decision log (timestamp/phase/decision/rationale/evidence-pointer/result) for long-running work, reviewed by a *different model family* before the work is declared complete, flagging weak evidence in an "Attention" section.

**Proposal:** augment `verification-skill-authoring` (and/or `verify`) with this as a concrete implementation mechanism for the independence-budgeting concept already landed there from the 2026-07-14 triage. The cross-model review gate and evidence-pointer discipline (commit SHAs/file paths/test results, not prose) are the new pieces.

### 21. "When is Routing Meaningful?" (arXiv 2607.09197)
Multi-agent routing needs eval beyond accuracy: behavioral diversity and stability under perturbation. Key finding: diminishing returns past **~10 curated agents**; prompted/rule-based routers stay robust under perturbation where learned (KNN-style) routers get fragile.

**Proposal:** augment `multi-agent-patterns` with the diversity-diminishing-returns heuristic (cap subagent-type roster, prune redundant specializations) and add a perturbation-robustness check (rephrase a task, confirm routing stays consistent) to `evaluation` as a lightweight periodic test.

---

## TIER 2 — MINE (extract one piece, discard the rest)

### 5. Graph Engineering vs Loop Engineering
Keep the **4-question gut-check** for promoting a loop to a graph (specialized contexts? real fan-out/fan-in? routing as diagram? changed success criteria? — 0-1 yes = relabeled loop). → augment `loop-patterns`.

### 7. AI-Native Code Review
Keep: **"risk telescope"** framing (per-dimension tunable thresholds instead of binary pass/fail) and the **adversarial false-positive-suppression** step before surfacing findings. → augment `code-review-excellence` (and/or `security-review`).

### 15. Designing APIs for Agents
Keep four concrete principles: explicit-over-defaults, strict/precise error messages, unambiguous field naming, "facts not utilities" (expose primitives over SDK wrappers). → augment `api-design-principles`/`tool-design` as an "agent-consumer API" checklist.

### 2. raptor-loop-hunt
Keep: **disposition ledger** (candidate→verified/rejected state machine with evidence receipts, preventing re-litigation) and **monotonic knowledge base** (persistent dedup across repeat runs). → augment `verify`/`loop-patterns` for any iterative audit-style loop.

### 4. fractal
Keep: **per-node hard resource caps at spawn time** (max iterations/depth/children/cost/time) as a circuit breaker for recursive/nested delegation. → augment `dispatching-parallel-agents`/`parallel-agents`, which currently lack an explicit spawn-time cap convention.

### 16. 3 Techniques to Reduce Token Consumption
Keep: **code-graph/structural-index tool before Grep/Glob** ("map, not phone book") and the **subagent token-cap convention** (bounded model + tool allowlist + capped reply length). → augment `rtk-token-reduction`.

### 25. Self-Improvements in Modern Agentic Systems (survey)
No single algorithm, but the **update-target × change-signal taxonomy** is a useful lens to formalize how the harness's existing self-improvement loops (`skill-curator`, memory consolidation, `claudemd-review`) already work, and to spot gaps. → light augmentation, mostly a framing note, not new mechanics.

### 22. Generative Skill Composition (paper)
The constrained-decoding mechanism isn't portable without logit access, but the underlying principle — **decide the full skill subset + order in one pass, not by sequential retrieval** — is a real, encodable prompting pattern. → augment `skill-extraction`/`using-superpowers` guidance on multi-skill tasks (relevant to this very triage: it batched by theme rather than fetching serially).

### 10. 12-factor-agents (verify-only)
Well-known guide; likely already covered by the 2026-07-14 triage's `agent-harness-design`/`agent-execution-control` landings. Recommend a cheap diff pass on factors 5 (unify execution/business state), 9 (compact errors into context), 12 (stateless-reducer step function) to confirm coverage — not a fresh ingest.

### 28. Flint (Microsoft Research) — one-liner
Principle: **separate semantic data-spec from chart-spec**, let the LLM infer semantic types and have deterministic code derive scale/color/layout — reduces parameter-guessing errors. → one-line note in `dataviz`.

### 6. Thariq — Claude Code workflow video (low confidence)
Summary is search-derived, not primary-source verified (WebFetch couldn't pull transcript). If accurate: `/goal`-style persistent objective, plan-before-build "remove unknowns" pass, 80% system-prompt trim. Worth a real verification pass only if you want it — recommend checking whether `goal-mode` already encodes the `/goal` pattern before doing anything else here.

---

## TIER 3 — SKIP (with reason)

| # | Source | Reason |
|---|--------|--------|
| 1 | OpenAI — How AI is Expanding What People Do at Work | Labor-economics research finding (task crossover %), no agent/harness technique. |
| 3 | AI Agents 101 (aibuilderclub) | 101-level content, fully redundant with `agent-harness-design`/`multi-agent-patterns`/`loop-patterns`/`model-tiers`. |
| 12 | block/buzz | Full multi-service product (Nostr relay + Postgres/Redis/S3 + desktop/mobile clients) — infra, not a technique. |
| 14 | topoteretes/cognee | Heavyweight memory platform duplicating `memory-systems`/`agent-memory-*`; the remember/recall/forget/improve verb framing is too thin to justify on its own. |
| 11 | ion-design/ditto.site | Full standalone infra product (Playwright capture service + codegen queue), not a lightweight extractable technique. |
| 19 | rohitg00/ai-engineering-from-scratch | Educational curriculum, not an automation technique. |
| 20 | claude.ai artifact bfdfaef9... | Fetch failed: "served as a public (non-member) reader... not enabled yet." Inaccessible without owner re-sharing or an authenticated claude.ai session. |
| 9 | YouTube — 4 Free Repos That Cut Token Usage | WebFetch/WebSearch returned only title, no transcript or description. Nothing to triage without actually watching it. |
| 18 | jarrodwatts/claude-hud | A real, maintained statusline plugin — if you want this, install it directly rather than re-encoding it as a harness artifact. |
| — | Shubhamsaboo/awesome-llm-apps | Generic curated idea catalog (100+ apps); the harness has no active RAG-building work right now to justify mining corrective-RAG/trust-gated-audit patterns from it. |
| — | Houseofmvps/codesight | Blast-radius-via-import-graph and precompiled-context-file are already the `gitnexus-*` skill family's job. |
| — | benchflow-ai/skillsbench (repo) | Same actionable idea as the SkillsBench *paper* above (oracle-validation, multi-skill composition) — counted once, under Tier 1 item 26. |
| 17 | oliver-kriska/scribe | Density-prefilter/two-pass idea is marginal; the tool itself duplicates `agent-memory-consolidation`. |

---

## Recommendation

Value-density order:
1. **Tier 1 (24, 26, 8, 21)** — four items, each a clean augmentation to an existing skill (`skill-creator`+`skill-extraction`, `skill-curator`+`model-tiers`, `verification-skill-authoring`, `multi-agent-patterns`+`evaluation`). Highest confidence, lowest maintenance cost.
2. **Tier 2 quick wins (5, 7, 15, 28)** — one-paragraph-sized augmentations, low cost.
3. **Tier 2 larger (2, 4, 16, 25, 22)** — still augmentations to existing files, slightly more substantive edits.
4. **Tier 2 verify-only (10, 6)** — no new content unless the diff finds an actual gap; cheapest possible action is "check and report back."

Everything in Tier 3 is closed.

**Next step:** tell me which tiers/items to implement (e.g. "do Tier 1", "Tier 1 + items 5 and 7", "just 26 and 8"). I'll run each through the value-critic + augmentation-first check, show the exact diff before writing, and log provenance to `docs/sources/<category>/README.md` per item.

---

## Implementation Results (2026-07-28)

Implemented via 9 subagents partitioned by **target file** (disjoint sets → no write conflicts), same pattern as the 2026-07-14 batch. Several proposed homes weren't harness-owned skills — they're community/marketplace packages installed to `~/.claude/skills/` outside the harness source tree (`code-review-excellence`, `api-design-principles`, `dataviz`, `verify`, `dispatching-parallel-agents`, `parallel-agents`, `goal-mode`, `using-superpowers`, `security-review`) — so those items were redirected to the closest harness-owned equivalent instead of editing third-party content:

| Proposed home | Redirected to | Item |
|---|---|---|
| `code-review-excellence` | `agents/kiro/guardrails-agent.md` | 7 (AI-Native Code Review) |
| `api-design-principles` | `tool-design` | 15 (Designing APIs for Agents) |
| `verify` | `loop-patterns` | 2 (raptor-loop-hunt) |
| `dispatching-parallel-agents` / `parallel-agents` | `multi-agent-patterns` | 4 (fractal) |
| `goal-mode` | `agent-harness-design` (Agent-Run Contract) | 6 (Thariq video, low-confidence) |

**Duplicate found:** item 28 (Flint) turned out to already be fully ingested — `tool-design` already had the intent-vs-compiler section (with "Sources added: ... Microsoft Flint") from the 2026-07-14 pass. No edit made; not double-counted.

**Files touched (12, all augmentations — no new skills created):**
| File | Items | What landed |
|------|-------|-------------|
| `skills/skill-creator/SKILL.md` | 24, 26 | Gerund naming, third-person description, one-level-deep refs, TOC rule, eval-driven dev, per-tier testing, script-constant justification, MCP qualified naming, ≤3-module cap |
| `skills/skill-extraction/SKILL.md` | 24, 22 | Joint skill-composition-in-one-pass principle (Step 3a); SkillOS gate table reconciled against official Anthropic checklist |
| `skills/skill-curator/SKILL.md` | 26, 25 | Module-count audit + new Split action-type row; self-improvement-taxonomy framing note |
| `skills/model-tiers/SKILL.md` | 26 | Skill-curation vs. model-escalation as competing levers |
| `skills/verification-skill-authoring/SKILL.md` | 8 | show-me-your-work TSV decision log + cross-model review gate as an optional template for independence-budgeting |
| `skills/multi-agent-patterns/SKILL.md` | 21, 4 | Roster-size/router-robustness cap (~10 agents); spawn-time resource caps for nested coordinators |
| `skills/evaluation/SKILL.md` | 21 | Perturbation-robustness test for task routers |
| `skills/loop-patterns/SKILL.md` | 5, 2 | Loop→graph 4-question gut-check; disposition-ledger + monotonic-KB cross-run state guardrail |
| `skills/tool-design/SKILL.md` | 15 | Agent-Facing API Design Checklist (explicit-over-defaults, strict errors, unambiguous naming, facts-not-utilities) |
| `agents/kiro/guardrails-agent.md` | 7 | Risk-telescope per-dimension thresholds + adversarial false-positive suppression, composed with the existing PR Auto-Approve Gate |
| `skills/rtk-token-reduction/SKILL.md` | 16 | Structural-index-before-Grep; subagent token-cap convention |
| `skills/agent-harness-design/SKILL.md` + `skills/agent-execution-control/SKILL.md` | 10, 6 | Factor 5 (unified state) + Factor 12 (stateless reducer) from 12-factor-agents; low-confidence `/goal` cross-reference. Factor 9 was already covered — no edit. |

**Synced for this session:** all 12 harness-source files copied to their live `~/.claude/skills/<name>/SKILL.md` counterparts (real directories, not symlinks) so the changes are active immediately.

**Open follow-ups:**
- Not yet rolled out to other repos — run `bash ~/.claude/sdd-harness/update.sh` to propagate (also handles `agents/kiro/guardrails-agent.md`, which has no global `~/.claude/agents/` install path found in this environment; update.sh's existing copy logic is the source of truth for wherever it's meant to land).
- `context-optimization/SKILL.md` was checked (read-only) as part of the Thariq-video verify pass and already covers system-prompt-length minimization — no gap, no edit.

**Provenance logged:** `docs/sources/git/README.md` (4 entries), `docs/sources/papers/README.md` (4 entries), `docs/sources/articles/README.md` (6 entries).
