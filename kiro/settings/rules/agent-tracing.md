# Agent Tracing — Invocation Log for Observability

Commands that invoke sub-agents should append a trace entry to the memory trace log. This data feeds the evolve agent for evidence-based harness improvements.

## Trace File

Location: `.claude/memory/trace.log`

## Format

One line per agent invocation:

```
YYYY-MM-DD HH:MM | agent-name | tier | outcome | duration-hint
```

**Fields**:
- `agent-name`: The agent file stem (e.g., `spec-impl`, `validate-design`)
- `tier`: Model tier used (`opus`, `sonnet`, `haiku`)
- `outcome`: `pass`, `fail`, `error`, `no-go`, or `go`
- `duration-hint`: `fast` (<30s), `medium` (30s-2min), `slow` (>2min) — estimated, not measured

## Example

```
2026-03-30 14:22 | spec-impl | sonnet | pass | medium
2026-03-30 14:25 | validate-design | sonnet | no-go | fast
2026-03-30 14:30 | spec-refactor | opus | pass | fast
```

## Rules

- Append only — the trace log is a sequential record
- One entry per agent invocation (not per sub-step within an agent)
- The orchestrating command (not the agent itself) writes the trace entry
- If the trace file exceeds 200 lines, the housekeeping agent archives older entries to `glacier/`

## How Evolve Uses This

The evolve agent reads `trace.log` to:
- Identify agents with high failure rates (candidates for prompt improvement)
- Track tier usage patterns (are expensive agents being over-used?)
- Correlate failures with specific workflow phases
- Measure harness usage frequency over time
