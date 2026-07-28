# Skill-Extraction Triage — 21 Sources

**Date:** 2026-07-14
**Method:** Parallel fetch (6 subagents) → harness cross-reference → value-critic gate
**Default posture:** skip. Only items that fill a real gap and earn maintenance cost are proposed.
**Status:** ✅ IMPLEMENTED 2026-07-28 — Tier 1 + Tier 2 all landed (14 items). Tier 3 closed. See "Implementation Results" at the bottom.

---

## Verdict Summary

| # | Source | Verdict | Best home |
|---|--------|---------|-----------|
| 3 | Addy Osmani — Agentic Autonomy Levels | **INGEST** | augment `agent-harness-design` + `multi-agent-patterns` |
| 4 | Dan Luu — AI coding notes | **INGEST** | augment `multi-agent-patterns` + `agent-execution-control` + `loop-patterns` |
| 6 | Thariq — Field Guide to Fable (unknowns) | **INGEST** | new skill `surfacing-unknowns` OR augment `brainstorming`/`spec-design` |
| 9 | Kieran Klaassen — Closing the Verification Loop | **INGEST** | augment `verify` / new `dogfood` skill |
| 12 | Databricks — benchmarking coding agents | **INGEST** | augment `evaluation` / `macro-eval-sweep` |
| 1 | LMSYS — Agent-Assisted SGLang | **MINE** | anti-reward-hacking checklist → `evaluation`/`agent-execution-control` |
| 11 | PostHog — code review tips | **MINE** | StampHog fail-closed gate → `guardrails` |
| 14 | github/spec-kit | **MINE** | `/converge` spec↔code reconciliation → new `kiro:converge` |
| 21 | google/mantis | **MINE** | learning-loop + sandboxed-repro → `ai-security-workflow`/`reflect` |
| 20 | ClaudeDevs — model vs effort | **MINE** | diagnostic → augment `model-tiers` |
| 19 | LangChain — OpenWiki-Brains | **MINE** | proactive/reactive + connector taxonomy → `para-memory-files` |
| 10 | Aparna Dhinakaran — agent-as-judge | **MINE** | trajectory-eval + coupling-risk → `evaluation`/`agent-harness-design` |
| 15 | Microsoft — Flint | **MINE** | intent-vs-compiler principle → `tool-design`/`dataviz` |
| 18 | Agent Cookbook — 18 settings | **MINE (verify first)** | verified subset → `update-config`/`context-optimization` |
| 2 | Elliot Smith — autoresearch | **SKIP** | already `/kiro:autoresearch` |
| 5 | Theo — Codex delegation | **SKIP** | personal, cross-vendor |
| 7 | davidondrej/skills | **SKIP** | generalist overlap |
| 8 | EXM7777 — 25 loops | **SKIP** | marketing hype |
| 13 | Yangshun — frontend perf checklist | **SKIP** | covered by `frontend-performance` |
| 16 | Jamon Holmgren — agentic setup | **SKIP** | corroboration only |
| 17 | davila7/claude-code-templates | **SKIP** | beginner catalog, browse not extract |

**Tally:** 5 INGEST · 9 MINE · 7 SKIP

---

## TIER 1 — INGEST (high value, clear gap)

### 3. Addy Osmani — Agentic Autonomy Levels
Two-axis autonomy model (Agency × Orchestration), six levels across three eras. The extractable gold is operational, not the taxonomy:
- **Agent-run "contract"**: goal (outcome not activity) · scope/non-goals · tools/permissions · stopping conditions · evidence requirements · escalation · budget (tokens/attempts/parallelism).
- **Three questions before granting high autonomy**: how fast do problems surface? how cleanly can work be undone? what independently verifies success?
- **Four anti-patterns**: autonomy-as-status · permission laundering · summary substitution · fleet cosplay.

**Gap it fills:** `agent-harness-design` has temporal scaling tiers but no explicit *contract* schema or the anti-pattern list. `multi-agent-patterns` warns of goal drift / laziness but lacks "calibrated autonomy / move up one axis at a time."
**Proposal:** augment `agent-harness-design` with the contract schema + 3 questions; add the 4 anti-patterns to `multi-agent-patterns`.

### 4. Dan Luu — AI coding notes (agentic loops appendix)
Highest-novelty source. Practitioner-grounded, empirical:
- **Forced execution beats independent cross-checking**: pure explanation was wrong ~50% of the time; forcing the agent to *run code to confirm its hypothesis* removed most errors. Doing both is best.
- **Persona ensemble** with contrarian personas (verbatim: "review as linus torvalds, kyle kingsbury, marc brooker, tptacek, dan luu, and 4 contrarian personas") — each counteracts a specific loop pathology; improved output at equal token budget.
- **Fuzz invariants, don't "write tests"**: "look for risky areas… find invariants that might be violated and fuzz them."
- **Build bespoke loops, not heavyweight orchestrators** — a loop only needs to be correct for *your* workflow.
- **Loops degrade without a human** nudging; no fully autonomous loop yet replaces the operator.

**Gap it fills:** `agent-execution-control` has Plan-Execute-Verify but not the "forced execution > cross-checking" empirical rule. `multi-agent-patterns` has adversarial validation but not the *contrarian persona ensemble* as a named pattern.
**Proposal:** augment `agent-execution-control` (forced-verification rule), `multi-agent-patterns` (contrarian persona ensemble), and `loop-patterns` (fuzz-invariants + build-bespoke-loop).

### 6. Thariq (trq212) — Field Guide to Fable: Finding Your Unknowns
Pre-execution discovery techniques, framed via the four-quadrant unknowns model:
- **Blind-spot pass** — "do a blind spot pass to help me figure out my relevant unknown unknowns," pointed at diffs/docs/threads.
- **Design-prototypes to extract tacit taste** — "make me a page with four widely different design decisions so I can react" (reaction beats description).
- **Architecture interview** — "interview me one question at a time; prioritize questions where my answer changes the architecture."
- **Implementation-deviation logging** — have the agent log decisions you didn't specify; those reveal model↔reality divergence.
- **Pre-merge quizzing** — agent quizzes you on the change before approval (comprehension over rubber-stamp).

**Gap it fills:** `brainstorming` and the `questions` skill do requirement elicitation, but none of these five discovery moves are named/encoded. `spec-design` has a discovery process but not "blind-spot pass" or "deviation logging."
**Proposal:** strongest case for a **new skill** `surfacing-unknowns` (or augment `brainstorming` + `spec-design`). Recommend new skill — it's a coherent, reusable pre-execution routine.

### 9. Kieran Klaassen — Closing the Verification Loop
Seven-phase autonomous-QA skill, densely actionable:
- **Flows-before-Matrix ("The Email Rule")**: "the breakage lives between the pages" — map user-visible changes as flows before deriving test scenarios.
- **Dual judges**: functional (browser-driven) + experiential (persona re-read, hunting "paper cuts").
- **Fix-Loop Governor**: "judge the size of the fix before touching code; escalate what is not yours to decide." Auto-fix only when clear bug + obvious fix + few files + no schema/arch/product trade-off.
- **Every fix ships a regression test designed to fail-before / pass-after.**
- **Independence-budgeting**: "a finding is only as trustworthy as the independence of whoever confirmed it" — orchestrator self-pass capped at low confidence.
- **Blocked states** for legs the browser can't drive; **resumable** via disk report.

**Gap it fills:** the `verify` skill drives change end-to-end but lacks flows-before-matrix, the dual-judge split, the fix-loop governor, and independence-budgeting. `verification-skill-authoring` could absorb these as authoring guidance.
**Proposal:** augment `verify` + `verification-skill-authoring` with flows-before-matrix, fix-loop governor, and independence-budgeting confidence cap.

### 12. Databricks — Benchmarking Coding Agents on a Multi-Million-Line Codebase
Concrete eval methodology from real merged PRs:
- **Real-PR → prompt benchmark recipe**: filter PRs (exclude bot/AI/auto-generated, require good tests, self-contained) → extract intent, strip solution → isolate tests → human review → **rewrite tests to allow alternative implementations** (anti-overfit).
- **Execution-based grading, no LLM judge** — checkpoint code, patch tests back, run for pass/fail.
- **Git-history sealing anti-cheat** — "cut the working copy off from the repository entirely" so agents can't read the solution from commits.
- **Harness > model**: same model + different harness = >2x cost swing. Rank by **cost-per-completed-task**, not per-token.

**Gap it fills:** `macro-eval-sweep` / `evaluation` do population-scale trace analysis but have no benchmark-*construction* recipe or the anti-cheat controls.
**Proposal:** augment `evaluation` (or a `benchmark-construction` resource) with the real-PR recipe + git-history sealing + cost-per-task ranking principle. Also a quotable line for `agent-harness-design`/`model-tiers`: "harness matters as much as the model."

---

## TIER 2 — MINE (extract specific pieces / augment; discard the rest)

### 1. LMSYS — Agent-Assisted SGLang
Keep: **anti-reward-hacking containment** (identical ABI/build/flags for baseline vs candidate; interleaved timing; correctness gates; invalidate a trace if the backend silently changed) and **hard machine-checkable exit conditions** ("a single sentence claiming task complete is not enough to exit"). Discard the GPU-kernel-specific profiling tables. → augment `evaluation` + `agent-execution-control`. The 5-question skill schema overlaps `skill-creator` — skip.

### 11. PostHog — Code Review Tips
Most of it corroborates existing rules (reviewer≠author, qa-swarm, verify-by-observation). Keep the **one new artifact**: the StampHog **fail-closed auto-approve gate** — no merge conflicts / no change-requests · deny-list keywords (auth, secrets, billing, public APIs) · **< 500 lines AND < 20 files** · LLM showstopper check · route complex → SME. → augment `guardrails` as a PR auto-approve governance checklist.

### 14. github/spec-kit
Heavy overlap with the `kiro:` SDD suite (1:1 on init/requirements/design/tasks/impl). Mine only the genuine gaps: **`/speckit.converge`** (validate live codebase against the spec — kiro validates impl but has no spec↔code *reconciliation*) and **`/speckit.analyze`** (cross-artifact consistency across spec/plan/tasks vs. `harness-validate` which is structural only). → propose new `kiro:converge`; consider folding analyze into `harness-validate`. `taskstoissues` complements `jira-solve` but is lower priority.

### 21. google/mantis
Security-domain-specific but two architectural patterns transcend it: **durable machine-readable cross-run learning loop** (`mantis_reflect` → `historical_learnings.jsonl` → `mantis_history` feeds next planning cycle) and **sandboxed-reproduction verification** (`mantis_critic`/`mantis_reproduce` prove findings by actually reproducing, not just testing). → the learning-loop pattern could sharpen `reflect`/`learn-eval`; the 15-stage JSON-state pipeline is a strong exemplar for `ai-security-workflow`. Domain-specific → augment, don't adopt wholesale.

### 20. ClaudeDevs — Model vs Effort
Crisp diagnostic (official Claude Code content): **model changes what Claude knows; effort changes how much work it does.** When wrong, ask "did it not know enough, or not try hard enough?" → bump model vs. raise effort; fix context first. → augment `model-tiers` with this diagnostic. Low cost, high clarity.

### 19. LangChain — OpenWiki-Brains
Mostly corroborates file-based Markdown memory. Keep two framings: **proactive vs. reactive memory** (agent fetches/maintains its own context vs. user hands it) and **deterministic vs. agentic connectors** (auto-fetch feeds vs. goal-directed search tools). → augment `para-memory-files` vocabulary; a scheduled connector-refresh routine is a possible future item, not now.

### 10. Aparna Dhinakaran — Agent-as-a-Judge / Own the Loop
Keep: **evaluate trajectories, not just final outputs** (agents fail in sequences — stuck loops, dropped context, broken tool calls behind a plausible answer) and **harness↔model coupling = portability risk**. → trajectory-eval framing augments `evaluation`; coupling-risk note augments `agent-harness-design`. Partly covered by `active-observability` + Raindrop trace tools.

### 15. Microsoft — Flint
The tool is niche; the **principle** transfers: have the LLM emit terse high-level *intent* + semantic types, and let deterministic code derive the fragile low-level params (scales, formatting, layout). Reduces tokens and error surface. → augment `tool-design` (intent-vs-config pattern) and note in `dataviz`. `flint-chart-mcp` is an optional future MCP, not an extraction.

### 18. Agent Cookbook — 18 Claude Settings
Mixed reliability — **verify before encoding anything.** Real & useful: MCP `enabled` flag (each server loads 800–6k tokens), `cache_control` breakpoint placement + TTL economics, `permissions.deny` patterns (`.env`, `**/*secret*`, `rm -rf`, `sudo`), per-project `model` override, `hooks.SessionStart` context loading. Suspect/likely fabricated: `inference_geo`, "US residency 10% premium," "Dreaming signal," `cleanupPeriodDays: 180`. → cross-check the real subset against `claude-api` + actual `settings.json` schema, then augment `update-config` / `context-optimization`. **Do not encode unverified claims.**

---

## TIER 3 — SKIP (with reason)

| # | Source | Reason |
|---|--------|--------|
| 2 | Elliot Smith — autoresearch | The harness already has `/kiro:autoresearch` (command + agent + init). "Single measurable objective," "models race to be done," clean-context loop are already the design. Nothing to add beyond a one-line aphorism. |
| 5 | Theo — Codex delegation | A personal hybrid workflow routing execution to Codex. The harness is Claude-native; cross-vendor delegation isn't its model. Anecdote, not extractable technique. |
| 7 | davidondrej/skills | Solo-dev generalist kit; the harness has stronger equivalents (skill-creator, loop-patterns, deep-research, instruction-architecture). Only `fable-safe-prompt`/`goal-loop` are marginally distinctive — not worth the maintenance. |
| 8 | EXM7777 — 25 loops | Marketing/hype promo. The only idea (loop = flow-map+prompt+tool+KPI) is already in `loop-patterns`' loop-contract format. |
| 13 | Yangshun — frontend perf checklist | Performance-101; every item already in `frontend-performance`. Hollow addition. |
| 16 | Jamon Holmgren — agentic setup | Corroboration only. Router AGENTS.md → `instruction-architecture`; self-healing docs → `sync-docs`; run-the-app → `verify`; persona reviewers → `multi-agent-patterns`; diagnose-which-doc-misled → `harness-fix`; traces → `save-session`. All already covered. |
| 17 | davila7/claude-code-templates | Community aggregator for beginners. Its one distinctive angle (`--analytics`/`--chats`/`--health-check` monitoring) is adjacent to the dashboard + Raindrop. Browse the K-Dense science catalog if a specific skill is ever missing; don't extract now. |

---

## Recommendation

Approve in this order of value density:
1. **Tier 1 augmentations** (3, 4, 6, 9, 12) — five edits, four of them into existing skills; item 6 is the one new-skill candidate (`surfacing-unknowns`).
2. **Tier 2 quick wins** (20 model-vs-effort, 11 StampHog gate, 1 anti-reward-hacking) — small, high-clarity edits.
3. **Tier 2 larger** (14 `kiro:converge`, 21 learning-loop, 12 benchmark recipe) — these are new commands/sizeable augments; treat each as its own approval.

Item 18 gated behind schema verification. Everything in Tier 3 is closed.

**Next step:** tell me which tiers/items to implement (e.g. "do Tier 1", "Tier 1 + items 20 and 11", "just 6 and 9"). I'll then run each through the value-critic + `better-call` where an incumbent exists, and propose the exact edits before writing.

---

## Implementation Results (2026-07-28)

Implemented via 5 subagents partitioned by **target file** (disjoint sets → no write conflicts). Two triage homes were redirected because they aren't in the source tree: `para-memory-files` (item 19) → folded into `agent-harness-design`'s Memory component; `dataviz` (item 15) → `tool-design` only. Item 18 stayed conservative (verified token-economics only; no live settings.json mutation).

**New artifacts (2):**
- `skills/surfacing-unknowns/SKILL.md` — NEW skill (item 6). 1,124 words, description 197 chars, passes SkillOS + identity gates; copied into `~/.claude/skills/` for this session.
- `commands/kiro/converge.md` — NEW command (item 14), reuses `validate-impl-agent` in CONVERGE mode.

**Augmentations (11 files):**
| File | Items | What landed |
|------|-------|-------------|
| `skills/multi-agent-patterns/SKILL.md` | 3, 4 | Contrarian Persona Ensemble; Autonomy Anti-Patterns |
| `skills/agent-execution-control/SKILL.md` | 4, 1 | Forced-execution-beats-cross-checking; Machine-Checkable Exit Conditions |
| `skills/loop-patterns/SKILL.md` | 4 | Fuzz-invariants; build-bespoke-loops |
| `skills/agent-harness-design/SKILL.md` | 3, 12, 10, 19 | Agent-Run Contract + 3 questions; "harness matters as much as the model"; proactive/reactive memory + connector taxonomy + coupling-risk |
| `skills/evaluation/` (+`resources/benchmark-construction.md`) | 12, 1, 10 | Real-PR benchmark recipe; git-history sealing; trajectory eval; anti-reward-hacking containment |
| `skills/model-tiers/SKILL.md` | 20, 12 | Model-vs-effort diagnostic |
| `skills/verification-skill-authoring/SKILL.md` | 9 | Autonomous-QA methodology (flows-before-matrix, dual judges, fix-loop governor, independence-budgeting) |
| `agents/kiro/guardrails-agent.md` | 11 | PR Auto-Approve Gate (fail-closed) |
| `skills/ai-security-workflow/SKILL.md` | 21 | JSON-state pipeline + sandboxed-reproduction verification |
| `agents/kiro/reflect-agent.md` | 21 | Cross-run learning loop (`learnings.jsonl`) |
| `skills/tool-design/SKILL.md` | 15 | Intent-vs-Compiler principle |
| `skills/context-optimization/SKILL.md` | 18 | MCP `enabled` flag + cache-breakpoint economics (verified subset only) |
| `commands/kiro/harness-validate.md` + agent | 14 | Cross-artifact spec-consistency check |

**Open follow-ups:**
- `reflect-agent`'s `learnings.jsonl` is write-only until a planning step reads it back — wire a consumer to close the loop.
- `context-optimization`: the 1h-TTL cache break-even (3+ reads, ~2× write cost) was flagged inline rather than encoded — confirm against `claude-api` before relying on it.
- Not yet rolled out to other repos: run `bash ~/.claude/sdd-harness/update.sh` to propagate.

**Provenance logged:** `docs/sources/articles/README.md` (8), `docs/sources/git/README.md` (2), `docs/sources/x/README.md` (4).
