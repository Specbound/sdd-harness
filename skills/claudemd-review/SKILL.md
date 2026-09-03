---
name: claudemd-review
description: "Bi-weekly audit of the current repo's CLAUDE.md and AGENTS.md files. Identifies stale model-assumption instructions, outdated gotchas, over-constraining rules from pre-Claude-4.x habits, missing capability documentation, AGENTS.md/CLAUDE.md drift, and hardcoded-path staleness. Empirically ablation-tests ambiguous candidates (cost-bounded) before proposing removal. Triggered automatically by session-start hook per repo."
allowed-tools: Read, Bash, Edit, Glob
user-invocable: true
risk: safe
---

# CLAUDE.md Review

Audit all CLAUDE.md files for content that has drifted out of date — especially instructions written for earlier Claude versions that now constrain rather than help.

> "Instructions designed for older models may constrain newer ones."

## When to Use

- Bi-weekly scheduled routine
- After a major Claude model release
- When Claude seems overly cautious or slow in ways that don't match its current capabilities

## Do Not Use

- To audit skills → use `skill-curator`
- To add new instructions → just edit CLAUDE.md directly

---

## Phase 1: Discover All CLAUDE.md and AGENTS.md Files

Find every CLAUDE.md and AGENTS.md in the current repo (root + subdirectories) — AGENTS.md is the open cross-tool standard (Codex, Cursor, Aider, etc.) that sits alongside CLAUDE.md; both need to stay in sync:

```bash
find . \( -name "CLAUDE.md" -o -name "AGENTS.md" \) -not -path "*/node_modules/*" -not -path "*/.git/*"
```

Read each file found.

---

## Phase 2: Stale Pattern Detection

For each CLAUDE.md, check against these staleness signals:

### Model-Assumption Drift (High Priority)

Flag instructions compensating for limitations Claude 4.x no longer has:

| Stale Pattern | Why it's stale |
|---|---|
| "Always re-state the full context because Claude may forget" | Larger context + better retention |
| "Break tasks into very small steps, Claude struggles with multi-step work" | Significantly improved reasoning |
| "Explain your reasoning at every step" | Natural behavior now; redundant |
| "Never attempt more than X files in one session" | Context window is much larger |
| "Re-read the codebase at the start of each task" | Unnecessary with proper CLAUDE.md + .claudeignore |

### Over-Constraining Rules

Flag rules that limit more than intended:
- Blanket "never" rules with obvious legitimate exceptions
- Rules requiring confirmation for routine actions
- Instructions already enforced by hooks (duplicate enforcement = noise)

### Conflicting Instructions

Flag pairs of lines — within one CLAUDE.md, or across CLAUDE.md/skills/system prompt — that pull in opposite directions on the same decision (e.g. "leave documentation as appropriate" vs. "never add comments"). These force the model to arbitrate every time instead of acting directly. Propose which should win, or how to scope them apart.

**Hook-injected context is in scope for this check.** Any hook that emits
`hookSpecificOutput.additionalContext` (`SubagentStart`, `SessionStart`, `UserPromptSubmit`)
is a first-class instruction surface: always resident, and for a subagent it is the *only*
one — CLAUDE.md and `.claude/rules/` never reach a spawned agent. Read those hook bodies in
`hooks/claude/` and include their injected text alongside the CLAUDE.md files when hunting
for conflicts and duplicates.

Two failure modes live here and nowhere else:
- **Duplicate statement.** A rule stated in both CLAUDE.md and an injected hook costs context
  on every spawn and gives you two copies to keep in sync. Ask which surface actually reaches
  the audience that needs it, and delete the other.
- **Unsatisfiable MUST.** A rule naming a tool that currently errors trains the model to
  discount every other MUST. Flag any absolute rule whose tool you cannot verify works.

This does **not** relax the Phase 4 ablation fence — hooks are read as *inputs* here, never
edited by an ablation experiment.

### Outdated Gotchas

Flag gotchas that may no longer be true:
- References to specific library bugs that have since been fixed
- "This API returns X" claims — check if still accurate
- Platform-specific workarounds for resolved issues

### Missing New Capabilities

Flag gaps where Claude 4.x capabilities could be better leveraged:
- No mention of extended thinking for complex reasoning tasks
- No reference to available MCP tools that Claude could use automatically
- No mention of relevant skills available for recurring workflows

### AGENTS.md / CLAUDE.md Drift

If both files exist in the same directory, compare them:
- One is a near-empty stub while the other carries real project conventions → flag for reconciliation (a tool that only reads AGENTS.md — Codex, Cursor, Aider — would see almost nothing)
- Content diverges materially between the two (different rules, contradictory instructions) → flag the specific lines that disagree
- Only one of the pair exists where the repo is known to be used with multiple AI coding tools → flag as a gap, not a blocker

### Hardcoded File-Path Staleness

Flag instructions that name an exact file path to describe a capability or convention (e.g. "see `scripts/foo.sh` for X"). These go stale as the codebase evolves and the file moves, renames, or is deleted. Verify the path still exists; if not, flag as stale and propose either updating the path or rephrasing to describe the capability without pinning a path.

### Unenforced MUST Rules

The Over-Constraining check above runs one direction — it flags prose that
*duplicates* an existing hook. This is the other direction, and it is the one that
actually costs something.

Collect every hard rule in the file (MUST / NEVER / ALWAYS / "on every X"). For each,
find what mechanically enforces it: a hook matcher in `settings.json`, a
`permissions.deny` entry, a lint rule, a test. Then:

| Enforcement | Verdict |
|---|---|
| A hook, permission, or test enforces it | Fine. If the prose adds nothing the mechanism doesn't, it may be redundant — hand it to Over-Constraining. |
| Nothing enforces it | **Flag it.** Propose the concrete artifact: which event, which matcher, which deny rule. |

A hard rule backed only by prose is a hope. It holds while the context is short and
attention is on it, and quietly stops holding under long sessions, compaction, and
subagents — which is exactly when it mattered. This is the check that decides whether
a rule belongs in CLAUDE.md at all: **if it must always hold, it belongs in a hook, a
permission, or a test, and CLAUDE.md should at most point at it.** Prose is for
judgement calls, not invariants.

Do not propose a hook for every MUST reflexively. Some rules are genuinely
unenforceable mechanically (they need semantic judgement about intent), and saying so
explicitly is a valid outcome — but say it, rather than leaving the rule unexamined.

### Three-Axis Leakage

Content that is already enforced or already stated elsewhere costs context on every
session and changes nothing. Check all three axes — the review historically only
checked the first:

1. **Lint leakage** — rules a formatter or linter already enforces (line length,
   quote style, import order, naming). Compare against `ruff.toml`,
   `.eslintrc`/`eslint.config.*`, `pyproject.toml`, `.editorconfig`. The linter wins
   every time: it is deterministic and it runs whether the model remembered or not.
   Empirically the most common of the three — worth checking first.
2. **README / manifest leakage** — setup steps, dependency lists, script names, and
   project descriptions copied from `README.md`, `package.json`, or `pyproject.toml`.
   Point at the source instead of restating it, so there is one copy to keep true.
3. **Skill leakage** — guidance duplicated from a `SKILL.md` body. Skills load on
   invocation; CLAUDE.md loads always. Anything living in both is paid for on every
   session to say what the skill will say anyway when it fires.

Axes 1 and 3 are near-mechanical (compare against config files and skill bodies).
Axis 2 needs judgement about whether a restatement adds project-specific context or
merely repeats.

Keep only what the model **cannot infer** from the repo itself: expensive or
destructive commands, generated files it must not edit, areas it must not touch, and
conventions that genuinely surprise. Everything else it can read from the source —
and reading the source beats reading a summary of the source, which goes stale
silently.

---

## Phase 2b: Empirical Ablation Check (cost-bounded, CLAUDE.md only)

Phase 2 is pattern-matching — a guess. This phase verifies ambiguous candidates by actually testing removal, so a proposal is evidence-backed, not heuristic. **Scope: CLAUDE.md lines only.** Never extend this phase to skills, hooks, or scripts — those have their own gates (`skill-eval-gate`, `skill-curator`).

Only run this on candidates Phase 2 could not confidently classify (skip it entirely for obvious cases — e.g. a gotcha that references a library version that demonstrably no longer exists doesn't need an empirical run, just remove it).

### Cost guardrails (hard limits — do not exceed)

- **Max 3 candidates tested per cycle.** Rank ambiguous candidates by suspected impact; test the top 3, queue the rest.
- **N=2 runs per candidate** (baseline: line removed / treatment: line present) — not 3. Two runs are enough to tell "repeated" (both runs same outcome) from "one-off" (split) per the source ablation methodology; a third run buys no extra signal here and doubles cost for nothing.
- **Model: haiku tier only** for every baseline/treatment subagent (see `model-tiers` skill) — never the primary session model. These are short, targeted checks, not full-quality task completions.
- **Scenario = one short, targeted prompt per candidate**, not a full task replay. Design it to directly elicit the specific behavior the line guards against — e.g. for "always confirm before destructive git ops," the prompt is literally "run git reset --hard on this repo," not an unrelated multi-step feature task.
- **Hard ceiling: 6 subagent calls total per cycle** for this phase (3 candidates × 2 runs). If a cycle would exceed this, stop after the ceiling and queue the remainder — never silently skip; log queued candidates so Phase 6 reports them.

### Per-candidate procedure

1. **Derive the guarded failure** — what specific mistake does this line exist to prevent?
2. **Write one deterministic check** for that failure — grep the transcript/output for a confirmation prompt, an exit code, a specific tool call happening or not happening. Not a subjective quality judgment.
3. **Run baseline and treatment** (N=2 each) per the guardrails above.
4. **Score against the check only** — did the guarded failure reappear, yes/no per run.

### Verdict

| Baseline fails guarded check | Verdict | Action |
|---|---|---|
| 0/2 | Removal confirmed | Propose removal in Phase 4 with evidence |
| 1/2 | Inconclusive | Do not remove — queue for next cycle |
| 2/2 | Line retained | Do not propose removal, even if Phase 2 flagged it as stale-looking |

---

## Phase 3: Score Each File

```
## [repo-name] — [relative path to CLAUDE.md or AGENTS.md]

Freshness: [Fresh / Needs minor update / Needs significant update / Stale]

Stale patterns:
- "[quoted text]" → [recommended change or removal] | Ablation: [Not tested / Removal confirmed / Inconclusive — queued / Retained]

Over-constraining rules:
- "[quoted text]" → [recommended relaxation] | Ablation: [Not tested / Removal confirmed / Inconclusive — queued / Retained]

Missing:
- [gap] → [recommended addition]

AGENTS.md / CLAUDE.md drift: [None / "[quoted divergence]" → recommended reconciliation]

Hardcoded path staleness:
- "[quoted path]" → [exists / stale — path no longer found] → [recommended fix]

Queued for next cycle (ceiling reached):
- "[quoted text]" — not yet tested
```

---

## Phase 4: Propose Changes

For each file with issues, quote the stale text and propose the minimal edit — prefer removal over rewriting. For any candidate that went through Phase 2b, cite its ablation verdict as the justification instead of the pattern-match alone. Never propose removing a candidate that came back "Line retained" or "Inconclusive." Present all proposals together before making any changes.

Wait for user approval.

---

## Phase 5: Apply Approved Changes

Apply edits. Lean files are better than well-organized verbose ones — when in doubt, remove.

---

## Phase 6: Summary & Stamp

```
## CLAUDE.md Review Complete — [date]

| File | Status | Changes |
|---|---|---|
| CLAUDE.md | [Fresh/Updated] | [what changed or "no changes"] |
| AGENTS.md | [Fresh/Updated/Reconciled with CLAUDE.md] | [what changed or "no changes"] |
| [subdir]/CLAUDE.md | [Fresh/Updated] | [what changed or "no changes"] |

Queued for ablation next cycle: [N candidates, or "none"]

Next review: ~2 weeks
```

After printing the summary, stamp the per-repo state file so the session-start hook knows the review ran:

```bash
echo "$(date +%Y-%m-%d)" > .claude/memory/.last-claudemd-review
```
