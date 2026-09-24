---
name: superpowers-lab
description: Use when drafting, testing, or promoting a new Claude skill — a sandbox for taking a skill from rough idea to a dry-run-verified SKILL.md before it's added to the live library. Distinct from using-superpowers, which governs invoking skills that already exist.
source: "https://github.com/obra/superpowers-lab"
risk: unknown
---

# Superpowers Lab

## When to Use

- You have an idea for a new skill and want to shape it before writing the real `SKILL.md`
- A skill you wrote isn't triggering, or triggers on the wrong tasks, and you want to isolate why before rewriting it live
- You're deciding whether a workflow belongs in an existing skill or needs its own — draft both shapes and compare
- Skip this if the skill already exists and works — that's normal use, not lab work

## Workflow

1. **Draft** — write the trigger description and a minimal body (When to Use + one workflow) in a scratch file, not the real skill directory. Don't polish; the goal is a testable shape, not a finished skill.
2. **Classify** — decide Rigid or Adjustable per `using-superpowers`'s taxonomy:
   - **Rigid** (exact steps, order matters, e.g. TDD, a security checklist): the draft should read as a sequence with no "adapt as needed" language.
   - **Adjustable** (principles applied to context, e.g. a design pattern): the draft should name the judgment calls explicitly rather than hiding them.
   Misclassifying is the most common cause of a skill that "feels wrong" once live — a Rigid skill written with hedging language gets silently skipped under pressure; an Adjustable skill written as a rigid checklist gets followed past the point it stops making sense.
3. **Dry-run** — walk through the draft against 2-3 concrete scenarios it should trigger on, and 1-2 it should NOT. If the description's trigger cues don't clearly separate those groups, rewrite the description before touching the body — a good body behind a bad trigger never gets read.
4. **Promote or fold** — once the dry-run holds:
   - **Promote**: move the draft into a real `skills/<name>/SKILL.md`, following this repo's `skill-write.sh` convention if the skill will live in the installed library, not just a scratch file.
   - **Fold**: if the dry-run showed the workflow is just a variant of an existing skill, add a section to that skill instead of creating a new one — a near-duplicate entry costs every future session a listing slot for no new coverage.

## Anti-patterns

- Skipping the dry-run and promoting straight from draft — the failure modes above (wrong trigger cues, wrong Rigid/Adjustable classification) are exactly what step 3 catches before they cost real sessions.
- Drafting a new skill for a one-off task — if you won't reuse the workflow, it doesn't need a skill.
