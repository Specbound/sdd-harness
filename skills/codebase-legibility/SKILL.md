---
name: codebase-legibility
description: "Set up a codebase for optimal Claude Code work: CLAUDE.md hierarchy (root + subdirectory files), .claudeignore for noise exclusion, codebase map markdown, and per-subdirectory command scoping. Run once when onboarding a new repo."
allowed-tools: Read, Bash, Write, Edit, Glob
user-invocable: true
risk: safe
---

# Codebase Legibility

Make a repository easy for Claude Code to navigate by establishing the configuration layer: CLAUDE.md hierarchy, noise exclusion, and structural orientation.

> "Claude's ability to help in a large codebase is bounded by its ability to find the right context."

## When to Use

- Onboarding a new repo to the SDD harness (run after `/kiro:steering`)
- When Claude reads too many irrelevant files in a session
- When tests/builds time out because the wrong suite runs

## Do Not Use

- For memory or session context → use `/kiro:reflect`
- For project architecture docs → use `/kiro:steering`
- To update existing CLAUDE.md content rules → edit directly

---

## Phase 1: Audit Current State

```bash
# List all existing CLAUDE.md files
find . -name "CLAUDE.md" -not -path "*/node_modules/*" -not -path "*/.git/*"

# Check for .claudeignore
ls -la .claudeignore 2>/dev/null || echo "MISSING"

# Top-level structure
ls -la
```

Read any existing CLAUDE.md files found.

---

## Phase 2: Root CLAUDE.md Health Check

The root CLAUDE.md should contain **only**:
- Big-picture context: what the project does (1–2 sentences)
- Critical gotchas: things that would waste Claude's time if unknown
- Entry-point commands: build, test, lint, run
- Pointers to subdirectory CLAUDE.md files and resources

**Strip anything that is:**
- Reusable domain knowledge (→ skills)
- Step-by-step workflows (→ commands/agents)
- Obvious from reading the code
- Already enforced by hooks (redundant instruction)

Propose any trimming needed.

---

## Phase 3: Subdirectory CLAUDE.md Files

For each significant subdirectory (services, modules, packages), create a CLAUDE.md when:
- It has its own tech stack, test runner, or build command
- There are non-obvious patterns a developer wouldn't guess
- It can be worked on independently as a unit

**Template:**
```markdown
# [Subdirectory Name]

## Commands
- `<test command>` — run tests scoped to this directory only
- `<build command>` — build
- `<lint command>` — lint

## Conventions
- [non-obvious pattern]

## Gotchas
- [anything that would waste Claude's time]
```

---

## Phase 4: .claudeignore

Create or update `.claudeignore`. Standard exclusions:

```
# Build outputs
dist/
build/
out/
target/
__pycache__/
*.pyc

# Generated files
*.generated.*
*.gen.*
*_pb2.py
*_pb2_grpc.py

# Dependencies
node_modules/
.venv/
venv/
vendor/

# Test fixtures
__snapshots__/
fixtures/
testdata/

# Binary / media assets
*.png
*.jpg
*.gif
*.mp4
*.pdf
*.zip

# IDE and OS noise
.idea/
.vscode/
.DS_Store

# Harness internals
.gitnexus/
.claude/memory/glacier/
```

Add any project-specific patterns (generated protos, compiled assets, large data files).

---

## Phase 5: Codebase Map

If the repo has more than 6 top-level directories, create `.claude/codebase-map.md`:

```markdown
# Codebase Map

## Top-Level Structure
| Directory | Purpose |
|---|---|
| `src/` | [what's here] |
| `tests/` | [what's here] |
| ... | ... |

## Key Entry Points
- `src/main.py` — [what it does]
- `tests/conftest.py` — test fixtures and setup

## Where to Start
- Feature work → `src/`
- Bug investigation → check `tests/` for failing case first
```

Reference it from root CLAUDE.md:
```
- `.claude/codebase-map.md` — top-level structure (read when unfamiliar with repo layout)
```

---

## Phase 6: Summary

```
## Codebase Legibility Setup Complete

✅ Root CLAUDE.md — [trimmed / updated / no changes needed]
✅ Subdirectory CLAUDE.md — created for: [list] / none needed
✅ .claudeignore — [created / updated with N patterns]
✅ .claude/codebase-map.md — [created / not needed (≤6 dirs)]

Signal-to-noise improvement: [brief assessment of what Claude will now skip]
```
