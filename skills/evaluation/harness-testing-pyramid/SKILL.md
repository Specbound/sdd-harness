---
name: evaluation/harness-testing-pyramid
description: Build-time test-authoring pattern for LLM-product code — three layers (deterministic unit tests, replay cases, seeded-determinism scenario tests) plus an AI narrative-quality judge. Distinct from the rest of the evaluation family, which grades production runs after the fact.
source: "chrismdp.com/prompt-evals-are-useless/"
---

# Harness Testing Pyramid

The rest of the `evaluation` family (`micro`, `macro`, `funnel`, `long-trajectory`) grades runs that already happened — production traffic, replayed sessions, A/B outcomes. This sub-skill is about **what to write into the test suite before shipping** a prompt/agent change, so regressions are caught in CI rather than discovered in production grading.

## When to Use

- Designing or auditing the test suite for an LLM-product feature (a prompt, an agent workflow, a tool) — not grading its live output
- A prompt change needs a regression test and "write an eval" feels too heavyweight or too vague
- Existing tests are flaky because they compare against a fixed LLM output string

## Do Not Use When

- You're grading runs that already happened → use `evaluation/micro` or `evaluation/macro` instead
- Deciding whether to ship an A/B test → use `evaluation/funnel`

## The Three Layers

### 1. Deterministic unit tests
Ordinary unit tests for everything that isn't the LLM call itself: input validation, prompt template rendering, tool-call argument construction, output parsing. If it doesn't touch the model, test it exactly like any other code — no judge, no LLM involved.

### 2. Replay cases
Store a real request/response pair from production or a hand-crafted scenario. When a prompt changes, resend the **same stored request** against the new prompt and diff the new response against the old one. This catches unintended behavior drift on real inputs without needing a live model call in CI for every test, and without asserting on exact output text (which breaks on every model update).

- Store: `{input, prior_output, prior_output_reasoning_if_relevant}`
- On prompt change: re-run with new prompt, diff structurally (schema/fields/tool-calls-made), not string-for-string
- Flag for human review when the diff is non-trivial; don't auto-fail on any diff, since some are the intended improvement

### 3. Seeded-determinism scenario tests
For agents/features with any randomness (temperature > 0, sampling, retries with jitter), fix the seed/dice so the *test* is deterministic even though production isn't. This turns "the agent sometimes does X" into a reproducible pass/fail instead of a flaky test that only fails intermittently.

- Fix `temperature=0` (or the framework's seed equivalent) for the scenario test specifically — production can still run with its real settings
- Assert on structural properties (did it call the right tool, did it reach the right end state) rather than exact text

### Layer 4 (orthogonal): AI narrative-quality judge
For the subset of output where quality is genuinely about writing style/tone (not structure), a judge call is appropriate — but scope it narrowly to *narrative quality* specifically, not general correctness. Use `evaluation/micro`'s rubric-design guidance for how to build that judge; this pyramid tells you when you need it (rarely — layers 1-3 should catch most regressions structurally) versus when a deterministic assertion would do.

## Choosing the Layer for a New Test

| Question | Layer |
|---|---|
| Does this touch the model at all? | No → Layer 1 (deterministic unit test) |
| Is there a real production input worth locking in? | Yes → Layer 2 (replay case) |
| Does the feature have any randomness that needs pinning to make a test reproducible? | Yes → Layer 3 (seeded scenario test) |
| Is the thing being checked genuinely about writing style/tone, not structure? | Yes → Layer 4 (narrative judge), scoped narrowly |

## Related Skills

- `evaluation` (router) — production-run grading family this sub-skill complements
- `evaluation/micro` — rubric design and judge construction, reused here for Layer 4
