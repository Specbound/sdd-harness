# Articles

Online articles, blog posts, and documentation pages that were passed to `/skill-extraction` and turned into harness skills. Ordered by date added.

---

## Cursor: Continually Improving with AI Feedback Loops
**URL:** https://cursor.com/blog/continually-improving | **Added:** 2026-05-07 | **Source:** Cursor Engineering Blog

**What it's about:** How Cursor instruments its AI coding agent to continuously improve through behavioral governance — specifically, how memory contamination by case-specific facts (rather than reusable workflow patterns) is the #1 silent failure mode in long-running agents per the OpenAI cookbook. Covers compaction boundary timing, memory write discipline, and the distinction between investigation artifacts (ephemeral) and workflow patterns (persistent).

**What we added:**
- Hook: `hooks/claude/memory-discipline-hook.sh` (PreToolUse, gate on `*/memory/*.md` and `MEMORY.md` writes) — displays discipline rules before any memory write executes, enabling self-correction of violations (case-specific facts, pronouns, duplicated content)
- Hook: `hooks/claude/compaction-discipline-hook.sh` (PreCompact) — injects boundary-timing principles before every compaction: compact at workflow phase boundaries, preserve artifact paths/decisions/open questions, merge not regenerate (regeneration compounds LLM sampling drift)
- Skill: `agent-memory-discipline` — canonical reference for memory governance; 3-tier type system, body structure rules, what to save vs. skip
- Skill enhancement: `context-compression` — new "Compaction Modes and Boundary Timing" section (3-mode taxonomy: routine, phase-boundary, crisis)

---

## Overloaded Context: Why Agent Memory Fails at Scale
**URL:** https://www.dbreunig.com/2026/05/10/overloaded-context | **Added:** 2026-05-12 | **Source:** Drew Breunig (dbreunig.com)

**What it's about:** Analysis of why agents reach for external search too eagerly — burning tokens and introducing latency — when the answer already exists in session memory or the memory-first lookup chain. Argues for a retrieval priority hierarchy: local memory → external search, not the reverse.

**What we added:**
- Design context for `hooks/claude/gbrain-external-search.sh` — the hook's memory-first lookup chain (search → get_observations → timeline before any WebFetch/WebSearch) directly implements this article's retrieval priority hierarchy. The article was the reasoning input for that hook's design alongside the garrytan/gbrain patterns.

---

## Claude Code `/goal` — Goal-Driven Autonomous Execution
**URL:** https://code.claude.com/docs/en/goal | **Added:** 2026-05-14 | **Source:** Anthropic / Claude Code documentation

**What it's about:** Documents the `/goal` primitive in Claude Code — a completion evaluator (Haiku) that runs after each turn, checks whether the stated goal has been met, and either continues autonomously or stops when done. Enables running any workflow without permission stops until a verifiable condition is met.

**What we added:**
- Skill: `goal-mode` — patterns for running any feature development workflow in autonomous mode (goal-driven, runs until completion) vs interactive mode (permission steps, debuggable). Fills gap in the existing 53 development workflow skills which had no goal-driven autonomous execution pattern.

---

## Continuous Evaluation for Skill Extraction Workflows
**URL:** https://huggingface.co/blog/continuous_eval | **Added:** 2026-05-18 | **Source:** Hugging Face

**What it's about:** Methodology for continuous evaluation of LLM-powered pipelines — specifically, the principle that deterministic enforcement patterns should be implemented as hooks (run every time, measurable) rather than as skills or prompts (advisory, easily skipped). Introduces 4 evaluation signals for identifying hook candidates.

**What we added:**
- Skill enhancement: `skill-extraction` — Phase 3 now has a mandatory "Hook Candidate Assessment" section that invokes the `hook-design` skill to evaluate each extracted capability against 4 signals before proposing integration type: (1) must run every time, (2) describes enforcement, (3) lifecycle-aware, (4) prompt would fail to enforce. If any signal is positive → Hook entry in the proposal.

---

## How is Linear So Fast? A Technical Breakdown
**URL:** https://performance.dev/how-is-linear-so-fast-a-technical-breakdown | **Added:** 2026-05-27

**What it's about:** Technical breakdown of Linear's engineering decisions behind its notoriously fast UI: a local-first sync engine (IndexedDB as primary store, server as sync target), optimistic updates that commit to local state before network confirmation, `modulepreload` for zero-latency navigation, composited-only CSS animations (`transform`/`opacity` exclusively), property-level MobX observables (not object-level), and keyboard-first interaction design with no modals.

**What we added:**
- Skill: `frontend-performance` — architecture decision matrix (local-first vs server-driven), optimistic update pattern, bundle/load strategy, animation constraint rules (absolute: only `transform`/`opacity`, ≤150ms), reactivity granularity (property-level > object-level), service worker guidance, and keyboard-first interaction checklist.

---

## Better Experiments with LLM Evals: A Funnel, Not a Fork
**URL:** https://engineering.atspotify.com/2026/5/better-experiments-with-llm-evals-a-funnel-not-a-fork | **Added:** 2026-05-27 | **Source:** Spotify Engineering Blog

**What it's about:** Proposes using LLM evals as a *filter before* A/B tests, not as an alternative to them. Key data: only ~12% of A/B tests ship positively, ~42% of launched experiments eventually reverse due to secondary metric regression. Running evals first eliminates clearly non-promising candidates before consuming experiment bandwidth. Covers judge calibration (verifying that eval-preferred variants actually win with users), tiered evidence requirements, and guardrail monitoring.

**What we added:**
- Skill: `llm-eval-funnel` — three-tier testing framework (quick eval sweep → rigorous A/B → post-experiment calibration), when each tier is sufficient, the judge calibration loop, and pre-experiment filtering workflow. Prevents teams from running expensive A/B tests on candidates that fail a basic quality bar.

---

## Managed Agents: Verify with Outcome Grader
**URL:** https://platform.claude.com/cookbook/managed-agents-cma-verify-with-outcome-grader | **Source:** Anthropic Cookbook

**What it's about:** Walkthrough of the Outcomes feature in Claude Managed Agents — a stateless grader agent evaluates a writer agent's output against a rubric and drives revisions until the output passes, without requiring custom orchestration code. Covers the TASK/RUBRIC separation pattern, how to write checkable rubrics for objective criteria (research quality, citation checking, compliance review, structural completeness), and the full grade-and-revise loop.

**What we added:**
- Skill: `cma-outcomes` — when Outcomes fits vs. doesn't (rubric-based verification vs. open-ended creative tasks), the TASK/RUBRIC separation pattern, rubric writing guide, and the full grade-and-revise loop implementation with the `OutcomeGrader` API.

---

## Six Levels of Complexity in a Codex Morning Brief
**URL:** https://jxnl.co | **Added:** 2026-05-27 | **Author:** Jason Liu

**What it's about:** A practical framework for AI workflow design that enforces one-real-capability-at-a-time progression through six complexity levels: (1) simple prompt, (2) structured output, (3) tool use, (4) agentic loop, (5) multi-agent, (6) persistent memory vault. The argument is that most teams over-engineer AI features by jumping to level 5 before proving value at level 3. Each level has a specific qualification gate before advancing.

**What we added:**
- Skill: `progressive-complexity-ladder` — the 6-level framework as an AI feature design gate.
- Integration into `kiro:spec-design` via Principle 10 in `kiro/settings/rules/design-principles.md` — automatically invoked when classifying any AI integration feature.
- Step D (Morning Brief) added to `.claude/scripts/daily-maintenance-prompt.md`.

---

## Macro Evals for Agentic Systems
**URL:** https://developers.openai.com/cookbook/examples/partners/macro_evals_for_agentic_systems/macro_evals_for_agentic_systems | **Added:** 2026-05-31 | **Source:** OpenAI Cookbook

**What it's about:** Methodology for evaluating multi-agent systems at *population scale* rather than grading one run. Compress many traces into comparable documents, discover recurring behavior patterns (BERTopic-style: embed → UMAP → HDBSCAN), rank them by impact (prevalence × severity), then backward-trace high-impact patterns to the workflow step most likely responsible via a decomposable suspect score. Core insight: a correct final answer can hide a broken middle, so cluster the evidence, don't trust the last event. Built on Promptfoo (per-run rubrics) + OpenAI Agents SDK traces.

**What we added:**
- Skill: `macro-evals` — the five-phase macro methodology (collect/normalize → trace-document → cluster discovery → impact leaderboard → backward suspect trace), explainable scoring formulas, and do's/don'ts. Sits as the *macro* layer above the micro `evaluation`/`cma-outcomes` skills (cross-linked both ways).
- Routine: `/macro-eval-sweep` command + `macro-eval-runner.sh` + `macro-eval-prompt.md` — twice-weekly local sweep over Raindrop Workshop traces (`query_traces` → group → impact-rank → suspect-trace), writes a dated report to `.claude/reports/macro-evals/` and posts `issue`/`note` annotations back onto offending runs/spans in Workshop. Preflight fails loud (writes `*-SKIPPED.md`) if the Raindrop MCP server is unreachable in a headless context. Scheduler registration left to the user (launchd/cron, Mon & Thu).

---

## Exploring Agent-Assisted Qualitative Analysis
**URL:** https://www.sh-reya.com/blog/ai-qual-analysis/ | **Added:** 2026-05-31 | **Source:** Shreya Shankar (sh-reya.com)

**What it's about:** Shankar points AI agents at grounded-theory qualitative analysis (open → axial → selective coding) over 451 tweets and reports where they break. The valuable part is her empirically-measured failure catalog: agents paraphrase instead of analyzing (93.8–100% of codes used exactly once), cover only 6–68% of the corpus before silently stopping, converge prematurely, overfit/forget human feedback, and produce vague unfalsifiable categories ("Reliability and Trust") that can't be measured or acted on. She flags the direct transfer to agent error analysis on traces.

**What we added** (chose enhance-existing over a new skill — the harness's memory-mining loop already *does* qualitative coding on the observation corpus):
- Enhancement: `learn-eval-agent` — Step 3b hard gates: **falsifiability** (drop vague buckets you can't check adherence to) and **generalizability/anti-paraphrase** (drop one-off restatements of a single event).
- Enhancement: `reflect-agent` — pattern promotion now requires 3+ *distinct* observations, falsifiable, no premature convergence; added a **coverage** report. Canonical rule mirrored in `memory-conventions.md`.
- Process: extended `doc-sync`/`sync-docs` with **Resource & Registry Coverage** — capability additions are now a first-class change bucket that must be documented in the resources (this sources index, `.claude/docs/**`, `README.md`, `SDD-USAGE.md`) per Phase 6. See memory `enhancement-qual-coding-gates`.

---

## Learn Harness Engineering — Lectures 03–05, 07–08, 12
**URL:** https://walkinglabs.github.io/learn-harness-engineering | **Added:** 2026-05-31 | **Source:** Walking Labs (walkinglabs.github.io)

**What it's about:** Practical harness engineering course covering the lifecycle of an agentic instruction file — from initial design to ongoing maintenance. Key lectures: (03–04) lean entry-file + topic-document architecture, "lost in the middle" LLM attention research, SNR auditing, instruction maintenance metadata (source/applicability/expiry), anti-patterns and worked refactor example; (07–08) machine-readable feature state machines (not_started/active/blocked/passing), triple structure (behavior+verification+state), WIP=1 finding (5→1 active feature, 20%→100% pass rate on 8-feature REST API), pass-state gating rules, granularity calibration; (05, 12) session-as-database-transaction model, five-dimension clean state checklist, clock-in/clock-out protocols, PROGRESS.md + DECISIONS.md + QUALITY.md structures, entropy management, harness simplification cadence.

**What we added:**
- Skill: `instruction-architecture` — lean entry-file + topic-document architecture, "lost in the middle" countermeasures, SNR audit procedure, instruction maintenance metadata fields. Enforced by `harness-validate-agent` (Step 8) and `evolve-agent` (Step 1d).
- Skill: `feature-list-primitive` — machine-readable feature state machine, triple structure (behavior+verification+state), WIP=1 discipline with quantified outcomes, pass-state gating, dependent harness components table. Enforced by `harness-validate-agent` (Step 9).
- Skill: `session-clean-state` — five-dimension clean state, clock-out/clock-in protocols, PROGRESS.md/DECISIONS.md/QUALITY.md templates, entropy management, harness simplification cadence. Enforced by `reflect-agent` (Step 6) and `evolve-agent` (Step 1e).
- Agent enhancement: `harness-validate-agent` — Step 8 (instruction architecture audit: line count, constraint count, topic doc adoption, middle-placement check) and Step 9 (feature list primitive audit: triple structure, WIP=1, pass-state).
- Agent enhancement: `evolve-agent` — Step 1d (instruction architecture health check: bloat, SNR, middle placement, monolithic pattern) and Step 1e (session clean state health check: PROGRESS.md freshness, debug artifacts, verify path); added "Harness Architecture Health" scorecard table to output.
- Agent enhancement: `reflect-agent` — Step 6 (session clean state check: five-dimension table with corrective action items) and "Clean State" section in output format.
- Skill enhancement: `agent-harness-design` — Phase 4: Operational Diagnostics (Fresh Session Test, Controlled Ablation Methodology, Affordance Analysis, Harness Rot Detection cadence).

---

## 3 Top Takeaways From Dropbox's Former Most Senior Engineer | James Cowling
**URL:** https://www.developing.dev/p/3-top-takeaways-from-dropboxs-former
**Added:** 2026-05-31
**Source / Author:** Ryan Peterman interview with James Cowling (former Senior Principal Engineer at Dropbox, founder of Convex)

**What it's about:** Interview covering three engineering principles: (1) AI-era skill maintenance — use AI tools without atrophying problem-solving and architectural thinking; (2) system bias / outcome naming — teams named after technologies they own (MySQL team, AWS team) resist necessary implementation changes; rename by problem domain to realign incentives; (3) simplicity as the harder design choice — simple systems cost more upfront design effort but maintain observability and reduce operational burden (Dropbox example: 1,000 MySQL nodes with plain block-ID lookups, trivially queryable).

**What we added:**
- Design Principle augment: `kiro/settings/rules/design-principles.md` Principle 10 **"Problem-Scoped Identity & Observability Gate"** — name agents/commands/scripts by the problem they solve (not the technology), and use immediate state observability as a concrete simplicity criterion. Also added two anti-patterns: mechanism-named components and states invisible without special tooling.

---

## Introducing Dynamic Workflows in Claude Code
**URL:** https://claude.com/blog/introducing-dynamic-workflows-in-claude-code
**Added:** 2026-05-31
**Source / Author:** Anthropic

**What it's about:** Announces Claude Code's `Workflow` tool (research preview, May 2026) — deterministic JavaScript-script-based orchestration that fans out tens-to-hundreds of parallel subagents within a single session. Covers the `ultracode` effort setting (auto-deploys workflows for complex tasks), task shapes that warrant a workflow (service-wide audits, multi-hundred-file migrations, adversarial verification sweeps), token cost warnings (start scoped), first-workflow confirmation protocol, and progress persistence/resume.

**What we added:**
- Skill enhancement: `multi-agent-patterns` v1.3.0 — "Tool Selection: Agent vs. Workflow" section with decision table, task-shape routing tree, ultracode mode note, and token budget guidance. Positions the `Workflow` tool as the scale-escalation path above `Agent`-based dispatch, with explicit cross-link to `superpowers:dispatching-parallel-agents` for the small-fleet path.

---

## Agent Judge: Solving Long-Context Evaluations
**URL:** https://www.judgmentlabs.ai/blogs/agent-judge-solving-long-context-evaluations
**Added:** 2026-06-01
**Source / Author:** JudgmentLabs

**What it's about:** Describes the "Agent Judge" architecture for evaluating long-horizon agents where standard LLM judges fail — specifically when trajectories exceed context limits, actions modify external state (CRM, GitHub, AWS, DB), or evaluation criteria drift as agent behavior evolves. Three core capabilities: Search (slice long trajectories into targeted evidence chunks via worker agents), Verify (cross-check agent claims against external system state rather than trusting agent descriptions), and Adapt (Rubric Builder — closed-loop calibration of rubrics against human labels and production outcomes). Empirical results on trajectory-level hallucination detection: Agent Judge (refined) 0.86 accuracy / 0.79 F1 vs. 0.74 / 0.65 for a standard LLM judge across difficulty deciles.

**What we added:**
- Skill: `evaluation/long-trajectory` — three-phase workflow (Search / Verify / Adapt), evidence-slice strategies, external system verification checklist (API, DB, GitHub, cloud, logs, filesystem), Rubric Builder iteration loop with calibration signals and trigger conditions. Part of the consolidated `evaluation/` skill family.
- Restructure: consolidated `evaluation`, `macro-evals`, and `llm-eval-funnel` into a single `evaluation/` skill family with a router (`evaluation/SKILL.md`) and four sub-skills (`micro`, `macro`, `funnel`, `long-trajectory`). Router provides a decision tree and supports loading multiple sub-skills for cross-layer tasks. Documentation added at `docs/evaluation/README.md`.

---

## Agentic RL: Token-In, Token-Out Done Right
**URL:** https://qgallouedec-tito.hf.space | **Added:** 2026-06-02 | **Source:** Hugging Face (qgallouedec)

**What it's about:** Identifies a silent correctness bug in multi-turn RL training loops for tool-calling LLMs. When conversation history is re-rendered through the chat template at each step, BPE drift produces different token sequences than what the model originally sampled — gradients then target tokens the model never generated. The fix is a single invariant ("never re-encode what you decoded") implemented via a running token buffer. Also covers the prefix-preservation property test (12-line Python), a model compatibility table (18/19 major open-weight models pass unchanged), the Qwen3 one-line Jinja template fix, and edge case handling (history rewriting, truncation).

**What we added:**
- Skill: `agentic-rl-tito` — TITO invariant, correct loop algorithm, prefix-preservation property test with code, model compat table, `compute_tool_delta()` pattern, edge case recipes. Fires only on RL fine-tuning / multi-turn training loop tasks. Full code patterns in `resources/code-patterns.md`.

---

## Running an AI-Native Engineering Organization
**URL:** https://claude.com/blog/running-an-ai-native-engineering-org
**Added:** 2026-06-07
**Source / Author:** Anthropic (Claude Code team)

**What it's about:** Anthropic's Claude Code team describes how they restructured engineering around agentic coding — shifting bottlenecks from writing code to verification, review, and security. Covers four process changes (JIT planning, ask-Claude-first context, AI/human review tiering, blurred team roles), three org principles (dogfood, flat teams, kill obsolete processes), specific adoption metrics (onboarding ramp, PR cycle time, Claude-assisted commit rate), and the "pick your noisiest workflow" prioritization heuristic.

**What we added:**
- Skill: `ai-native-org-patterns` — five-phase framework: process audit ("noisiest workflow" heuristic), JIT planning pattern, AI/human review tiering table, ask-Claude-first context gathering, adoption metrics with targets, and three non-negotiable org principles.
- Skill enhancement: `karpathy-guidelines` — added "Review Tiering" section (Section 5) with explicit AI-owns-mechanical / human-owns-judgment split table and updated "How to Know It's Working" checklist.

---

## Modern Engineering Values
**URL:** https://cpojer.net/posts/modern-engineering-values
**Added:** 2026-06-07
**Source / Author:** Christoph Nakazawa (cpojer) — creator of Jest/Metro

**What it's about:** Five engineering principles that remain essential — and are amplified — when AI agents handle most code execution: Strong Ownership, Taste (judgment over execution), Strict Guardrails & Fast Feedback, Context in the Repo, and Own your Stack. Argues the engineering bottleneck shifts from writing code to exercising judgment. Adds Option Value as a design principle: every architectural choice should unlock future options, not foreclose them.

**What we added:**
- Skill enhancement: `karpathy-guidelines` — Section 6 "Before Adding a Dependency" (ownership cost check: what constraints does this lock in? can it be built with agents instead?) and Section 7 "Option Value Check" (does this architectural decision unlock or foreclose future changes?). Also added two conditional checklist items to "Before You Write a Single Line". No new skill created — principles fit cleanly as additions to an existing checklist skill at different decision points (dependency selection, architecture).

---

## How I Actually Code (and Review) With AI in 2026
**URL:** https://medium.com/google-cloud/how-i-actually-code-and-review-with-ai-in-2026-005c89fbd113
**Added:** 2026-06-11
**Source / Author:** Christina Lin — Google Cloud Community

**What it's about:** Practical cookbook for writing code that AI agents can reason about and modify safely. Central thesis: AI has a cognitive load (the context window) that degrades past ~300k–400k tokens (context rot), so code should be designed for local reasoning with minimal blast radius. Covers five concrete patterns: blast-radius-first design, Rule of Three for abstractions (wait for 3 real call sites before extracting), vertical-slice folder organization (feature = one folder, no cross-imports), fail-fast/fail-loud error handling, and the reviewer-model-mismatch principle (the model that wrote the code is the worst reviewer of it).

**What we added:**
- Skill enhancement: `karpathy-guidelines` — Section 8 "AI-Legible Code" covering all five patterns; two new checklist items ("Blast radius estimated?", "Rule of Three applied?") in "Before You Write a Single Line"; updated frontmatter description. No new skill — principles belong in the always-invoked behavioral checklist.
- CLAUDE.md: Added "AI-Legible Code" section (6-bullet always-on block) to harness CLAUDE.md so principles are present in every session context without requiring skill invocation.

---

## loops! — Named Agentic Dev Loop Catalog
**URL:** https://loops.elorm.xyz/loops
**Added:** 2026-06-11
**Source / Author:** elorm (elorm.xyz)

**What it's about:** Curated catalog of 8 pre-built, self-pacing agentic dev workflow loops — each defined by a standardized kickoff prompt contract: named goal, max iterations, between-iterations check command, and binary exit condition. Loops include: Ship PR Until Green (CI), De-Sloppify Pass (cleanup), Spec-First Ship (checklist-driven impl), Build Until Green, Coverage Until Threshold, E2E Until Green, PR Self-Review (3 passes), and Pre-Commit Guard. The key insight is the portable loop contract format: a natural-language prompt template Claude can execute in any session without scaffolding.

**What we added:**
- Skill: `loop-patterns` — The 8 named loop templates as copy-paste kickoff prompts + the loop contract format + authoring guidance for new loops. Fills the gap between heavy `iterative-repair-loop` (JSON handoffs, artifact-specific) and `goal-mode` (evaluator-driven, delegates to sub-skills). Positioned as the lightweight, check-command-driven loop layer.
- Command: `/kiro:loop` — Interactive picker that lists all 8 loops, accepts a slug argument, and generates + launches the kickoff prompt automatically. Usage: `/kiro:loop ship-pr` or `/kiro:loop` for the picker.

---

## Claude Code — Model Configuration
**URL:** https://code.claude.com/docs/en/model-config
**Added:** 2026-06-15
**Source / Author:** Anthropic (Claude Code docs)

**What it's about:** Reference for how Claude Code resolves models — aliases (`opus`/`sonnet`/`haiku`/`fable`/`opusplan`/`default`), the `[1m]` context-window suffix, reasoning effort levels (`low`→`max`, plus `ultracode`), precedence order across `/model`/`--model`/`ANTHROPIC_MODEL`/settings, subagent model config (`CLAUDE_CODE_SUBAGENT_MODEL`), and enterprise controls (`availableModels`, `enforceAvailableModels`, `modelOverrides`, `fallbackModel`, gateway discovery). Notes Fable 5 as the most capable model for long autonomous sessions and Opus 4.8 as the current deep-reasoning tier.

**What we added:**
- Augmentation: `model-tiers` skill (migrated orphaned skill into harness source `skills/model-tiers/` so it now propagates via `install.sh`) — refreshed the deep-tier model ID `claude-opus-4-7` → `claude-opus-4-8`, added a 5th **autonomous** tier (`claude-fable-5`) for multi-sitting work, and a new "Effort Level — An Orthogonal Dial" section so effort (`low`→`max`) is treated as a lever separate from model choice. Tightened the description to predict WHEN it fires (≤200 chars).
- Doc sync: corrected stale `opus-4-7` references and added the Fable tier in `docs/memory/gbrain-patterns/gbrain-patterns.md` and `docs/harness-documentation/SDD-USAGE.md` (plus their `.claude/` mirrors).

---

## Don't let the LLM speak, just probe it
**URL:** https://blog.j11y.io/2026-06-10_hidden-state-probes/
**Added:** 2026-06-15
**Source / Author:** James Padolsey (j11y.io)

**What it's about:** When an LLM processes "does content X satisfy criterion Y?", the decision is already computed in the residual stream before any token is generated — generation is just the model translating a decision it has already made. Describes a 5-step recipe: small open model, seed token (`Assessment:`), training triples with varied criteria, hidden states at that seed position at ~70% layer depth, tiny MLP head, isotonic regression calibration. Result: one frozen model + one MLP = any English-criterion classifier at embedding-classifier cost with calibrated probabilities. Optional LoRA trick: train the LoRA to *write* verdicts (next-token loss), then never generate at inference — the text is scaffolding that crystallizes decision geometry at the seed token.

**What we added:**
- Skill augmentation: `llm-evaluation` — new "### 4. Hidden State Probes (non-generative classifier)" section under Core Evaluation Types, after LLM-as-Judge. Covers when to use over judges (structural criteria, calibrated probabilities, high-volume batch), when NOT to use (CoT needed, API-only model, dataset too small), the 5-step recipe, the LoRA geometry trick, and result framing. Also added a trigger bullet to "Use this skill when".

---

## index.how/to/articulate — Design Vocabulary Reference
**URL:** https://index.how/to/articulate
**Added:** 2026-06-15
**Source / Author:** Emil & Glenn (Index — pre-launch design education platform)

**What it's about:** 188 precisely-defined design terms across 12 categories (typography, color, iconography, layout, interaction, motion, accessibility, IA, copywriting, tools, analysis, components). Each definition contains embedded design opinions — not just "what is X" but "how to use X correctly." Tagline: "Say precisely what you mean."

**What we added:**
- Augmentation: `frontend-code-quality` skill — added "Visual Design Rules" CSS subsection (disabled state tokens, nested border-radius formula, tabular nums, dvh vs vh, safe area insets, pointer-events on decorative layers, OKLCH for gradients, semantic color tokens); expanded Animations section (ease-out/ease-in asymmetry, 150ms threshold, reduced motion media query); expanded Accessibility section (focus state replacement, 44×44px touch target, DOM order warning, label/for association); updated Quick Review Checklist with 14 new checkboxes across HTML and CSS sections.

---

## Agentic Code Review
**URL:** https://addyosmani.com/blog/agentic-code-review/
**Added:** 2026-06-17
**Source / Author:** Addy Osmani

**What it's about:** When agents make writing code cheap, the leveraged engineering skill becomes *proving* code works. Argues for risk-tiered review (effort proportional to blast radius), heterogeneous reviewers (everyday correctness + production-failure severity), and treating every AI review as a sensor, not a verdict. Sharpest actionable warning: agents take the cheapest path to a passing build — weakening tests or lowering CI thresholds ("gradient descent to green") instead of fixing the code.

**What we added:**
- Hook: `hooks/claude/test-integrity-guard.sh` (PostToolUse, matcher `Write|Edit|MultiEdit`, soft gate) — fires when a test file or CI/coverage config is edited and flags weakening signals: added skip/xfail/`@Disabled` markers, tautological/stub assertions (`assert True`, `expect(true).toBe(true)`), touched coverage thresholds (`--cov-fail-under`, `fail_under`, `coverageThreshold`), and removed assertions. Names the gradient-descent-to-green anti-pattern and asks Claude to confirm a deliberate spec change vs. a shortcut to green. Never blocks. Fills the gap where the harness reviewed code heavily but never watched the agent weakening the test gate itself.
- *Rejected:* risk-tiered review and separate-model review (already covered by CLAUDE.md blast-radius + reviewer-model-mismatch rules, `validate-adversarial-agent`, `session-judge`); decision-log/PR-reasoning capture (covered by `action-capture.sh`); prompt-injection scanning (covered by `scan-pii.sh` + `ai-security-workflow`).

---

## UI Skills — Curated UI Skill Directory + Routing Pattern
**URL:** https://www.ui-skills.com/
**Added:** 2026-06-17
**Source / Author:** ibelick (also https://github.com/ibelick/ui-skills)

**What it's about:** Curated directory of ~106 installable UI/frontend skills (design taste, motion, accessibility, React/Vue/Next, Three.js, charts, slides) fronted by a "UI Skills Root" routing skill. The routing skill's core idea is context economy: given a UI goal, identify the category, load the *smallest useful* set of skills, and **never load more than 3** ("prefer 1; 2 only for two clear angles; 3 only for broad review/redesign").

**What we added:**
- Augmentation: `skills/ui-skills/SKILL.md` — rewrote the prior hollow stub into a **UI build router**. Carries no UI rules of its own; maps task category → the harness's existing UI skills (`ui-ux-pro-max`, `frontend-design`, `wcag-audit-patterns`, `threejs-skills`, `react-best-practices`, etc.) and enforces the "prefer 1, never >3 skills" context-economy discipline via the Skill tool (no `ui-skills` CLI needed). Fills the known wrong-skill-fires / over-selection failure mode in the large UI skill family.
- *Rejected:* the `ui-skills` CLI + 106-skill registry (duplicate infra; harness already exposes equivalents via the Skill tool); individual Three.js/Vue/React/a11y/chart/slide skills (covered by `threejs-skills`, `react-best-practices`, `wcag-audit-patterns`, `frontend-slides`, etc.); niche design-taste skills (Oklch, Brutalist, Morphing Icons, Web Sounds — bloat, low repeated-task value); new hook/routine (routing is contextual judgment, not enforceable/schedulable); dashboard widget (no persistent output).

---

## Forward Future "Loop Library" — 45 Community Agent Loops
**URL:** https://signals.forwardfuture.ai/loop-library/
**Added:** 2026-06-21
**Source / Author:** Forward Future (forwardfuture.ai)

**What it's about:** Curated catalog of 45 community-contributed agent "loops" — self-pacing prompts that iterate → verify against explicit criteria → fix the highest-impact issue → re-test → stop on success/budget/stall. The site distills them to 6 universal principles: define success up front, one change per iteration, independent verification (separate builder/reviewer, adversarial critics, or two models), evidence required (root cause + before/after proof + changed files), fresh/clean state, and stop conditions. Nearly all 45 are domain variations on the same meta-pattern the harness `loop-patterns` skill already encodes.

**What we added** (augment-not-create — the existing `loop-patterns` skill is the engine; only genuinely-absent loop *classes* survived the value gate):
- Augmentation: `loop-patterns` skill — added loop **#9 Fresh-Clone Onboarding** (verify README/install docs from a disposable clean checkout; fix docs not environment) and **#10 Recent-Feedback Sweep** (turn one user correction into a project-wide fix + regression guard). Both fill loop categories the existing 8 CI/build/test loops lacked. Also added a **"Fresh/clean state"** guardrail (run reproducibility/onboarding passes from a disposable env to prevent false-green from a warmed workspace). Updated description count 8→10. See also: prior loop-library source entry "loops! — Named Agentic Dev Loop Catalog" (elorm.xyz) that created the skill.
- *Rejected:* new `loop-library` skill of all 45 (>70% duplicate of `loop-patterns` engine; bloat, fails compression); multi-LLM convergence (covered by `validate-adversarial`/`codex-review` + existing "two models/sessions" guardrail); builder-reviewer (covered by `subagent-driven-development` + `spec-refactor-agent`); accessibility repair (covered by `wcag-audit-patterns`/`accessibility-compliance`); test-stabilizer (covered by E2E-Until-Green + `test-fixing`); housekeeper (covered by `housekeeping-agent`/`simplify`); Goal Forge/SPEC.md (covered by `kiro:spec-*`); propagation/compliance loop (motion subsumed by Recent-Feedback Sweep; held back for leanness); new command/hook/routine/dashboard (`kiro:loop` exists; loops aren't lifecycle-automatable — contextual, user-triggered).

---

## Async Multi-Agent Orchestration — Anthropic Cookbook
**URL:** https://platform.claude.com/cookbook/patterns-agents-async-multi-agent-orchestration
**Added:** 2026-06-21
**Source / Author:** Anthropic Cookbook

**What it's about:** Bare-mechanics skeleton (Anthropic Python SDK + `asyncio`) for two multi-agent shapes — fixed N-agent peer team and dynamic spawn — built on a shared message `Hub` (per-agent inbox + `asyncio.Event`), a `spawn → status → collect → kill` lifecycle, and `send_message`/`wait_for_message` as the only inter-agent channel. Key non-obvious trick: peer messages are **appended to the last tool result** so agents receive them inline in their tool-use loop rather than polling.

**What we added:**
- Augmentation: `multi-agent-patterns` skill — added "### Implementing Async Peer-to-Peer Agents (raw SDK)" subsection under Detailed Topics (after Framework Considerations) summarizing the Hub + Event mechanics, the append-to-tool-result delivery trick, and the spawn→status→collect→kill lifecycle. Full code skeleton moved to `references/async-sdk-orchestration.md` (compression). Added cookbook to the References section. Fills the gap where the skill covered multi-agent *design*/tool-selection but had zero raw-SDK *implementation* mechanics.
- *Rejected:* new standalone skill (better as augmentation — `multi-agent-patterns` is the logical home; parallel skill would fragment "how to multi-agent" and risk wrong-skill firing); hook/routine (nothing fires every-time or on a schedule); script/command (reference knowledge, not an invokable action); dashboard widget (no persistent output); augmenting `async-python-patterns` (that skill is generic I/O-bound asyncio, not agent-specific).

---

## Vercel Eve: Open-Source Agent Framework
**URL:** https://vercel.com/blog/introducing-eve | **Added:** 2026-06-21 | **Source:** Vercel Blog

**What it's about:** Vercel's open-source framework that treats an agent as a directory of files (model, instructions, tools, skills, subagents, channels, schedules) — the framework owns the agent loop. Ships durable sessions, sandboxed compute, human-in-the-loop approvals, tracing/evals, and "channels" (Slack/Discord/Teams surfaces). Nearly all of it maps onto capabilities the harness already has; only the outbound-channel idea filled a real gap.

**What we added:**
- Script: `scripts/integrations/channels/notify.py` — stdlib-only sender that POSTs a message to whichever Slack/Discord/Teams incoming webhooks are configured in `~/.env.channels`; fills the harness's missing outbound-notification path
- Template: `templates/.env.channels.template` — copy to `~/.env.channels` (home dir, chmod 600, outside every repo); webhook URL is the credential, no OAuth
- Command: `commands/global/notify.md` — `/notify <message>` in-session broadcast to configured channels
- Routine wiring: `scripts/orchestration/daily-runner.sh` posts each repo's daily-maintenance summary to channels, gated on `~/.env.channels` existence (no-op otherwise; `SDD_SKIP_CHANNEL_NOTIFY=1` opts out)
- Docs: `docs/integrations/channels/README.md` — setup + per-platform webhook walkthrough
- Rejected: inbound channels / bot listeners (harness is a local CLI, not a deployed service)

---

## Top 30 Prompt Techniques That Actually Work in 2026
**URL:** https://agent-cookbook.com/tutorial/top-30-prompt-techniques-that-actually-work-in-2026 | **Added:** 2026-07-02 | **Source:** agent-cookbook.com

**What it's about:** A listicle enumerating 30 general Claude prompting techniques (explicitness, XML tags, few-shot, extended thinking, self-eval, agent-mode, plus 9 task-specific templates). 29 of 30 are already encoded in the harness's `prompt-engineering` + `prompt-quality-assess` skills and the agent-design skill family. The default-skip gate rejected all but one.

**What we added** (one augmentation — everything else was already covered):
- Skill augmentation: `prompt-engineering` — new "XML Tag Delimiting" subsection after Instruction Hierarchy. Teaches wrapping prompt regions in explicit XML tags (`<instructions>`, `<context>`, `<document>`) so the model never confuses instructions with data — Anthropic's most-emphasized structuring primitive, materially relevant on a 1M-context model that concatenates large context blocks, and a first-line prompt-injection defense for untrusted input. The one item literally absent from the existing skill (which taught only a markdown-header Instruction Hierarchy).

**Rejected (29/30, already covered):** few-shot / extended-thinking / context-first / self-eval loop / 1M-context / iterate → `prompt-engineering` sections; be-explicit / output-format / define-"done" / negative-constraints → `prompt-quality-assess` dimensions; agent-mode / multi-persona debate / prompt-chaining / reverse-brainstorming → `agent-execution-control` + `multi-agent-patterns`; the 9 task-specific templates → instances of the existing "Template Systems" pattern (encoding them = bloat). Also rejected the two other links from this batch outright — **DeepSeek dSpark** (GPU inference-serving speedup, a layer the harness never touches) and **Ornith-1.0** (self-scaffolding RL is training-only, baked into weights; the harness trains no models) — zero integrations each.

---

## "How to Kill the Bloat in Claude Code's System Prompt" — aihero.dev
**URL:** https://www.aihero.dev/how-to-kill-the-bloat-in-claude-codes-system-prompt
**Added:** 2026-07-08 | **Source:** aihero.dev

**What it's about:** Claude Code injects a hidden per-session startup payload (tool definitions, bundled skills, workflow engine) before any user content — a fixed token tax that runtime optimization techniques (RTK, lean-ctx) never see. The article provides a concrete four-lever taxonomy to reduce this: `disableBundledSkills`, `disableWorkflows`, `permissions.deny` (bare tool name to remove definition entirely), and `skillOverrides: "off"` / `"user-invocable-only"`. Measurement workflow: `/context` for category totals → proxy script for per-tool breakdown → apply levers → verify savings.

**What we added:**
- Skill augmentation: `context-optimization` — new "Claude Code System Prompt Levers" subsection inside "Two Independent Token Axes: Startup vs Runtime". Expands the previously empty startup axis with: measure-first procedure (`/context` baseline), per-tool inspection via proxy, a five-lever decision table (`disableBundledSkills`, `disableWorkflows`, `permissions.deny`, `skillOverrides: "off"`, `skillOverrides: "user-invocable-only"`), and the key invariant that RTK handles runtime and these levers handle startup — strictly independent axes.

**Rejected:** Standalone `claude-system-prompt-optimization` skill (conceptual home already exists in `context-optimization`); `claude-prompt-audit.sh` script (one-time developer investigation, not a recurring routine); `/claude-payload-audit` command (every decision node requires human judgment, no automation value).

---

## Batch Triage 2026-07-08 — 6 articles (4 AUGMENT, 2 SKIP via separate index files)

The following six articles were triaged in a single parallel batch on 2026-07-08.
Two additional resources (OpenWiki — git, PACE — papers) are logged in their respective category files.

---

## Autoresearch: The Feedback Loop Behind Self-Improving Agents
**URL:** https://www.latent.space/p/autoresearch-introspection
**Added:** 2026-07-08
**Source / Author:** Latent Space / Gavrilescu

**What it's about:** A Three-Loop Blueprint for self-improving agents: inner loop (task execution) + outer loop (loop improvement) + signal filtering layer. Introduces "Agent Recipes" — versioned artifacts capturing not just agent code/prompts but evals, judges, human expertise examples, failure history, and WHY decisions were made. Advocates git-based audit trails and staged autonomy (start human-heavy, agents absorb preferences over time).

**What we added:**
- Command augmentation: `commands/kiro/autoresearch.md` — new "Agent Recipe" section describing the `recipe.md` artifact, signal filtering policy, and staged autonomy levels. The inner loop (Karpathy experiment loop) was already handled; this adds the outer loop meta-layer and recipe convention.

**Rejected:** Standalone `agent-recipes` skill (content belongs in the command that uses it, not a separate artifact); outer loop hook (no lifecycle event maps to "the loop should improve itself"); `evolve-agent` augmentation (already handles behavioral audit — MCE concept in agent-harness-design covers the meta-improvement framing more precisely).

---

## Advanced Tool Use
**URL:** https://www.anthropic.com/engineering/advanced-tool-use
**Added:** 2026-07-08
**Source / Author:** Anthropic Engineering

**What it's about:** Three empirically validated techniques for high-scale tool systems: Tool Search (deferred discovery via `defer_loading: true`, 85% token reduction), Programmatic Tool Calling (Claude writes orchestration code, 37% token reduction, enables parallel calls), and Tool Use Examples (concrete JSON examples in definitions, 72%→90% accuracy). Enabled via `betas=["advanced-tool-use-2025-11-20"]`.

**What we added:**
- Skill augmentation: `skills/tool-design/SKILL.md` — new "Advanced Tool Use Patterns" section covering all three techniques with implementation details and decision rules. These are orthogonal to the existing consolidation/description engineering content.

---

## Anthropic Prompt Caching Documentation
**URL:** https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching
**Added:** 2026-07-08
**Source / Author:** Anthropic

**What it's about:** Authoritative implementation guide for Anthropic's server-side prefix caching via `cache_control` blocks. Covers: minimum token thresholds by model family, the 20-block lookback window limit, the non-symmetric cache invalidation dependency table (tool changes cascade; tool-choice-only changes don't), pre-warming with `max_tokens: 0`, and automatic vs. explicit breakpoint modes.

**What we added:**
- Skill augmentation: `skills/context-optimization/SKILL.md` — new "Anthropic API Prompt Caching" section. This is a third, orthogonal caching mechanism distinct from CAG (local HuggingFace KV preloading) and the KV-cache ordering heuristics already in the skill.
- Skill augmentation: `skills/cag-implementation/SKILL.md` — clarifying note in Limitation 2 pointing to `context-optimization` for the Anthropic API variant, preventing confusion between the two mechanisms.

---

## Graph-Based Agent Memory
**URL:** https://newsletter.systemdesign.one/p/graph-based-agent-memory
**Added:** 2026-07-08
**Source / Author:** System Design Newsletter (Omnigraph case study)

**What it's about:** Omnigraph: typed entity nodes + labeled edges + schema enforcement, with three retrieval layers (graph traversal + BM25 + vector, fused via Reciprocal Rank Fusion). Atomic manifest versioning for all-or-nothing writes, git-like branch isolation for concurrent multi-agent writes, and commit lineage for audit trails.

**What we added:**
- Skill augmentation: `skills/para-memory-files/SKILL.md` — new "Relationship-First Memory" section extracting the schema enforcement principle, explicit relationship entries (written to both sides), and branch isolation for concurrent writes. Full Omnigraph infrastructure was not extracted (too heavy for the file-based harness model).
- Reference fix: `skills/multi-agent-patterns/SKILL.md` — fixed two dangling references to a non-existent `memory-systems` skill; replaced with `para-memory-files` pointers (the actual closest equivalent in the harness).

---

## Agent Test Harnesses
**URL:** https://lilianweng.github.io/posts/2026-07-04-harness/
**Added:** 2026-07-08
**Source / Author:** Lilian Weng (lil'log)

**What it's about:** Survey of agent harness engineering patterns: plan→execute→observe→improve loop, persistent filesystem memory for long-horizon tasks, parallel sub-agents, Meta Context Engineering (MCE — a meta-agent that optimizes context management strategy itself), and AlphaEvolve-style evolutionary search. Introduces a seven-bottleneck checklist for diagnosing harness quality plateaus.

**What we added:**
- Skill augmentation: `skills/agent-harness-design/SKILL.md` — new "Phase 5: Harness Bottleneck Checklist" (7-item table: weak evaluators, memory lifecycle, incentive misalignment, diversity collapse, reward hacking, short-term bias, inappropriate oversight points) and "Meta Context Engineering (MCE)" section (three MCE shapes: agentic crossover, context flow strategy evolution, harness self-repair loop).

---

## Don't Rewrite Your CLI for Agents
**URL:** https://developer.microsoft.com/blog/dont-rewrite-your-cli-for-agents
**Added:** 2026-07-08
**Source / Author:** Microsoft Developer Blog

**What it's about:** Empirical study showing traditional argument-based CLI interfaces strictly outperform JSON payloads for agent use. Key findings: args achieve 100% correctness across all models; JSON degrades smaller models (Haiku 4.5: 40% vs 100%). JSON costs 4×–11× more tokens per task due to retry cycles. Shell escaping tax causes 9× cost gap on PowerShell vs Bash for JSON mode (args unaffected). Core principle: narrowing the valid input space compensates for model capability gaps.

**What we added:**
- Skill augmentation: `skills/tool-design/SKILL.md` — new "CLI-to-Agent Bridging" section with empirical data table, the "don't rewrite" rule, and a minimal intervention checklist (exit codes, quiet mode, optional `--json` flag). Fills the gap between "design a new tool" (existing content) and "make an existing CLI agent-friendly" (previously uncovered).

---

## Agent-Assisted SGLang Development: An Initial Exploration
**URL:** https://www.lmsys.org/blog/2026-07-02-agent-assisted-sglang-development
**Added:** 2026-07-28
**Source / Author:** LMSYS Org (SGLang Team)

**What it's about:** Agents are most effective inside complex systems when constrained by executable, evidence-gated workflows rather than given free rein. Emphasizes evidence-before-code (fixed profiling tables), frozen benchmarks, anti-reward-hacking containment (identical build path/flags for baseline vs candidate), and hard machine-checkable loop exit conditions.

**What we added:**
- Skill augmentation: `skills/agent-execution-control/SKILL.md` — "Machine-Checkable Exit Conditions" pattern ("a single sentence claiming task complete is not enough to exit").
- Resource augmentation: `skills/evaluation/resources/benchmark-construction.md` — anti-reward-hacking A/B containment (hold everything identical except the change under test; interleave runs; invalidate a run if the measured path silently changed).

---

## Agentic coding notes from Galapagos Island
**URL:** https://danluu.com/ai-coding/
**Added:** 2026-07-28
**Source / Author:** Dan Luu

**What it's about:** Practitioner-grounded notes on agentic coding failure modes and workarounds. Key empirical finding: agents explaining a hypothesis without running code were wrong ~50% of the time even across independent cross-checks; forcing actual execution removed most errors. Also covers contrarian persona ensembles, fuzzing invariants, and building bespoke loops over heavyweight orchestrators.

**What we added:**
- Skill augmentation: `skills/agent-execution-control/SKILL.md` — "Forced execution beats cross-checking" empirical rule tied into Plan-Execute-Verify.
- Skill augmentation: `skills/multi-agent-patterns/SKILL.md` — "Contrarian Persona Ensemble" pattern (each persona guards a named loop pathology; improves output at equal budget).
- Skill augmentation: `skills/loop-patterns/SKILL.md` — "Fuzz invariants, don't write tests" + "Build bespoke loops, not heavyweight orchestrators" (with the loops-degrade-without-a-human caveat).

---

## Closing the Verification Loop
**URL:** https://thinkroom.kieranklaassen.com/d/njrS5TJhis
**Added:** 2026-07-28
**Source / Author:** Kieran Klaassen (ThinkRoom)

**What it's about:** A seven-phase autonomous-QA skill where a branch proves itself ready: real-browser reality, functional + experiential (persona) judges, a fix-loop governor that escalates decisions it shouldn't make, and proof durable to a commit SHA per scenario. Central thesis: autonomous verification is about being auditable, not confident.

**What we added:**
- Skill augmentation: `skills/verification-skill-authoring/SKILL.md` — "Autonomous-QA Methodology" section encoding Flows-before-Matrix (The Email Rule), dual judges, the Fix-Loop Governor, regression-test-per-fix (red-before/green-after), independence-budgeting, and the exit gate ("a green matrix with a red suite is not ready").

---

## Stop Being the Code Review Bottleneck
**URL:** https://newsletter.posthog.com/p/code-review-tips
**Added:** 2026-07-28
**Source / Author:** PostHog Newsletter — Jina Yoon

**What it's about:** Delegate review toil to swarms of AI reviewer agents behind fail-closed automation, reserving human attention for genuinely complex decisions. Introduces StampHog, a PR auto-stamper with concrete fail-closed safety gates. Mostly corroborates existing harness rules (reviewer≠author, adversarial swarm, verify-by-observation); the novel artifact is the auto-approve gate checklist.

**What we added:**
- Agent augmentation: `agents/kiro/guardrails-agent.md` — "PR Auto-Approve Gate (Fail-Closed)" checklist: no conflicts/change-requests → deny-list blast radius (auth/secrets/billing/public APIs) → diff cap (<500 lines AND <20 files) → LLM showstopper pass → SME/CODEOWNERS routing; stamps only when all pass.

---

## Benchmarking Coding Agents on Databricks' Multi-Million Line Codebase
**URL:** https://www.databricks.com/blog/benchmarking-coding-agents-databricks-multi-million-line-codebase
**Added:** 2026-07-28
**Source / Author:** Databricks Blog — Gaba, Mathur, Singh, Wendell, Zaharia

**What it's about:** An internal benchmark built from real merged PRs. Findings: no vendor owns the Pareto frontier, the harness matters as much as the model (>2x cost swing on the same model), and setups should be ranked by cost-per-completed-task rather than per-token price. Uses execution-based grading (no LLM judge) and git-history sealing to prevent agents recovering the solution from commits.

**What we added:**
- Resource augmentation: `skills/evaluation/resources/benchmark-construction.md` — real-PR→prompt recipe (filter, strip solution, human-review, rewrite tests to allow alternative implementations), execution-based grading, and git-history-sealing anti-cheat.
- Skill augmentation: `skills/agent-harness-design/SKILL.md` — governing principle blockquote "The harness matters as much as the model" + cost-per-completed-task ranking.

---

## Flint: A Visualization Language for the AI Era
**URL:** https://www.microsoft.com/en-us/research/blog/flint-a-visualization-language-for-the-ai-era/
**Added:** 2026-07-28
**Source / Author:** Microsoft Research — Wang, Sarikaya, Tsukamaki, Galley, Gao

**What it's about:** An intermediate, semantic, human-editable chart language: the LLM emits terse high-level intent + semantic types, and a compiler derives the fragile low-level details (scales, formatting, layout). The transferable principle — emit intent, derive config — applies well beyond charts to any tool where the model currently hand-writes verbose fragile config.

**What we added:**
- Skill augmentation: `skills/tool-design/SKILL.md` — "Intent-vs-Compiler: Emit Intent, Derive Config" section (two-layer example, token-cost + error-surface payoff, decision rule).

---

## 18 Claude Settings That Change Everything
**URL:** https://agent-cookbook.com/tutorial/18-claude-settings-that-change-everything-14-are-hidden-3-clicks-deep-4-arent-in
**Added:** 2026-07-28
**Source / Author:** Agent Cookbook

**What it's about:** A catalog of Claude/Claude Code/API settings. Reliability is mixed — several claims (inference_geo, residency premiums, a "Dreaming signal") appear fabricated. Only a verified token-economics subset was extracted; the rest was deliberately excluded.

**What we added:**
- Skill augmentation: `skills/context-optimization/SKILL.md` — "Claude Code Token-Economics Settings" with ONLY two verified items: the MCP server `enabled` flag (~800–6,000 tokens/server, toggle per session) and prompt-caching breakpoint placement (after the stable prefix; TTL economics cross-checked against `claude-api`, with the 1h-TTL break-even discrepancy flagged rather than encoded). No settings.json was modified.

---

## Introducing OpenWiki Brains: General-Purpose Wiki Memory for Agents
**URL:** https://www.langchain.com/blog/introducing-openwiki-brains-general-purpose-wiki-memory-for-agents
**Added:** 2026-07-28
**Source / Author:** LangChain Blog — Brace Sproul

**What it's about:** Argues agent memory should be *proactive* (the agent fetches and maintains its own structured wiki from connected sources on a schedule) rather than *reactive*. Distinguishes deterministic connectors (auto-fetch feeds) from agentic connectors (goal-directed search tools). (Note: distinct from the `langchain-ai/openwiki` CLI repo logged in `git/README.md`, which was SKIP'd — this is the conceptual blog post, mined for framings only.)

**What we added:**
- Skill augmentation: `skills/agent-harness-design/SKILL.md` (Memory component) — "proactive vs. reactive memory" axis + "deterministic vs. agentic connector" taxonomy.

## Agent Skills — Best Practices (Anthropic official docs)
**URL:** https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | **Added:** 2026-07-28 | **Source:** Anthropic / Claude platform docs

**What it's about:** Official Anthropic authoring guide for SKILL.md files: naming/description rules, "one level deep" reference discipline, progressive disclosure, eval-driven development (build scenarios + a no-skill baseline before writing docs), per-model-tier testing, and script-writing anti-patterns.

**What we added:**
- Skill enhancement: `skill-creator` — added gerund-form naming check, third-person description mandate, one-level-deep reference rule, >100-line-needs-TOC rule, eval-driven development (≥3 scenarios + baseline), per-model-tier testing, "solve don't defer" script-constant justification, and MCP fully-qualified tool naming.
- Skill enhancement: `skill-extraction` — reconciled Phase 5b SkillOS Quality Gate table against the same checklist (added as sub-bullets under existing Content quality / Compression dimensions, no new row added).

---

## Graph Engineering vs Loop Engineering
**URL:** https://www.aibuilderclub.com/blog/graph-engineering-vs-loop-engineering | **Added:** 2026-07-28 | **Source:** AI Builder Club

**What it's about:** Argues a loop is just one node in a graph, and promoting a loop to a multi-node graph only pays off under specific conditions — otherwise it's a relabeled loop with added maintenance cost. Provides a 4-question gut-check to score whether a design is a genuine paradigm shift.

**What we added:**
- Skill enhancement: `loop-patterns` — new "When a loop should become a graph, not just relabeled" subsection with the 4-question gut-check and scoring rubric (0-1 yes = keep it a loop; 2-3 = genuine composition; 4 = paradigm shift).

---

## AI-Native Code Review
**URL:** https://agentfield.ai/blog/ai-native-code-review | **Added:** 2026-07-28 | **Source:** AgentField

**What it's about:** Argues traditional PR review bundles jobs that fracture once AI writes code autonomously, and proposes "risk telescope" framing — per-dimension tunable thresholds instead of a single pass/fail verdict — plus an adversarial false-positive-suppression pass before surfacing findings.

**What we added:**
- Agent enhancement: `agents/kiro/guardrails-agent.md` — new "Refinements: Risk Telescope + Adversarial Suppression" section composing with the existing PR Auto-Approve Gate (deny-list decides which dimensions need human review; risk telescope tunes how sensitive each dimension's auto-flagging is; adversarial pass filters findings before they reach the human or the showstopper check).

---

## Designing APIs for Agents
**URL:** https://www.freestyle.sh/blog/opinion/designing-apis-for-agents | **Added:** 2026-07-28 | **Source:** Freestyle

**What it's about:** Argues agent-facing API design inverts human-API conventions — agents read full docs in one pass, so explicit-over-defaults, strict/precise error messages, unambiguous field naming, and thin "facts not utilities" interfaces serve agents better than convenience abstractions.

**What we added:**
- Skill enhancement: `tool-design` — new "Agent-Facing API Design Checklist" section with the four principles (explicit-over-defaults, strict errors over lenient coercion, unambiguous field naming, facts-not-utilities).

---

## 3 Techniques to Reduce Token Consumption in Claude Code / Codex
**URL:** https://tech.autoscout24.com/blog/posts/3-techniques-to-reduce-token-consumption-claude-code-codex/ | **Added:** 2026-07-28 | **Source:** AutoScout24 Tech Blog

**What it's about:** Argues token waste mostly comes from "information movement" (noisy output, blind file search, over-powered models) rather than reasoning. Covers output-trimming, structural/code-graph search over brute-force Grep, and task-based model routing.

**What we added:**
- Skill enhancement: `rtk-token-reduction` — new "Structural index before Grep/Glob" section (prefer AST-aware tools as the first navigation step on unfamiliar code) and "Subagent token caps" section (cap subagent reply length/model/tool allowlist for bounded subtasks; track cache-hit ratio and cost-per-task).

---

## Thariq (Anthropic / Claude Code team) — agentic workflow talk
**URL:** https://www.youtube.com/watch?v=IHbsfvbfAto | **Added:** 2026-07-28 | **Source:** YouTube (summary derived from search snippets, not a verified transcript)

**What it's about:** Describes a `/goal`-style mechanism to keep long agent runs on a persistent objective, a plan-before-build "remove unknowns" pass, and an 80% system-prompt-length cut by the Claude Code team.

**What we added:**
- Skill enhancement: `agent-harness-design` — one sentence cross-referencing the `/goal`-style persistent-objective pattern next to the existing Agent-Run Contract, explicitly flagged as a low-confidence/unverified source since the summary was search-derived rather than primary-source verified.

---

## Own the Outer Loop
**URL:** https://addyo.substack.com/p/own-the-outer-loop | **Added:** 2026-07-30 | **Source:** Addy Osmani (Substack)

**What it's about:** As agents write more code, the human's job shifts to owning the "outer loop" — accountability for shipping decisions, not code authorship. Introduces a "ladder of agency" (flag → investigate → execute → diagnose → propose → recommend → resolve) for graduated autonomy on out-of-scope discoveries, and reframes the governing question from "can we build this" to "should this exist, can we answer for it." Third Osmani piece extracted here — see "Agentic Code Review" (2026-06-17) and "Agentic Autonomy Levels" (2026-07-28, `docs/sources/x/README.md`), both of which already absorbed most of this article's accountability/contract/evidence framing.

**What we added:**
- Skill enhancement: `agent-permissions-design` — new "Ladder of Agency (Handling Out-of-Scope Discoveries)" section, mapping the 7-rung escalation model onto the skill's existing Scope Inheritance principle and Step 4 action-classification table.
- Command enhancement: `commands/kiro/pref-elicit.md` — new Step 1.5 "Confirm This Is Worth Building" existence check before the 5-question Socratic session, plus a "Why This Exists" section in the generated `prefs.md` output. Advisory, not a gate.
- Rejected: accountability contract (already distributed across `pr-babysit` Authority Boundary, Post-Task Convention, `action-capture.sh`); brownfield practices — worktrees/scoped-changes/time-boxing (covered by `using-git-worktrees`, `agent-permissions-design` scope inheritance, `agent-harness-design` stopping conditions); "operationalize your taste" (already the operating model of `impeccable-audit`/`clarity-gate`); distinct human roles reorg (org-design advice, not agent-actionable); decision-evidence logging for long-horizon tasks (covered by `action-capture.sh` + Agent-Run Contract evidence requirements); survey/study statistics (context only).

---

## Interviewing Engineers in the AI Era: Lessons from a Year of Rebuilding
**URL:** https://www.coinbase.com/blog/interviewing-engineers-in-the-ai-era-lessons-from-a-year-of-rebuilding | **Added:** 2026-07-30 | **Source:** Coinbase Engineering Blog

**What it's about:** Coinbase rebuilt its engineering interview loop for the AI-coding era around a 3-dimension "AI Fluency Rubric" (Usage / Application / Understanding Limits) and a strict "we don't add rounds" discipline — new signal must replace or merge with existing signal, never stack. The concrete evidence: two interview rounds meant to test different things showed 84% outcome correlation, meaning most of the second round's signal was already captured by the first; the fix was merging rounds, not adding a third to compensate.

**What we added:**
- Skill enhancement: `multi-agent-patterns` — new "Redundant Signal Check" subsection (after Contrarian Persona Ensemble) applying the 84%-correlation finding to review/verify pipelines: before stacking a new pass, check whether it's empirically redundant with an existing one; merge if so, only add a pass that catches a genuinely distinct failure mode.
- Rejected: AI Fluency Rubric and the rest of the interview-loop redesign (HR/hiring process, out of scope for a coding-agent harness).

---

## Eval Gates for Prompts
**URL:** https://luke.geek.nz/azure/eval-gates-for-prompts/ | **Added:** 2026-07-30 | **Source:** luke.geek.nz

**What it's about:** Argues prompt edits deserve the same CI gate as code deploys — fail closed if no eval exists, evaluate only the latest version, require actionable failure messages, and warn that a slow/opaque gate invites silent bypass paths. Frames a 4-stage maturity model (no process → manual review → automated eval gate → continuous evaluation of live traffic feeding regressions back into the test set), illustrated via Microsoft Foundry's prompt-agent versioning and the `microsoft/ai-agent-evals` GitHub Action.

**What we added:**
- Skill enhancement: `skill-curator` — new "Phase 3.5: Continuous Eval-Gate Drift Check" (stage 4 of the article's maturity model): samples Raindrop traces for skills with a logged `skill-eval-gate` PASS, clusters via `active-observability` to surface failure patterns the original scenario set missed, and proposes new scenarios as an "Add eval scenario" curation action. Rides the existing weekly cron — no new schedule.
- Skill enhancement: `skill-eval-gate` — new Safety bullets: overrides of a FAIL/INCONCLUSIVE verdict must be logged durably to `docs/skill-curation-report.md` history (not just the turn's chat summary), per the article's silent-bypass-becomes-default warning; and an explicit note that scenario sets go stale and should be revisited via the new drift check, not treated as one-time checkpoints.
- Rejected: statistical-significance/confidence-interval scoring (article's CI action runs over hundreds of live samples; harness gate runs n=3-5 authored scenarios — stat testing at that N is theater); prompt versioning + N→N+1 promotion routing (already solved by git + `update.sh`); separate status-check vs promotion-authority roles (no analog — skill-extraction Phase 5b is already the single promotion gate); standalone new hook/script (trigger is time-based drift, not a tool event — folded into the existing weekly routine instead).

---

## The Session You Cannot Take With You
**URL:** https://earendil.com/posts/session-portability/ | **Added:** 2026-08-02 | **Source:** Earendil Engineering blog

**What it's about:** Argues stateful LLM provider APIs (OpenAI Responses API, Anthropic Messages, Gemini Interactions API) are breaking the assumption that a saved transcript fully represents a session, via 6 opacity mechanisms — encrypted reasoning tokens, hosted search with only citations exposed, opaque server-side compaction, encrypted subagent messages, provider-only-resolvable file/cache references, and server-keyed conversation IDs. Proposes 5 audit criteria (Inspection / Export / Replay / Audit / Deletion) and 7 recommendations for anyone building agent systems against these APIs.

**What we added:**
- Skill enhancement: `secure-agent-design` — new "Pattern 7: Provider-State Portability & Audit Trail" section applying the 5 criteria as a design-review checklist (relying solely on `store:true`/`previousResponseId`, hosted-search citations without logged evidence, forwarding encrypted reasoning/signature blocks across a model switch, encrypted subagent messages with no plaintext log), plus a new checklist line in the skill's "Before Shipping an Agent" list.
- Rejected: standalone new skill (this is the same "agent touches external/provider state safely" concern `secure-agent-design` already owns — augmenting keeps it one coherent file rather than fragmenting); hook enforcing portability checks on file writes (no reliable static signal without heavy false positives — needs judgment); dashboard widget scoring session portability (nothing in this harness's actual Claude Code CLI usage exercises the measured failure mode — would show a permanently empty metric); augmenting `compaction-discipline-hook.sh`/`write_handoff.py` to log "lineage of what compaction dropped" (not automatable — Claude Code exposes only a `PreCompact` hook, no `PostCompact` diff, so what the real compaction step removed is invisible to us; current handoff snapshot is already the best available substitute); verbatim `session.export()`/`continueFrom()` pseudocode (no real SDK implements it as shown — documentation-only noise).

---

## Evals Skills for Coding Agents
**URL:** https://hamel.dev/blog/posts/evals-skills/ | **Added:** 2026-08-02 | **Source:** Hamel Husain (hamel.dev)

**What it's about:** Argues vendor eval MCP servers (Braintrust, LangSmith, Phoenix, Truesight) give agents data access but not judgment, and ships 7 Claude Code skills (`eval-audit`, `error-analysis`, `generate-synthetic-data`, `write-judge-prompt`, `validate-evaluator`, `evaluate-rag`, `build-review-interface`, repo: [hamelsmu/evals-skills](https://github.com/hamelsmu/evals-skills)) as a starting-point taxonomy of eval judgment tasks. Recommends practitioners build stack/domain-specific skills rather than relying on generic ones.

**What we added:**
- Skill enhancement: `evaluation/micro` — new "Error-Analysis Bootstrap" section (7-phase manual process: collect ~100 traces, read-and-note first-root-cause-only, cluster into 5–10 categories after 30–50 traces, label, compute failure rates, prioritize direct-fix > code-check > LLM-judge-evaluator, iterate). Fills a real gap: `evaluation/macro` and `active-observability` both assume an ML-clustering pipeline already exists — this is the human-driven bootstrap step before that infra is worth building. Output written to `.claude/memory/failure-taxonomy-<date>.md`, picked up automatically by the dashboard's memory-files panel (no new widget needed).
- Doc update: `docs/evaluation/README.md` — new entry for the error-analysis addition, matching the existing per-sub-skill convention (extracted-from link, coverage bullets, automation status).

**Rejected:** `validate-evaluator`'s TPR/TNR + Rogan-Gladen bias-correction judge-validation technique — real methodology, but requires a volume of human pass/fail labels on the exact quality dimension being judged, and this harness (internal dev tooling, no end-user-graded outputs) has no automatic source for that. Existing `action-capture.sh` only captures objective git/test/deploy signals, which don't need an LLM judge in the first place. Revisit if a downstream project starts collecting real human-graded output at volume. Also rejected: `eval-audit` (repo SKILL.md unfetchable, and structurally redundant with the existing `evaluation` router + `skill-curator`/`claudemd-review` fan-out-and-synthesize pattern), `write-judge-prompt` (binary-vs-Likert nuance folded as a one-line note rather than a standalone skill — rest already covered by `evaluation/micro`'s LLM-as-Judge section), `evaluate-rag` (no RAG project in current harness scope), `generate-synthetic-data` (no concrete method given in the source, already loosely covered by `evaluation/macro` Phase 0), `build-review-interface` (one-off UI-scaffolding task, not a repeatable methodology).

---

## Stacked pull requests are now in public preview
**URL:** https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/ | **Added:** 2026-08-02 | **Source:** GitHub Changelog

**What it's about:** GitHub native feature (public preview, 2026-07-30): break one large change into ordered, dependent PRs ("layers"), each targeting the layer below via the `gh-stack` CLI extension (`gh extension install github/gh-stack`). Reviewers see one layer's diff at a time via a stack map; merging the top PR cascades all unmerged layers beneath it; merging a lower layer auto-rebases/retargets the layers above. Launched after the model's Jan 2026 training cutoff — genuine capability gap, not generic git-workflow duplication.

**What we added:**
- Skill: `stacking-pull-requests` — reference for the automated flow below; owns troubleshooting (sync conflicts, reordering via `gh stack modify`, abandoning a stack), manual overrides (`SDD_SKIP_STACK`, `SDD_STACK_MIN_TASKS`), and deliberately does not restate `gh stack`'s CLI surface (public preview, delegates to GitHub's own docs/companion skill to avoid staleness).
- Script augmentation: `skills/git-pushing/scripts/smart_commit.sh` — auto-detects stack eligibility on the first task commit of a spec-impl branch (gh-stack extension installed + a `specs/<slug>/tasks.md` whose slug matches the branch name + ≥2 total tasks), inits the stack, and routes every subsequent commit through `gh stack add` + `gh stack submit --auto` instead of a plain commit — mapping this harness's existing "one task = one commit" convention (`CLAUDE.md:19`) onto "one task = one stack layer" with no per-instance judgment call needed.
- Hook augmentation: `scripts/pr/detect_base_and_create.sh` (shared by `pr-auto-create-hook.sh` / `pr-mention-nudge.sh`) — if `.git/gh-stack` shows an active stack, runs `gh stack submit --auto` instead of bundling everything into one `gh pr create`. Covers manual pushes that bypass `smart_commit.sh`.
- Doc updates: `docs/hooks/README.md` (both `detect_base_and_create.sh`-backed hook sections, new `[STACK-SUBMITTED]` output line); `skills/git-pushing/SKILL.md` (new "Stacked PRs" note).

**Rejected:** wrapper script around `gh stack` (CLI already complete, no capability gained); new `/stack-pr` slash command (redundant — the automation is unconditional, and manual invocation is covered by the skill's natural-language trigger); dashboard widget (one-time workflow decision, not an ongoing metric); editing the plugin-owned `create-pr`/`finishing-a-development-branch`/`git-advanced-workflows` skills (`~/.claude/skills/`, not harness source — edits would be lost on the next plugin update).
