# Calibrating With Trajectories

A behavior spec's wording is only as good as its ability to survive contact with real trajectories. Calibrate before shipping — and re-calibrate whenever the spec is materially revised.

## The four fixture types

Test every new or changed spec against, at minimum:

1. **Positive** — the trigger fires and the expected conduct occurred. Confirms the spec doesn't over-constrain a case that's actually fine.
2. **Negative** — the trigger fires and the expected conduct did *not* occur. Confirms the spec's wording actually catches the violation, not just describes it in the abstract.
3. **Outside-scope** — the trigger does not fire at all. Confirms the spec doesn't accidentally activate on unrelated trajectories (over-broad triggers are the most common failure mode).
4. **Lucky-correct negative** — the agent reached a correct-looking final answer *without* the expected conduct. The hardest and most important case: a spec that only catches wrong answers isn't grading process, it's grading outcome, and duplicates `evaluation/micro`.

## Where to get real trajectories in this harness

- **Raindrop Workshop** (`mcp__raindrop__query_traces`, `search_run`, `get_run_outline`) — if the project has traced runs, pull actual recorded trajectories matching the trigger situation.
- **`.claude/memory/observations.md`** — session-level evidence (drains, reverts, feedback citations) even without full trace capture.
- **The evidence that prompted the spec** — the judge drain / feedback memory / revert that triggered `behavior-spec-agent` in the first place is itself one fixture (usually the negative).

## When a fixture genuinely doesn't exist yet

For a brand-new candidate behavior, it's common to have only the negative (the evidence that prompted it) and no positive/outside-scope/lucky-correct example yet. Do not invent one to fill the slot — that fabricates a hidden fact into the judge, exactly what upstream warns against.

Instead:

- Ship the spec with the fixtures you have.
- Note in `references/` which fixture types are still unverified.
- Treat the spec as provisional until a matching trajectory appears (next nightly run, or a future Raindrop trace) and can be checked against it.

## If reviewers can't locate the trigger or evidence

That's a wording problem, not a fixture problem. Revise the behavior's altitude (usually: too abstract — tie it to something concretely observable) or flag that this project's observability doesn't yet capture the relevant signal. Never solve an observability gap by inventing hidden facts in the spec or the judge.

## Rubric Builder overlap

`evaluation/long-trajectory`'s Phase 3 (Rubric Builder) runs a similar evaluate → calibrate → refine loop, but against *production outcomes* over time, for rubrics used in active grading. This calibration step is upstream of that: it's a one-time (or per-revision) check that the *wording* is soundly adjudicable before the spec is trusted as an input to that loop at all. Do not skip straight to Rubric Builder calibration without first confirming the spec passes its own four fixture types.
