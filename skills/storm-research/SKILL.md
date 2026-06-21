---
name: storm-research
description: "Research a topic from 5 adversarial perspectives, map their contradictions, synthesize a reliability-ranked briefing, then self-peer-review for bias. Use before a decision, report, or investment."
risk: safe
source: local
---

# STORM Research

Multi-perspective topic research adapted from Stanford OVAL's STORM method (NAACL 2024). A single "tell me about X" returns the majority view and inherits its blind spots. STORM forces five distinct expert voices, surfaces where they clash, synthesizes a reliability-ranked briefing, then grades its own work for bias.

Four phases: **Perspectives → Contradiction Map → Synthesis → Peer Review.**

## When to Use This Skill

- User says "research X", "what do I need to know about X", "brief me on X before [a decision/report/interview/investment/negotiation]"
- A topic where the popular framing likely hides counter-evidence or incentives
- Pre-work for writing, a major decision, due diligence, or learning a new field
- User explicitly asks for "STORM" or "multi-perspective research"

## Do Not Use This Skill When

- Reviewing a design *you* proposed — use `multi-agent-brainstorming` (it critiques a known design; this researches an unknown topic)
- A single sourced fact lookup — just answer it
- The user wants an external paid deep-research run — use `deep-research` (Gemini API)
- Constructing a feature or idea from scratch — use `brainstorming`

## Two Run Modes

Decide mode before Phase 1.

| Mode | When | How |
|---|---|---|
| **Workflow (default for substantive topics)** | Topic is broad / high-stakes / user wants thoroughness | Fan the 5 personas out as parallel agents so no voice contaminates another, then run contradiction → synthesis → peer-review as downstream stages. See "Workflow Mode" below. |
| **Inline (quick runs)** | Narrow topic, fast turnaround, conversational | Run all 4 phases sequentially in this context using the verbatim prompts in `resources/prompts.md`. |

If unsure, ask the user: "Quick inline pass or full parallel Workflow run?"

## The Five Perspectives (fixed roster)

Each voice is constrained to its lens — its job is to see what the others miss.

1. **The Practitioner** — works with this daily. What do practitioners know that academics miss? What practical realities get ignored?
2. **The Academic** — studied it for years. What does peer-reviewed evidence actually say? Where does evidence contradict popular belief?
3. **The Skeptic** — thinks the mainstream view is wrong. Strongest counterargument? What evidence do proponents conveniently ignore?
4. **The Economist** — follows the money. Who profits from the current narrative? What financial incentives shape the research?
5. **The Historian** — has seen the pattern before. What historical parallels exist? How did those play out?

For each: core position (2 sentences), strongest supporting evidence, and the one thing this voice would say that no other would.

## Workflow Mode

Author a `Workflow` run with these stages. Pass the topic via `args`.

**Phase 1 — Perspectives (parallel, barrier).** Spawn 5 agents, one per persona, each blind to the others. `parallel()` so no voice anchors on another. Each returns `{position, evidence, unique_insight}`.

**Phase 2 — Contradiction Map (1 agent).** Feed all 5 perspectives to one agent. It returns:
- Direct conflicts (which voices clash, on what specific claims)
- Strongest-evidence vs weakest-evidence perspective, with why
- The one question that would resolve the biggest contradiction
- What **every** perspective agrees on (likely true — even opponents confirm it)
- What **none** addressed (the field's blind spot — often the most valuable finding)

**Phase 3 — Synthesis (1 agent).** Feed perspectives + contradiction map. Returns the briefing:
1. One-paragraph CEO summary (nuance, not headline)
2. 5 key findings ranked by reliability, each tagged with which perspectives support/challenge it
3. The hidden connection visible only across all 5 voices
4. Actionable insight — what someone in the user's role should do differently (ask the user their role if relevant)
5. The frontier question

**Phase 4 — Adversarial Peer Review (1 agent, skeptical stance).** Grades the Phase 3 briefing. Returns:
- Confidence score 1–10 per key finding, with rationale
- Weakest link: least-confident claim + what would verify it
- Bias check: which perspective dominated the synthesis
- Missing 6th angle that would change conclusions
- Overall grade + what to fix

Then **surface the briefing to the user**, annotated with the peer-review's confidence scores and any flagged weak links. Do not bury the critique — the self-critique is the deliverable's quality signal.

Pipeline shape (the contradiction/synthesis/review stages are inherently serial — each needs the full prior output):

```
phase('Perspectives')
const voices = await parallel(PERSONAS.map(p => () =>
  agent(perspectivePrompt(p, topic), {schema: VOICE_SCHEMA, phase: 'Perspectives'})))
phase('Map'); const map = await agent(contradictionPrompt(voices), {schema: MAP_SCHEMA})
phase('Synthesis'); const brief = await agent(synthesisPrompt(voices, map, role), {schema: BRIEF_SCHEMA})
phase('Review'); const review = await agent(peerReviewPrompt(brief), {schema: REVIEW_SCHEMA, effort: 'high'})
return { brief, review }
```

## Inline Mode

Run the 4 prompts in `resources/prompts.md` in order, in this conversation. Faster, but the 5 voices share one context so they partially anchor on each other — accept that trade for speed. Still run all 4 phases; the peer-review (Phase 4) is the step most people skip and the one that catches bias.

## Grounding Rule

Personas simulate expertise — they do not invent citations. When a claim is empirical and checkable, use `WebSearch`/`WebFetch` to ground it rather than asserting from the persona's voice. The peer-review phase must flag any load-bearing claim that was never grounded as a weak link.

## Pass Criteria

A complete STORM run produces all four artifacts: 5 distinct perspectives, a contradiction map (including the unanimous-agreement and nobody-addressed items), a reliability-ranked synthesis, and a peer review with per-finding confidence scores. A run missing the contradiction map or the peer review is incomplete — those two are what separate this from a normal answer.

## Related Skills

- `multi-agent-brainstorming` — sequential review of a design *you* proposed (different intent: known design, not unknown topic)
- `deep-research` — external Gemini autonomous research (paid, opaque internals); use when you want a long-running cited report instead of structured perspectives
- `brainstorming` — creative construction of features/ideas
- `multi-agent-patterns` — the orchestration patterns (parallel fan-out, adversarial verify) this skill's Workflow mode builds on
- `verification-before-completion` — the peer-review phase is an instance of evidence-before-claims
