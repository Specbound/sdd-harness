# X (Pasted Text)

Content passed directly as pasted text to `/skill-extraction` — not a URL, repo, or file path. Ordered by date added.

---

*No entries yet.*

When you paste content directly (e.g. a thread, an excerpt, a doc snippet), it gets logged here with:
- A short title describing the source
- What the content covered
- What was extracted and added to the harness

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
