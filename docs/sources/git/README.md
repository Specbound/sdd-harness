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
