---
name: skill-eval-gate
description: "Gates a new/edited skill's docs on measured with-vs-without pass-rate lift before finalization. Invoked from skill-creator/skill-extraction quality gates — never run standalone."
risk: safe
source: local
---

# skill-eval-gate

## When to Use This Skill

- Invoked by `skill-creator` Phase 4b or `skill-extraction` Phase 5b, immediately before a new or edited `SKILL.md` is finalized/installed.
- Never invoked directly by the user — it is a gate inside another skill's workflow, not a standalone entry point.

## Do Not Use When

- **General agent behavior testing** (reliability, regression, capability benchmarking unrelated to a specific skill) → use `agent-evaluation` instead.
- **Comparing a new candidate against an existing skill/hook/script for overlap** → use `better-call` instead. `skill-eval-gate` measures whether a skill helps at all; `better-call` measures whether a *new* one beats an *existing* one.
- **The skill under test has no clear pass/fail check** (pure creative/subjective output with no objective success criterion) → state this explicitly and skip the gate rather than fabricating a rubric; log the skip reason in the calling skill's summary.

## Instructions

### Phase 1: Define Evaluation Scenarios

Write at least 3 concrete task scenarios the skill is meant to help with. Each scenario needs:
- A realistic user prompt (not a toy example — something the skill would actually fire on)
- A **deterministic pass/fail check**: a grep pattern, file-existence check, exit code, or short rubric with named criteria — not open-ended "did it do a good job?"

Scenarios must vary in difficulty or angle (not 3 near-duplicates) so the result isn't a single lucky/unlucky draw.

### Phase 1b: Calibrate Scenario Difficulty (before measuring anything)

"Vary in difficulty" is unverifiable by inspection — every scenario looks reasonable
to the person who wrote it. Calibrate it with a two-point probe instead, using the
tiers named in `model-tiers`:

- Run the **baseline** (no skill) on a **strong** model.
- Run the **treatment** (with skill) on a **weak** model.

Read the result as a property of the *scenario*, not the skill:

| Observation | Meaning | Action |
|---|---|---|
| Strong baseline passes | Scenario is too easy — the model already does this unaided | Replace it. Any lift it later shows is noise. |
| Weak treatment fails, and weak baseline also fails everywhere | Scenario is too hard — no lift is measurable through it | Replace or simplify. |
| Weak treatment passes, strong baseline fails | Well-calibrated | Keep. Lift measured here is real. |
| **Strong scores *worse* than weak on the same scenario** | Not a difficulty signal at all | **Stop.** This is a reward hack or a broken checker. Fix the check before running the gate. |

That last row is the one to watch for. A stronger model losing to a weaker one on an
identical task is almost never a fact about the skill — it means the pass/fail check
rewards something other than doing the task well (shorter output, a literal string,
declining to act). Measuring lift against a check like that produces a confident
number that means nothing.

A gate that measures lift on scenarios of unknown difficulty is how a skill
manufactures a pass. This phase is what makes the delta in Phase 4 worth anything.

### Phase 2: Run the No-Skill Baseline

For each scenario, spawn an `Agent` (subagent_type: `general-purpose`, isolation: none needed unless the task writes files) with the scenario prompt **and explicitly instruct it not to reference or invoke the skill under test**. Capture its output.

Score each baseline run against the Phase 1 pass/fail check.

### Phase 3: Run the Treatment (With-Skill)

For each scenario, spawn a fresh `Agent` with the same prompt, this time explicitly told the skill is available and to use it if relevant (or, if the skill isn't yet installed, paste its `SKILL.md` content directly into the prompt as available context). Capture its output.

Score each treatment run against the same Phase 1 pass/fail check used for the baseline.

### Phase 3b: Validate the Judge (only when scoring uses an LLM rubric)

Skip this when every Phase 1 check is deterministic — a grep, an exit code, and a
file-existence test cannot be fooled. When any scenario is scored by a rubric an LLM
applies, that judge is the load-bearing component of the whole gate and it is the one
thing the gate never checks.

Validate it before trusting a single score:

1. Build **two reference answers** for one real scenario: a deliberately bad one
   (over-built, or minimal-but-incomplete — whichever failure the skill is supposed
   to prevent) and a clearly good one.
2. Ask the judge to rank them, with the same rubric, same model, temperature 0.
3. **If the judge does not rank the good one strictly above the bad one, discard the
   entire run.** Fix the rubric and start over. Scores from an unvalidated judge are
   not weak evidence; they are no evidence.

**Pair every quality judgement with a completeness judgement.** A skill can win on
any "is this lean / clean / focused" rubric by producing less — declining work,
stubbing, omitting the hard part. If the rubric only measures quality, doing less is
a winning strategy and the gate will certify it. Score whether the task was actually
*completed* as a separate axis, and treat a quality win with a completeness loss as
a FAIL.

Require the judge to **cite the specific construct** behind its score, or say `none`.
A judge that cannot point at what it penalized is pattern-matching on tone.

**Persist the raw runs.** Keep each run's full output and workspace, and re-score from
those artifacts when the rubric changes. Re-generating runs to try a scoring tweak
pays the expensive half of the loop twice, and worse, changes two variables at once —
you can no longer tell whether the number moved because of the rubric or because of
sampling.

### Phase 4: Compute the Delta

Tabulate:

| Scenario | Baseline (no-skill) | Treatment (with-skill) |
|---|---|---|
| 1 | pass/fail | pass/fail |
| 2 | pass/fail | pass/fail |
| 3 | pass/fail | pass/fail |

Compute pass-rate delta = treatment pass rate − baseline pass rate.

### Phase 5: Verdict

| Delta | Verdict | Action |
|---|---|---|
| Treatment clears baseline on a majority of scenarios, with no baseline-only passes | **PASS** | Skill may proceed to finalization/installation. |
| Treatment ties or loses to baseline on a majority of scenarios | **FAIL** | Do not finalize. Rewrite the skill's instructions (sharper triggers, more concrete steps, narrower scope) and re-run from Phase 2. |
| Fewer than 3 scenarios could be scored deterministically, or results are mixed with no clear majority | **INCONCLUSIVE** | Do not finalize on this evidence alone. Either add a deterministic check for the failing scenario(s) or add more scenarios until a majority verdict is reachable. |
| Phase 1b was skipped, or scenarios failed calibration (strong baseline passed / strong scored below weak) | **INCONCLUSIVE** | The delta is unreadable regardless of its size. Recalibrate the scenarios and re-run from Phase 2. |
| An LLM rubric was used and Phase 3b's judge validation was skipped or failed | **INCONCLUSIVE** | Discard the scores. Fix the rubric, revalidate, re-run. |

Report the verdict and the scenario table back to the calling skill (`skill-creator` Phase 4b or `skill-extraction` Phase 5b). A **FAIL** or **INCONCLUSIVE** verdict blocks that phase from passing — the calling skill must not proceed to installation/finalization until this gate returns PASS.

## Success Criteria

- Every finalized skill that passed through `skill-creator` or `skill-extraction` has a logged PASS verdict from this gate, backed by a scenario table with real (not assumed) pass/fail results from two independent runs per scenario.
- No skill is finalized on the strength of the *author's* confidence that it will help — only on a measured delta.

## Inputs and Outputs

**Input:** the draft `SKILL.md` content (or its file path once written) plus the calling skill's context on what task domain it targets.

**Output:** a PASS/FAIL/INCONCLUSIVE verdict, the scenario table, and — on FAIL — a short list of concrete instruction weaknesses observed in the treatment runs (e.g., "skill's Phase 2 was ambiguous about which file to edit, treatment agent picked the wrong one in 2/3 scenarios").

## Safety

- This gate runs subagents that consume tokens; keep scenario prompts short and count (3–5) proportionate to the skill's stakes — do not run this for trivial one-line skill tweaks where the maintenance cost of gating exceeds the risk of a bad skill.
- Do not skip straight to a PASS verdict without actually running both baseline and treatment — a gate that isn't run is not a gate.
- If the calling skill overrides an INCONCLUSIVE/FAIL verdict and finalizes anyway, that override must be logged somewhere durable — append a line (skill name, verdict, reason, date) to `reports/skill-curation-report.md`'s history, not just mentioned in that turn's chat summary. An unlogged override is how a bypass path quietly becomes the default route.
- Scenario sets are authored once at creation time and go stale; `skill-curator`'s weekly Continuous Eval-Gate Drift Check samples live traces to catch failure modes the original scenarios missed and proposes new ones — this gate should not be treated as a one-time checkpoint.

## Related Skills

- `skill-creator` — invokes this gate at Phase 4b before installing a new skill.
- `skill-extraction` — invokes this gate at Phase 5b before finalizing an extracted/augmented skill.
- `better-call` — answers a different question (does a challenger beat an incumbent for overlap); not a substitute for this gate.
- `agent-evaluation` — general agent behavioral testing, not skill-specific with/without comparison.
