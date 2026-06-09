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
