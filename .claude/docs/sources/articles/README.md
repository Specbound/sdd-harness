# Articles

Online articles, blog posts, and documentation pages that were passed to `/skill-extraction` and turned into harness skills. Ordered by date added.

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

## The Website Specification
**URL:** https://specification.website | **Added:** 2026-06-02

**What it's about:** A platform-agnostic, machine-readable reference for 100+ web standards across 10 categories: Foundations, SEO, Accessibility, Security, Well-Known URIs, Agent Readiness, Performance, Privacy, Resilience, and Internationalisation. Every spec is tagged `required` / `recommended` / `optional` / `avoid`. Accessible as Markdown endpoints, `/llms-full.txt`, or via a stateless HTTP MCP server at `https://mcp.specification.website/mcp` (tools: `search`, `list_topics`, `get_topic`, `get_checklist`, `audit_url`). The site also publishes its own Agent Skill at `/.well-known/agent-skills/specification-website/SKILL.md`.

**What we added:**
- Skill: `website-spec` — when/how to use the specification.website MCP, audit workflow (required → recommended → optional), status level semantics, Agent Readiness category guide (llms.txt, MCP discovery, A2A, DNS-AID, Web Bot Auth), and citation rules.
- Config: `specification-website` MCP server registered in user scope (`~/.claude.json`) via `claude mcp add --transport http`.

---

## The AI Agent Bottleneck Isn't Model Performance — It's Permissions
**URL:** https://venturebeat.com/orchestration/the-ai-agent-bottleneck-isnt-model-performance-its-permissions | **Added:** 2026-06-02 | **Source:** VentureBeat

**What it's about:** Enterprise AI agents stall not on model capability but on authorization design. The core argument: permissions must live where the data lives (in the system of record, not a separate governance layer), agents must be scoped to a strict subset of the authorizing human's actual permissions, high-stakes actions need a separate pre-execution verification model (not self-check), and audit trails must be co-located with the data in-transaction. Quotes Workday's Sana agent architecture (Gemini base + context engine + verification models + SoR-scoped execution + SoR audit write) and practitioners from Würk and Compance.AI.

**What we added:**
- Skill: `agent-permissions-design` — five-principle framework (scope inheritance, system-of-record authority, pre-execution verification gates, agent identity transparency, audit co-location), 7-step design workflow, action classification table (read-only / reversible write / irreversible write / cross-system), agent identity record schema, anti-pattern catalogue, and the Sana reference architecture diagram.
- Enhancement: `ai-agents-architect` — added "Permissions & Scope" section pointing to `agent-permissions-design` as a first-class design concern; added it to Related Skills.
- Hook: `skill-permissions-gate.sh` — PostToolUse on `Write|Edit` to `*/skills/*/SKILL.md`; fires a soft gate after every skill write prompting Claude to invoke `agent-permissions-design` and verify tool access, irreversible action gates, scope boundaries, and external access before marking skill creation complete. Registered in harness `.claude/settings.json`.
- Enhancement: `skill-creator` Phase 4c — explicit Permissions & Scope Review step added before installation.
- Enhancement: `skill-extraction` Phase 5d — explicit Permissions & Scope Review step added before the Confirm phase.

---

## Introducing Dynamic Workflows in Claude Code
**URL:** https://claude.com/blog/introducing-dynamic-workflows-in-claude-code
**Added:** 2026-05-31
**Source / Author:** Anthropic

**What it's about:** Announces Claude Code's `Workflow` tool (research preview, May 2026) — deterministic JavaScript-script-based orchestration that fans out tens-to-hundreds of parallel subagents within a single session. Covers the `ultracode` effort setting (auto-deploys workflows for complex tasks), task shapes that warrant a workflow (service-wide audits, multi-hundred-file migrations, adversarial verification sweeps), token cost warnings (start scoped), first-workflow confirmation protocol, and progress persistence/resume.

**What we added:**
- Skill enhancement: `multi-agent-patterns` v1.3.0 — "Tool Selection: Agent vs. Workflow" section with decision table, task-shape routing tree, ultracode mode note, and token budget guidance. Positions the `Workflow` tool as the scale-escalation path above `Agent`-based dispatch, with explicit cross-link to `superpowers:dispatching-parallel-agents` for the small-fleet path.

---

## Agentic RL: Token-In, Token-Out Done Right
**URL:** https://qgallouedec-tito.hf.space | **Added:** 2026-06-02 | **Source:** Hugging Face (qgallouedec)

**What it's about:** Identifies a silent correctness bug in multi-turn RL training loops for tool-calling LLMs. When conversation history is re-rendered through the chat template at each step, BPE drift produces different token sequences than what the model originally sampled — gradients then target tokens the model never generated. The fix is a single invariant ("never re-encode what you decoded") implemented via a running token buffer. Also covers the prefix-preservation property test (12-line Python), a model compatibility table (18/19 major open-weight models pass unchanged), the Qwen3 one-line Jinja template fix, and edge case handling (history rewriting, truncation).

**What we added:**
- Skill: `agentic-rl-tito` — TITO invariant, correct loop algorithm, prefix-preservation property test with code, model compat table, `compute_tool_delta()` pattern, edge case recipes. Fires only on RL fine-tuning / multi-turn training loop tasks. Full code patterns in `resources/code-patterns.md`.
