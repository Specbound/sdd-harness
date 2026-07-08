# Batch Skill Extraction Triage — 2026-07-08

8 resources evaluated via parallel sub-agents + direct fetch. Verdicts below ranked by value.

---

## Summary Table

| Resource | Category | Verdict | Priority |
|---|---|---|---|
| Anthropic Advanced Tool Use | articles | **AUGMENT** `tool-design` | High |
| Prompt Caching docs | articles | **AUGMENT** `context-optimization` | High |
| Lilian Weng — Agent Harness | articles | **AUGMENT** `agent-harness-design` | Medium |
| Microsoft — Don't Rewrite CLI | articles | **AUGMENT** `tool-design` | Medium |
| AutoResearch Introspection | articles | **AUGMENT** `autoresearch` skill | Medium |
| Graph-Based Agent Memory | articles | **AUGMENT** `para-memory-files` (patterns only) | Low |
| OpenWiki (LangChain) | git | **SKIP** | — |
| arXiv 2607.02032 (PACE) | papers | **SKIP** | — |

---

## AUGMENT Candidates

### 1. Anthropic Advanced Tool Use
**URL:** https://www.anthropic.com/engineering/advanced-tool-use  
**Target:** `~/.claude/skills/tool-design/SKILL.md`  
**Priority:** High — empirically validated, large measurable gains

Three new techniques, none currently in `tool-design`:

**A. Tool Search Tool (Deferred Discovery)**
- Mark tools with `defer_loading: true`; Claude searches for tools on-demand instead of loading all definitions upfront
- 85% token reduction on definition-heavy MCP setups (>10K tokens in tool defs)
- Accuracy: Opus 4.5 improved 79.5% → 88.1% on MCP evals
- Decision rule: use when you have 10+ tools or >10K tokens in definitions
- Keep 3-5 most-used tools always loaded; defer the rest

**B. Programmatic Tool Calling (Code Orchestration)**
- Claude writes Python code to orchestrate tool calls rather than one-at-a-time natural language
- Eliminates redundant inference passes: 20-tool workflows go from 19+ passes to 1
- 37% token reduction (43,588 → 27,297 tokens on complex tasks)
- Intermediate results stay in code executor, not Claude's context
- Enable via `allowed_callers: ["code_execution_20250825"]` per tool
- Enable beta: `betas=["advanced-tool-use-2025-11-20"]`

**C. Tool Use Examples**
- Provide concrete JSON examples in tool definitions beyond what JSON Schema expresses
- Covers: when to use optional parameters, which combinations make sense, API conventions
- Accuracy: 72% → 90% on complex parameter handling
- 1-5 realistic examples per tool; focus on ambiguous areas

**Automation path:** Not a hook; design-time guidance. Add to `tool-design` as a new "Advanced Patterns" section. The existing skill covers description engineering and consolidation — these three patterns are orthogonal and complementary.

**Side note:** The doc confirms Tool Search doesn't break prompt caching because deferred tools are excluded from the initial prompt entirely. This is worth cross-referencing in `context-optimization`.

---

### 2. Anthropic Prompt Caching Documentation
**URL:** https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching  
**Target:** `~/.claude/skills/context-optimization/SKILL.md`  
**Priority:** High — production API feature with real cost implications; nothing like it exists in the harness

This is distinct from both `cag-implementation` (local HuggingFace KV cache preloading) and `context-optimization`'s current KV-cache heuristics. These are Anthropic's server-side prefix cache mechanics via `cache_control` blocks.

**Add to `context-optimization` as "Anthropic API Prompt Caching" subsection:**

- **Minimum token thresholds by model** (cache is no-op below these):
  - 512 tokens: Claude Fable/Mythos variants
  - 1,024 tokens: Opus 4.8, Sonnet 5
  - 4,096 tokens: Opus 4.6/4.5, Haiku 3.5
- **Lookback window gotcha:** Max 20 `cache_control` blocks per request; placing a breakpoint on frequently-changing content = guaranteed cache miss with full-price re-billing
- **Cache invalidation dependency table:** Tool changes cascade to system + messages; tool-choice-only changes only wipe messages — not symmetric, and not guessable
- **Pre-warming pattern:** Send a request with `max_tokens: 0` to warm the cache before latency-sensitive traffic starts
- **Automatic vs. explicit breakpoints:** Automatic for multi-turn conversations; explicit `cache_control` placement for multi-section prompts (tools, system, examples sections)

**Also add a one-line clarification note to `cag-implementation`** disambiguating it from this mechanism to prevent confusion.

---

### 3. Lilian Weng — Agent Harness Engineering
**URL:** https://lilianweng.github.io/posts/2026-07-04-harness/  
**Target:** `~/.claude/skills/agent-harness-design/SKILL.md`  
**Priority:** Medium — adds a concrete quality checklist + one novel meta-pattern

The post covers: harness as plan→execute→observe→improve loop, persistent filesystem state, parallel sub-agents. Most of this is already in `agent-harness-design`. Two genuine additions:

**A. Seven Harness Bottlenecks Checklist** (new quality gate, not in any existing skill)
1. Weak/fuzzy evaluators for research claims
2. Memory lifecycle management (state growth beyond context windows)
3. Incentive misalignment around negative results
4. Diversity collapse in optimization loops
5. Reward hacking vulnerabilities
6. Short-term optimization bias
7. Inappropriate human oversight points

This maps cleanly onto an audit checklist for the harness-validate agent or as a Phase N gate in the `agent-harness-design` skill workflow.

**B. Meta Context Engineering (MCE) Pattern** (conceptually new, not in skill)
- A meta-agent that optimizes *how context is managed*, not just what context contains
- "Agentic crossover over prior skills": meta-agent iterates on context management strategies the way AlphaCode iterates on code
- Practical framing for the harness: the `evolve-agent` already does behavioral audit — MCE suggests it should also mutate the context-flow strategy itself

**Automation path:** Neither is directly automatable as a hook. Add the 7-bottleneck checklist as a `## Harness Health Audit` section in `agent-harness-design`; add MCE as a `## Meta-Improvement` concept.

---

### 4. Microsoft — Don't Rewrite Your CLI for Agents
**URL:** https://developer.microsoft.com/blog/dont-rewrite-your-cli-for-agents  
**Target:** `~/.claude/skills/tool-design/SKILL.md`  
**Priority:** Medium — empirical data that overturns a common assumption

**Core finding:** Traditional argument-based CLIs outperform JSON payloads for agent use. This is counterintuitive and empirically backed.

**Key data:**
- Args achieved perfect accuracy across all models on correctness tests
- JSON failed in smaller models: Claude Haiku 4.5 achieved only 2/5 vs 5/5 with args
- JSON cost 4x–11x more tokens per task (retry cycles from syntax/escaping failures)
- Shell escaping tax: same model (Sonnet 4.6) on PowerShell vs Bash showed 9x cost gap for JSON, 1.5x for args — identical correctness, different shells

**Pattern to extract:**
- "Narrowing the valid input space compensates for gaps in model capability" — the reason args win
- Never rewrite a CLI to JSON-first; keep existing arg structure, offer `--json` as optional addition only
- Errors in JSON compound across retry cycles; arg errors are atomic

**Add to `tool-design` as "CLI-to-Agent Bridging" section.** This complements the existing "Adapting Existing Tools" content without overlap — current skill focuses on new tool design, not existing CLI adaptation.

---

### 5. AutoResearch Introspection (Latent Space)
**URL:** https://www.latent.space/p/autoresearch-introspection  
**Target:** `~/.claude/skills/kiro/autoresearch/SKILL.md` or `autoresearch-agent` prompt  
**Priority:** Medium — fills the missing "outer loop" concept; harness has inner loop only

The article's Three-Loop Blueprint:
- **Inner loop:** Claude does the actual task (this is what the harness's Karpathy-style autoresearch loop already handles)
- **Outer loop:** A separate agent system maintains and improves the inner loop — "the loop is the product"
- **Signal filtering:** Not all feedback should trigger loop updates; intentional filtering prevents "slop" accumulation

**Agent Recipes** (the most extractable concept):
- A versioned artifact capturing not just the agent's code/prompts but: evals, judges, human expertise examples, failure-driven iterations, and *why* decisions were made
- Inspired by ML data recipes (DML): portable, auditable, evolvable
- Git-based audit trail for loop history
- Distinguishes from CLAUDE.md: the recipe is a living document tied to the agent's *operational history*, not static instructions

**Currently missing from the harness:**
- No recipe artifact type (CLAUDE.md is static; memory files capture facts, not agent evolution)
- No outer loop mechanism (autoresearch runs experiments but has no meta-improvement layer)
- No signal filtering guidance (agents consume all feedback)

**Staged autonomy principle:** "Begin with heavy human-in-the-loop; agents gradually absorb learned preferences." The harness already does some of this via human review gates, but it's not articulated as a progressive model.

**Automation path:** The recipe concept could become an artifact standard for the `autoresearch-init` command (a `recipe.md` alongside `program.md`). The outer loop pattern maps conceptually to `evolve-agent`. Not directly hookable — design-time guidance.

---

### 6. Graph-Based Agent Memory (System Design Newsletter)
**URL:** https://newsletter.systemdesign.one/p/graph-based-agent-memory  
**Target:** `~/.claude/skills/para-memory-files/SKILL.md`  
**Priority:** Low — patterns extractable, but full infrastructure not applicable

The article covers Omnigraph: typed entity nodes + labeled edges + schema enforcement, with three retrieval layers (graph traversal + BM25 + vector, fused via Reciprocal Rank Fusion), atomic manifest versioning, and git-like branch isolation for multi-agent writes.

**What's extractable without the infrastructure:**
- **Schema enforcement principle:** Define which memory types are allowed and what relationships connect them — the harness already has typed memory files (user/feedback/project/reference) but no explicit relationship schema
- **Typed relationship encoding:** Instead of flat prose in memory files, express relationships as explicit links (`[[memory-slug]]` already exists but isn't schema-enforced)
- **Branch isolation concept:** When multiple agents touch memory simultaneously, changes should be isolated until merged — currently there's no protection against concurrent memory writes

**What's NOT extractable:**
- The full Omnigraph infrastructure (graph DB, vector store, BM25 index) — too heavy for the file-based harness
- Reciprocal Rank Fusion across three retrieval layers — no query-time retrieval in the current memory model
- Commit lineage system — git already handles this for the harness

**Side finding:** The `multi-agent-patterns` skill references a `memory-systems` skill that doesn't exist. The graph memory article provides the conceptual foundation to write it if desired — but the article alone doesn't justify a new skill. At minimum, fix the dangling reference in `multi-agent-patterns`.

**Add to `para-memory-files`:** A "Relationship-First Memory" section covering schema enforcement (what relationships are valid between memory types) and the branch-isolation principle (one agent writing memory at a time, or explicit merge step).

---

## SKIP Candidates

### 7. OpenWiki (LangChain)
**URL:** https://github.com/langchain-ai/openwiki  
**Verdict: SKIP**

- Auto-generates a codebase wiki and appends stub instructions to CLAUDE.md — the `instruction-architecture` skill explicitly treats uncontrolled CLAUDE.md growth as an anti-pattern
- The generated content is equivalent to what `adapt-to-repo` derives on-demand from the live codebase
- Requires Node CLI + separate API key + periodic `--update` runs with no freshness guarantee
- Richer curated alternatives already exist: `.claude/steering/`, `.claude/memory/`, `specs/`
- CI/CD PR automation for docs conflicts with CLAUDE.md: "Never commit SDD files"

No extractable patterns.

---

### 8. arXiv 2607.02032 — PACE (Proxy for Agentic Capability Evaluation)
**URL:** https://arxiv.org/abs/2607.02032  
**Verdict: SKIP**

PACE predicts expensive agentic benchmark performance (SWE-Bench, GAIA) using cheap non-agentic evals. Achieves ~4% MAE and 0.81 Spearman correlation at <1% of full benchmark cost.

- Requires a calibration corpus of 14+ models scored on 19+ benchmarks — multi-week offline ML effort, not a harness skill
- Addresses "which model do I run on expensive benchmarks" — the harness answers "which Claude tier do I use for this task type"
- The `evaluation/funnel` skill already covers early-stage filtering conceptually at product-team scale; PACE operationalizes it at ML-research scale with no overlap
- No hook, routine, or skill could generate or maintain the regression corpus PACE needs

No extractable patterns.

---

## Dangling Reference (Bonus Finding)

The `multi-agent-patterns` skill references a `memory-systems` skill that does not exist anywhere in the harness. This should be either:
1. Removed from the reference, or
2. Backfilled — the graph-based memory article provides a reasonable foundation for the concept

Worth flagging before the next `harness-validate` run.

---

## Implementation Priority Order

If implementing all AUGMENTs:

1. **`tool-design` augmentation** — two separate additions (Advanced Tool Use patterns + CLI args > JSON). High value, tightly scoped, no new files.
2. **`context-optimization` augmentation** — Anthropic API caching section. High value, concrete mechanics, real cost implications.
3. **`agent-harness-design` augmentation** — Seven bottlenecks checklist + MCE pattern. Medium lift, good long-term quality gate.
4. **`autoresearch` augmentation** — Agent Recipes concept + signal filtering. Medium lift; consider adding `recipe.md` artifact to `autoresearch-init`.
5. **`para-memory-files` augmentation** — Relationship-first memory + fix dangling `memory-systems` reference. Low lift; low urgency.
