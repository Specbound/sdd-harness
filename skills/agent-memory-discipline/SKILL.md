---
name: agent-memory-discipline
description: "Govern what belongs in agent memory vs. artifacts. Prevents memory contamination by case-specific facts, ensuring only reusable workflow patterns are stored across runs."
source: "https://developers.openai.com/cookbook/examples/agents_sdk/building_reliable_agents_memory_compaction"
risk: safe
---

# Agent Memory Discipline

Memory contamination is the #1 silent failure mode in long-running agent workflows. When agents store case-specific findings, document citations, or investigation outcomes in memory, those "lessons" become non-transferable and can actively mislead future runs with unrelated tasks.

This skill governs **what should and should not be stored** in agent memory — not storage architecture, but content governance.

## The Three-Layer Responsibility Model

| Layer | Purpose | Examples |
|-------|---------|---------|
| **Context** | Help the agent work *now* | Active conversation, current task state, retrieved docs |
| **Memory** | Help future agents work *better* | Workflow patterns, user preferences, process lessons |
| **Artifacts** | Hold facts people rely on | Output files, memos, citations, case conclusions |

Each layer has distinct scope. Conflating them — especially storing artifact-level facts in memory — is the root failure mode.

## Memory Content Rules

### What TO Store

- Workflow patterns worth replicating ("always check the manifest before scanning files")
- User preferences and collaboration style ("user prefers concise uncertainty over false confidence")
- Process lessons that generalize across tasks ("compact at phase boundaries, not arbitrary turn counts")
- Reusable procedures and heuristics discovered during work

### What NOT to Store

- Case-specific conclusions ("Northwind violated Policy 4.2")
- Document citations or evidence references ("per Exhibit C, line 47...")
- Investigation outcomes or determinations from a specific run
- Entity-specific facts: client names, document titles, data values, findings
- Routine artifacts: monitoring signals that fire on idle runs (e.g., loop-debt repeating on stale anchors in zero-charge windows) — distinguish from true signals before storing. (source: 2026-06-22 friction-enforceable)

## The Transfer Test

Before writing anything to memory, ask:

> "Would this lesson help a **different** future task, or does it only describe **this** task's results?"

If it only describes this task → write it to an artifact or output file, not memory.

## Memory Generation Configuration

When configuring programmatic memory generation, use an explicit prohibition prompt:

```python
Memory(generate=MemoryGenerateConfig(
    extra_prompt="""
    Store ONLY workflow lessons, process patterns, and user preferences.
    NEVER store: case-specific findings, document citations, conclusions,
    investigation determinations, or entity-specific facts from this run.
    Ask: does this lesson apply to future different tasks? If no, skip it.
    """
))
```

## Post-Run Validation

After any long-running task, audit memory for contamination:

1. Scan for proper nouns (client names, document titles, project names from the task)
2. Scan for specific data values (numbers, dates tied to the task)
3. Scan for outcome statements ("X was found to...", "result was...")
4. If found → move to an artifact file, remove from memory

## Memory Body Sub-Types

The system prompt defines 4 memory *types* (user, feedback, project, reference) that determine the file and metadata. Within each type's body, structure content using these sub-types to make retrieval more precise:

| Sub-type | Belongs in | What it captures |
|---|---|---|
| **attributes** | `user` | Role, expertise, context ("senior Go dev, new to React") |
| **people** | `user` | Relationships, team members, stakeholders |
| **preferences** | `feedback` | Behavioral patterns, style choices ("prefers concise over verbose") |
| **rules** | `feedback` | Enforced constraints, "always/never" behaviors |
| **facts** | `project` | Durable project truths that don't change often |
| **events** | `project` | Decisions made, incidents, notable occurrences |
| **skills** | `user` or `project` | Capabilities/expertise learned about user or their systems |

Label sub-types in the body with a bold heading (e.g. `**Preferences:**`, `**Rules:**`) when a memory file contains multiple sub-types.

## Session Attribution

When a memory emerges from a specific task or branch, add an optional `session:` field to the frontmatter:

```markdown
---
name: feedback-test-isolation
description: ...
metadata:
  type: feedback
  session: zora-redis-worker-refactor
---
```

Use the git branch name or a short task descriptor as the session value. This makes future retrieval targeted: "what did I learn *during* the redis-worker work?" Omit `session:` for general/global memories that don't belong to a specific task.

## Citation Schema (Write-Time)

When a memory references a specific file, function, flag, or line of code, structure it as a citation object at write time. This enables JIT validation before the memory is acted on (the pattern shipped by Copilot — the only harness with published A/B evidence).

**Schema:**

```markdown
---
name: <slug>
description: <one-line>
metadata:
  type: <user|feedback|project|reference>
  citation:
    file: src/auth/middleware.py
    line: 47
    symbol: validate_token          # optional — function/flag/class name
    verified_at: 2026-06-07         # date last confirmed correct
  expires_at: 2026-08-07            # optional — 60 days default for code citations
---
```

**When to add citation fields:**
- Memory names a file path → `citation.file`
- Memory names a function, flag, or class → `citation.symbol`
- Memory names a line number → `citation.line`

**Do not add `citation` block for:**
- Preference memories ("prefers concise responses")
- Process/workflow lessons
- User role/background memories

**Validation rule (read-time):** Before recommending anything from a memory with a `citation` block, verify the file exists and the symbol is still present. The CLAUDE.md system instructions already mandate this check — the citation block makes it mechanical.

**Expiry:** Code citations rot fastest. Default 60-day expiry is reasonable; preference memories don't need expiry. If `expires_at` is past, re-verify before acting — don't silently trust.

## Relationship to Other Skills

- `memory-systems` — covers WHERE to store (vectors, graphs, temporal KG); this covers WHAT to store
- `context-compression` — covers HOW to compress; this covers what survives compression into memory
- `agent-memory-systems` — covers memory retrieval patterns; this covers memory content governance
