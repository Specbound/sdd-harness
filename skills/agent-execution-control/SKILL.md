---
name: agent-execution-control
description: >
  Patterns for controlling long-horizon autonomous agent execution: Plan-Execute-Verify loops,
  action validation (gatekeeper), execution trace grounding, and iterative repair.
  Activate when building or debugging agents that run multi-step sequences autonomously,
  implementing feedback loops for code-generating agents, or designing verification pipelines.
  Do NOT activate for standard one-off coding tasks or interactive development.
---

# Agent Execution Control

Autonomous agents running long-horizon tasks need more than good prompts — they need structural control patterns that make failure visible early, route feedback into the right loops, and keep recovery cheap. This skill describes the key patterns from the "Code as Agent Harness" framework.

## When to Activate

Activate when:
- Building agents that run multi-step sequences without a human in the loop at each step
- Implementing feedback loops where code is generated, executed, and revised iteratively
- Debugging agents that succeed early but fail after many steps (execution drift)
- Designing verification pipelines for agent behavior (CI/CD for agents)
- Architecting how an agent interacts with an execution environment (shell, API, test runner)

Do NOT activate for:
- Standard single-step coding tasks
- Interactive sessions where the user can correct at each step
- One-shot operations with no iterative loop

## Core Patterns

### 1. Plan-Execute-Verify Loop

The fundamental control pattern for autonomous execution. Generates a plan, executes steps, verifies outcomes, and uses failures to trigger correction — without requiring human intervention at each step.

```
plan → execute step → verify → [pass: next step | fail: diagnose + repair + retry]
```

**Key implementation principles:**
- Verification uses deterministic signals (tests, assertions, type checks, exit codes) — not model self-assessment
- Failure is a signal, not a terminal state; the loop is designed to encounter and absorb failures
- Verification should be lightweight per step and comprehensive at checkpoints
- The plan is not sacred — if execution reveals the plan is wrong, update the plan

**When verification is a signal vs. a blocker:**
Intermediate failures are *signals* that feed repair, not hard stops. Only block on: invariant violations, safety constraints, or explicitly defined hard gates. Everything else feeds the repair loop.

```python
def plan_execute_verify(plan, executor, verifier, max_retries=3):
    for step in plan.steps:
        for attempt in range(max_retries):
            result = executor.run(step)
            outcome = verifier.check(result, step.expected)
            if outcome.passed:
                break
            elif outcome.is_invariant_violation:
                raise HardStop(outcome.reason)
            else:
                step = repair_step(step, result, outcome.failure_context)
        else:
            plan = replan(plan, step, outcome)
```

**Forced execution beats cross-checking (empirical):** When agents explain a hypothesis *without running code*, they were wrong ~50% of the time — even across multiple independent cross-checking rounds. Forcing the agent to actually execute code to confirm the hypothesis removed most of those errors. Rule: prefer forced execution/verification over independent analyses that merely cross-check each other; doing both is best. In the loop above, this means the `verify` step must *run* the check, not reason about whether it would pass.

### 2. Action-Validation Gatekeeper

The harness filters agent-requested actions before execution. Implements safety and environment constraints programmatically, not through model self-restraint.

**Use for:**
- Actions with irreversible side effects (file deletion, API writes, deployment)
- Actions that cross trust boundaries (shell execution, external services)
- High-frequency automated loops where drift could compound

**Do not use for:**
- Read-only operations
- Actions the model is already constrained to perform correctly by design
- Interactive sessions where the user is present

```python
class ActionGatekeeper:
    def __init__(self, allow_list, deny_patterns, require_confirm):
        self.allow_list = allow_list
        self.deny_patterns = deny_patterns
        self.require_confirm = require_confirm

    def gate(self, action):
        if any(p.matches(action) for p in self.deny_patterns):
            return GateResult.DENY
        if action.type in self.require_confirm:
            return GateResult.CONFIRM_REQUIRED
        if action.type in self.allow_list:
            return GateResult.ALLOW
        return GateResult.DENY  # default deny for unknown actions
```

**Practical design:** Keep the gatekeeper as simple as possible. Complex gatekeepers become bottlenecks and introduce their own failure modes. Prefer narrow, well-defined allow/deny rules over heuristic scoring.

### 3. Execution Trace Grounding

Expose intermediate execution state as feedback signals — not just final outputs. The bottleneck for autonomous repair is usually that the agent only sees "success" or "failure", not *where* and *why*.

**Signals to expose:**
- Variable states at key checkpoints
- Control flow path taken (which branches, which loops)
- Function-level test pass/fail (not just full suite pass/fail)
- Intermediate I/O pairs
- Stack traces with local variable context, not just error messages

**Contrast with naive feedback:**
```python
# Naive: agent sees only final result
result = run_code(code)
feedback = "success" if result.ok else "failed"

# Trace-grounded: agent sees intermediate state
result = run_code_with_tracing(code)
feedback = {
    "final": result.status,
    "failing_assertion": result.first_failed_assert,
    "last_variable_states": result.checkpoint_vars,
    "branch_taken": result.control_flow_summary,
}
```

**Design principle:** More signal granularity reduces repair iterations. But also adds noise. Calibrate: expose enough intermediate state that the repair prompt has actionable context, not so much that it drowns the signal.

### 4. Contract Formation via Planning

Treat planning outputs as executable contracts, not just natural language intentions. The plan describes *expected behavior* the harness can verify.

**What this means in practice:**
- Each plan step should include a verifiable success criterion (an assertion, an expected output, a test)
- Planning is part of the execution loop, not just a prefix to it
- Deviations between plan expectations and execution results are concrete failure signals

```yaml
# Example plan step as contract
- step: "generate authentication middleware"
  produces: "auth/middleware.py"
  success_criteria:
    - file_exists: "auth/middleware.py"
    - tests_pass: ["tests/test_auth.py::test_middleware_*"]
    - no_type_errors: true
  failure_action: "repair with error context, then re-verify"
```

**Key insight:** Natural language plans are ambiguous. Executable contracts are not. The more precisely you can specify success criteria upfront, the cheaper repair becomes.

### 5. Iterative Code-Grounded Repair

When a step fails, include the failure context in the repair prompt. Context-aware repair is dramatically more efficient than cold retry.

**Include in repair context:**
- The original intent (what the step was supposed to do)
- The exact error/failure signal (not paraphrased)
- The code that failed (not a description of it)
- Any execution trace signals available (from §3 above)
- What was already tried if this is a retry

```python
def repair_with_context(failed_step, error_signal, original_intent, attempt_num):
    repair_prompt = f"""
    Original intent: {original_intent}
    Code that failed:
    ```
    {failed_step.code}
    ```
    Error:
    ```
    {error_signal.full_trace}
    ```
    Failing assertion: {error_signal.failing_assertion}
    Variable state at failure: {error_signal.checkpoint_vars}
    Attempt: {attempt_num} of 3
    
    Repair the code to address the specific failure above.
    """
    return generate_repair(repair_prompt)
```

**Skill-memory caching:** If the system has seen similar failures before, retrieve cached repair patterns before attempting generation. Fast recovery > correct recovery on first principles.

### 6. Machine-Checkable Exit Conditions

A single sentence claiming "task complete" is not enough to exit the loop (LMSYS/SGLang). Loop exit must be gated on explicit, machine-checkable conditions — tests pass, a benchmark table is produced, an evidence artifact is written to disk — not on the agent asserting it is done.

- Define the exit gate as a command or file check the harness runs, not a self-report the model emits.
- If the exit condition can't be expressed as something a script could verify, it isn't an exit condition yet — sharpen it before starting the loop.
- Pair with §1: the `verify` step and the exit gate are the same kind of object — a deterministic signal, never model self-assessment.

## Memory Layers in Multi-Agent Context

When applying these patterns in multi-agent systems, recognize the four memory types and where each pattern reads/writes:

| Memory Type | Role | Pattern Usage |
|---|---|---|
| **Working memory** | Current execution state, immediate task context | Execution trace grounding reads/writes here |
| **Semantic memory** | Repository knowledge, environment facts | Contract formation reads here (codebase structure, API specs) |
| **Experiential memory** | Interaction traces, past failures | Iterative repair reads here; execution traces write here |
| **Long-term memory** | Reusable skills, abstracted patterns | Skill-memory caching reads here; successful repairs can write here |

In this harness: working memory ≈ hot-memory.md, long-term ≈ skills/, experiential ≈ observations.md + ERRORS.md, semantic ≈ steering/ docs + specs/.

## Practical Guidance

### Calibrating Control Tightness

Not every agent needs all four patterns. Use this guide:

| Agent Type | Patterns Needed |
|---|---|
| Interactive (human in loop at each step) | None required — human provides feedback |
| Automated with low-stakes outputs | Plan-Execute-Verify + trace grounding |
| Automated with high-stakes/irreversible outputs | All four patterns |
| Long-horizon code generation agent | Plan-as-contract + trace grounding + repair |

### Failure Budget

Set explicit failure budgets per step and per plan:
- Per-step max retries: 2-3 (beyond this, replan rather than retry)
- Per-plan replanning limit: 1-2 (beyond this, surface to human)
- Invariant violations: always hard-stop immediately

### Signals to Monitor

During execution, monitor for these indicators that control is degrading:
- Retry rate per step > 50% → plan quality problem, not execution problem
- Same error repeating across retries → repair context is insufficient
- Steps passing verification but plan goal not achieved → success criteria are wrong
- Repair prompt size growing across retries → trace context needs pruning

## References

Source: "Code as Agent Harness" (Ning et al., 2026) — arXiv:2605.18747

Related skills:
- `multi-agent-patterns` — Architecture patterns for coordinating multiple agents
- `context-degradation` — Managing context quality across long execution runs
- `test-driven-development` — Verification patterns applicable to agent step contracts

---

## Skill Metadata

**Created**: 2026-05-27
**Author**: Extracted from arXiv:2605.18747 "Code as Agent Harness"
**Version**: 1.0.0
