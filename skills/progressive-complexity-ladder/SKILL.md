---
name: progressive-complexity-ladder
description: >
  Use when designing or scoping any AI-powered workflow, agent system, or automation from scratch.
  Triggers on: "build an AI workflow", "design an agent", "add AI automation", "how should I approach
  building X with AI", or when kiro:spec-design classifies a feature as an AI integration or automation.
  Prevents over-engineering by enforcing one-capability-at-a-time progression.
---

# Progressive Complexity Ladder

When building AI-powered features, start at the lowest effective level and add exactly one real
capability per iteration. Never design for level 6 when level 2 solves the problem.

Source: Jason Liu's six-level morning brief framework — adapted for feature/system design.

---

## The Ladder

### Level 1 — Basic Integration
Connect existing tools and ask a plain question.
- Wire up the data sources (API, database, queue)
- Ask a single natural-language question
- Validate that the AI surfaces genuinely useful information before investing further

**Design test:** Does this level alone provide value the user couldn't get otherwise?

### Level 2 — Persistent Instructions (AGENTS.md pattern)
Move from ad-hoc prompts to a persistent instruction file.
- Define preferences, output format, focus areas in a versioned file
- The AI reads this file at the start of every invocation
- Different contexts (roles, projects) get separate instruction files

**Design test:** Would repeating the same prompt multiple times be wasteful? Then externalize it.

```
# Example instruction file
Focus on:
- items waiting on me
- decisions that are blocked
- what changed since last run

Output format:
- To-do: [item] — [why it matters]
- Reply needed: [person] — [what they're waiting for] — [direct link]
- Blocked: [project/decision] — [what unblocks it]

Keep it under 200 words. If nothing important changed, say that.
```

### Level 3 — Recurrence via Natural Language
Frame scheduling in user language, not cron syntax.
- "Run every weekday morning" not `0 9 * * 1-5`
- Store outputs in persistent threads/logs so feedback accumulates
- The thread carries preferences forward — no prompt reconstruction needed

**Design test:** Should this happen without the user remembering to ask?

### Level 4 — Project-Level Specialization
Split one general agent into focused per-domain agents.
- Each domain gets its own instruction file and thread
- Domain-specific definitions of "important" — not one-size-fits-all
- Threads retain domain context, reducing prompt weight over time

**Design test:** Is one agent trying to serve three different audiences? Split it.

### Level 5 — Draft Output, Not Final Action
The agent produces drafts for human approval, not autonomous actions.
- Draft responses (unsent), not sent messages
- Assembled materials (unsubmitted), not submitted actions
- Flagged decisions (unresolved), not resolved decisions

**Critical principle — Draft, Don't Impersonate:**
> The agent generates artifacts in the user's name that require human approval before
> execution. It never acts as the user. This boundary is the trust boundary.

**Design test:** Can the user review, edit, and discard any output before it affects others?

### Level 6 — Memory Vault (Compounding Context)
Wire the agent to a persistent knowledge structure so today's context improves tomorrow's output.
- Open loops captured to a TODO equivalent (don't let them disappear into chat history)
- People context stored persistently (collaborator state, open threads)
- Project state maintained between runs
- Previous decisions accessible to future briefs

**Design test:** Is the agent re-learning the same context every run? Then build the vault.

**Vault structure (adapt to your memory system):**
```
memory/
├── action-items.md      # open loops, commitments
├── entities.md          # people, companies, projects (persistent context)
├── hot-memory.md        # current priorities and key decisions
└── daily/               # per-day facts and archived outputs
```

---

## Application to kiro Feature Design

When `spec-design` classifies a feature as **AI Integration** or **AI-powered workflow**:

1. Place the feature on the ladder — what level is the minimum viable version?
2. Scope requirements to that level only. Higher levels are future specs, not this one.
3. Add to requirements.md: "Out of scope: levels N+1 through 6" to prevent scope creep.
4. Name the spec phase: `level-N-{feature-name}` so the progression is visible.

### Feature Classification Mapping

| Feature type | Start at | Typical ceiling |
|---|---|---|
| Read-only data surfacing | Level 1 | Level 2 |
| Recurring summarization | Level 2 | Level 3 |
| Multi-domain monitoring | Level 3 | Level 4 |
| Workflow acceleration | Level 4 | Level 5 |
| Autonomous agent system | Level 5 | Level 6 |

---

## Anti-Patterns

| Temptation | Reality |
|---|---|
| "Let's build the full system now" | Level 1 often delivers 80% of the value. Build it first. |
| "We need a vault before we can start" | Start without memory. Add it when re-learning context becomes expensive. |
| "The agent should just send the message" | Draft-not-impersonate is a trust boundary, not a limitation. |
| "One agent can handle everything" | Split when definitions of "important" diverge across domains. |
| "We'll add personalization later" | Level 2 instruction files are cheap. Do it when repeatability matters. |

---

## Integration

Connects to:
- `multi-agent-patterns` — Level 4–5 multi-agent coordination; see its **Tool Selection** section to decide between the `Agent` tool (2–10 subtasks) and the `Workflow` tool (tens-to-hundreds, script-based) once you've committed to multi-agent
- `para-memory-files` — Level 6 vault implementation
- `context-optimization` — reducing context load as levels increase
