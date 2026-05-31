# Git Repositories

GitHub repositories that were passed to `/skill-extraction` and turned into harness skills or tooling. Ordered by date added.

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

## github.com/rtk-ai/rtk
**URL:** https://github.com/rtk-ai/rtk | **Added:** 2026-05-27

**What it is:** RTK (Rust Token Killer) — a Claude Code PreToolUse hook that intercepts Bash commands and rewrites them to compressed equivalents, achieving 60–90% token reduction on common dev operations (git, pytest, jest, tsc, eslint, Docker, kubectl, AWS CLI). Output semantics are preserved; only verbosity is removed.

**What we added:**
- Skill: `rtk-token-reduction` — guidance on when to use `rtk proxy` (exact raw output for piping/debugging), `rtk gain` (check cumulative savings), and how to configure exclusions for commands where compression would break downstream parsing.
