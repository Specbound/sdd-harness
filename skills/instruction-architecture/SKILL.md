---
name: instruction-architecture
description: >
  Activate when designing, refactoring, or auditing agent instruction files (AGENTS.md, CLAUDE.md,
  or any harness instruction document). Prevents instruction bloat — the most common harness failure
  mode — by enforcing lean entry-file + topic-document architecture, "lost in the middle"
  countermeasures, and SNR maintenance.
source: walkinglabs.github.io/learn-harness-engineering (Lectures 03–04)
---

# Instruction Architecture

The most common harness failure mode is instruction bloat: a monolithic instruction file that grows
to 600+ lines as each agent mistake triggers adding a new rule. This degrades performance through
context budget exhaustion, the "lost in the middle" effect, and priority signal collapse.

## When to Activate

- Designing a new AGENTS.md, CLAUDE.md, or equivalent entry file
- Auditing an existing instruction file that is >200 lines
- Diagnosing an agent that is ignoring rules or violating constraints
- After any harness refactor that touches instruction files

## Core Architecture: Entry File + Topic Documents

### Entry File (50–200 lines maximum)

The entry file is a **router**, not an encyclopedia. Its job: load fast, orient the agent, point to
topic documents for depth.

Required sections (in order):

```markdown
# [Project Name] — Agent Entry File

## Project Overview
One or two sentences: what the system is and what it does.

## First-Run Commands
- Install: <command>
- Start:   <command>
- Verify:  <command>  ← run after any change

## Hard Constraints (max 15)
Non-negotiable rules that apply to every task:
- NEVER [...]
- ALWAYS [...]
- [...]

## Topic Documents
Load the relevant document for your current task:
- API work    → docs/api/ARCHITECTURE.md
- Database    → docs/db/CONSTRAINTS.md
- Frontend    → docs/frontend/CONVENTIONS.md
- Testing     → docs/testing/STANDARDS.md
```

**Line budget rules:**
- Overview: ≤ 5 lines
- First-run commands: ≤ 10 lines
- Hard constraints: ≤ 15 rules (≈ 30 lines)
- Topic document pointers: ≤ 1 line per topic
- Total: 50–200 lines; treat any excess as a defect

### Topic Documents (50–150 lines each)

One document per concern, co-located with the code it governs:

```
project/
├── AGENTS.md                    ← entry file (router)
├── src/
│   ├── api/
│   │   └── ARCHITECTURE.md      ← API layer decisions
│   ├── db/
│   │   └── CONSTRAINTS.md       ← DB operation rules
│   └── auth/
│       └── PATTERNS.md          ← auth patterns
└── docs/
    └── PROGRESS.md              ← session state
```

Proximity rule: a constraint about API authentication belongs in `src/api/ARCHITECTURE.md`, not in
the root entry file. When the agent reaches API code, it simultaneously reaches the constraint.

## "Lost in the Middle" Countermeasures

Research finding (Liu et al., 2023): LLMs process information at text extremes far better than in
the middle. A critical security constraint at line 300 of a 600-line file has a high probability of
being ignored.

**Placement rules:**
- Hard constraints → top of entry file (≤ 30 lines in)
- Verification commands → immediately after hard constraints
- Historical notes and context → bottom or removed entirely
- Anything in the middle → either move it to top or to a topic document

**Priority signal collapse:** When hard constraints, guidelines, and historical notes appear in the
same format, the agent cannot distinguish non-negotiable requirements from suggestions. Use explicit
tiering:

```markdown
## MUST (non-negotiable)
- NEVER commit secrets or credentials
- ALWAYS run `make verify` before declaring done

## SHOULD (strong default)
- Prefer functional style for pure transformations

## CONTEXT (informational)
- The auth module was refactored in 2026-Q1; the old pattern is deprecated
```

## Signal-to-Noise Ratio (SNR) Audit

SNR = (instructions relevant to the current task) / (total instructions in file)

A healthy entry file has SNR > 0.8 for any task type. Low SNR means the agent is parsing
irrelevant content on every task.

**Audit procedure:**
1. List all instructions in the entry file
2. For each of your 3 most common task types, mark which instructions apply
3. Instructions that apply to <20% of tasks → move to topic documents or remove
4. Instructions that apply to >80% of tasks → keep in entry file

## Instruction Maintenance

Every instruction must carry three fields (inline comment or separate registry):

| Field | Purpose |
|---|---|
| **Source** | Why this rule exists (incident, decision, upstream requirement) |
| **Applicability** | When it applies (which tasks, which files, which scenarios) |
| **Expiry** | Condition under which it can be removed (e.g., "after migrating to v3 API") |

Instructions without a known source accumulate as dead weight. When an expiry condition is met,
remove the rule — deletion requires the same rigor as addition.

**Audit cadence:** Review the entry file every 2 weeks. Remove rules that:
- Reference removed code or deprecated patterns
- Duplicate constraints enforced by linting/tests
- Have been superseded by newer rules
- Have no known source (inherited rules that no one can explain)

## Anti-Patterns

| Anti-pattern | Symptom | Fix |
|---|---|---|
| Reactive rule-addition | File grows after every failure | Add rule to topic document, not entry file |
| Format uniformity | Can't distinguish MUST from SHOULD | Add explicit tiering headers |
| Middle placement | Critical rules at line 200+ | Move to top or topic document |
| No expiry tracking | Rules accumulate without removal | Add expiry field to each instruction |
| Monolithic growth | Entry file >200 lines | Refactor: split into topic documents |

## Worked Example: Refactor Signal

A team had a 600-line AGENTS.md. Security constraint compliance was 60%.

**Refactor:**
- Entry file: reduced to 80 lines (hard constraints + topic document pointers)
- Three topic documents: API (120 lines), security (60 lines), testing (80 lines)

**Outcome:** Success rate 45% → 72%; security compliance 60% → 95%.

Root cause: agents were never reading line 300 of the original file.

## Integration

This skill is enforced by:
- `harness-validate-agent` — checks entry file line count and instruction count
- `evolve-agent` — audits SNR and instruction staleness as harness health dimensions

Related skills:
- `agent-harness-design` — broader harness component framework
- `context-optimization` — managing context budget when instruction files are large
