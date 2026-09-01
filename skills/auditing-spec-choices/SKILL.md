---
name: auditing-spec-choices
description: "Audits decisions made where the spec was silent, recording each as sound/unsound/needs-user in specs/<feature>/choices.md with a reversible provisional call so unattended runs never stall."
risk: safe
source: local
---

# Auditing Spec Choices

The harness reviews **artifacts** (`kiro:validate-impl`, `kiro:validate-adversarial`,
`kiro:verify`) and **conduct** (`session-quality`, `.claude/behaviors/`). Neither
catches the failure mode this skill exists for: an implementation that is correct,
tested, and passes every gate — while quietly embedding an architecture the user
never chose.

Those decisions are invisible to a diff review, because a diff shows what was
built and says nothing about the alternatives that were silently discarded. They
are invisible to spec validation, because the spec never mentioned them. They
only exist in the implementer's reasoning, and by default that reasoning is
discarded when the session ends.

This skill reconstructs those decisions and writes them down.

**Hard constraints — the audit's value depends on all three:**

1. **It changes no code.** Ever. It is a read-and-record pass. If it starts
   editing, it stops being an honest record of what happened.
2. **It never blocks.** An unattended run must be able to complete with an open
   ledger. Blocking would make it unusable in exactly the mode it was built for.
3. **It records uncertainty rather than resolving it.** A decision the agent is
   not qualified to make gets written down as needing the user, not guessed at
   and buried.

## Use this skill when

- A `kiro:spec-impl` pass just finished (one pass, one audit — not once at the end)
- Closing out a spec, to consolidate the ledger before the feature is called done
- An unattended or long-running agent loop (`goal-mode`, `kiro:loop`) has produced
  work nobody watched
- You are about to accept a large diff and want to know what it decided, not just
  what it changed

## Do not use this skill when

- Reviewing code correctness, style, or security — that is `kiro:validate-impl`,
  `code-review-excellence`, and `security-review`. This skill is indifferent to
  whether the code is good; it cares whether the *choice* was the user's to make.
- The change had no spec (bugfix, perf work, tooling) — there is no "silent spec"
  to be silent, so there is nothing to audit against
- Mid-implementation. Auditing a half-finished pass produces entries about
  decisions that are still being made.

---

## Workflow

### Phase 1: Gather Evidence

Three sources, in this order. Do not skip the second — delegated work is where
undocumented decisions concentrate, because the subagent had even less spec
context than the parent.

1. **The spec as written** — `specs/<feature>/requirements.md`, `design.md`,
   `tasks.md`. This is the baseline of what *was* specified.
2. **Every subagent report from this pass.** Each delegated agent made its own
   calls and summarized only its conclusions. Read the reports, not just the
   parent's summary of them.
3. **The diff and the session trace** — what actually landed, and the reasoning
   that produced it.

If a source is unavailable (trace compacted away, subagent report lost), say so
in the ledger entry rather than inferring. `Evidence: partial — subagent report
unavailable` is a useful record. A confident entry built on a guess is not.

### Phase 2: Find the Silent Decisions

For each non-trivial choice visible in the diff, ask one question:

> **Did the spec determine this, or did the implementer?**

Three outcomes:

| The spec… | Then… |
|---|---|
| Specified it | Not a ledger entry. Move on. |
| Explicitly delegated it ("implementer's choice") | Not a ledger entry — the freedom was named, which is the spec working correctly. |
| Said nothing | **Ledger entry.** This is the whole target set. |

What counts as non-trivial: anything a competent reviewer might have done
differently and cared about. Data shape and storage location. Error handling
posture. Sync vs async. What happens on the failure path. Naming that leaks into
a public interface. Dependency added. Boundary drawn between modules. What was
deliberately *not* built.

What does not count: formatting, local variable names, the order of independent
statements. A ledger padded with these is a ledger nobody reads.

### Phase 3: Verdict Each Entry

Exactly one of three, and the distinction between the last two is the point:

| Verdict | Meaning | Test |
|---|---|---|
| `sound` | Any reasonable implementer would have chosen this. The spec's silence cost nothing. | Would you defend this choice to the user without hedging? |
| `unsound` | Defensible at the time, but wrong or risky on reflection. Needs rework. | Would you make this choice again knowing what you know now? |
| `needs-user` | Not the agent's call. A real preference, tradeoff, or commitment the user owns. | Is this a question about *what they want*, not about *what is correct*? |

`needs-user` is not "I am unsure." Uncertainty about correctness is `unsound` —
go verify it. `needs-user` is reserved for decisions where being more careful
would not help, because the answer is a preference and the agent does not have
access to it.

**Order the ledger least-confident first.** A user skimming it should hit the
entries that most need their attention before their attention runs out.

### Phase 4: Provisional Calls for `needs-user`

Every `needs-user` entry must record a **reversible provisional call** — what was
actually done in the meantime, and what it would cost to change.

This is what lets an unattended run finish. Without it, an audit that surfaces a
user-owned decision either blocks the run or leaves a hole where the
implementation should be. With it, the run continues on a documented default
that the user can overturn cheaply.

The call must be genuinely reversible. If it is not — a schema migration, a
published interface, an external write — then that fact is the finding:

```
Provisional: NOT REVERSIBLE. <what was done> cannot be undone cheaply because
<reason>. Flag this to the user before the next pass builds on it.
```

Do not manufacture a reversible-sounding call for an irreversible action. That
converts a real warning into false comfort.

### Phase 5: Append to the Ledger

Write to `specs/<feature>/choices.md`. Append; never rewrite prior entries —
the ledger is a record of what was decided when, and editing history destroys
the only thing it is good for.

```markdown
## Pass <N> — <YYYY-MM-DD>

### <short decision label>
- **Verdict:** needs-user
- **Spec said:** nothing about <the dimension>
- **Chose:** <what was actually done>
- **Alternatives:** <what else was viable, and why this one>
- **Provisional:** <the reversible default> — reversible by <specific action>
- **Evidence:** <file:line, subagent report, or "partial — <what was missing>">
```

Keep entries short. Four lines that name the decision beat a paragraph that
narrates the session.

### Phase 6: Read the Ledger as a Signal

The ledger is not only an output — it is feedback on spec quality.

- **Entries clustering on one slice** → that slice was under-specified. Stop
  patching it and reslice it: re-inspect it as its own feature, and if it hides
  multiple unknowns, split it before the next pass.
- **Many `needs-user` entries in one pass** → the spec's decision budget was
  wrong. Route this to the Decision-Budget Gate in `kiro:spec-impl` Phase -1,
  which should have caught it before implementation started.
- **Repeated `unsound` on the same theme** → a missing convention, not a series
  of unrelated mistakes. Propose the convention (`.claude/steering/`, CLAUDE.md)
  rather than fixing each instance.

### Phase 7: Consolidate at Spec Close

Once, when the feature is finished:

1. **Resolve provisionals.** Every `needs-user` entry is either confirmed by the
   user, changed, or explicitly deferred. None may stay silently open.
2. **Drop reverted entries.** A decision whose code no longer exists is noise —
   remove it and note the removal.
3. **Dedupe.** The same decision re-litigated across three passes is one entry
   with the final verdict, not three.
4. **Promote what generalized.** A `sound` decision that will bind future work
   belongs in `.claude/steering/` or the design doc, not buried in a ledger for
   one feature.

Report the closing state plainly: how many entries, how many still open, and
which ones the user still has to answer. If entries remain unresolved, say so —
do not describe the spec as closed.

---

## Anti-patterns

- **Auditing the diff instead of the decisions.** If the output reads like a code
  review, the wrong question was asked. The question is not "is this good?" but
  "who decided this?"
- **Blocking on `needs-user`.** Record the provisional call and continue. An audit
  that halts unattended runs will be turned off.
- **Fixing what you find.** The moment this skill edits code, its record stops
  matching what actually happened. Findings route to the next pass.
- **Everything marked `sound`.** A pass that produced no uncertainty at all is
  more likely a shallow audit than a perfectly specified feature. Re-read the
  subagent reports.
- **Padding.** Variable names and import order are not decisions. A long ledger is
  a worse ledger.
