---
name: agent-memory-consolidation
description: "Detect and prevent consolidation loop drift — the failure mode where iterative LLM rewrites of agent memory degrade quality below no-memory baseline. Covers three failure modes (misgrouping, interference, overfitting) and the episodic-first architecture pattern."
source: "https://dylanzsz.github.io/faulty-memory/"
risk: safe
---

# Agent Memory Consolidation

When an LLM agent rewrites its own experience into textual lessons through repeated consolidation passes, performance degrades non-monotonically: improving initially, then falling *below* the no-memory baseline. This is the consolidation loop problem.

## When to Use This Skill

- Designing agentic memory systems with update/consolidation loops
- Reviewing why a memory-equipped agent performs worse than expected
- Auditing existing memory pipelines for consolidation drift
- Configuring compaction or summarization behavior for long-running agents

## The Three Failure Modes

### 1. Misgrouping
Consolidation pools unrelated episodes together, creating composite lessons that mix incompatible strategies from different problem families. The resulting "lesson" misleads on any specific problem it contains.

**Signal:** A lesson that covers "both X and Y situations" where X and Y require opposite approaches.

### 2. Interference
Abstraction strips away applicability conditions, producing overgeneralized rules that mislead on related but distinct tasks. A lesson valid in 3 of 5 cases becomes destructive in the 2 where it doesn't apply.

**Signal:** Lessons stated as universals without qualifying conditions ("always", "never", "in all cases").

### 3. Overfitting
Narrow input distributions cause memories to encode surface features rather than underlying strategies. The memory works for seen variants but fails on novel-but-close inputs.

**Signal:** Lessons referencing specific identifiers, file names, or surface patterns from past tasks rather than the underlying principle.

## Root Cause: Generative Loop Drift

Each consolidation pass:
1. Reads current memory + new trajectory
2. Generates updated memory (an LLM sample)
3. Writes that sample back as ground truth

Stacking iterations creates a chain: step k is conditioned on k−1, which was conditioned on k−2. Specific facts drop out preferentially because they're highest-surprise tokens. Over many passes, content drifts toward the model's prior — generic, confident-sounding, disconnected from the actual episodes that produced it.

## The Episodic-First Architecture

Empirical finding: **reading only raw episodes matches or beats full auto-consolidation**. Abstract-only memory never beats the no-memory baseline at any checkpoint.

### Principles

1. **Raw episodes are primary evidence, not compression material.** Keep trajectory entries intact; abstraction is optional.
2. **Gate abstraction — don't mandate it.** The agent decides when to generalize; the system does not do it automatically on every update.
3. **Decouple the two stores:**
   - *Episodic buffer* — fast writes, raw trajectories, no LLM rewrite
   - *Schema store* — slow, selective, agent-gated abstraction
4. **Always benchmark episodic-only first.** Measure episodic-only performance as baseline before adding any abstraction. If abstraction doesn't beat it, don't ship it.
5. **Stress-test under scaling.** Evaluate at 8, 32, 64, 128+ examples. Consolidation drift compounds — what looks fine at small scale often collapses at scale.

## Audit Checklist

- [ ] Does each consolidation pass do a full regeneration, or merge into existing structure? (Full regen = high risk)
- [ ] Are lessons qualified with applicability conditions, or stated as universals? (Universals = interference risk)
- [ ] Do any lessons mix multiple distinct problem types? (Mixed = misgrouping risk)
- [ ] Are surface features (file names, entity names) in lessons instead of abstract principles? (Surface = overfitting risk)
- [ ] Has episodic-only baseline been measured and beaten by the abstraction layer?
- [ ] Has the system been tested at 8x and 16x the initial evaluation scale?

## Consolidation Timing Patterns

Two production-shipped patterns for *when* to consolidate:

### Pattern A: Idle-Gate + Two-Phase Merge (Codex)

Consolidation happens in two phases, not one:

1. **Per-session extract** (6hr idle gate): After a session has been idle for 6 hours, extract against a strict schema and write to a local state DB. Do NOT write to the final memory store yet.
2. **Global merge** (under lock): A consolidation sub-agent reads the state DB, merges patches, drops stale entries, and writes the diff to the main store.

Key properties:
- The lock prevents two consolidations racing and diverging
- The idle gate prevents back-to-back sessions from consolidating mid-streak (avoids premature abstraction of incomplete trajectories)
- Bounded: 256 rollouts max, 30-day age pruning, rate-limit aware

**When to use:** Long-running personal memory systems where sessions run in batches with natural gaps.

**Shortcoming:** Back-to-back sessions that never hit the 6hr gate never consolidate. Not suitable when you want consolidation after every session.

### Pattern B: Utilization-Gauge Trigger (Hermes)

Consolidation fires when storage hits a threshold, not on a schedule:

- MEMORY.md and USER.md have §-delimited sections with a utilization gauge
- Consolidation triggers at **80% capacity** — before overflow, not after
- The system prompt holds a frozen snapshot until the next session (to preserve prefix cache) — writes land on disk but the active session keeps the old snapshot

Key properties:
- Capacity-based trigger is self-regulating: low-activity periods coast, high-activity periods consolidate more often
- The frozen-snapshot pattern avoids reloading the system prompt mid-session (prefix cache preservation)

**When to use:** Bounded memory stores where overflow is the primary failure mode and session-to-session stability matters.

**Combined implication:** The right trigger depends on the failure mode you're protecting against — idle-gate protects against premature abstraction; utilization-gauge protects against overflow. A robust system can combine both: idle-gate for temporal correctness, utilization-gauge as a hard ceiling fallback.

## Sleep Cycle Protocol (Harness Integration)

Inspired by Behrouz et al. (2026) — "Language Models Need Sleep". Maps the biological Wake/Sleep paradigm to the harness's automatic memory pipeline.

### Wake Phase (active session)

During any session, struggle signals are tagged automatically:

- **action-capture hook** fires on failed Bash commands (non-zero exit code), infers skill domain, and auto-writes `[seed-target:<domain>]` to `observations.md` — no manual action needed
- These entries accumulate across the session as weak-spot markers

### Sleep Phase (daily runner — Step D)

At nightly maintenance, `skill-augment-agent` runs as the Knowledge Seeding step:

1. **Seed collection**: reads `[seed-target:]` entries + judge drains → builds candidate skill list
2. **Knowledge Seeding**: for each candidate with evidence, drafts minimal skill improvements (anti-patterns, trigger additions, learned patterns)
3. **Dreaming**: generates 1-2 synthetic worked examples per skill gap → writes to `~/.claude/skills/<name>/resources/examples/YYYY-MM-DD-examples.md`
4. **Targeted distillation**: max 3 skills updated per run; every change is evidence-cited; no full-memory rewrites

### Key Properties

- **Episodic-first preserved**: raw `[seed-target:]` observations are primary evidence; the agent does NOT rewrite them
- **Gated distillation**: only skills with actionable, non-redundant evidence get updated — prevents overfitting from noisy signals
- **Automatic, not manual**: the full Wake→Sleep cycle fires via hooks + daily runner without user intervention

### Convention: `[seed-target:]` Observation Format

```
- YYYY-MM-DD [seed-target:<skill-domain>]: command failed (exit N): <command-60-chars>
```

Examples of domain mappings auto-applied by the hook:
- `import|pip|npm` → `dependency-management`
- `docker|kubectl` → `deployment-engineer`
- `git|merge|rebase` → `git-advanced-workflows`
- `python|\.py` → `python-pro`
- *(default)* → `systematic-debugging`

## Relationship to Other Skills

- `agent-memory-discipline` — governs WHAT content to write (transfer test, content categories); this governs HOW the update process corrupts memory over time
- `memory-systems` — covers storage architecture (vector DBs, KGs, temporal stores); this covers write-path quality
- `context-compression` — the `compaction-discipline-hook.sh` "merge not regenerate" rule directly operationalizes episodic-first for Claude's own compaction
