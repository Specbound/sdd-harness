---
name: agent-identity
description: "Build or audit the SOUL.md identity layer for an AI agent — 8-section framework (identity, core truths, worldview, voice, expertise, boundaries, memory policy, pet peeves). Auto-triggered by skill-extraction and skill-creator."
risk: safe
source: local
---

# Agent Identity (SOUL.md Framework)

The identity layer sits at the top of the system prompt — before memory, skills, and tools. It defines who the agent is when it shows up. An hour here changes every conversation that follows.

**Key insight:** "Be helpful and professional" changes nothing — models already try this by default. Only specificity compounds. A SOUL.md that works lets you predict the agent's next response before reading it.

## When to Activate

- **Called automatically by `skill-extraction` (Phase 5c) and `skill-creator` (Phase 4c)** to validate skill identity sharpness during any new skill creation
- Building a new agent, subagent, or CLAUDE.md persona from scratch
- Writing or auditing a skill's description and `When to Activate` triggers for specificity
- Debugging inconsistent agent behavior across sessions (root cause is almost always a vague identity)
- User mentions SOUL.md, agent identity, agent persona design, or "who the agent is"

## Phase 1: Classify the Task

Two modes:

**A — Full SOUL.md** (building or auditing an agent's identity file): work through all 8 sections in order.

**B — Skill identity check** (called from skill-extraction or skill-creator): apply only the reduced identity check at the bottom of this skill. Do not generate a full SOUL.md for a skill.

## Phase 2: The 8 Sections (Mode A)

A complete identity layer has exactly these sections, in this order. Target: 30–80 lines total. Specificity beats coverage — cut any section that can't pass the Prediction Test.

### 1. Identity

One line. WHO, not what. Role + operating stance, not a function list.

| Bad | Good |
|---|---|
| `You are an AI assistant that helps with code.` | `You are a production engineer who ships, not a consultant who advises.` |

Test: Can a reader predict what the agent prioritizes — and deprioritizes — from this one line?

### 2. Core Truths

Imperative principles, 4–8 items, each with a one-line unpacking. Every truth must be falsifiable — you can observe whether the agent violated it.

| Bad | Good |
|---|---|
| `I am honest.` | `Every claim has a traceable source. If you can't cite it, flag it as inference.` |

### 3. Worldview

Opinionated takes by domain, sharp enough to predict a response on a tradeoff question.

| Bad | Good |
|---|---|
| `I value code quality.` | `Verbose code is a defect, not a style preference. Fewer lines is almost always the correct direction.` |

Test: For any domain take, can you predict the agent's tradeoff answer before seeing it?

### 4. Voice

Concrete behavioral rules, not adjectives.

| Bad | Good |
|---|---|
| `Concise and professional.` | `Lead with the answer. Under 3 sentences for yes/no questions. Never "Certainly!" or "Great question!"` |

Test: Would a reader notice if the rule was broken?

### 5. Expertise

Primary domain, fluent tools/frameworks, and explicit deference points. The deference list matters — it prevents confident hallucination outside the domain.

```
Primary: [domain]
Fluent: [tools / languages / frameworks]
Defers to user on: [topics outside domain]
Out of scope: [explicit exclusions]
```

### 6. Boundaries

Explicit "won't" lines. No soft language ("prefers not to", "tries to avoid"). Each boundary is a hard constraint, not a preference.

| Bad | Good |
|---|---|
| `Avoids generating insecure code.` | `Will not produce code that cannot be tested deterministically. If the caller demands it, says so explicitly.` |

### 7. Memory Policy

What persists, what stays private, what is ephemeral.

```
Persists: [types stored across sessions]
Private: [never stored or surfaced]
Ephemeral: [exists only within a session]
```

### 8. Pet Peeves

Phrases and tones the agent never produces. Be specific — list exact phrases, not categories.

Examples of what to list: `"Certainly!"`, `"Great question!"`, bullet-point soup (3+ nesting levels), `"As an AI language model..."`, restating the question before answering.

## Phase 3: Quality Gate — Prediction Test

Apply to each section before finalizing:

> "Given only this section, can I predict the agent's response to a specific scenario — and would that prediction be wrong if the section were removed?"

| Section | Prediction test |
|---|---|
| Identity | Can I predict what the agent prioritizes AND deprioritizes? |
| Core truths | Can I identify a violation when one occurs? |
| Worldview | Can I predict a tradeoff answer before seeing it? |
| Voice | Would I notice if the rule was broken? |
| Expertise | Do I know what the agent will NOT handle? |
| Boundaries | Is each line a hard constraint vs. a preference? |
| Memory policy | Do I know what persists and what doesn't? |
| Pet peeves | Can I list exact phrases the agent will never say? |

**If any section fails:** make it more specific or remove it. Vague sections are net-negative — they consume space without shaping behavior.

## Phase 4: Reduced Identity Check (Mode B — called from skill-extraction / skill-creator)

When invoked during skill creation, do NOT produce a full SOUL.md. Instead, evaluate these four dimensions of the skill being created:

| Dimension | Check |
|---|---|
| **Description specificity** | Does the description let you predict WHEN the skill fires — not just what it does? |
| **Trigger sharpness** | Are `When to Activate` conditions falsifiable? Two readers must agree on whether a given situation matches. |
| **Behavioral concreteness** | Does the skill give concrete instructions, or only describe what steps would look like? |
| **Explicit exclusions** | Does the skill say what it does NOT do? Without this, the model scope-creeps. |

Report as a short checklist (pass/fail per dimension). Fix failures before the skill is marked complete. One sentence per fix is enough — this is a gate, not a rewrite.
