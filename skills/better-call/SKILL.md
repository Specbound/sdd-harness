---
name: better-call
description: "Called by skill-extraction when it detects a duplication or alignment with an existing harness artifact. Evaluates the CHALLENGER (new) vs INCUMBENT (existing) and issues a binding verdict: KEEP / ADOPT / AUGMENT / MERGE / COEXIST."
risk: safe
source: local
---

# Better Call

When skill-extraction flags a potential duplication, this skill takes over the comparison decision. Its job is not to protect what exists — it's to find the best outcome.

**The default answer is not "keep existing."** The default answer is the one that leaves the harness in better shape.

## When to Activate

Invoked by skill-extraction Phase 3e (Value Critic Gate) when check #1 fires — the new capability overlaps ≥70% with an existing artifact. Do not invoke for unrelated tasks.

## Do Not Use When

- No existing harness artifact overlaps with the candidate (skip straight to Phase 4 proposal)
- The user is not in a skill-extraction workflow

---

## Workflow

### Step 1: Name the Contestants

Identify and label both sides clearly:

- **CHALLENGER** — the new capability being proposed (from the external source)
- **INCUMBENT** — the existing harness artifact that allegedly already covers it (name, path, type)

Read both in full before scoring. A shallow skim produces wrong verdicts.

### Step 2: Score on Six Dimensions

Score each on a 1–5 scale per dimension. Be honest — a low score on one dimension doesn't disqualify; the totals decide.

| Dimension | What it measures | Scoring guide |
|---|---|---|
| **Coverage breadth** | How many real use cases does it handle? | 1 = narrow edge case; 5 = handles the full domain |
| **Implementation quality** | How well is it built? | 1 = vague/incomplete; 5 = concrete, actionable, no dead steps |
| **Automation potential** | Can it be wired to a hook or routine? | 1 = user must always invoke; 5 = zero-touch automation possible |
| **Complementarity delta** | Does it cover territory the other doesn't? | 1 = pure subset; 5 = entirely different angle on the problem |
| **Maintenance cost** | How expensive to keep this working? | 1 = high churn / fragile; 5 = stable, no upkeep expected |
| **Harness fit** | Does it follow harness conventions and terminology? | 1 = foreign patterns; 5 = feels native to the harness |

Produce a score table:

```
| Dimension               | CHALLENGER | INCUMBENT |
|-------------------------|------------|-----------|
| Coverage breadth        | X/5        | X/5       |
| Implementation quality  | X/5        | X/5       |
| Automation potential    | X/5        | X/5       |
| Complementarity delta   | X/5        | X/5       |
| Maintenance cost        | X/5        | X/5       |
| Harness fit             | X/5        | X/5       |
| **Total**               | **/30**    | **/30**   |
```

### Step 2b: Score It Again With the Order Reversed

Score the pair a second time, presenting the **incumbent first** — read it first, score it first, write its column first. Same six dimensions, same 1–5 scale, no reference to the first pass while scoring.

Why: a pairwise judge anchors on whichever option it reads first. Google Cloud's AutoSxS neutralizes this by swapping answer order between runs and reporting a win rate across both orders, not a single verdict. This skill already guards *defender* bias (Key Principles); it did not guard *position* bias, and the two are independent. One presentation order is one sample — the same reason `session-judge` runs 3× and takes the median.

Compare the two passes:

| Both passes | Then |
|---|---|
| Same verdict | That verdict stands. Report both totals in the verdict block. |
| Different verdicts | **INCONCLUSIVE.** The result is position-driven, not evidence-driven. |

`INCONCLUSIVE` is a real outcome, not a failed run. Do not average the two passes into a middle verdict, and do not re-run until they agree. Either name the one dimension that moved and re-score only that with a stated reason, or return `INCONCLUSIVE` and let skill-extraction default to keeping the incumbent. Adopting on a verdict that flips with reading order is worse than adopting nothing.

### Step 3: Issue a Verdict

Choose exactly one verdict based on the scores and narrative reasoning:

| Verdict | Condition | Meaning |
|---|---|---|
| **KEEP INCUMBENT** | Challenger total < Incumbent total by ≥5 pts AND complementarity delta ≤ 2 | New adds nothing meaningful; existing is superior. Recommend skip in Phase 4. |
| **ADOPT CHALLENGER** | Challenger total > Incumbent total by ≥5 pts | New is measurably better. Recommend replacing or superseding existing artifact. |
| **AUGMENT INCUMBENT** | Challenger scores higher on 1–2 dimensions only | Challenger has specific ideas worth grafting onto the existing artifact. Extract those ideas; discard the rest. |
| **MERGE** | Both total within 4 pts of each other AND complementarity delta ≥ 3 | Both have distinct, non-overlapping value. Create a unified artifact that combines them. |
| **COEXIST** | Complementarity delta = 5 AND both total ≥ 18/30 | Genuinely different domains or audiences. Both are warranted without conflict. Justify explicitly. |
| **INCONCLUSIVE** | Step 2b's two passes reached different verdicts | Reading order decided it, not the artifacts. skill-extraction keeps the incumbent and records why. |

If scores fall near a boundary, break ties with this tiebreaker priority:
1. Automation potential (highest wins — the harness is self-sustaining by design)
2. Complementarity delta (diversity of coverage beats depth of one)
3. Implementation quality (better-built wins)

### Step 4: Return the Verdict Block

Output a structured block that skill-extraction can consume directly:

```
## better-call Verdict

**CHALLENGER:** [name / description]
**INCUMBENT:** [name / path]

| Dimension               | CHALLENGER | INCUMBENT |
|-------------------------|------------|-----------|
| Coverage breadth        |            |           |
| Implementation quality  |            |           |
| Automation potential    |            |           |
| Complementarity delta   |            |           |
| Maintenance cost        |            |           |
| Harness fit             |            |           |
| **Total**               |            |           |

**Order-reversed pass (Step 2b):** [totals from the second pass] → [same verdict / different verdict]

**Verdict: [KEEP INCUMBENT / ADOPT CHALLENGER / AUGMENT INCUMBENT / MERGE / COEXIST / INCONCLUSIVE]**

**Reasoning:** [2–4 sentences. What tipped the decision? What does the winning option do that the other doesn't? If AUGMENT or MERGE, what specifically should be extracted or fused?]

**Instruction to skill-extraction:**
- [Concrete directive: "Reject this candidate", "Propose as replacement for X", "Augment X with sections Y and Z from challenger", "Create unified skill merging both", "Propose both as separate artifacts"]
```

---

## Key Principles

- **Recency is not quality.** Existing artifacts earn their place — but so can challengers.
- **Better-built beats first-built.** A challenger that is more concrete, more automatable, and better scoped wins even if the incumbent arrived first.
- **Score honestly.** Defender bias (protecting what's already installed) is the failure mode this skill exists to prevent.
- **AUGMENT is the most common right answer.** Pure replacement is rare; total rejection is also rare. Most challengers have at least one idea worth extracting.
- **COEXIST requires explicit justification.** Two artifacts in the same domain is only right when the use cases are genuinely non-overlapping and both are strong enough to warrant their own file.
