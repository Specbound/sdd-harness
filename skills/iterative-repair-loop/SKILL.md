---
name: iterative-repair-loop
description: Three-phase Review→Repair→Validate loop with structured JSON handoffs and remaining-delta feedback. Generic engine for any artifact with measurable validation. Stops on convergence, stall, or max iterations. Token cost ~3k–20k per cycle.
source: https://developers.openai.com/cookbook/examples/codex/build_iterative_repair_loops_with_codex
risk: low
---

# Iterative Repair Loop

Separate judgment from proof. Each iteration produces evidence; failures become structured feedback for the next pass.

## When to use

Three conditions must hold:
1. An agent produces or modifies an **artifact**
2. **Measurable validation** exists (tests, rubric, checks, execution)
3. Failures can be described as **structured feedback**

Common applications: skill quality repair, code modernization, doc maintenance, API migration.

## When NOT to use

- No measurable validation criterion exists ("looks better" is not a rubric)
- Artifact requires full rewrite rather than incremental repair
- One-off fix with no iteration value

## Token budget

One full loop (up to 3 iterations, one artifact): ~3k–20k tokens depending on artifact size and failure complexity.

---

## Phase 0 — Define the Contract

Before looping, establish:

**Business rules** — what "good" means for this artifact type. Pass verbatim to each phase so policy isn't re-inferred each pass.
- Skills: see `resources/skillos-rubric.md` (SkillOS 4 dimensions)
- Code: target API patterns, lint rules, test pass rate
- Docs: required sections, link validity, currency of examples

**Validation rubric** — the scoring function for Phase 3. Must be specific and executable.

**Max iterations** — default 3.

---

## Phase 1 — Review

Inspect the artifact **without modifying it**. Return structured findings:

```json
{
  "artifact": "<name or path>",
  "findings": [
    {
      "issue_type": "<deprecated_api|missing_step|wrong_tool|compression_bloat|stale_content>",
      "severity": "high|medium|low",
      "description": "<what is wrong>",
      "suggested_fix_direction": "<what to change, not how>"
    }
  ]
}
```

---

## Phase 2 — Repair

Apply targeted edits using findings + remaining delta from the last validation cycle.

Inputs: artifact (current state) · review findings · previous remaining delta (empty on first pass) · business rules

Constraints:
- Focused edits only — don't rewrite unless the whole artifact is the problem
- Do NOT claim the artifact passes validation — that's Phase 3's job
- Track what changed (for audit trail)

---

## Phase 3 — Validate

Run the validation rubric. Return:

```json
{
  "passed": false,
  "rubric_results": [
    {"case": "<dimension>", "passed": true, "evidence": "<what you observed>"}
  ],
  "remaining_delta": [
    {"issue_type": "<same taxonomy>", "description": "<what still fails>", "fix_direction": "<next step>"}
  ]
}
```

**Convergence check:** Compare `remaining_delta.length` to the previous iteration's count.
- Shrinking → continue looping
- Unchanged or growing → **stall detected** → stop, surface remaining delta to user

---

## Loop Logic

```
prev_delta_count = null
findings = phase1(artifact, business_rules)

for iteration in range(1, max_iterations + 1):
    repair_result = phase2(artifact, findings, prev_delta, business_rules)
    validation = phase3(repaired_artifact, rubric)
    save_audit_record(iteration, findings, repair_result, validation)

    if validation.passed:
        break

    curr = len(validation.remaining_delta)
    if prev_delta_count is not None and curr >= prev_delta_count:
        flag_stall(validation.remaining_delta)
        break

    prev_delta_count = curr
    prev_delta = validation.remaining_delta
```

---

## Audit Trail

Save after each iteration (path: `/tmp/repair-<artifact>-iter<N>.json`):

```json
{
  "artifact": "<name>",
  "iteration": 1,
  "review_findings": ["..."],
  "repair_summary": "<what changed>",
  "validation": {"passed": false, "remaining_delta": ["..."]}
}
```

---

## Phase 4 — Report

```
## Repair Loop Complete — <artifact>

Iterations: N / max_N
Outcome: Passed ✅ | Stalled ⚠️ | Max iterations reached 🔁

Changes made:
- <iteration 1>: <summary>
- <iteration 2>: <summary>

Remaining delta (if any):
- <issue_type>: <description>
  Fix direction: <next step>

Token cost: ~Xk tokens
```

If stalled: surface the remaining delta so the user can intervene with domain knowledge the loop couldn't supply.

---

## Default Rubric for Skills (SkillOS Quality Gate)

See `resources/skillos-rubric.md` for the full table. Quick reference:

| Dimension | Fail signal |
|---|---|
| Task relevance | No "When to use" / hypothetical tasks only |
| Operational validity | Dead tool references, non-existent paths |
| Content quality | Narration instead of steps, missing phases |
| Compression | >5,000 words, description >200 chars, no resources/ for verbose content |
