# Papers

Scientific papers (primarily arXiv) that informed skills or methodology in this harness. Ordered by date added.

---

## Don't Do RAG: When Cache-Augmented Generation is All You Need
**arXiv:** https://arxiv.org/abs/2412.15605 | **Year:** 2024 | **Authors:** Brian J Chan, Chao-Ting Chen, Jui-Hung Cheng, Hen-Hsen Huang

**What it's about:** Proposes Cache-Augmented Generation (CAG) as an alternative to RAG for bounded knowledge bases. Rather than retrieving documents at query time, all relevant knowledge is preloaded into the LLM's extended context once and the resulting KV cache state is persisted to disk. Subsequent queries reuse the cached state without re-encoding the knowledge — eliminating retrieval latency, retrieval failure modes, and chunking complexity.

**What we added:**
- Skill: `cag-implementation` — CAG vs RAG decision matrix, three-phase implementation pattern (preload → persist → query loop), HuggingFace `past_key_values` implementation. See also: [git/README.md](../git/README.md) for the reference implementation repo.

---

## Automating Skill Acquisition through Large-Scale Mining of Open-Source Agentic Repositories
**arXiv:** https://arxiv.org/abs/2603.11808 | **Year:** 2026 | **Authors:** Shuzhen Bi, Mengsong Wu, Hao Hao, Keqian Li, Wentao Liu, Siyu Song, Hongbo Zhao, Aimin Zhou

**What it's about:** Framework for automatically extracting procedural skills from open-source agentic repositories and encoding them into standardized formats that augment LLM capabilities without retraining. Shows that procedural knowledge mined from repos can achieve 40% gains in knowledge transfer efficiency compared to conventional methods, enabling scalable skill acquisition for autonomous systems.

**What we added:**
- Methodology: The entire `/skill-extraction` pipeline (`docs/skill-extraction/README.md`) — three-stage process (structural analysis → semantic identification → artifact generation), scoring rubric (4 criteria, 0–12 scale, threshold ≥6), and the `/kiro:skill-extract` + `/kiro:skill-extract-scan` commands are based on this framework.

---

## From Model Scaling to System Scaling: Scaling the Harness in Agentic AI
**arXiv:** https://arxiv.org/abs/2605.26112 | **Year:** 2026 | **Author:** Shangding Gu

**What it's about:** Argues that the next major bottleneck in agentic AI is system-level architecture, not model capability. Introduces a 6-component harness decomposition model — 𝒫_H = Φ(ℛ, ℳ, 𝒞, 𝒮, 𝒪, 𝒢) — where each component (reasoning substrate, memory, context constructor, skill-routing, orchestration, governance) is an independent design lever. Proposes temporal scaling tiers (prompt/skill/memory) and a shift from outcome metrics to process metrics (context efficiency, memory hygiene, routing accuracy, trajectory quality). Benchmarks against CheetahClaws, a Python-native reference implementation.

**What we added:**
- New skill: `agent-harness-design` — 6-component framework as design/audit vocabulary; per-component audit questions and failure modes; staleness-aware memory ranking formula; temporal scaling tier heuristics; process metrics table; harness alignment check format used by skill-extraction Phase 3.
- Integration into `skill-extraction` — Phase 3 now has a mandatory Step 3a that invokes `agent-harness-design` before mapping integration types, so every extraction passes through the architectural lens.
- Enhancement: `context-optimization` v1.1 — "Context Governance" section: selection-policy framing, 4-axis governance table (relevance/compactness/traceability/refresh), staleness-aware ranking formula, provenance-in-practice pattern.
- Enhancement: `multi-agent-patterns` v1.2 — "Skill Routing Quality" section: 4 requirements (specificity/selectivity/composability/verifiability), post-condition coupling pattern, routing audit trail guidance.

---

## Code as Agent Harness
**arXiv:** https://arxiv.org/abs/2605.18747 | **Year:** 2026 | **Authors:** Xuying Ning, Katherine Tieu, Dongqi Fu et al. (42 authors)

**What it's about:** Comprehensive survey reframing code as the operational foundation for agent systems — not just output, but the substrate for reasoning, action execution, environment modeling, and verification. Organized around three layers: Harness Interface (code as reasoning substrate and action interface), Harness Mechanisms (planning, memory, tool use, feedback loops, adaptive optimization), and Scaling (multi-agent coordination, shared state, collective verification).

**Key quote:** "The bottleneck of autonomy is not only the reasoning ability of the base model, but also the reliability of the system that connects model outputs to long-horizon actions and persistent states."

**What we added:**
- New skill: `agent-execution-control` — Plan-Execute-Verify loop (failures are signals, not blockers), Action-Validation Gatekeeper pattern (programmatic safety for irreversible actions), Execution Trace Grounding (intermediate state as repair signals), Contract Formation via Planning (plans as testable specs), Iterative code-grounded repair. Scoped to autonomous multi-step agents only.
- Enhancement: `multi-agent-patterns` v1.1 — Functional Role Specialization taxonomy (Synthesis / Understanding / Verification / Execution / Planning), Convergence Mechanisms taxonomy (6 types: Correctness, Security, Performance, Score-based, Consensus, Implicit), Adversarial Validation pattern (dedicated falsification agent).
