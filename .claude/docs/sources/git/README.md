# Git Repositories

GitHub repositories that were passed to `/skill-extraction` and turned into harness skills, scripts, or tooling. Ordered by date added.

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
- Skill: `skill-curator` — local post-CCR curation step. The TypeScript script and Codex-specific paths (models_cache.json, history.jsonl) were not portable, but the core concepts were: description-budget analysis (chars per description, 150/200-char thresholds, grammar compression heuristics) were absorbed into Phase 2 of the skill. Phase 1 reads the existing weekly CCR report; Phases 3–5 handle consolidated proposal + human-approved execution (merge/compress/delete). Also fixed a gap: the weekly CCR routine referenced `skill-curator` in its "How to use" but the skill didn't exist.
- Updated: `docs/ccr-routines/README.md` — corrected weekly routine's "How to use" to reference `/skill-curator`, added Known Limitation note about CCR not accessing `~/.claude/skills/`.

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

## github.com/affaan-m/ECC
**URL:** https://github.com/affaan-m/ECC | **Added:** 2026-05-31

**What it is:** ECC ("harness-native operator system for agentic work") — a cross-harness AI agent operating system with 63 agents, 249 skills, and 15+ hook events, built over 10+ months of daily production use. Supports Claude Code, Cursor, OpenCode, Codex, Copilot, and Zed. Notable patterns: observer loop prevention (5-layer re-entrancy guard), hook profile switching via env vars, and instinct-based pattern extraction with confidence scoring.

**What we added:**
- Skill (augmentation): `hook-design` — added "Observer Loop Prevention" section (env-var sentinel, matcher specificity, state-file lock patterns) and "Session Profile Switching" section (`SDD_HOOK_PROFILE=off|minimal|standard` preamble pattern). Fills a gap: none of the existing harness hooks had re-entrancy guards despite firing on Write/Edit events that can themselves produce writes.
