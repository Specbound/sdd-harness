---
name: feature-list-primitive
description: >
  Activate when setting up multi-feature agent work, creating task lists for long-running agent
  sessions, or auditing how feature state is being tracked. Enforces machine-readable feature state
  machines with pass-state gating — preventing the "mostly done" ambiguity that causes duplicate
  work and 20+ minute session startup overhead.
source: walkinglabs.github.io/learn-harness-engineering (Lectures 07–08)
---

# Feature List as Harness Primitive

Feature lists are not planning memos — they are harness infrastructure that other components depend
on. Without machine-readable feature state, agents lack shared consensus on what "done" means,
leading to reimplementation and compounding rework across sessions.

**Key insight:** A feature list acts like a database constraint, not a document. Documents can be
ignored; primitives cannot be bypassed.

## When to Activate

- Planning a multi-feature implementation (3+ features, multi-session)
- Setting up a new spec or work breakdown for agent execution
- Diagnosing why features are being reimplemented or partially completed
- Auditing feature tracking in an existing project

## The Triple Structure

Every feature entry requires three mandatory fields:

```json
{
  "id": "F03",
  "behavior": "POST /cart/items returns 201 with item ID in body",
  "verification": "curl -s -X POST http://localhost:3000/cart/items -d '{\"sku\":\"ABC\",\"qty\":1}' | jq '.status == \"created\"'",
  "state": "not_started"
}
```

| Field | Purpose | If Missing |
|---|---|---|
| `behavior` | What the feature does (end-user observable) | Agent uses its own judgment — inconsistent |
| `verification` | Executable command proving the behavior | No objective completion criterion |
| `state` | Current status (machine-readable) | Cannot drive automation |

An entry missing any field is incomplete and unusable by scheduling and verification components.

## State Machine

Four allowed states with strict transition rules:

```
not_started → active → passing
                ↓
            blocked
```

| State | Meaning |
|---|---|
| `not_started` | Not yet begun |
| `active` | Currently being worked on; only ONE feature may be active at a time |
| `blocked` | Stalled pending external resolution |
| `passing` | Verification command executed successfully |

**Pass-state gating (critical):** Only the harness — not the agent — may transition a feature to
`passing`. Transition requires the verification command to actually execute and return a success
exit code. An agent self-declaring "this is done" is not a valid transition.

Once `passing`, a feature does not regress. If the verification breaks later, investigate rather
than rolling back the state.

## WIP=1: One Active Feature at a Time

The default safe configuration is exactly one feature in `active` state. This is not a style
preference — it is a quantified performance finding.

**Mechanism:** Agents have finite context capacity C. With k simultaneous tasks, each receives C/k
reasoning resources. When C/k < minimum threshold for completion, none complete.

**Measured outcome (8-feature REST API):**
- Unconstrained: 5 features activated → 800 lines, 20% end-to-end pass rate → 3/8 complete
- WIP=1: 1 feature at a time → 200 lines, 100% pass rate → 7/8 complete (1 blocked externally)

Enforce WIP=1 in the harness instruction file:
```
Work on one feature at a time. Only start the next feature after current verification passes.
Do not parallelize implementation.
```

## Recommended File Format

For small lists (≤ 10 features), Markdown is sufficient:

```markdown
## Feature List

### F01: User Registration (passing)
**Behavior**: POST /api/register with email+password returns 201 and user ID
**Verification**: `curl -s -X POST http://localhost:3000/api/register -d '{"email":"t@t.com","password":"abc123"}' | jq '.id'`
**Evidence**: commit a3f2c1b

### F02: Login (active)
**Behavior**: POST /api/login with valid credentials returns JWT token
**Verification**: `curl -s -X POST http://localhost:3000/api/login -d '{"email":"t@t.com","password":"abc123"}' | jq '.token | length > 0'`
**Evidence**: —

### F03: Password Reset (not_started)
**Behavior**: POST /api/reset-password sends email and returns 202
**Verification**: `curl -s -X POST http://localhost:3000/api/reset-password -d '{"email":"t@t.com"}' | jq '.status == "queued"'`
**Evidence**: —
```

For larger lists or automated harnesses, JSON:

```json
{
  "features": [
    {
      "id": "F01",
      "behavior": "POST /api/register returns 201 with user ID",
      "verification": "curl -s -X POST .../api/register ... | jq '.id'",
      "state": "passing",
      "evidence": "commit a3f2c1b"
    }
  ]
}
```

## Granularity Rule

Features must be completable in **one session**. Calibrate scope:

| Too broad | Right | Too narrow |
|---|---|---|
| Implement shopping cart | User can add items to cart and see total | Create `qty` field on CartItem model |

Too broad → stalls mid-implementation. Too narrow → overhead explodes. One session = one feature.

## Single Source of Truth

All scope information derives from one feature list. No contradictions allowed between:
- The feature list file
- TODO comments in code
- Conversation history
- Session notes

When contradictions exist, the feature list wins. All other sources are updated to match.

## Verification Discipline

**Behavioral verification, not code quality:**
- ✅ `curl /api/endpoint | jq '.status == 201'` — end-to-end behavioral
- ✅ `pytest tests/test_cart.py::test_add_item -v` — integration test
- ❌ "No syntax errors" — insufficient
- ❌ "Looks fairly complete" — meaningless to successor agents

The verification command must test the stated behavior, not the code's internal quality.

## Dependent Harness Components

Four components read the feature list:

| Component | What it reads |
|---|---|
| **Scheduler** | Selects next `not_started` feature for work |
| **Verifier** | Executes verification command, gates state transitions |
| **Handoff reporter** | Generates session summaries from state distribution |
| **Progress tracker** | F01–F03 passing, F04 active, F05–F10 not_started |

**Quantified impact:** Structured feature tracking vs. memo mode:
- 45% higher feature completion rate
- Zero duplicate implementations
- 60–80% reduction in session startup diagnostic time

## Anti-Patterns

- **"Mostly done"**: No successor agent can act on this. Use `active` + remaining verification steps in notes.
- **Missing verification command**: Agent judgment fills the gap — inconsistent across sessions.
- **Verifying code instead of behavior**: Unit tests that mock dependencies cannot catch integration failures.
- **Self-declaring passing**: Agents submit verification requests; the harness executes and transitions.
- **Free-form progress notes**: Cannot be machine-read by scheduler or verifier.

## Integration

This skill is enforced by:
- `spec-tasks-agent` — enforces triple structure when creating task breakdowns
- `harness-validate-agent` — checks feature list format compliance

Related skills:
- `agent-execution-control` — Plan-Execute-Verify loop; verification gates align with this skill
- `agent-harness-design` — feature lists operate at the 𝒢 (governance) component
