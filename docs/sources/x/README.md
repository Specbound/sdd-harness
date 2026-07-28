# X (Pasted Text)

Content passed directly as pasted text to `/skill-extraction` — not a URL, repo, or file path. Ordered by date added.

---

## @nityeshaga — Trust Battery Design
**URL:** https://x.com/nityeshaga/status/2044864114682741134 | **Added:** 2026-04-21 | **Source:** @nityeshaga (X post)

**What it's about:** Design for a "trust battery" system inspired by Tobi Lütke's Shopify mental model. Core insight: separate the Judge (scores behavior, proposes nothing) from the Reflector (improves, reads Judge's drains) — if one agent both scores and improves, it optimizes for score not quality. The sharpest practical signal: every re-explained preference is a memory the agent should have saved but didn't.

**What we added:**
- Script: `scripts/detect_reexplanation.py` — Haiku detector scanning session user turns for drain signals (re-explanation, frustration) and charge signals (explicit approval). Runs at session end via stop-hook; appends at most one `[memory-gap]` and one `[session-charge]` per calendar day
- Script: `scripts/trust_score.py` — score math: ±4.5%/day cap, [0,100] clamp, idempotent per calendar day, rewrites hot-memory.md scoreboard header
- Agent: `agents/kiro/session-judge.md` — adversarial Haiku scorer; emits verdict JSON only, hard constraint: never proposes fixes
- Command: `/kiro:daily-maintenance` — nightly orchestrator: Judge → Reflect → Housekeeping → Score → Alert
- Rule: `kiro/settings/rules/session-quality-rubric.md` — charges (+1, max 5/day) and drains (-2, max 5/day) with evidence requirements. Trust Score is observability only — never gates harness behavior.
- Hook enhancement: `hooks/claude/stop-hook.sh` — calls detector after each session
- Docs: `docs/trust-battery/README.md`

---

## @sukh_saroy — Skill Augmentation from Session Learnings
**URL:** https://x.com/sukh_saroy/status/2046177... | **Added:** 2026-05-06 | **Source:** @sukh_saroy (X post)

**What it's about:** Pattern of automatically encoding session friction signals back into skill files — closing the loop between nightly judge verdicts and the skill library. Each drain maps to a skill domain; each drain should produce an anti-pattern note in the relevant SKILL.md.

**What we added:**
- Agent: `agents/kiro/skill-augment-agent.md` — reads judge verdict + today's observations, appends anti-patterns/learned patterns to up to 3 skills per run. Append-only, 150-char limit per addition, citation required. Domain mapping: memory-gap→memory-systems, silent-failure→error-handling-patterns, gate-bypass→verification-before-completion, rule-skip→systematic-debugging, stale-context→context-management
- Command enhancement: `commands/kiro/daily-maintenance.md` — Step 6 added after score step
- Routine: nightly CCR registered at 9:47 PM daily

---

## Verifying Agentic Development at Scale (Pasted article)
**Added:** 2026-06-02
**Source / Author:** Pasted article — Cognition (Devin team) blog post on autonomous end-to-end testing

**What it's about:** How Cognition's Devin agent approaches self-verification after completing async work. Core insights: (1) test plans must be grounded in actual source code before testing begins — models hallucinate paths that don't exist when they work from assumptions; (2) assertions committed *before* performing an action (annotation-first, like TDD) make it much harder to rationalize unexpected results as passes; (3) repeated setup steps (login flows, env setup, dependency installs) extracted to deterministic scripts reduce flakiness and token cost dramatically; (4) async agents are only trustworthy if they return verifiable proof, not just a success claim.

**What we added:**
- TDD augmentation: `tdd-workflows-tdd-red` — step 0 "Source scan first" inserted before test identification. Read `git diff HEAD` for bug fixes, spec + existing interfaces for new features. Only write tests for paths that actually exist; flag assumed paths `# TODO: verify path exists`.
- TDD augmentation: `tdd-workflow` — "Source Grounding" block added to section 3 (RED Phase Principles): scenario → what to read first lookup table (bug fix → diff, new feature → spec + interfaces, refactor → current implementation).
- Hook: `setup-buffer-hook.sh` (PostToolUse Bash) — accumulates setup-like commands (pip/npm/yarn/pnpm/brew installs, docker, db migrations, `.env` exports, `git clone`, `make setup/init`) to `.claude/memory/.setup-session-buffer.log` during a session.
- Hook augmentation: `stop-hook.sh` — added "Setup sequence capture" section: at session end, if buffer has ≥2 setup entries, writes a dated `bash` code block to `.claude/memory/setup-knowledge.md` (project-level memory), then clears the buffer.
- `settings.json` updated: `setup-buffer-hook.sh` registered in PostToolUse Bash hooks array.

---

## Claude Code Token Reduction (YouTube transcript)
**Added:** 2026-06-02 | **Source / Author:** Pasted transcript — YouTube video on 4 strategies to reduce Claude Code token usage by up to 90%

**What it's about:** Four complementary token reduction strategies for Claude Code: (1) CodeGraph — semantic codebase indexing via SQLite graph so Claude finds files by natural language instead of grep loops; (2) RTK (Rust Token Killer) — CLI proxy that compresses Bash output 60–90% before it enters context; (3) Caveman — per-session mode that compresses Claude's own response text 65% on average; (4) Session hygiene — `/compact`, `/clear`, `/model` switching, plan mode first. Each strategy targets a different layer and carries distinct trade-offs (staleness, lossy compression, quality degradation at ultra levels).

**What we added:**
- Tool: `rtk` v0.42.0 installed at `~/.local/bin/rtk` — replaced `ztk`; global PreToolUse hook (`rtk hook claude`) wired in `~/.claude/settings.json`
- Tool: `caveman` installed — SessionStart hook auto-activates lite mode every session; default set in `~/.config/caveman/config.json`; user can run `/caveman full`, `/caveman ultra`, or `normal mode` to adjust
- Propagation: `update.sh` run for all 3 registered projects — rtk docs synced, ztk docs replaced

---

## SOUL.md Anatomy + Orchestration Tax (Pasted thread)
**Added:** 2026-05-31
**Source / Author:** Pasted text — X thread on SOUL.md + Google I/O 2026 panel essay (Seroter, Hammerly, Jaspan)

**What it's about:** Two complementary frameworks for building better agentic systems. (1) SOUL.md: an 8-section identity file format for AI agents that sits at the top of the system prompt before memory/skills/tools — identity, core truths, worldview, voice, expertise, boundaries, memory policy, pet peeves. Key claim: "be helpful and professional" changes nothing; specificity (30–80 lines) is the only thing that compounds. (2) Orchestration Tax: human attention is the GIL of multi-agent systems — the single serial resource all agent work must route through. Amdahl's Law applied to review throughput explains why adding more agents grows queue depth without increasing output. Five practical rules for designing around this constraint.

**What we added:**
- Skill: `agent-identity` — new skill implementing the 8-section SOUL.md framework. Mode A (full SOUL.md) for agent design; Mode B (reduced identity check) auto-triggered from skill-extraction and skill-creator to validate skill identity sharpness at creation time.
- Enhancement: `skill-extraction` Phase 5c — mandatory identity alignment check (invokes `agent-identity` Mode B) before any new skill is logged to the sources index.
- Enhancement: `skill-creator` Phase 4c — same identity check wired into the harness skill-creator before installation.
- Enhancement: `multi-agent-patterns` Orchestration Tax section — GIL analogy, Amdahl's Law framing, and 5 design rules (scale fleet to review rate, sort work, batch reviews, spend the lock on judgment, protect serial time).

---

## Claude Code Feedback Loops — Self-Verification Patterns (Pasted article)
**Added:** 2026-06-07
**Source / Author:** Pasted text — Anthropic/Claude Code team article on self-verification and workflow bundling

**What it's about:** How to encode domain-specific manual checks as verification skills so Claude self-verifies mid-work without prompting. Core insight: the gap between Claude's first response and your final result is filled by checks only you were running. Three patterns: (1) `<domain>-verify` skills encode manual inspection steps as executable phases; (2) bundling skills into a composite pipeline (simplify → verify → design → PR → CI watch) lets Claude complete entire feature workflows autonomously; (3) second-agent review before merge provides unbiased quality gating from a fresh context.

**What we added:**
- Skill: `verification-skill-authoring` — meta-skill for creating `<domain>-verify` companion skills; includes domain defaults (frontend, API, data pipeline, CLI) and rubric pattern for qualitative checks
- Skill augmentation: `skill-extraction` Phase 5d — after identity check on any new skill, automatically asks if a companion verify skill is warranted; invokes `verification-skill-authoring` if yes
- Skill augmentation: `skill-creator` Phase 4d — same companion check wired into the skill-creator workflow
- Command augmentation: `kiro:ship` Step 0 — `/simplify` added before the verify pipeline, matching the described composite pipeline pattern

---

## State of Memory in Agent Harnesses (Pasted article)
**Added:** 2026-06-07
**Source / Author:** Pasted text — comparative analysis of memory architectures across 6 major AI coding harnesses

**What it's about:** Systematic comparison of how Claude Code, Anthropic Managed Agents, OpenAI Codex, GitHub Copilot, OpenClaw, and Hermes Agent implement memory. Introduces a 3-tier taxonomy (working/external/parametric) and the memo ceiling theorem (arXiv:2604.27707: Ω(k²) vs O(d)). Covers each harness's retrieval mechanism, persistence model, hard limits, and key shortcoming. Only Copilot has published real-world A/B data (83%→90% PR merge rate lift). Key patterns: Copilot citation-schema at write time + JIT expiry, Codex two-phase consolidation (6hr idle gate → locked merge), Hermes 80% utilization threshold trigger.

**What we added:**
- Skill augmentation: `agent-memory-systems` — added "Production Memory Ceiling" section (3-tier taxonomy + memo theorem) and "Harness Comparison" table (6 systems, retrieval mechanisms, limits, shortcomings, published A/B metric).
- Skill augmentation: `agent-memory-discipline` — added "Citation Schema (Write-Time)" section: Copilot-inspired structured frontmatter (`citation: {file, line, symbol, verified_at}` + `expires_at`) enabling mechanical validation of code-citing memories. Pairs with existing CLAUDE.md read-time check.
- Skill augmentation: `agent-memory-consolidation` — added "Consolidation Timing Patterns" section: Pattern A (Codex two-phase idle-gate + locked merge) and Pattern B (Hermes 80% utilization-gauge trigger), with guidance on which to use per failure mode.

---

## Braintrust Topics — Continuous Trace Intelligence at Scale (Pasted article)
**Added:** 2026-06-07
**Source / Author:** Pasted text — Braintrust engineering blog post on their "Topics" trace intelligence pipeline

**What it's about:** How Braintrust built active observability for production LLM agent traces — finding patterns you didn't know to look for. Core insight (from Anthropic's Clio paper): instead of embedding raw multi-million-token traces, ask an LLM to summarize the trace along one dimension in 1-2 sentences, then embed that summary. The same pipeline works for any analytical dimension (task, issues, sentiment, custom). Key optimizations: batch multiple facets into one LLM call (trace tokens paid once), hard-cap preprocessed input at 128K tokens, use HDBSCAN + UMAP without prespecifying cluster count, and classify via nearest-centroid lookup (~100ms, no LLM at classify time).

**What we added:**
- Skill: `active-observability` — full workflow for batch pattern discovery in Raindrop Workshop traces; 4-phase pipeline (collect → batch-facet → LLM-cluster summaries → report); adapted from Braintrust's 6-stage pipeline using LLM-as-judge clustering instead of ML deps
- Hook: `raindrop-best-practices.sh` (PreToolUse `mcp__raindrop__`) — soft gate injecting 5 key patterns as context whenever any Raindrop MCP tool fires; registered in `~/.claude/settings.json` and `templates/settings.json.template`
- Skill augmentation: `raindrop-eval-loop` — added Phase −1 "Pattern Discovery" block pointing to `active-observability` for use before writing eval assertions

---

## Orchestrator/Executor Routing — Rubric-Based Model Tier Selection (Pasted article)
**Added:** 2026-06-08
**Source / Author:** Pasted text — "15 prompts that cut my Coding bill from $7,800 to $129" — AI workflow cost optimization article

**What it's about:** Orchestrator/executor model split pattern: use reasoning-tier models (Opus) for planning, judgment calls, and quality review; use execution-tier models (cheap parallel agents) for batch work with clear output specs. Core insight: the routing decision reduces to one question — "can you write a rubric that a machine could grade?" If yes → execution tier. If no → reasoning tier. Article includes 15 prompt templates for the plan→rubric→execute→review→assemble workflow cycle.

**What we added:**
- Skill augmentation: `model-tiers` — added "The Rubric Test" section between Decision Heuristics and Practical Patterns: the semantic routing test (can you write a machine-gradable rubric?) with two worked examples showing where it catches what complexity-signal scoring misses.
- Skill augmentation: `multi-agent-patterns` — added "Rubric-First Dispatch" subsection in Skill Routing Quality: 3-field rubric structure (pass/fail/failure-modes), handoff sequence diagram, and the TDD-red-first analogy for pre-commitment; paired with the existing post-condition coupling pattern.

---

## Dynamic Workflow Patterns — 6 Patterns and 14 Steps (Pasted article)
**Added:** 2026-06-08
**Source / Author:** Pasted text — "How to master Dynamic Workflows in Claude Code" — movez.substack.com, ~Jun 2026

**What it's about:** Deep explainer on Claude Code's Dynamic Workflow feature (shipped May 28, 2026). Covers the mental model (Claude writing its own JS harness using `agent()`, `parallel()`, `pipeline()`), the 3 failure modes workflows fix (agentic laziness, self-preferential bias, goal drift), the 6 composable patterns (classify-and-act, fan-out-and-synthesize, adversarial verification, generate-and-filter, tournament, loop-until-done), pattern composition recipes for 9 real use cases (migrations, research, sorting, triage, evals, etc.), workflow controls (`/goal`, `/loop`, token budgets), quarantine pattern for prompt injection in untrusted input, and how to save/ship workflows as Skills.

**What we added:**
- Skill augmentation: `multi-agent-patterns` — added "Dynamic Workflow Patterns" major section covering: the 3 failure modes and which pattern fixes each; all 6 patterns with when-to-use rules and code examples; composition matrix (use case → pattern combination); workflow controls (`/goal`, `/loop`, token budgets); quarantine pattern (read-only reader agent for untrusted input); workflow-as-Skill packaging; and 8-item common-mistakes table. Also updated description frontmatter to include dynamic workflow triggers. Version bumped 1.3.0 → 1.4.0.

---

## Loop Engineering — Designing Systems That Prompt Agents
**Added:** 2026-06-11
**Source / Author:** Pasted text — article on loop engineering (@bcherny head of Claude Code, @steipete framing)

**What it's about:** Framework arguing the leverage point in AI coding has shifted from writing good prompts to designing loops that self-prompt agents. Five building blocks: automations (heartbeat), worktrees (parallel isolation), skills (encoded knowledge), connectors (MCP), sub-agents (maker/checker). Plus a 6th: the external state file as loop spine. Key insight: three failure modes worsen *as the loop improves* — cognitive surrender (accepting loop output without judgment), comprehension debt (mental model gap grows as loop ships code you didn't write), and self-preferential maker (loop's learning pipeline grades its own output). Article argues designing the loop is harder than prompt engineering, not easier; the leverage point moved.

**What we added:**
- Script change: `scripts/routines/daily-maintenance-prompt.md` Step E — changed "apply up to 3 updates" to goal-driven: "address all [seed-target:] observations from today, max 5 as circuit breaker." Closes the arbitrary count → verifiable stop condition gap.
- Script addition: `scripts/routines/daily-maintenance-prompt.md` Step F — adversarial checker agent spawned after Step E; verifies each [skill-update] against the gap that motivated it; emits [skill-update-verified] or [skill-update-flagged]. Implements maker/checker split in the loop's own learning pipeline.
- Hook change: `hooks/claude/stop-hook.sh` — added loop-debt detection block: Python inline script checks if [skill-update] entries are ≥3 days old with no [session-charge] since; appends [loop-debt] observation if so. Cognitive surrender proxy.
- Script change: `scripts/session/trust_score.py` — added [loop-debt] tag to `_tally_tags` and `cmd_auto_score`; penalty of −1 per occurrence (max −2/day) in delta calc. Loop health now a scored signal.
- Skill augmentation: `skills/multi-agent-patterns/SKILL.md` — added "Loop Health" section with three named failure modes (cognitive surrender → [loop-debt], comprehension debt → keep-rate, self-preferential maker → Step F), harness detection for each, and counter-moves. Version bumped 1.4.0 → 1.5.0.

---

## Building a Good Vertical Agent — Context as a Layered Cache (Pasted text)
**Added:** 2026-06-15
**Source / Author:** Pasted text — Peter Wang (@BrainsAndTennis), builder of the Shortcut spreadsheet agent

**What it's about:** Argues a good agent is a faithful compression of its task distribution, and that context (system prompt + tools + artifacts) should be structured like a CPU memory hierarchy. Users bring a long-tailed task distribution; the objective is to minimize context spent per task averaged over that distribution. L1 = always-resident bread-and-butter ops (the 80%), made token-compressed and consequence-reporting. L2 = curated, gotcha-aware English specs fetched in one discovery step (the ~15%). L3 = the raw complete substrate on disk plus a short skill that teaches the agent to mine it with grep (the long tail). Placement is the craft: resident tokens are paid every task, discovery tokens only on a miss. The boundary slides down a tier as models strengthen, but the hierarchy never disappears. Also argues for one `execute_code` tool over many (covered already by `tool-design`).

**What we added:**
- Skill augmentation: `agent-harness-design` — added "Context as a Layered Cache (L1/L2/L3)" subsection to the 𝒞 (Context Constructor) component: a placement decision rule (minimize resident + discovery cost over the task distribution), a tier table mapping L1/L2/L3 onto harness artifacts (CLAUDE.md + SKILL.md bodies / `resources/` + deferred tools / on-disk references + grep-recipe skill), the consequence-reporting property for L1 ops, and the "tiers slide with model strength" note. Cross-referenced `context-optimization` (intra-tier mechanics) and the existing temporal-scaling tiers (when interventions act vs. where capability lives). Rejected: one-tool (dup of `tool-design`), read/write compression specifics (spreadsheet-domain), and a standalone skill (would add a 4th overlapping context-* skill).

---

## Self-Improvement Loop for Skills (Warp blog, pasted text)
**Added:** 2026-06-18
**Source / Author:** Pasted text — Warp blog on self-improvement loops for Skills (issue-triage example, Oz cloud agents)
See also: [git/README.md](../git/README.md) — companion repo https://github.com/warpdotdev-demos/issue-triage-loop

**What it's about:** A two-loop pattern for skills that improve from external feedback. Inner loop applies a skill and records every run (file/trace/external system). Outer loop runs on a schedule, observes the inner runs — especially where a human *overrode* the agent's output and said why — and diffs the SKILL.md to fix it. Thesis: the human override is the gold training signal; an automated grader can substitute only when the goal is machine-gradable.

**What we added** (one augmentation — the harness already implements the two-loop architecture via `daily-maintenance` Step E + `skill-augment-agent`; everything else rejected as duplicate):
- Agent augmentation: `agents/kiro/skill-augment-agent.md` — new Step 1.5 loads today's `type: feedback` memories (user corrections) as a first-class evidence source, **auto-qualifying (2/2) and drafted before LLM judge-drain evidence** — encodes Warp's "human override outranks the grader" thesis. Closes the gap where skill-shaped user corrections lived only in memory and never reached the skill diff. Rides existing nightly automation; no new hook/routine. Mirrored to README.md, SDD-USAGE.md, scheduled-tasks/README.md.
- Rejected: two-loop framework (already = Step E + augment agent), GitHub Action inner-loop trigger (no issue-tracker goal), scheduled outer agent (= daily-maintenance), `improve-triage-skill`/`triage-issue` skills (domain-specific), human-correction capture hook (noisy detection; capture already exists via `detect_reexplanation.py` + `type: feedback` memories — only routing was missing).

---

## The Stanford STORM Method (Pasted text, Nav)
**Added:** 2026-06-21
**Source / Author:** Pasted text — popularization of Stanford OVAL's STORM (Synthesis of Topic Outlines through Retrieval and Multi-perspective Question Asking, NAACL 2024)

**What it's about:** A 4-prompt research workflow that compresses PhD-style topic research: simulate 5 adversarial expert perspectives (Practitioner/Academic/Skeptic/Economist/Historian) → map their contradictions (incl. unanimous agreement = likely true, unaddressed = field blind spot) → synthesize a reliability-ranked briefing → adversarially peer-review the briefing for bias. Stanford's published result: multi-perspective articles ~25% more organized, ~10% broader than single-prompt.

**What we added:**
- Skill: `storm-research` — the 4-phase method as a harness-native skill. Default **Workflow mode** fans the 5 personas out as *parallel* agents (no voice contaminates another) then runs contradiction → synthesis → adversarial peer-review as serial downstream stages; **Inline mode** runs the 4 verbatim prompts sequentially for quick passes. Verbatim prompts live in `resources/prompts.md`. Adds a grounding rule (personas don't invent citations — ground empirical claims via WebSearch) the source lacked.
- Rejected: augment `multi-agent-brainstorming` (sharp identity = review of a *proposed design*, not unknown-topic research — would blur it); augment `deep-research` (external paid Gemini API, opaque internals); `/storm` command (Skill is the right surface); hook (no lifecycle event / on-demand only); routine (not scheduled); dashboard widget (no persistent metric).

---

## Hermes Agent — Self-Improving Loop (Pasted text)
**Added:** 2026-06-21
**Source / Author:** Pasted text — "Hermes Agent FULL GUIDE: Architecture, Setup, and the Self-Improving Loop" (Nous Research)

**What it's about:** A cloud-resident messenger agent whose self-improving loop (trigger system → background review agent → curator) maintains its own skill library. The curator's distinguishing mechanic is a hidden **usage log** — load count + last-use timestamp per skill — feeding a token-free mechanical pass that deprecates agent-generated skills unused >30d and archives those unused >90d (with pinning), *before* any LLM review.

**What we added** (one integration — the harness already implements the loop via reflect/evolve/skill-augment/skill-curator/agent-memory-consolidation + daily-orchestrator; only the usage-evidence layer was a genuine gap):
- Hook: `skill-usage-tracker.sh` (`PostToolUse` matcher `Skill`, silent, zero tokens) — logs `{ts,skill}` per skill invocation to global `logs/skill-usage.jsonl`. Closes the gap where `skill-curator` claimed to prune "unused" skills but had no usage data (it guessed from file mtime).
- Curator augmentation: new **Phase 1.5 — Usage Evidence Audit** in `skill-curator-prompt.md` + report **Usage Evidence** section; `skill-curator` SKILL.md Delete criterion now requires evidence-backed cold status (no 30d use) and protects `pinned: true`.
- Dashboard: `render_skill_usage()` in `dashboard.py` adds hot/cold stats (total/30d invocations, skills used, cold count), a top-skills bar chart, and a deprecate-candidate list to the **Skill Changes** tab.
- Rejected: self-improving loop / triggers / curator (core of harness already); model routing for aux tasks (`model-tiers` + `background-work-routing`); skill-struggle real-time trigger (covered by `skill-augment-agent` + `action-capture` struggle detection); cron `-no-agent` token-free scripts (daily-runner already does this); curator auto-backup + rename map (git = backup, human-approval gate exists); webhooks/Kanban/goal-judge/terminal-backends/memory-engines (cloud-agent architecture, N/A to local harness).

---

## Your AI's Memory Is Quietly Making It Dumber (I Cut Mine to 6 Files) (Pasted text)
**Added:** 2026-07-02
**Source / Author:** Pasted text — Matt Van Horn (@mvanhorn)

**What it's about:** Push-memory (CLAUDE.md + native auto-memory) injects into context every session and *past a threshold reduces instruction adherence* rather than adding knowledge — the author's memory index hit 218 files / 46 KB and the harness was silently dropping half of it. Central thesis ("skills over memory"): most "memory" is a **misfiled skill lesson** — a fix tied to one skill belongs *in that skill* (as a PR, version-controlled, helping everyone who uses it), not journaled in a global store where it rots. Bucket every entry as trash (git has it) / skill-tied (route to skill) / genuinely cross-cutting (keep). Also: archive-before-delete, keep entry files <200 lines, and the push-memory (always-loaded) vs pull-memory (queried on demand) distinction.

**What we added** (two augmentations — the harness is already the *opposite* of the cautionary tale: global CLAUDE.md 1 line, project 52, MEMORY.md 16 entries; and `instruction-architecture`/`skill-curator`/`housekeeping-agent`/`skill-augment-agent`/`skill-extraction` already cover the CLAUDE.md-leanness, skill-pruning, archive-before-delete, push-lessons-into-skills, and >2×→make-a-skill hacks. The one genuine gap was the misfiling *decision at the memory-write gate*):
- Augmentation: `learn-eval-agent` + `learn-eval` command gain a fourth verdict **Route** (alongside Save/Absorb/Drop). When a pattern's evidence is tied to exactly one existing skill, it is NOT written to `patterns.md` — it is routed to `skill-augment-agent` to push into that skill's SKILL.md. Prevents skill-tied lessons being misfiled into global memory at intake. `daily-maintenance` Step 6 now consumes Route markers as the handoff.
- Augmentation: `housekeeping-agent` gains **Step 6.5 — Flag Skill-Tied Entries**, the backfill complement: it flags already-saved memory entries that belong in a skill and recommends routing them (recommend-only, archive-first discipline — never auto-moves).
- Rejected: `<200-line CLAUDE.md`/lost-in-middle (covered by `instruction-architecture`); skill pruning + description budget (`skill-curator`); archive-before-delete/prune (`housekeeping-agent`); >2×→make-a-skill (`skill-extraction`/`skill-creator` + Rule of Three in CLAUDE.md); push-vs-pull memory framing + retrieval-store tools gbrain/mem0/supermemory (conceptual, harness memory already lean push; hollow); disable native auto-memory `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` (N/A — harness uses bespoke *gated* file memory, not native auto-memory); `@AGENTS.md` import / `ln -s AGENTS.md CLAUDE.md` (real but low value — only pays off running Codex/Cursor against this repo; flagged not built).

---

## Cloud Software Factory — Spec-Driven Development (Pasted text)
**Added:** 2026-07-02
**Source / Author:** Pasted text — Warp blog, "How to build a cloud software factory" (part 2, spec-driven development). See also: [git/README.md](../git/README.md) — `github.com/warpdotdev-demos/cloud-factory-demo`

**What it's about:** Part 2 of Warp's automated-SDLC "cloud factory" series. Adds a **triage gate** to a Triage→Implementation pipeline: a triager classifies each incoming GitHub issue by roadmap/vision fit + complexity (>~few hundred LOC) + ambiguity (multiple materially-different viable implementations needing human choice), then applies one of four labels — `ready-to-implement` (one-shot), `ready-to-spec` (Spec agent produces PRODUCT.md + TECH.md), `needs-info` (clarify), `wait-to-implement` (defer). Spec agent runs via a label-triggered GitHub Action (Docker + Warp's Oz cloud); specs are checked into a `specs/<issue>` dir; interactive `/grill-me`-style refinement precedes implementation.

**What we added** (one integration — this harness *is* a local SDD harness and already ships the whole spec pipeline: `spec-init→requirements→design→grill→tasks→impl`, `spec-quick`, `spec-grill` = grill-me, `validate-impl`/`validate-adversarial` = validate-changes-match-specs, `.claude/steering/` = roadmap/vision. The only genuine gap was the *upstream routing decision*):
- Skill: `issue-triage-routing` — source-agnostic decision gate applied *before* spec/impl. Classifies a raw issue on roadmap-fit → ambiguity → complexity and routes to DEFER / CLARIFY / SPEC / ONE-SHOT (the four labels, mapped to local entrypoints). Falsifiable thresholds; sharp When/When-NOT triggers for auto-firing. Wired as a pre-gate into `jira-solve` routing and as a pre-check in `spec-quick` so trivial work isn't over-spec'd and off-roadmap work is caught early.
- Rejected: PRODUCT.md/TECH.md split (= requirements+design+tasks, more granular); `/grill-me` (= `spec-grill`); validate-changes-match-specs (= `validate-impl`/`validate-adversarial`); roadmap.md/vision.md docs (= `.claude/steering/`, which the triage skill reads); GitHub Actions + Docker + Oz cloud infra (N/A to a local-first harness); label mechanics (the decision logic behind them is what the skill captures).

---

## Your AI's Memory Is Quietly Making It Dumber (Pasted text)
**Added:** 2026-07-02
**Source / Author:** Pasted text — Matt Van Horn (@mvanhorn)

**What it's about:** Memory files and CLAUDE.md both inject every session and rot; past ~200 lines more text means worse adherence, not more knowledge. Bucket every memory entry as *trash* (git has it) / *skill-tied* (belongs in the skill as a PR) / *cross-cutting* (keep). Audit instruction files ruthlessly: flag files >200 lines, anything the model can infer from the repo (stack, generic filler), and project files that duplicate instructions instead of importing (`@AGENTS.md`). Also draws the push-memory (always-loaded) vs pull-memory (queried on demand) distinction.

**What we added** (one integration — the harness already covers archive-before-delete via glacier, nightly line-caps via housekeeping, and a write-time quality gate via memory-discipline-hook; and auto-memory is load-bearing here so the article's "turn it off" advice was rejected):
- Command: `/claudemd-review` (`commands/global/claudemd-review.md`) — **fills a dangling reference**: `session-start-hook.sh` fires `/claudemd-review` bi-weekly per repo but no command implemented it. Audits the current repo's `CLAUDE.md`/`AGENTS.md` against a lean-context rubric (200-line size budget, "inferable from the manifest" filter, generic-filler test, `@AGENTS.md` import/dedup, stale model-assumption + over-constraining checks), rates each file clean/minor/needs-update, writes `.claude/memory/claudemd-review-report.md`, and stamps `.claude/memory/.last-claudemd-review`. Propose-only by default; `--apply` for low-risk fixes. Distinct from the harness-wide `harness-health-runner` CLAUDE.md pass (all repos → `docs/claudemd-review-report.md`).
- Rejected: disable auto-memory (load-bearing — `skill-augment-agent` reads `type: feedback` auto-memories as its highest-trust signal); archive-before-delete (glacier already does this); memory/CLAUDE.md size-budget hook (housekeeping caps memory nightly; the CLAUDE.md size check folded into the command's rubric); standalone memory-bucketing skill (write-side = the proposed-but-declined learn-eval routing; prune-side = housekeeping); "anything done twice → skill" (skill-extraction + skill-creator already embody it); push-vs-pull external memory tools gbrain/supermemory/mem0/Letta (infrastructure choices, not a harness capability).
- Also proposed but user-declined this run: skills-over-memory routing (a `[seed-target:]` verdict in `learn-eval-agent` to divert skill-tied lessons to `skill-augment` instead of `patterns.md`).

---

## "Continual Learning for Agents" — Replit / pirroh@repl.it
**Added:** 2026-07-08 | **Source:** Pasted text (Replit Engineering)

**What it's about:** Three-layer improvement model for agents that can't touch model weights (model / harness / context). Introduces ViBench (benchmark built from production PRDs + natural-language test plans), Telescope (trace clustering system), and a self-improvement loop (trace clusters → hypothesis → candidate PR → measurement → ship/drop). Identifies three human taste gates — hypothesis selection, eval curation, launch approval — as irreplaceable.

**What we added:**
- Skill augmentation: `loop-patterns` — new Loop 11 "Harness-Improvement Loop" with two mandatory human gates (hypothesis selection and ship decision). Closes the gap where `/kiro:macro-eval-sweep` produces a ranked report that has no defined consumer.
- Skill augmentation: `evaluation/macro` — new Phase 0 "Construct the Population from Traces" (mine production PRDs, pair with natural-language test plans, maintain as living document). Previous skill assumed the benchmark already existed.
- Skill augmentation: `evaluation/macro` — new "Human Handoff — Hypothesis Selection Gate" section after Phase 5. Surfaces top 3 cluster candidates in a structured format and waits for human selection before proceeding to the Harness-Improvement Loop.
- Skill augmentation: `agent-harness-design` — new "Improvement Layer Decision" subsection in Phase 1. Routes diagnosis through harness-layer → context-layer → model-layer in that priority order before assuming weight-level fixes are needed.
- Skill augmentation: `evaluation/micro` — eval-curation note added to Rubric Design section. Makes explicit that rubric dimension/weight choices are product decisions requiring product-owner sign-off, not engineering checkboxes.

---

## "What The New 100x Agentic Engineer Looks Like In The Era Of Fable & GPT 5.6" — @systematicls
**Added:** 2026-07-08 | **Source:** Pasted text (@systematicls on X)

**What it's about:** Argues that agent capability is no longer the bottleneck — human preference-articulation is. Introduces a 2×2 framework (declarative vs. imperative × strategic vs. tactical) for expressing preferences to agents. The core claim: agents default to lowest-common-denominator solutions when preferences are unstated; the 100x engineer knows how to constrain the solution space through explicit preference expression and Socratic dialogue.

**What we added:**
- Command: `/kiro:pref-elicit` (`commands/kiro/pref-elicit.md`) — pre-spec Socratic elicitation command. Runs a structured 5-question protocol to surface declarative/imperative and strategic/tactical preferences before spec-init. Writes `prefs.md` to the spec directory. Wired as mandatory Step 1.5a in `spec-quick` Interactive Mode; recommended pre-check in `spec-init` standalone usage.
- Skill augmentation: `prompt-engineering` — new "Declarative vs. Imperative Preferences" subsection with the 2×2 matrix and routing rules. Maps onto the existing "degrees of freedom" section.
- Skill augmentation: `instruction-architecture` — new "Preference Origin: Strategic vs Tactical Routing" subsection. Maps preference origin onto the existing MUST/SHOULD/CONTEXT tier structure. Tactical preferences in the entry file = primary source of instruction bloat.

---

## "Agentic Autonomy Levels" — @addyosmani
**Added:** 2026-07-28 | **Source:** https://x.com/addyosmani/status/2072885435312042327 (Addy Osmani)

**What it's about:** A two-axis model of agentic autonomy (Agency × Orchestration) across six levels/three eras, with a warning that higher autonomy isn't inherently better — match autonomy to task risk, reversibility, and available verification ("calibrated autonomy"). Introduces the per-run "contract" and four autonomy anti-patterns.

**What we added:**
- Skill augmentation: `skills/agent-harness-design/SKILL.md` (Governance) — "Agent-Run Contract" (goal/scope/tools/stopping/evidence/escalation/budget) + the three questions before granting high autonomy (how fast do problems surface, how cleanly can work be undone, what independently verifies success).
- Skill augmentation: `skills/multi-agent-patterns/SKILL.md` — "Autonomy Anti-Patterns" (autonomy-as-status, permission laundering, summary substitution, fleet cosplay).

---

## "A Field Guide to Fable: Finding Your Unknowns" — @trq212
**Added:** 2026-07-28 | **Source:** https://x.com/trq212/status/2073100352921215386 (Thariq Shihipar, Anthropic)

**What it's about:** "The map is not the territory" — the map is your prompts/skills/context, the territory is the real codebase, and the gap is unknowns. Argues output quality is now bottlenecked by the operator's ability to surface their own unknowns before execution, using the four-quadrant frame (known/unknown × known/unknown) and concrete pre-execution discovery moves.

**What we added:**
- Skill (NEW): `skills/surfacing-unknowns/SKILL.md` — a pre-execution discovery routine with six named techniques (blind-spot pass, design-prototype for tacit taste, architecture interview one-question-at-a-time, reference-as-map, implementation-deviation logging, pre-merge quizzing), a "When NOT to Use" section, and explicit exclusions. Fires before a spec/design/large change; skips well-specified mechanical tasks.

---

## "Own the loop / agent-as-a-judge" — @aparnadhinak
**Added:** 2026-07-28 | **Source:** https://x.com/aparnadhinak/status/2073079029624943040 (Aparna Dhinakaran, Arize AI)

**What it's about:** Two adjacent Arize themes: (1) evaluate agent *trajectories*, not just final outputs — agents fail in sequences (stuck loops, dropped context, broken tool calls hidden behind a plausible final answer); and (2) tight model-harness coupling that feels magical is also a portability risk, locking you to one vendor's models/prices.

**What we added:**
- Resource augmentation: `skills/evaluation/resources/benchmark-construction.md` — trajectory evaluation (grade intermediate steps; a valid agent can take different paths to the same goal).
- Skill augmentation: `skills/agent-harness-design/SKILL.md` (Memory) — one-line "harness↔model coupling is portability risk" framing.

---

## "Model and effort in Claude Code: knowing more vs. trying harder" — @claudedevs
**Added:** 2026-07-28 | **Source:** https://x.com/claudedevs/status/2074900291062034618 (Claude Code team — Lydia Hallie)

**What it's about:** Two Claude Code dials that both seem to "make the answer better" do different things: the model changes what Claude *knows* (knowledge, reasoning ceiling); effort changes how much *work* it does before checking back (files read, tests run, verification loops). Diagnostic: when Claude is wrong, ask "did it not know enough, or did it not try hard enough?"

**What we added:**
- Skill augmentation: `skills/model-tiers/SKILL.md` — "Model vs. Effort — Which Dial to Turn" diagnostic (not-knowing → bump the model; not-trying → raise effort; fix context first).
