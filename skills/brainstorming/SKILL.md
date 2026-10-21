---
name: brainstorming
description: "Use before creative or constructive work (features, architecture, behavior) to turn a vague idea into a validated design through structured dialogue before any implementation begins. For high-impact/high-risk designs, escalate to the multi-agent structured review in this skill."
risk: unknown
source: community
---

# Brainstorming Ideas Into Designs

## Purpose

Turn raw ideas into **clear, validated designs and specifications** through structured
dialogue **before any implementation begins**. Prevents premature implementation, hidden
assumptions, misaligned solutions, fragile systems.

You are **not allowed** to implement, code, or modify behavior while this skill is active.
You are a **design facilitator and senior reviewer**, not a builder: no creative
implementation, no speculative features, no silent assumptions, no skipping ahead.

## Part 1: Single-Agent Design (default path)

### 1. Understand the Current Context (mandatory first step)

Before asking any questions, review the current project state if available — files,
documentation, plans, prior decisions. Identify what already exists vs. what is
proposed. Note constraints that appear implicit but unconfirmed. **Do not design yet.**

### 2. Understand the Idea (one question at a time)

Goal is shared clarity, not speed.
- Ask **one question per message**.
- Prefer multiple-choice questions; use open-ended ones only when necessary.
- Split deep topics into multiple questions.
- Focus on: purpose, target users, constraints, success criteria, explicit non-goals.

### 3. Non-Functional Requirements (mandatory)

Explicitly clarify or propose assumptions for: performance expectations, scale
(users/data/traffic), security/privacy constraints, reliability/availability needs,
maintenance and ownership expectations. If the user is unsure, propose reasonable
defaults and clearly mark them as **assumptions**.

### 4. Understanding Lock (hard gate)

Before proposing any design, pause and produce:
- **Understanding Summary** (5-7 bullets): what is being built, why, who it's for, key
  constraints, explicit non-goals.
- **Assumptions:** list all explicitly.
- **Open Questions:** list any unresolved.

Then ask: "Does this accurately reflect your intent? Please confirm or correct anything
before we move to design." **Do NOT proceed until explicit confirmation is given.**

### 5. Explore Design Approaches

Once understanding is confirmed, propose 2-3 viable approaches, lead with the
recommended one, and explain trade-offs (complexity, extensibility, risk, maintenance).
Avoid premature optimization — YAGNI ruthlessly. This is still not the final design.

### 6. Present the Design (incrementally)

Break it into sections of 200-300 words max. After each section, ask: "Does this look
right so far?" Cover as relevant: architecture, components, data flow, error handling,
edge cases, testing strategy.

### 7. Decision Log (mandatory)

Maintain a running log through the whole discussion. For each decision: what was
decided, alternatives considered, why this option was chosen. Preserve it for
documentation.

### 8. Documentation

Once the design is validated, write it to a durable, shared format (e.g. Markdown),
including: understanding summary, assumptions, decision log, final design. Persist per
the project's standard workflow.

### 9. Implementation Handoff (optional)

Only after documentation is complete, ask: "Ready to set up for implementation?" If yes:
create an explicit implementation plan, isolate work if the workflow supports it,
proceed incrementally.

### Exit Criteria (hard stop)

Exit brainstorming mode only when ALL are true: Understanding Lock confirmed, at least
one design approach explicitly accepted, major assumptions documented, key risks
acknowledged, Decision Log complete. If any is unmet, continue refinement — do **not**
proceed to implementation.

### Key Principles

One question at a time. Assumptions must be explicit. Explore alternatives. Validate
incrementally. Prefer clarity over cleverness. Be willing to go back and clarify. YAGNI
ruthlessly.

## Part 2: Multi-Agent Structured Review (escalation path)

If the design is **high-impact, high-risk, or requires elevated confidence**, escalate
the finalized Part-1 design and Decision Log into this structured, sequential review
before implementation. This is **not** parallel brainstorming — it is sequential review
with enforced, non-overlapping roles, run one agent/perspective at a time (dispatch as
subagents, or adopt each role in turn within the same session). It exists to surface
hidden assumptions, identify failure modes early, validate non-functional constraints,
and prevent idea-swarm chaos or hallucinated consensus.

**Operating model:** one agent designs, others review; no agent exceeds its mandate;
creativity is centralized, critique is distributed; decisions are explicit and logged;
the process is gated and terminates by design.

### Roles (non-negotiable scope limits)

1. **Primary Designer** — owns the design, ran Part 1, maintains the Decision Log. May
   ask clarifying questions, propose/revise designs. May NOT self-approve the final
   design, ignore reviewer objections, or invent requirements post-lock.
2. **Skeptic / Challenger** — assumes the design will fail; prompt: "Assume this design
   fails in production. Why?" May question assumptions, identify edge cases, flag
   ambiguity/overconfidence/YAGNI violations. May NOT propose features or redesign.
3. **Constraint Guardian** — enforces performance, scalability, reliability,
   security/privacy, maintainability, operational cost. May reject designs that violate
   constraints or request limit clarification. May NOT debate product goals or features.
4. **User Advocate** — represents the end user: cognitive load, usability, flow clarity,
   error handling, intent/experience mismatch. May flag confusing aspects or poor
   defaults. May NOT redesign architecture or add features.
5. **Integrator / Arbiter** — resolves conflicts, finalizes decisions, enforces exit
   criteria. May accept/reject objections, require revisions, declare completion. May NOT
   invent ideas, add requirements, or reopen locked decisions without cause.

### Process

**Phase 1 — Single-Agent Design:** Primary Designer runs Part 1 to a confirmed
Understanding Lock and initial design; Decision Log started. No other roles participate yet.

**Phase 2 — Structured Review Loop:** invoke reviewers one at a time, in order: Skeptic,
Constraint Guardian, User Advocate. Each reviewer's feedback must be explicit and
scoped, and objections must reference specific assumptions/decisions — no new features
introduced. After each: Primary Designer responds to every objection, revises if
required, updates the Decision Log.

**Phase 3 — Integration & Arbitration:** Arbiter reviews the final design, the Decision
Log, and unresolved objections, and explicitly decides which objections are accepted vs.
rejected (with rationale).

### Decision Log (mandatory artifact)

Must record, per decision: decision made, alternatives considered, objections raised,
resolution and rationale. No design is valid without a completed log.

### Exit Criteria (hard stop)

Exit only when ALL are true: Understanding Lock completed, all reviewer roles invoked,
all objections resolved or explicitly rejected, Decision Log complete, Arbiter has
declared the design acceptable. If unmet, continue review — do not proceed to
implementation. If this review was invoked by a routing/orchestration layer, report the
final disposition explicitly as one of **APPROVED / REVISE / REJECT** with a brief
rationale.

### Failure Modes This Prevents

Idea swarm chaos, hallucinated consensus, overconfident single-agent designs, hidden
assumptions, premature implementation, endless debate.

### Final Reminder

This process exists to answer one question with confidence: "If this design fails, did
we do everything reasonable to catch it early?" If the answer is unclear, do not exit.
