---
name: agent-permissions-design
description: "Design the authorization layer for AI agents: scope inheritance from authorizing humans, system-of-record as permission authority, pre-execution verification gates, agent identity tracking, and audit co-location. Use when building agents that act on behalf of users, designing agent tool permissions, or reviewing agent authorization in regulated contexts."
source: venturebeat-article (2026-05-29)
risk: low
---

# Agent Permissions Design

Design authorization systems for AI agents that act on behalf of humans — especially in regulated domains (HR, finance, legal, compliance) where "almost right is not acceptable."

## Use this skill when

- Designing which tools an AI agent should be allowed to call, and under what conditions
- Building agents that act on behalf of a specific user or role
- Reviewing an existing agent implementation for authorization gaps
- Deciding whether an action is within scope for an agent in a regulated context
- Architecting multi-agent systems where agents delegate to sub-agents

## Do not use this skill when

- Implementing authentication for a web app or API (use `auth-implementation-patterns`)
- General agent architecture without authorization concerns (use `ai-agents-architect`)
- The agent is sandboxed with no access to live systems or data

## The Five Principles

### 1. Scope Inheritance — Never Exceed the Authorizing Human

An agent's permission scope is a strict subset of the permissions held by the human who authorized it. The agent cannot do anything the human cannot do. This is non-negotiable.

```
agent_scope ⊆ authorizing_user_scope
```

Design implication: resolve the authorizing user's actual permissions at request time, not at agent-configuration time. Permissions change; agents must reflect the current state.

### 2. System-of-Record as Authority

Permissions must live where the data lives — not in a separate governance layer, external config, or agent-side rule set.

> "If your permissions are defined somewhere outside of where the data actually lives, you've already lost." — Dan Obendorfer, Würk

Design implication: the data system (ERP, HRIS, CRM) is the authoritative source of what the agent can touch. Do not replicate permission logic into the agent layer; query the SoR instead.

### 3. Pre-Execution Verification Gate

Before the agent executes any irreversible or high-stakes action, a verification step interrogates the planned action:

- Does this action fall within the agent's resolved scope?
- Does it match the user's stated intent?
- Are the preconditions (record state, business rules) satisfied?

The verification step is a separate model or rules layer — not the same model that planned the action. Self-verification is insufficient for regulated domains.

### 4. Agent Identity Transparency

Every agent action must be attributable to three things:

1. **The agent** — which agent/version took the action
2. **The authorizing human** — on whose behalf it acted
3. **The permission scope** — what access level applied at execution time

Without all three, an audit trail is incomplete. "The agent did it" is not accountability.

### 5. Audit Trail Co-location

Audit logs live in the system of record, not in the agent's own logging infrastructure or an external observability platform.

Design implication: write the audit record to the SoR as part of the action transaction, not as a side-effect afterward. A post-hoc log can be lost; an in-transaction record cannot.

## Design Workflow

### Step 1 — Map the Authorizing Human's Scope

Identify who can authorize this agent and what that person is actually allowed to do in the target system. This becomes the ceiling.

Questions to answer:
- Which roles can invoke this agent?
- What data objects / actions does each role have access to?
- Are permissions dynamic (time-bound, context-dependent)?

### Step 2 — Define the Agent's Scope as a Subset

Determine which subset of the authorizing user's permissions the agent actually needs. Apply least privilege — start with nothing and add only what the workflow requires.

```
Required agent permissions = (workflow steps) ∩ (authorizing user permissions)
```

### Step 3 — Identify the Permission Authority

Decide where permission checks are resolved:

| Option | When appropriate |
|---|---|
| Query the SoR directly at runtime | Regulated domains, permissions change frequently |
| Cache SoR permissions with short TTL | Performance-critical, low-change environments |
| Agent-side permission rules | Sandboxed agents only, never for live system access |

For regulated contexts: always option 1.

### Step 4 — Design Pre-Execution Verification

For each tool the agent can call, classify it:

| Class | Definition | Verification required? |
|---|---|---|
| Read-only | No state change | Light — scope check only |
| Reversible write | Can be undone | Moderate — scope + intent check |
| Irreversible write | Cannot be undone | Strict — scope + intent + precondition check |
| Cross-system | Triggers downstream systems | Strict + human confirmation gate |

For strict-class actions, use a separate verification model or rules engine — not a self-check prompt.

### Step 5 — Plan Agent Identity Tracking

For every action, record to the SoR:

```
{
  agent_id: string,           // which agent + version
  agent_action: string,       // what it did
  authorizing_user_id: string, // on whose behalf
  permission_scope_snapshot: string, // what access applied
  timestamp: ISO8601,
  request_id: string          // ties back to original user intent
}
```

### Step 6 — Audit Trail Co-location Check

Verify that the audit record is written:
- In the same transaction as the action (not async)
- To the SoR, not only to the agent's own logs
- With enough context to reconstruct who authorized what

### Step 7 — Compounding Error Risk Assessment

In regulated domains, permission errors compound across interdependent systems (policy configs, role hierarchies, org structures). Identify:

- Which downstream systems will this agent's actions propagate to?
- What is the blast radius of an over-permissioned action?
- Are there compensating controls (approvals, time delays) before irreversible propagation?

## Anti-Patterns

| Anti-pattern | Risk | Fix |
|---|---|---|
| Permissions defined in agent config, not SoR | Agent ignores real-time permission changes | Move authority to SoR; query at runtime |
| Agent scope = any authenticated user's full scope | One compromised session = full agent access | Scope to minimum required per workflow |
| Self-verification ("did I follow the rules?") | Same model that errs also validates the error | Separate verification model or rules layer |
| Audit logs in observability stack only | Logs lost on infra change; not co-located with data | Write to SoR in-transaction |
| Permission check at agent configuration time | Stale permissions; doesn't reflect role changes | Check at request-execution time |
| Sub-agents inherit parent agent's full scope | Privilege escalation via delegation chain | Each sub-agent re-derives scope from SoR |
| Guard matches the rendered string form of a structured value | Trivially bypassed by re-rendering the same value | Normalize before comparing (see below) |
| "Ask the human" verdict emitted in a headless run | Unanswerable; degrades to a hang or an implicit allow | Degrade `ask` → `deny` when unattended |

## Verdict Computation and Context-Dependence

A permission decision has two halves that are usually conflated: **how the verdict is
computed**, and **what the verdict means where it fires**. Both are load-bearing.

### Normalize before comparing

**Never match a guard rule against the rendered string form of a structured value.**
Shell commands, URLs, IP addresses, and file paths all have many textual renderings of
the same underlying value. A guard that greps the text can always be defeated by
re-rendering — and the bypass looks nothing like an attack, so it will not be noticed.

The canonical illustration: a rule blocking the literal string `169.254.169.254` does
nothing about `curl http://2852039166/`, which is the same address in decimal form.
The same class of bug lived in this harness's own `git-destructive-guard-hook.sh` until
2026-08, where quote-stripping plus `grep -E` was defeated by every one of:

```
F=--force; git push $F        # value arrives via expansion
bash -c 'git push --force'    # hidden inside a quoted wrapper
git push --fo""rce            # token split by empty quotes
cd sub && git push --force    # not the first command in the line
```

**The rule:** parse the input into its structure — argv via a real lexer, URLs via a URL
parser, addresses into their numeric form — then compare fields and tokens *exactly*.
Substring and regex matching over prose or command text is not a security control.
(This harness additionally bans regex-parsing outright; emit or parse structured data.)

**Fail closed on what you cannot resolve.** If a value arrives through an unresolvable
expansion (`$VAR`, `$(...)`), the guard cannot prove it is safe. For a small set of
high-stakes verbs, refuse and ask for the literal value — deliberate over-blocking on a
narrow surface beats a guard that is confidently wrong.

**Grant matching should be tiered.** If approvals are cached or reused, match secret- and
credential-tier grants on *exact* command shape, and cheaper tiers loosely. Otherwise an
approval granted for one command can be replayed by a rewrapped variant that smuggles
something past — approve `curl X`, then reuse it for `cd t && curl X && echo $KEY`.
*(Note: Claude Code exposes no persistent grant store a harness can control, so in this
harness this half is design guidance for systems you build, not a mechanism you can wire.)*

### An `ask` verdict is context-dependent

`allow` / `ask` / `deny` is not a three-valued constant — `ask` only exists where a human
is present to answer. In an unattended run there is nobody to prompt, so `ask` silently
becomes either a hang or an implicit allow, which is the worst of both.

**Rule: `ask` degrades to `deny` under headless execution.** Any guard reachable from a
scheduled or background context needs to know which it is in. In this harness that means
anything invoked via `scripts/orchestration/daily-orchestrator.sh` or `scripts/routines/*`
— those runs have no interactive user, so a guard there must decide, not ask. Evaluate
guards short-circuit and cheapest-deterministic-first, leaving any human prompt last: a
human's attention is the most expensive thing a guard can spend.

## Delegation Ceiling (Checkability × Reversibility)

Step 4's write-class table only asks "can this be undone?" That misses a second axis: **can this even be verified deterministically?** A reversible-but-subjective task (a readability refactor) and an irreversible-but-tested task (a gated schema migration) land in very different risk buckets even though only one axis differs. Cross both axes before picking a rung:

| | Hard to check (subjective, no oracle) | Easy to check (deterministic test/oracle exists) |
|---|---|---|
| **Hard/costly to undo** | **L0 — Agent as assistant.** Sensitive code, no grep-able invariant, big blast radius. Rung ceiling: Investigate/Diagnose only. | **L2 — Agent delegation.** Default ceiling for most dev work: tests gate correctness, a human/hook gates the merge. Rung ceiling: Execute if pre-authorized, else Propose. |
| **Cheap/easy to undo** | **L1 — Human-in-the-loop.** Draft stays unmerged until a human (or LLM-as-judge) verifies taste/judgment. Rung ceiling: Propose/Recommend. | **L3 — Self-driving.** Lint fixes, dep bumps, scheduled scouts. Rung ceiling: Resolve, narrowly scoped. |

Level-up moves — how to raise the ceiling for a task stuck in a low quadrant, instead of leaving it there indefinitely:

- **L0 → smaller pieces:** decompose until sub-tasks fall into checkable or undoable quadrants; keep only the irreducible sensitive core at L0.
- **L1 → proxy for judgment:** add an LLM-as-judge pass (a *separate* verification model — see Principle 3), or replace subjective eval with a scoped, measurable success contract (e.g. "iterate until conversion ≥3%") that turns taste into a check.
- **L2 → guardrails as code:** don't default every irreversible action to a human gate — encode it (dry-run-by-default, scoped credentials, feature-flagged rollout, deny-list hard-blocks). This harness already does this for git/gh: `hooks/claude/agent-behavior-guard.sh` and the destructive-op PreToolUse block hard-fail rather than prompt a human per call.
- **L3 → sharpen the signal:** the bottleneck at this level isn't trust, it's knowing there's real work to do — invest in the thing that tells a scheduled/autonomous agent *when* to act (clear trigger conditions), not further loosening its permissions.

This axis composes with the Ladder of Agency below — checkability narrows which rungs are reachable, reversibility (Step 4) narrows further within that.

## Ladder of Agency (Handling Out-of-Scope Discoveries)

When an agent finds an issue outside its current task scope — a bug, a flaky test, dead code, a missing check — match its response to the lowest rung that resolves the discovery. Escalating without an explicit contract for the *new* action is scope creep: apply Scope Inheritance (Principle 1) to the discovery itself, not just the original task.

1. **Flag** — name the issue, take no action. Default when no scope or authorizing human covers touching it.
2. **Investigate** — read-only research to characterize the issue (root cause, blast radius). No writes.
3. **Execute** — fix it directly, but only if pre-authorized, reversible, and within the already-approved workflow.
4. **Diagnose** — produce a root-cause writeup without a fix, when the fix path is unclear or crosses systems the agent isn't scoped for.
5. **Propose** — draft the fix (patch, PR) but don't apply it. Use when the change is plausible but crosses a scope boundary (new file, new dependency, different subsystem).
6. **Recommend** — surface the issue with a suggested owner and priority, no code. Use when the fix needs domain judgment the agent shouldn't make (architecture, product tradeoff).
7. **Resolve** — fix and merge autonomously. Reserve for narrowly pre-authorized, low-risk, reversible issue classes only (e.g. lint auto-fix) — never the default.

Match the rung to Step 4's action classification: read-only discoveries can Investigate/Diagnose freely; reversible-write discoveries may Execute if in-scope; irreversible or cross-system discoveries should never go past Propose/Recommend without a human decision. Default to the lowest rung that produces a useful signal.

## Reference Architecture (Workday Sana Pattern)

```
User Request
    │
    ▼
[Identity Resolution] ← resolves authorizing user's SoR permissions
    │
    ▼
[Base Reasoning Layer] ← LLM plans the action
    │
    ▼
[Verification Model] ← interrogates planned action before execution
    │           └── rejects if out of scope or preconditions unmet
    ▼
[Execution] ← acts only within resolved permission scope
    │
    ▼
[SoR Audit Write] ← co-located with action, in-transaction
```

## Related Skills

- `auth-implementation-patterns` — web app auth (JWT, OAuth2, RBAC)
- `ai-agents-architect` — general agent architecture; see Permissions & Scope section
- `api-security-best-practices` — API-layer security hardening
- `security-audit` — broad security review
