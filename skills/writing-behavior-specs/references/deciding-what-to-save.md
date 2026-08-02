# Deciding What to Save

Most candidate behaviors should not become a spec. This is a filter, not a template to fill in.

## The three-part test

A candidate belongs in `.claude/behaviors/` only if all three hold:

1. **Recognizable situation class** — a reviewer can point at a trajectory and say "this is one of those" without the author's background context.
2. **Meaningful choice** — the agent could plausibly have acted otherwise, and the two paths matter (not "did it use the right function name").
3. **Provable trajectory evidence** — some observable trace (a tool call, a file diff, an absence of a check, a claim vs. a verified fact) would let a reviewer mark the behavior as occurring or not.

If any leg is missing, it isn't a behavior spec — it's something else:

| Missing leg | What it actually is | Where it belongs instead |
|---|---|---|
| No recognizable situation | A generic virtue ("be careful", "be thorough") | Nowhere — too vague to adjudicate |
| No meaningful choice | Tool syntax or a one-off procedural detail | A skill's own instructions, or nowhere |
| No provable evidence | An internal mental step with no trace | Improve observability first, or drop it |

## Signals that a candidate is worth capturing (this harness's evidence sources)

`behavior-spec-agent` treats these as candidate evidence, ranked by trust:

1. **`type: feedback` memory** (a user correction) — highest trust, auto-qualifies on a single occurrence. A human said "no, do it this way" and explained why; that is the closest thing to ground truth this harness has.
2. **A judge drain repeated ≥2 times** across sessions, mapping to the same conduct class (not just the same skill domain — `skill-augment-agent` already owns that mapping).
3. **A `[revert]`/`[drain]` observation repeated ≥2 times** — the user reverted or reset work after Claude's changes, and the underlying cause recurs.
4. **A `learnings.jsonl` situation/insight pair recurring across ≥2 distinct dates** with the same `applies_when` shape.

Single, non-repeating occurrences (other than human feedback) are not enough — a one-off mistake is noise, not a durable pattern. This mirrors the harness's existing `MIN_FAILS=2` convention in `tool-failure-recall.sh` and the `2/2` scoring gate in `skill-augment-agent`.

## Do not elevate

- **Generic virtues** — "be thorough", "double-check your work". Everything here is meaningless if it's true of every task.
- **Tool syntax** — "use `rg` not `grep`". That's a skill's job, not an answer key.
- **One-off procedures** — a fix specific to one bug, never to recur.
- **A disguised scoring rubric** — if the "behavior" is really just "score 8/10 on this exact task", it's not durable; it's a one-time grading note.

## A named runtime mechanism CAN be a behavior

Exception: if using a specific mechanism (e.g. "the agent MUST render and inspect the deck before returning it") is itself the durable, recurring control point — and a trajectory can prove whether it happened — that's legitimate. Make the reason explicit in the spec body: name the mechanism, then explain why using it (not just any correct-looking result) is what's being adjudicated.

## Preserve existing intent

Before creating a new spec, check `.claude/behaviors/` for one already covering this class. If found:

- **Revision** — the evidence sharpens or corrects existing wording. Preserve the original intent unless the new evidence explicitly contradicts it.
- **Split** — the existing spec has grown to cover two situations with different ownership or adjudication needs.
- **Merge** — two existing specs turn out to describe the same situation class from different angles.

Folder placement is not activation — a spec sitting in `.claude/behaviors/` doesn't get enforced anywhere automatically; it is discovered by whoever/whatever reviews a trajectory later. Do not assume a manifest or index needs updating unless this project has one.
