---
name: writing-behavior-specs
description: Authors and revises BEHAVIOR.md specs that capture recurring, judgeable agent conduct for this project. A BEHAVIOR.md is answer-key material for reviewing traces and grading runs — it is kept blind from the agent being evaluated, unlike CLAUDE.md rules or a `<domain>-verify` skill. Invoked automatically by `behavior-spec-agent` during nightly maintenance when a recurring conduct signal is found; not meant to be run on demand.
source: https://github.com/braintrustdata/agentbehavior
risk: safe
---

# Writing Behavior Specs

Write the smallest durable behavior spec that lets a reviewer or judge distinguish acceptable from unacceptable agent conduct across real trajectories.

**Invocation:** This skill is loaded by `behavior-spec-agent` (Step 6b of `/kiro:daily-maintenance`), never invoked directly by the user. It fires when the nightly pipeline finds a recurring conduct signal (a judge drain, a `type: feedback` memory, or a revert/drain observation repeated ≥2 times, or any single human-feedback memory — which auto-qualifies). If you are reading this outside that context, you are reviewing or hand-authoring a spec — the workflow below still applies.

## The core distinction

A behavior spec is **not** a runtime prompt. It is not shown to the agent whose trajectory it will judge. This is the opposite of:

- `CLAUDE.md` / project rules — read by the agent, shape what it does next
- `<domain>-verify` skills (`verification-skill-authoring`) — run by the agent, mid-work, as a self-check

A `BEHAVIOR.md` is read by whoever (or whatever judge) reviews a *completed* trajectory afterward, to decide whether the recorded conduct met the standard — same role as an eval rubric, but durable and shared across every future review instead of reinvented per run.

## Where specs live

```text
.claude/behaviors/
└── <name>/
    ├── BEHAVIOR.md       # Required: YAML frontmatter + behavior description
    └── references/       # Optional: rationale, examples, background
```

(Upstream uses `.agents/behaviors/`; this harness uses `.claude/behaviors/` to match its own dot-directory convention.)

## Decide whether the behavior belongs

Use [deciding-what-to-save.md](references/deciding-what-to-save.md). Prefer a sparse set of high-impact, recurring choices over an inventory of every instruction.

A useful candidate has all three:

- a recognizable class of situations in which it applies
- a meaningful choice about how the agent should act
- evidence in a trajectory that could show whether the choice occurred

Do not elevate generic virtues, tool syntax, one-off procedures, implementation details, or a disguised scoring rubric.

## Choose the unit

A behavior spec is a directory and its `BEHAVIOR.md`; the file may describe one behavior or several related behaviors.

- Group behaviors when they share ownership, discovery, or a behavioral domain and should be reviewed together.
- Split behaviors when they need independent ownership, discovery, reuse, or adjudication.
- Do not group unrelated behaviors merely because the same agent performs them.

Before drafting, answer:

1. When does this behavior apply?
2. What should the agent do or avoid?
3. What trajectory evidence would show it occurred?
4. Why does the distinction matter?

## Write the spec

```markdown
---
name: <name>
description: <what this spec covers and when it applies>
---
```

`name` must match the parent directory. Write for a reader who has the trajectory but not the author's background:

- Name the agent as the subject; use active voice.
- State the trigger and expected conduct directly.
- Describe observable evidence without dictating a particular judge implementation.
- Include the negative boundary — what would count as wrong.
- Prefer one behavioral idea per sentence.
- Use the recommended dimensions when they add clarity, not as mandatory boxes: **Intent, Evidence, Decision, Execution, Recovery, Failure modes.**

Example:

```markdown
## Primary-source tax research

When answering a substantive tax question, the agent may use secondary sources to
orient its research, but it consults relevant primary authority before deciding on
the answer. A correct conclusion reached without consulting relevant primary
authority does not satisfy this behavior.
```

## Calibrate before shipping

Use [calibrating-with-trajectories.md](references/calibrating-with-trajectories.md). At minimum, test the wording against:

- a positive trajectory where the trigger fires and the conduct occurs
- a negative trajectory where the trigger fires and the conduct does not occur
- an outside-scope trajectory where the trigger does not fire
- a lucky-correct negative where the final answer could hide the wrong process

If a real trajectory isn't available for one of these (common for a brand-new candidate), say so explicitly in the spec's `references/` notes rather than inventing one.

## Validate and reconcile

Run the structural validator before finalizing:

```bash
python3 .claude/scripts/validate-behavior-spec.py .claude/behaviors/<name>
```

It checks: `BEHAVIOR.md` exists at the right path, frontmatter has `name`/`description`, and `name` matches the parent directory. It does not and cannot check whether the spec is well-calibrated — that's this skill's job, not the script's.

Then:

1. Re-read the rendered Markdown without the source evidence.
2. Confirm every claim is grounded in cited evidence (an observation, a judge drain, a `type: feedback` memory).
3. Check `.claude/behaviors/` for duplication or contradiction with existing specs.

## Final review

A behavior is ready when a cold reader can answer:

- What recurring situation activates it?
- What meaningful conduct is required or prohibited?
- Where would that conduct be visible in a trajectory?
- Can a correct outcome still violate it?
- Is the rule broad enough to survive beyond the example, but narrow enough to adjudicate?

## Related

- `verification-skill-authoring` — the runtime-visible counterpart; a self-check the agent runs, not an answer key kept from it
- `evaluation/long-trajectory` — Phase 3's Rubric Builder loop calibrates rubrics against production outcomes; a shipped BEHAVIOR.md is a natural durable input to that calibration, not a replacement for it
- `evaluation/micro` — grades outcomes; BEHAVIOR.md grades *process*, deliberately the harder, complementary half
