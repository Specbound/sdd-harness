# X (Pasted Text)

Content passed directly as pasted text to `/skill-extraction` — not a URL, repo, or file path. Ordered by date added.

---

*No entries yet.*

When you paste content directly (e.g. a thread, an excerpt, a doc snippet), it gets logged here with:
- A short title describing the source
- What the content covered
- What was extracted and added to the harness

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
