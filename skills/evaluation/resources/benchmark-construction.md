# Benchmark Construction & Anti-Cheat

Reference material for the `evaluation` family: how to build a trustworthy agent benchmark from real work, grade it without an LLM judge gaming you, evaluate the whole trajectory, and keep an A/B comparison honest. Load when constructing a new benchmark or auditing an existing one for reward hacking.

## Real-PR → Prompt Benchmark Recipe (Databricks)

Turn merged pull requests into agent tasks:

1. **Filter source PRs** — exclude bot / service-account / fully-AI / auto-generated commits; require a high-quality test suite; require self-contained changes (no sprawling cross-cutting diffs).
2. **Extract intent** — read the PR, capture *what it was trying to do*, and strip all solution detail out of the prompt.
3. **Isolate tests** — pull the relevant tests; set the non-test files as the agent's edit target.
4. **Human-review every sample** — no auto-generated benchmark ships unreviewed.
5. **Rewrite tests to allow alternative implementations** — decouple the tests from the original diff so a *different but correct* solution still passes. This is the step that prevents overfitting to one author's approach.

## Execution-Based Grading + Git-History Sealing (Databricks)

- **Grade by running tests, not by LLM judgment of correctness.** Checkpoint the agent's code → patch the original tests back in → run → pass/fail is the grade. An LLM judge is fine for style/qualitative signals but must not be the correctness oracle.
- **Seal the git history.** Cut the working copy off from the repository entirely so the agent cannot recover the reference solution from commit history, branches, or reflog. If the answer is reachable, the benchmark measures retrieval, not capability.

## Trajectory Evaluation (Aparna Dhinakaran)

Agents fail in *sequences*, not single outputs: stuck loops, dropped context, a broken tool call papered over by a plausible-sounding final answer. Grade the **intermediate steps / trajectory**, not just the final artifact.

Caveat: a valid agent can take different paths to the same goal — do not grade against one canonical trajectory. Score for progress, tool-call validity, and absence of loops/context loss, not path-identity. (Pairs with `evaluation/long-trajectory`.)

## Anti-Reward-Hacking Containment (LMSYS SGLang)

Guardrail for benchmarking a candidate vs. a baseline: **do not leave room for benchmark reward hacking.**

- Hold **everything identical** except the change under test — same build path, flags, and wrapper.
- **Interleave A/B runs** rather than running all-A then all-B (guards against drift and warm-cache effects).
- Add **correctness gates**: regression checks plus NaN/Inf / poison-output checks on every run.
- **Invalidate a run** if the system silently changed backend/config so the measured path is no longer the target path — a "win" on the wrong code path is not a win.

**Sources:** Databricks agent-harness benchmark (PR-derived tasks, execution grading, history sealing); Aparna Dhinakaran (trajectory evaluation); LMSYS SGLang (A/B containment).
