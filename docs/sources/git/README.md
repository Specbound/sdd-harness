# Git Repositories

GitHub repositories that were passed to `/skill-extraction` and turned into harness skills, scripts, or tooling. Ordered by date added.

---

## github.com/karpathy/autoresearch
**URL:** https://github.com/karpathy/autoresearch | **Added:** 2026-03-30

**What it is:** Andrej Karpathy's autonomous ML research agent that iterates on a training script overnight — reads a research brief (`program.md`), proposes one hypothesis per loop, edits `train.py`, runs a 5-minute wall-clock-bounded experiment, keeps improvements via git commit, reverts failures via `git checkout`, and loops.

**What we added:**
- Command: `/kiro:autoresearch-init` — interactive 8-question interview that generates all 3 required files (`program.md`, `train.py`, `prepare.py`) from a user description
- Command: `/kiro:autoresearch [N]` — runs the autonomous experiment loop (N iterations or continuous)
- Agents: `autoresearch-init-agent` (interview → file generation), `autoresearch-agent` (experiment loop executor)
- Docs: `docs/autoresearch/README.md` — loop diagram, file roles, use cases, example `program.md`

---

## github.com/abhigyanpatwari/GitNexus
**URL:** https://github.com/abhigyanpatwari/GitNexus | **Added:** 2026-04-16

**What it is:** Zero-server code intelligence engine that builds a knowledge graph (symbols, dependencies, call chains, execution flows) from a codebase and exposes it via MCP tools.

**What we added:**
- Integration: PreToolUse hook (`hooks/claude/pre-tool-use-gitnexus.sh`) — automatically enriches every file read/edit with 360-degree symbol context (callers, deps, blast radius). Zero agent configuration needed.
- Integration: Post-commit hook auto-reindex — `hooks/git/post-commit` re-indexes the repo after every commit so the knowledge graph stays fresh.
- Integration wired into: `verify-agent` (Stage 0 risk detection), `spec-impl` (blast radius scan before TDD), `debug-agent` (Step 2 call chain tracing), `skill-extract-agent` (Leiden community cluster seeding)
- Command: `/kiro:gitnexus-explore` — launches GitNexus Web UI (localhost:4747) for visual repo exploration
- Docs: `docs/gitnexus/README.md`

---

## github.com/nidhinjs/prompt-master
**URL:** https://github.com/nidhinjs/prompt-master | **Added:** 2026-05-06

**What it is:** Active prompt factory with 30+ tool profiles, 14 templates, 38 anti-patterns, and native JSON-structured input support. Core insight: models guess when dimensions (tone, format, audience, length) are unspecified — JSON eliminates the guessing surface.

**What we added:**
- Skill: `prompt-master` v1.7.0 — JSON input detection, 9-dimension extraction framework, 30+ tool profiles across 11 categories, 14 templates, 38 anti-patterns (including 7 agentic credit-killers). Activates when ≥3 dimensions unspecified in a prose prompt.
- Lazy-load references: `references/templates.md` + `references/patterns.md` (loaded on demand to avoid context bloat)
- Docs: `docs/prompt-master/README.md` — JSON vs prose decision matrix, before/after gallery, key behaviors, tool profiles table

---

## github.com/openai/privacy-filter
**URL:** https://github.com/openai/privacy-filter | **Added:** 2026-05-06

**What it is:** OpenAI's Privacy Filter (OPF) — an 8-layer bidirectional transformer with sparse MoE FFN (128 experts, top-4) and Viterbi CRF decoder for character-level PII span extraction. ~2.8GB model weights auto-download on first use.

**What we added:**
- Hook: `hooks/claude/scan-pii.sh` — pre-commit git hook that runs OPF on staged files; exits 2 (warn, don't block) when OPF is missing; exits 1 on high-severity PII detection
- Docs: `docs/privacy-filter/README.md` — architecture diagram, graceful degradation pattern, output modes, Python API, performance tuning (`OPF_TORCH_COMPILE=1` for ~20% speedup), troubleshooting table. Links to: `secrets-management`, `gdpr-data-handling`, `security-sast`

---

## github.com/EveryInc/proof-sdk
**URL:** https://github.com/EveryInc/proof-sdk | **Added:** 2026-05-06

**What it is:** SDK for Proof — a collaborative markdown review tool that starts a local server, publishes a document to a live shareable URL, lets stakeholders comment and edit inline, and returns the finalized version. Designed for async multi-stakeholder review workflows.

**What we added:**
- Skill: `proof-collaborative-review` — SDD phase-gate integration: publishes spec/design/task-list artifacts to a live Proof document, waits for human review/adjustment, retrieves the final version, tears down the server. Used at spec phase transitions requiring stakeholder sign-off where "approve/reject" is insufficient.

---

## github.com/pbakaus/impeccable
**URL:** https://github.com/pbakaus/impeccable | **Added:** 2026-05-07

**What it is:** Design quality system for detecting AI-generated UI fingerprints and enforcing professional design standards via 27 deterministic rules across 7 domains.

**What we added:**
- Skill: `impeccable-audit` — 27 deterministic anti-pattern rules across typography, color/contrast, spatial design, motion, interaction, responsive, and UX writing. AI fingerprint detection flags 7 patterns that reliably mark AI-generated UIs: gradient text, glassmorphism, colored left borders, gradient backgrounds, nested cards, identical card grids, pure white backgrounds. Output: structured audit with PASS / NEEDS WORK / BLOCK verdict + file:line references.
- Hook: `hooks/claude/impeccable-detect-hook.sh` — detects when a prompt targets frontend/UI work and injects a reminder to run `impeccable-audit` before shipping.

---

## github.com/codejunkie99/ztk
**URL:** https://github.com/codejunkie99/ztk | **Added:** 2026-05-07

**What it is:** Quality metrics toolkit for measuring code authorship and survival patterns in git repositories. The key insight extracted: measuring the survival rate of generated code (% of lines still in HEAD after N days) provides a lagging quality signal independent of test passage.

**What we added:**
- Skill: `keep-rate` — calculates % of Claude-authored lines (grep: `Co-Authored-By: Claude` or `noreply@anthropic`) still present in HEAD after 7+ days. Thresholds: >80% strong, 60–80% normal, 40–60% warning, <40% alert. Auto-appends kaizen observations below 50%. Recommended cadence: Monday/Thursday evenings via CCR routine.

---

## github.com/garrytan/gbrain
**URL:** https://github.com/garrytan/gbrain | **Added:** 2026-05-12

**What it is:** GBrain — a pattern library for agent harnesses covering model tier selection (haiku/sonnet/opus routing), compiled-truth memory structure (State zone rewrite-in-place, Evidence zone append-only), memory-first lookup chains, and background task routing. Key principle: protocols should fire at the moment they're needed, not be manually invoked.

**What we added:**
- Hook: `hooks/claude/gbrain-agent-spawn.sh` (PreToolUse `Agent`) — injects model-tier guidance (haiku=classification, sonnet=generation/subagents, opus=deep-reasoning-only) + background-routing pain signals before every Agent spawn
- Hook: `hooks/claude/gbrain-memory-write.sh` (PreToolUse `save_observation`) — enforces compiled-truth two-zone structure (State at top rewrite-in-place, Evidence append-only at bottom) before every memory write
- Hook: `hooks/claude/gbrain-external-search.sh` (PreToolUse `WebFetch|WebSearch`) — injects memory-first lookup reminder (search → get_observations → timeline) before reaching external APIs
- Skill: `agent-memory-consolidation` — episodic-first architecture, 3 consolidation failure modes (misgrouping, interference, overfitting), audit checklist
- Docs: `docs/gbrain-patterns/gbrain-patterns.md`

---

## github.com/melagiri/code-insights
**URL:** https://github.com/melagiri/code-insights | **Added:** 2026-06-11

**What it is:** Local session analytics tool that parses AI coding sessions (Claude Code, Cursor, Copilot), extracts structured knowledge (decisions, learnings, cross-session patterns), scores prompt quality across 6 LLM-derived dimensions, and serves a React dashboard at localhost:7890 backed by a local SQLite DB. Privacy-first: no cloud sync, uses your own API key.

**What we added:**
- Hook: `hooks/claude/prompt-quality-check.sh` (PreToolUse `Agent`) — scores every agent spawn against 6 PQ dimensions (context_provision, request_specificity, scope_management, information_timing, correction_quality, overall) using fast Python heuristics; emits scored feedback to Claude's context; appends to `~/.code-insights/pq-log.jsonl`
- Hook extension: `hooks/claude/session-start-hook.sh` — added PQ baseline block that reads last 14 log entries and emits quality average + weakest dimensions at every session start
- Dashboard: `render_prompt_quality()` in `scripts/utils/dashboard.py` — new ✨ Prompt Quality sub-tab under Session Health; shows dimension bars, rolling trend, summary strip; reads `~/.code-insights/pq-log.jsonl`
- Skill: `prompt-quality-assess` — 6-dimension cognitive rubric with per-dimension rewrite patterns; pre-flight checklist to apply before writing agent prompts
- Docs: `docs/prompt-quality/README.md` — full system reference: dimensions, log format, files, hook output examples

---

## github.com/yvgude/lean-ctx
**URL:** https://github.com/yvgude/lean-ctx | **Added:** 2026-05-18

**What it is:** Single Rust binary MCP server exposing 51 `ctx_*` tools for token-efficient file reads and code analysis. `ctx_read(path, "signatures")` returns only exported symbols instead of full file (~400 tokens vs 12,000 for a typical file). Re-reads of cached files cost ~13 tokens regardless of size.

**What we added:**
- Integration: lean-ctx MCP server registered in harness `settings.json` template; complements RTK (RTK handles Bash output, lean-ctx handles file reads and AST analysis)
- Hook: `hooks/claude/lean-ctx-nudge-hook.sh` (UserPromptSubmit) — detects when a prompt involves file reading/analysis and suggests `ctx_read` modes over raw Read calls
- Docs: `docs/context-management/lean-ctx/README.md` — 10 read modes, ctx_graph vs gitnexus decision table, ctx_shell warning (don't use — RTK handles it), installation guide

---

## github.com/raindrop-ai/workshop
**URL:** https://github.com/raindrop-ai/workshop | **Added:** 2026-05-18

**What it is:** Raindrop Workshop — agent trace capture, replay, and evaluation platform. Records full execution traces from Claude agents, enables replaying specific runs, and provides an MCP server for querying spans and payloads programmatically.

**What we added:**
- Skills: `raindrop-instrument-agent`, `raindrop-eval-loop`, `raindrop-agent-replay` — instrument agent, run eval loops, and replay captured runs
- Dashboard: Raindrop Workshop tab added to `scripts/dashboard.py` (accessible at localhost port)
- Per-repo tracing configured across all 3 registered projects
- Docs: `docs/raindrop/README.md`

---

## github.com/bendc/frontend-guidelines
**URL:** https://github.com/bendc/frontend-guidelines | **Added:** 2026-05-27

**What it is:** Benjamin De Cock's opinionated HTML/CSS/JS style guidelines. Concise rules focused on correctness, brevity, and maintainability — semantic HTML, CSS structural patterns (selectors, specificity, units, composited-only animations), and JS idioms (pure functions, array methods over loops, composition, const-first).

**What we added:**
- Skill: `frontend-code-quality` — three-section code quality checklist (HTML, CSS, JS). Invoked during frontend code review. Pairs with `frontend-performance` for full coverage: `frontend-performance` handles architecture decisions, `frontend-code-quality` handles per-file patterns.

---

## github.com/hhhuang/CAG
**URL:** https://github.com/hhhuang/CAG | **Added:** 2026-05-27

**What it is:** Reference implementation of Cache-Augmented Generation — preloads knowledge documents into a HuggingFace model's KV cache once, persists the cache state to disk, and reuses it across queries. Eliminates real-time retrieval for bounded, stable knowledge bases. Accompanies arXiv:2412.15605.

**What we added:**
- Skill: `cag-implementation` — decision matrix (CAG vs RAG), three-phase implementation pattern (preload → persist → query loop), HuggingFace `past_key_values` implementation, and integration with the existing `rag-architect` skill routing decision. See also: [papers/README.md](../papers/README.md) for the accompanying paper.

---

## github.com/steipete/agent-scripts (skills/skill-cleaner)
**URL:** https://github.com/steipete/agent-scripts/blob/main/skills/skill-cleaner/SKILL.md | **Added:** 2026-05-31

**What it is:** Peter Steinberger's Codex/OpenClaw skill-cleaner — audits skill libraries for prompt-budget cost (descriptions as % of context window), duplicate skills, and unused skills. Includes a TypeScript analyzer that reads Codex session logs and models_cache.json.

**What we added:**
- Skill: `skill-curator` — local post-weekly-sweep curation step. The TypeScript script and Codex-specific paths (models_cache.json, history.jsonl) were not portable, but the core concepts were: description-budget analysis (chars per description, 150/200-char thresholds, grammar compression heuristics) were absorbed into Phase 2 of the skill. Phase 1 reads `docs/skill-curation-report.md` from the weekly skill-curator scheduled-tasks sweep; Phases 3–5 handle consolidated proposal + human-approved execution (merge/compress/delete). Also fixed a gap: the weekly sweep referenced `skill-curator` in its "How to use" but the skill didn't exist.
- Updated: `docs/scheduled-tasks/README.md` — corrected weekly routine's "How to use" to reference `/skill-curator`, added Known Limitation note about the sweep not accessing `~/.claude/skills/` directly.

---

## github.com/rtk-ai/rtk
**URL:** https://github.com/rtk-ai/rtk | **Added:** 2026-05-27

**What it is:** RTK (Rust Token Killer) — a Claude Code PreToolUse hook that intercepts Bash commands and rewrites them to compressed equivalents, achieving 60–90% token reduction on common dev operations (git, pytest, jest, tsc, eslint, Docker, kubectl, AWS CLI). Output semantics are preserved; only verbosity is removed.

**What we added:**
- Skill: `rtk-token-reduction` — guidance on when to use `rtk proxy` (exact raw output for piping/debugging), `rtk gain` (check cumulative savings), and how to configure exclusions for commands where compression would break downstream parsing.

---

## github.com/anomalyco/models.dev
**URL:** https://github.com/anomalyco/models.dev | **Added:** 2026-05-31 | **Live API:** https://models.dev/api.json

**What it is:** Open-source database of AI model specifications, pricing, and capabilities maintained by Anomaly. Covers 4,700+ models across 120+ providers (Anthropic, OpenAI, Google, Mistral, DeepSeek, xAI, Cohere, Amazon Bedrock, Azure, Groq, Perplexity, and many more). Per-model data includes context window, per-million-token pricing (input, output, cache read/write), input modalities, capability flags (tool use, vision, reasoning, structured output), and supported parameters. Published as a flat JSON blob at `https://models.dev/api.json` with per-provider nesting.

**What we added:**
- Dashboard section: **💰 Model Cost** (`scripts/dashboard.py`) — tracks Claude Code session token usage from `~/.claude/projects/*/` JSONL files, computes USD costs using historically-accurate pricing (snapshot closest to the session date), and renders: all-time + 30-day cost stats, 90-day daily cost chart, scrollable sessions table with per-project filter, and a cross-provider "What if?" switcher (cascading provider → model dropdowns covering all 12 featured providers, 394 priced models). A ⚠ icon flags sessions where pricing has changed since they ran.
- Artifact: `.dashboard/models-pricing-history.json` — local pricing snapshot store. Fetches `models.dev/api.json` on first run and bi-weekly thereafter; appends a new snapshot only when prices change (de-duplication by value comparison), so historical cost calculations remain accurate as the market moves.
- Functions added to `scripts/dashboard.py`: `load_or_refresh_pricing_history`, `get_pricing_at`, `gather_usage_data`, `_parse_session_file`, `compute_session_cost`, `render_model_cost`.
- Constants: `FEATURED_PROVIDERS` (12-provider curated list), `PROVIDER_DISPLAY` (human-readable names), `PRICING_HISTORY`, `PRICING_MAX_AGE`, `CLAUDE_PROJECTS`.

---

## github.com/multica-ai/andrej-karpathy-skills
**URL:** https://github.com/multica-ai/andrej-karpathy-skills | **Added:** 2026-05-31

**What it is:** A single-skill harness plugin packaging Andrej Karpathy's observations on LLM coding pitfalls into four behavioral principles: Think Before Coding (surface assumptions, present alternatives, ask when confused), Simplicity First (minimum code to solve the problem, nothing speculative), Surgical Changes (only touch lines traceable to the user's request, clean up only your own orphans), and Goal-Driven Execution (transform imperative tasks into verifiable test-first goals). Originally a `CLAUDE.md` snippet; the multica-ai fork ships it as a proper `SKILL.md` plugin.

**What we added:**
- Skill: `karpathy-guidelines` — 4-principle behavioral checklist that fires before every coding task (writing, editing, reviewing, refactoring). Description deliberately broad so the `using-superpowers` skill auto-invokes it on any coding request. Cross-references `questions`, `refactoring-safely`, and `test-driven-development` for deeper process support.

---

## github.com/affaan-m/ECC
**URL:** https://github.com/affaan-m/ECC | **Added:** 2026-05-31 | **Updated:** 2026-06-02

**What it is:** ECC ("harness-native operator system for agentic work") — a cross-harness AI agent operating system with 63 agents, 249 skills, and 15+ hook events, built over 10+ months of daily production use. Supports Claude Code, Cursor, OpenCode, Codex, Copilot, and Zed. Notable patterns: observer loop prevention (5-layer re-entrancy guard), hook profile switching via env vars, and instinct-based pattern extraction with confidence scoring.

**What we added:**
- Skill (augmentation): `hook-design` — added "Observer Loop Prevention" section (env-var sentinel, matcher specificity, state-file lock patterns) and "Session Profile Switching" section (`SDD_HOOK_PROFILE=off|minimal|standard` preamble pattern). Fills a gap: none of the existing harness hooks had re-entrancy guards despite firing on Write/Edit events that can themselves produce writes.
- Daily maintenance Step D (pattern scoring) — ECC's instinct-based pattern extraction with confidence scoring adapted as a new phase in `.claude/scripts/daily-maintenance-prompt.md`. Each morning the runner scans observations added since the last `[judge]:` line, scores each 1–5 for reusability, and appends PROMOTE-scored entries (4–5) to `.claude/memory/forward-patterns.md` as one-line reusable heuristics. The weekly skill-curator then picks up `forward-patterns.md` and decides what to graduate to full skills. Pattern score summary written as `[pattern-score]` observation. Docs updated: `docs/memory/README.md` (new file in tree + data flow).

---

## github.com/MemoriLabs/Memori
**URL:** https://github.com/MemoriLabs/Memori | **Added:** 2026-06-02

**What it's about:** Agent-native memory infrastructure built around the principle "memory from what agents DO, not just what they say." Provides a cloud MCP server + Python/TS SDK, but the valuable extract is its design patterns: entity/process/session attribution hierarchy, 8 augmentation layers (attributes, events, facts, preferences, relationships, rules, skills, people), and automatic memory capture from agent actions rather than conversational summaries. Achieved 81.95% on the LoCoMo benchmark at only 4.97% of full-context token footprint (~67% leaner than competing systems).

**What we added** (local patterns only — no cloud service, no API key required):
- Hook: `action-capture.sh` (PostToolUse, Bash, soft gate) — fires after `git commit`, failing `pytest` runs, and deploy commands; prompts Claude to consider saving a memory observation from the outcome. Implements the "memory from what agents do" principle locally without any external dependency.
- Skill enhancement: `agent-memory-discipline` — added "Memory Body Sub-Types" section (Memori's 8 augmentation layers mapped onto the 4 existing memory types for more precise body structure) and "Session Attribution" section (optional `session:` frontmatter field keyed by git branch or task descriptor for targeted retrieval).
- Docs updated: `docs/hooks/README.md` (new hook entry + wiring table), `docs/memory/README.md` (sub-types table + session attribution convention).

---

## github.com/agentscope-ai/ReMe
**URL:** https://github.com/agentscope-ai/ReMe | **Added:** 2026-06-01
**Source / Author:** AgentScope (Alibaba)

**What it's about:** ReMe is an AI-agent memory framework addressing limited context windows and stateless sessions. Beyond conversation memory it maintains **procedural memory** (task success/failure experiences) and **tool memory** (tool-usage experience + parameter optimization), plus file-based ("memory as files") and vector-based stores with hybrid retrieval. The procedural/tool-memory concept — an agent remembering which tool calls fail and avoiding the repeat — is the subset extracted here.

**What we added (a closed capture→recall→review loop for failing tool calls):**
- Hook: `tool-failure-capture.sh` (PostToolUseFailure, matcher `Bash|mcp__.*`) — records every failing Bash/MCP call into a per-repo ledger `.claude/memory/tool-failures.jsonl`, keyed by a normalized command *signature* (paths/numbers/hashes/strings collapsed) so the *same kind* of failure clusters and its `count` climbs. Re-opens a resolved entry if the failure recurs.
- Hook: `tool-failure-recall.sh` (PreToolUse, matcher `Bash|mcp__.*`, soft/advisory) — before a call runs, warns if that signature has failed ≥2× and is still open, showing the last error and any recorded remedy. Once-per-session-per-signature dedupe + 45-day recency gate keep it quiet; never blocks.
- Routine: `tool-failure-review` — `commands/kiro/tool-failure-review.md` + `scripts/tool-failure-review-runner.sh` (MIN_GAP_DAYS=3 self-pacing, no-ops unless the ledger has a promotable entry) wired into `daily-orchestrator.sh` `run_one()`. Diagnoses *why* recurring failures happen and promotes the durable lessons into memory (+ `ERRORS.md`), marking entries resolved/promoted. This is where the system learns from its mistakes.
- Skill: `tool-failure-memory` — the judgment layer: signature model, how to respond to a recall warning (don't reflexively re-run), and how to record a remedy / promote to memory.
- Config: registered the two hooks in `templates/settings.json.template` (PostToolUseFailure + PreToolUse) so the loop ships to every repo; runner added to install/update chmod lists.

---

## github.com/ulyssestenn/omt
**URL:** https://github.com/ulyssestenn/omt | **Added:** 2026-06-07
**Source / Author:** Bethany Hunt (ulyssestenn)

**What it's about:** Zero-dependency Python CLI (stdlib only) for running a prompt N times against any local Ollama model and saving every response to disk. Outputs are keyed on a SHA256 prompt hash so multi-model comparison runs land in the same folder automatically. Captures token counts, timing, and temperature per run in JSON metadata alongside Markdown response files.

**What we added:**
- Script: `ollama_model_test.py` — full OMT script added to `scripts/`; propagates to every project's `.claude/scripts/` via update.sh. chmod +x wired into install.sh and update.sh.
- Skill: `local-llm-eval` — guided workflow for offline prompt evaluation: pre-flight check, parameter selection, single/multi-model run patterns (shell loop), result interpretation, and prompt iteration loop. Fills gap between abstract `llm-evaluation` skill and actual local execution.
- Docs: `docs/local-llm-eval/README.md` — quick start, flag reference, output schema, common patterns (model comparison, variance audit, temperature sweep), related skills.

---

## github.com/anthropics/defending-code-reference-harness
**URL:** https://github.com/anthropics/defending-code-reference-harness | **Added:** 2026-06-07
**Source / Author:** Anthropic

**What it's about:** Anthropic's reference implementation for autonomous vulnerability discovery and remediation using Claude. Provides a 7-stage pipeline (recon → find → grade → judge → report → patch) with gVisor sandboxing and an egress-allowlist proxy, plus a set of interactive Claude Code skills (threat-model, vuln-scan, triage, patch) for the human-in-the-loop path. Key design patterns: `<untrusted_data>` wrapping to mitigate prompt injection, separate find/verify agent isolation (only the PoC crosses), serial judge for dedup race prevention, and egress-only network policy.

**What we added:**
- Skill: `ai-security-workflow` — 5-phase interactive security pipeline (threat-model → vuln-scan → triage → patch → close) with standardized artifact handoffs (THREAT_MODEL.md → VULN-FINDINGS.json → TRIAGE.json → PATCHES/ → SECURITY-REPORT.md). Distinct from existing scattered SAST skills: this is a choreographed, phase-gated process that gets from "do a security pass" to "here are my patches" with human review gates between each phase.
- Skill: `secure-agent-design` — 5-pattern checklist for building security-hardened Claude agents: `<untrusted_data>` prompt injection mitigation, find/verify isolation architecture, serial dedup judge, egress control, and credential handling. Fires when building any agent that processes untrusted input or runs in parallel.
- Runner: `security-report-runner.sh` + `security-report-prompt.md` — daily headless safety scan (MIN_GAP_DAYS=1) wired into `daily-orchestrator.sh`. Scans git changes from the last 24h for OWASP patterns, hardcoded secrets, injection sinks, and missing auth checks; writes `.claude/reports/security/<date>-security-report.md`.
- Dashboard: added `security-report` entry to `_scheduled_task_registry()` in `dashboard.py` so the Scheduled Tasks tab shows daily scan status and last report artifact.
- Hook: `frontend-security-nudge.sh` (UserPromptSubmit, global) — detects when a prompt combines "build/create/add" + frontend/design keywords and injects a reminder to invoke `secure-agent-design` skill before building. Registered in `~/.claude/settings.json` and `templates/settings.json.template`.

---

## github.com/github/spec-kit
**URL:** https://github.com/github/spec-kit | **Added:** 2026-06-07
**Source / Author:** GitHub

**What it's about:** Open-source Spec-Driven Development toolkit with a 7-phase workflow (Constitution → Specify → Clarify → Plan → Tasks → Validate → Implement) and slash commands for 30+ AI agents. Key patterns: `[NEEDS CLARIFICATION]` markers to force explicit ambiguity surfacing, constitutional gates (Simplicity/Anti-Abstraction/Integration-First) as Phase -1 pre-implementation checklists, and parallel task group identification. The harness already has a full SDD pipeline (Kiro); these three patterns filled concrete gaps.

**What we added:**
- Augment: `agents/kiro/spec-requirements.md` — `[NEEDS CLARIFICATION]` discipline: step 3 now marks every assumed value, unstated intent, or unclear constraint with an explicit inline marker + a step 4 that surfaces all markers to the user for resolution before requirements are approved.
- Augment: `agents/kiro/spec-tasks.md` — Output Description now includes "Parallel Execution Groups" section listing safe concurrent invocation groups, first sequential gate after each group, enabling users to dispatch parallel `/kiro:spec-impl` calls without reading the dependency chain.
- Augment: `commands/kiro/spec-impl.md` — Phase -1 Pre-Implementation Gates added before TDD subagent invocation: Simplicity Gate (≤3 components, no speculative tasks), Anti-Abstraction Gate (direct framework use, single model), Integration-First Gate (contracts in design.md, integration test task before unit-only tasks). Soft gate — user can override.
- Docs: `docs/kiro/README.md` — updated command table entries for `spec-requirements`, `spec-tasks`, and `spec-impl` to reflect new behaviors.

---

## github.com/tinyfish-io/bigset
**URL:** https://github.com/tinyfish-io/bigset | **Added:** 2026-06-07
**Source / Author:** TinyFish

**What it's about:** Self-hosted AI platform that takes a natural-language dataset description, infers a schema via Claude Sonnet, fans out parallel agents to research entities from live public web sources, deduplicates results, and exports a structured CSV/XLSX. Uses Mastra for workflow orchestration, TinyFish APIs for web access, Convex as the database, and Clerk for auth. Requires Docker + 3 free API keys.

**What we added:**
- Skill: `structured-web-dataset` — implements BigSet's pipeline natively in Claude Code (no Docker, no external APIs). Covers both Web mode (parallel Agent() fan-out per entity → verified rows from live sources) and Synthetic mode (schema + distribution rules → generated rows with controlled edge cases). Fills the gap between `deep-research` (prose reports) and raw data needs — output is always a typed, deduplicated table/CSV.
- Docs: `docs/structured-web-dataset/README.md` — workflow diagram, design decisions, related skills.

---

## github.com/chopratejas/headroom
**URL:** https://github.com/chopratejas/headroom | **Added:** 2026-06-08
**Source / Author:** Tejas Chopra

**What it's about:** Content-aware prompt compression layer for LLM agents and Claude Code. Compresses tool outputs, RAG chunks, file contents, and conversation history at the messages/prompt layer (60-95% token savings) using 6 algorithms: SmartCrusher (JSON), CodeCompressor (AST), Kompress-base (ML), log, search, and HTML extractors. Reversible Compression (CCR) stores originals locally; `headroom wrap claude` intercepts all context before it reaches the model with zero code changes. Distinct from RTK (shell output compression): headroom operates on the full prompt layer, not just Bash stdout.

**What we added:**
- Script: `headroom-setup.sh` — idempotent install script: installs `headroom-ai` globally (uv tool → pipx → pip --user, first that works) + per registered-repo virtualenv (mirrors raindrop-setup.sh pattern), adds `alias claude='headroom wrap claude'` to `~/.bashrc` so every new Claude Code session is automatically wrapped without any per-session decision.
- Wired: `install.sh` `install_globals()` and `update.sh` tail both call `headroom-setup.sh` alongside `raindrop-setup.sh` — propagates to all machines on next install/update run.

---

## github.com/run-llama/liteparse
**URL:** https://github.com/run-llama/liteparse | **Added:** 2026-06-08
**Source / Author:** LlamaIndex (run-llama)

**What it's about:** Local-first PDF/document parser built in Rust (Apache 2.0). Extracts text with bounding boxes via PDFium, runs OCR via bundled Tesseract or pluggable HTTP servers (EasyOCR, PaddleOCR), generates page screenshots for LLM vision workflows, and supports PDF natively plus DOCX/XLSX/PPTX via LibreOffice and images via ImageMagick. Python, Node.js, Rust, and WASM bindings ship with a `lit` CLI. Fills the gap between raw documents and RAG pipelines without any cloud dependency.

**What we added:**
- Skill: `document-parsing` — 6-phase workflow (install → format selection → CLI patterns → Python API → RAG handoff → cloud escalation decision). Fires before any RAG pipeline or document processing task; bridges raw documents into `rag-implementation`.
- Hook: `doc-parse-nudge.sh` (UserPromptSubmit, global) — detects action verbs combined with document/RAG keywords and injects a reminder to invoke `document-parsing` before building. Registered in both `~/.claude/settings.json` and `templates/settings.harness.json.template`.
- Wired: `install.sh` `install_globals()` and `update.sh` tail both include inline `pip install liteparse` (idempotent) — no separate setup script, propagates on next install/update run.
- Docs: `docs/skills/document-parsing/README.md` — supported formats table, activation instructions, related skills.

---

## github.com/Kaelio/ktx
**URL:** https://github.com/Kaelio/ktx | **Added:** 2026-06-11
**Source / Author:** Kaelio (YC-backed)

**What it's about:** Open-source context layer for AI data agents (Apache 2.0). Sits between a warehouse and AI agents — ingests dbt, LookML, and BI tool definitions into git-reviewable YAML/Markdown, then exposes an MCP server that resolves grain, joins, and business metric logic and compiles safe SQL. Prevents LLMs from guessing schema. Supports Snowflake, BigQuery, Redshift, PostgreSQL, Databricks, and ClickHouse; integrates with Claude Code, Cursor, Codex, and LangChain.

**What we added:**
- Skill: `ktx-data-context` — 4-phase workflow (install/connect → build context → wire MCP server → review loop). Decision matrix for ktx vs raw SQL vs RAG. Full context file shape reference. Fires when building data agents or adding analytics capability to a skill (e.g. `cfo-insights/`).
- Config: commented-out `mcpServers.ktx` block appended to `templates/settings.json.template` — uncomment and merge to enable `ktx_query` / `ktx_schema` / `ktx_metrics` tools in any project.
- Docs: `docs/skills/ktx-data-context/README.md` — problem framing, activation conditions, MCP config snippet, warehouse/source support table, related skills.

---

## github.com/metareflection/guardians
**URL:** https://github.com/metareflection/guardians | **Added:** 2026-06-17
**Source / Author:** metareflection (Erik Meijer et al.)

**What it's about:** Python library (~1900 LOC core, MIT) that verifies an AI agent's *entire planned* tool-call workflow **before** any tool executes. Three independent static checks over the workflow AST: taint analysis (does untrusted data flow from a source to a forbidden sink?), security automata (does the tool-call sequence reach an error state?), and Z3 theorem proving (do pre/post/frame conditions hold?). `verify_first=True` guarantees flow checks run before execution. Canonical demo: an injected instruction inside an email tells the agent to forward the inbox to an attacker — the source→sink flow is rejected and the workflow never runs. The transferable insight is the **plan-the-whole-workflow → statically verify → execute** paradigm + taint source→sink; the Z3/automata/pydantic machinery is library-specific deployment detail.

**What we added** (one augmentation — the default-skip gate rejected everything else):
- Skill augmentation: `secure-agent-design` — new **Pattern 6: Plan-then-Verify — Static Taint & Data-Flow Guards**. Captures the design pattern: emit the full tool-call plan upfront, tag tool params with taint labels (sources) + sink params (forbidden destinations), statically check source→sink reachability + allowlist + forbidden data-flow rules, and reject the whole plan on violation before any tool fires. Complements `agent-execution-control` §2 (which gates one *runtime* action in isolation and is blind to cross-step data flow). Added a matching pre-ship checklist line. Guardians cited as reference implementation.

**Rejected:** standalone skill (better as augmentation), adopting guardians as a zora-repo dependency (product decision, heavyweight z3-solver), enforcement hook (no reliable static-analysis trigger), Z3/automata reference doc (hollow — text not behavior).

---

## github.com/s0xDk/ghostty-blackhole
**URL:** https://github.com/s0xDk/ghostty-blackhole | **Added:** 2026-06-17
**Source / Author:** s0xDk (MIT)

**What it's about:** A Ghostty fragment shader that renders a ray-traced black hole sized to the live Claude Code context-window fill. A single Python script, wired as a `statusLine` plus `SessionStart`/`SessionEnd` hooks, reads the session JSON Claude pipes on stdin, computes context fill (`context_window.used_percentage`), and encodes it into the **cursor color** via an `OSC 12` escape (amber base + 16-bit signature/checksum so a theme color can't accidentally drive the hole). `blackhole.glsl` decodes `iCurrentCursorColor` every frame and sizes the hole; cursor color is per-surface so each split/window gets its own. Requires Ghostty 1.3+. Ships a macOS Swift/SwiftUI tuner app (ignored — macOS-only).

**What we added** (implemented as fully opt-in per user request — two gates: not template-wired + `SDD_BLACKHOLE` env):
- Script: `scripts/integrations/blackhole/blackhole-cursor.py` — the encoder (statusLine + SessionStart/SessionEnd, self-routed on `hook_event_name`). `apply()` no-ops unless `SDD_BLACKHOLE=1`, so hooks/statusLine stay dormant by default and the statusLine still prints its readout without touching the cursor.
- Resource: `scripts/integrations/blackhole/blackhole.glsl` (verbatim, `SIZE_MODE MODE_TOKENS`) + `SETUP.md` (Ghostty `custom-shader` line, the exact `settings.json` snippet to paste, the `SDD_BLACKHOLE=1` toggle). Deliberately **not** added to `templates/settings.json.template` — a `statusLine` entry would replace Claude's default status line for every repo.
- Docs: `docs/integrations/blackhole/README.md` — what it is, data-flow diagram, the two-gate opt-in design, files, requirements, caveats.

**Rejected:** auto-wiring `statusLine` into the settings template (breaks opt-in — would replace everyone's default status line); the Swift/SwiftUI tuner app (macOS-only, no WSL/Linux home); a dashboard context-fill widget (the hole already *is* the live gauge — redundant); a separate bash SessionEnd clear-hook + SessionStart augmentation (the one Python script already self-routes all three roles — fewer moving parts).

---

## github.com/DietrichGebert/ponytail
**URL:** https://github.com/DietrichGebert/ponytail | **Added:** 2026-06-17
**Source / Author:** Dietrich Gebert

**What it's about:** A cross-agent (~13 hosts) skill/ruleset plugin (JS ~93%, Python ~6%) that constrains AI coding agents to write minimal code. Two Node.js lifecycle hooks **re-inject** a YAGNI "ladder" ruleset (does it need to exist? → stdlib? → native platform feature? → already-installed dependency? → one line? → minimum) on **every turn** at intensity levels `lite`/`full`/`ultra`/`off`, while protecting validation/error-handling/security from being stripped. Separately, deliberate shortcuts get a `ponytail:` inline comment marker, collected on demand by **manual** commands (`/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`). Claimed: "80-94% less code · 3-6× faster · 42-75% cheaper." The default-skip gate rejected almost everything — the harness already enforces this thesis hard (CLAUDE.md AI-Legible Code every session, CAVEMAN every-turn injection, `karpathy-guidelines`, `simplify`).

**What we added** (two items — the minimalism ruleset itself was already covered):
- Skill augmentation: `karpathy-guidelines` §2 "Simplicity First" — a **deliberate-deferral marker** rule. When a real need is *consciously* postponed under simplicity pressure, tag it inline `# DEBT: <what was skipped> — revisit when <trigger>` (never for genuine YAGNI). No ledger file: `git grep -nE "(#|//)\s*DEBT:"` lists them. This is the one gap — the harness forces "do less" but had no way to track conscious tradeoffs. See also the prior `karpathy-guidelines` entry (2026-05-31).
- Dashboard widget: `count_debt_markers()` + a Maintenance Status banner in `scripts/utils/dashboard.py` — comment-anchored `git grep` (Markdown excluded so prose can't false-match; only tracked files), recomputed on **every dashboard launch**. **Improves on ponytail**, whose `/ponytail-debt` is a command you must remember — our count is always-current the next time you open the dashboard, with no command to run.

**Rejected:** the full YAGNI-ladder skill (>70% covered by `karpathy-guidelines`); a per-turn minimalism re-injection hook (duplicate of CLAUDE.md AI-Legible + CAVEMAN — noise/conflict); `/ponytail-debt` command + a dedicated daily runner (premature — scans nothing until markers accumulate; the dashboard line surfaces them for free, and `git grep` is the on-demand path); intensity levels (already modeled by CAVEMAN); dependency-bloat guard (covered by `karpathy-guidelines` §6).

---

## github.com/frankbria/ralph-claude-code
**URL:** https://github.com/frankbria/ralph-claude-code | **Added:** 2026-06-18
**Source / Author:** frankbria (MIT) — implements Geoffrey Huntley's "Ralph" technique

**What it's about:** A Bash harness (~9.4k stars) that runs the Claude Code CLI in a continuous autonomous loop until a project is finished, feeding `PROMPT.md`/`fix_plan.md`/`AGENT.md` context per iteration and parsing Claude's JSON output for a `RALPH_STATUS` block with an `EXIT_SIGNAL`. Its entire design targets the two failure modes of self-directed loops — **infinite looping** and **runaway API spend** — via intelligent exit detection plus rate limiting (`ralph_loop.sh`/`ralph_monitor.sh`/`ralph_queue.sh`, tmux orchestration, token budgeting, git backup, Docker/E2B sandboxes, multi-provider abstraction). The default-skip gate rejected nearly everything — the harness is already loop-saturated (`loop-patterns`, `iterative-repair-loop`, `/loop`, `kiro:autoresearch`, `goal-mode`).

**What we added** (one augmentation — the loop machinery itself was already covered):
- Skill augmentation: `loop-patterns` — new **Loop Guardrails** section. (a) **Dual-condition exit**: don't stop on the heuristic check alone; require an explicit one-line confirmation that the green output truly means the goal is met (guards stopping-too-early on flaky/partial passes). (b) **Circuit breakers** checked every pass, independent of the max cap: abort on 2 consecutive no-progress passes or 2 consecutive identical-error passes, then stop and report. This is the one gap — `loop-patterns` previously had only a one-line "use a cap to prevent runaway" note (`SKILL.md:234`), with no same-error/no-progress detection and a single-condition exit, which is exactly Ralph's thesis.

**Rejected:** `ralph_loop.sh`/`ralph_monitor.sh`/tmux orchestration (harness drives loops via `ScheduleWakeup`/`/loop` + `daily-orchestrator.sh`, not external bash spinning the CLI — would fork the loop model); `ralph-stats` metrics + token budgeting (dashboard + `Workflow` budget already cover); desktop notifications (`PushNotification`); git backup/rollback (atomic per-task commits already); Docker/E2B sandbox (infra decision, not a harness behavior); multi-provider abstraction (harness is Claude-only by design — anti-goal); log rotation + `PROMPT.md`/`fix_plan.md`/`AGENT.md` file conventions (harness uses `specs/`/`steering/`/`CLAUDE.md`).

---

## github.com/usestrix/strix
**URL:** https://github.com/usestrix/strix | **Added:** 2026-07-02
**Source / Author:** usestrix — autonomous AI pentesting platform

**What it's about:** An open-source autonomous pentesting platform that runs a graph of agents (recon → exploit → post-exploit) against live targets, validating findings with working PoCs. Its most reusable asset is not the code but its `strix/skills/` library: ~40 deep per-vulnerability-class knowledge packages (IDOR, SSRF, SSTI, GraphQL, race conditions) with attack-surface maps, bypass matrices, chaining logic, and false-positive catalogs. The default-skip gate rejected the whole platform — the harness has no live-exploitation sandbox — but the tool-agnostic *triage-reasoning* subset filled a real gap.

**What we added** (one augmentation — the platform and its agent orchestration were already covered):
- Skill augmentation: `ai-security-workflow` — new `references/vuln-class-heuristics.md` distilling per-class whitebox review heuristics (non-obvious cases: batch endpoints validating only `items[0]`, second-order injection, resolver-boundary GraphQL authz) plus a three-gate **false-positive discipline** (reachability → binding → prove-the-negative) and per-class FP catalog. Wired as two pointer lines into Phase 2 (Vuln Scan → "what to look for") and Phase 3 (Triage → the validation gate). Attacks the harness's weakest security link — triage noise — where the SKILL.md previously listed only class *names*.

**Rejected:** the full 40-file offensive library (~90% live-exploitation tradecraft presuming a running target + sandbox the harness lacks); Graph-of-Agents orchestration (covered by `multi-agent-patterns` + `secure-agent-design`); dynamic skill-injection (native Claude Code progressive disclosure + `skill-creator`/`skill-curator`); scan modes (overlap `model-tiers`/`progressive-complexity-ladder`); `source_aware_sast` (hard-requires semgrep/ast-grep/trivy — out of scope); headless CI mode (already have `security-report-runner.sh` + `pr-report`); nmap/nuclei/ffuf tooling playbooks (offensive CLI reference, out of scope).

---

## github.com/nadimtuhin/claude-token-optimizer
**URL:** https://github.com/nadimtuhin/claude-token-optimizer | **Added:** 2026-07-02
**Source / Author:** nadimtuhin

**What it's about:** A CLI (`cto`) that reframes token cost as a *documentation-structuring* problem — it minimizes the auto-loaded session-startup payload, then audits/compresses it deterministically with CI-friendly checks. Its optimization axis is **orthogonal** to existing harness tooling: RTK and lean-ctx attack *runtime* cost (command output, file reads) and Headroom attacks *API-context* cost, while `cto` attacks *startup* cost (what loads before you do anything). The default-skip gate rejected everything except that one uncovered axis.

**What we added** (one routine + one skill augmentation + one dashboard card):
- Routine: `scripts/routines/startup-payload-audit.sh` — deterministic (no LLM) daily audit measuring the fixed per-session token tax (`CLAUDE.md` + `@imports` + `.claude/rules/*` + auto-loaded `MEMORY.md`), flagging over-budget growth, stale files, and ghost references. Writes `.claude/reports/context/startup-payload.json`. Wired into `daily-orchestrator.sh` `run_one()` with `SDD_SKIP_STARTUP_AUDIT=1` opt-out + state-file cadence guard; registered in `_scheduled_task_registry()`; chmod-listed in install.sh + update.sh.
- Skill augmentation: `context-optimization` — new "Two Independent Token Axes: Startup vs Runtime" section naming the startup lever (which RTK/lean-ctx never see) and the inversion principle (*comprehensiveness → archive; essentiality → startup payload*).
- Dashboard widget: `_startup_payload_card()` in `scripts/utils/dashboard.py` — a Startup Payload card in the **Budget & Efficiency → Context Health** tab (tokens, budget status, stale/ghost counts, top files).

**Rejected:** `docs/learnings/` keyword-inject hook (covered by lean-ctx `ctx_knowledge wakeup` + MEMORY/hot-memory); framework `COMMON_MISTAKES.md` (covered by `ERRORS.md` + `tool-failure-memory`); `cto compress/prune` (overlaps `ctx_compress` — on-disk-doc part folds into the audit output); pre-tool read/bash blocking guards (RTK/lean-ctx already *reduce* > *block*); `cto watch` live dashboard (duplicates `rtk gain`); literal `.claudeignore` generation (harness auto-loads via `@import`/auto-memory — the audit *verifies* the principle instead).

---

## github.com/typedef-ai/fenic
**URL:** https://github.com/typedef-ai/fenic | **Added:** 2026-07-02
**Source / Author:** typedef-ai

**What it's about:** A PySpark-inspired DataFrame library that treats LLM inference as a first-class, typed, lazily-evaluated query operator (`semantic.extract/classify/predicate/reduce/join`, `sim_join`, `with_cluster_labels`), giving batch LLM work automatic caching, per-query cost accounting, and row-level lineage. The non-obvious insight — lazy eval is what unlocks the caching/cost/lineage layer — is covered by no existing harness skill (rag-architect = retrieval, structured-web-dataset = sourcing, csv-data-summarizer = post-hoc analysis, document-parsing = ingestion).

**What we added** (one pattern skill — the library itself is on-demand via `get-api-docs`):
- Skill: `semantic-data-pipeline` — a lean, library-agnostic **decision** skill: when batch LLM transformation over many rows needs reproducibility, model it as a lazily-evaluated query with a caching/cost/lineage layer, not an ad-hoc loop. Teaches the four-operator taxonomy (extract/classify/predicate/reduce) and the explore→pipeline→governed-tool graduation path, with fenic as the reference implementation. Explicit "Do NOT Activate" boundaries route sourcing → `structured-web-dataset`, retrieval → `rag-architect`, ingestion → `document-parsing`, analysis → `csv-data-summarizer` to prevent wrong-skill firing.

**Rejected:** a fenic-as-a-tool API tutorial skill (the "here's a library that exists" anti-pattern — `get-api-docs` handles docs on demand); `fenic check` linter as a harness pattern (harness authors no library agents call; ruff/serena/pytest already gate its own code); `fenic skill install` (duplicates `skill-creator`/`skill-curator`); operator taxonomy into `rag-architect` (adds vocabulary not decision value; bloats a mature skill); all hook/routine/dashboard/script/command angles (on-demand design decision, nothing to automate).

---

## langchain-ai/openwiki
**URL:** https://github.com/langchain-ai/openwiki
**Added:** 2026-07-08
**Source / Author:** LangChain

**What it's about:** A TypeScript CLI that auto-generates a codebase wiki in `openwiki/` by running an LLM over source files and appending stub instructions to AGENTS.md/CLAUDE.md pointing agents to consult it. Optional LangSmith tracing and CI/CD PR automation for doc updates.

**What we added:** Nothing — SKIP.

**Rejected (all candidates):** Auto-generated wiki content is equivalent to what `adapt-to-repo` derives on-demand from the live codebase. Appending to CLAUDE.md is the exact anti-pattern `instruction-architecture` guards against (uncontrolled growth). The `steering/`, `memory/`, and `specs/` layers cover curated documentation with provenance. CI/CD PR automation for docs conflicts with CLAUDE.md's "never commit SDD files" rule. External binary dependency with no freshness guarantees adds maintenance cost for zero capability gain.

---

## github.com/github/spec-kit
**URL:** https://github.com/github/spec-kit
**Added:** 2026-07-28
**Source / Author:** GitHub

**What it's about:** GitHub's official spec-driven development toolkit (constitution → spec → plan → tasks → implement, via a `specify` CLI). Heavy conceptual overlap with the local `kiro:` SDD suite (near 1:1 on init/requirements/design/tasks/impl). Only the genuine gaps were mined.

**What we added:**
- Command: `commands/kiro/converge.md` — from `/speckit.converge`. Reconciles the live codebase against an approved spec, classifying drift as {spec-ahead / code-ahead / contradiction} with a recommended action each. Reuses the existing `validate-impl-agent` in a CONVERGE mode (no new agent). Fills a real gap: kiro validated impl but had no spec↔code reconciliation.
- Agent augmentation: `agents/kiro/harness-validate-agent.md` — from `/speckit.analyze`. Added a cross-artifact spec-consistency check (spec ↔ requirements ↔ design ↔ tasks traceability: no task without a requirement, no requirement with zero tasks, no design element without a spec driver), with a scope guard to skip mid-authoring specs. Previously `harness-validate` did structural integrity only.

**Rejected:** wholesale adoption of the `specify` CLI + multi-agent integration layer (redundant with the kiro suite); `/speckit.taskstoissues` (complements `jira-solve` but lower priority — deferred).

---

## github.com/google/mantis
**URL:** https://github.com/google/mantis
**Added:** 2026-07-28
**Source / Author:** Google

**What it's about:** A model-agnostic framework letting AI coding agents autonomously find, reproduce, and patch software vulnerabilities via a ~15-stage pipeline of discrete skills that pass state through JSON files, executing generated code in Docker/gVisor sandboxes. Security-domain-specific, but two architectural patterns transcend the domain.

**What we added:**
- Skill augmentation: `skills/ai-security-workflow/SKILL.md` — "Architectural Patterns" section: JSON-state pipeline (stages pass machine-readable state for resumability + mechanical dedup) and sandboxed-reproduction verification (prove a finding by reproducing it in a sandbox, not by reasoning; false-positive filter before patching).
- Agent augmentation: `agents/kiro/reflect-agent.md` — "Cross-Run Learning Loop" (append-only `learnings.jsonl` of `{situation, insight, applies_when}` intended to feed a future planning step). NOTE: currently write-only — the read-back side is aspirational until a planning command is wired to consume it.

**Rejected:** wholesale adoption of the security pipeline (domain-specific; the harness already has `ai-security-workflow` + `security-review`); the meta-agent supervisor (covered by `multi-agent-patterns`).
