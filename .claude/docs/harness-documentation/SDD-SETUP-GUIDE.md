# SDD Setup Guide

> This file is managed by the SDD harness (`sdd-harness/docs/`).
> It is the single source of truth — do not edit copies in individual projects.
> _Last synced: 2026-06-01

A complete, self-contained guide to setting up the Spec-Driven Development (SDD)
harness used in this project. Follow these steps to replicate the setup in any
new Python/uv project.

---

## Prerequisites

- **Claude Code CLI** — installed and authenticated (`claude --version`)
- **Node.js** — for npx (`node --version`)
- **uv** — Python package manager (`uv --version`)
- **git** — initialized repo (`git status`)
- **impeccable** _(optional, for auto frontend scan)_ — `npm install -g impeccable`

**Windows users:** The recommended setup is **WSL2** — run everything from a WSL2 terminal and Claude Code will use the Linux environment. If running Claude Code natively on Windows, see the notes in Steps 6 and 8 regarding bash hooks and path differences. See [FIRST-TIME-SETUP.md](FIRST-TIME-SETUP.md) for the platform support summary.

---

## Step 1: Gitignore Configuration

Add to `.gitignore`:

```gitignore
# Claude Code SDD harness — local only
CLAUDE.md
specs/
# All harness docs now live under .claude/ (covered by .claude/ gitignore rule)
scripts/setup-git-hooks.sh
scripts/remap-ccsdd-paths.sh
.claude/settings.json
.claude/.last-harness-check
.claude/hooks/
.claude/steering/
.claude/commands/
.claude/agents/
.claude/kiro/
!.claude/settings.local.json
```

Commit: `git add .gitignore && git commit -m "chore: add SDD harness gitignore entries"`

---

## Step 2: Add ruff

```bash
uv add --dev ruff
git add pyproject.toml uv.lock && git commit -m "chore: add ruff linter to dev dependencies"
```

> This is the **only committed change** in the entire SDD setup.

---

## Step 3: Install cc-sdd

```bash
npx cc-sdd@latest --claude-agent --lang en
```

Generates 12 slash commands in `.claude/commands/kiro/`, 9 subagents in `.claude/agents/kiro/`,
and `.kiro/settings/` with templates and rules.

---

## Step 4: Remap Paths

The remap script moves cc-sdd's default `.kiro/` paths to our preferred locations:
- `.kiro/specs/` → `specs/` (at repo root)
- `.kiro/steering/` → `.claude/steering/`
- `.kiro/settings/` → `.claude/kiro/settings/`

It also patches all path references in command and agent files.

```bash
chmod +x scripts/remap-ccsdd-paths.sh
./scripts/remap-ccsdd-paths.sh
```

The script is idempotent — safe to run multiple times.

---

## Step 5: Create CLAUDE.md

Create `CLAUDE.md` at the repo root. Adapt for your project:

```markdown
# [Project Name]

## Context Resources (read on demand, not upfront)
- `.claude/steering/` — read when you need project architecture, stack, or code structure context
- `.claude/memory/hot-memory.md` — read at session start (current state, priorities)
- `.claude/memory/meta/patterns.md` — read at session start (workflow patterns)
- `.claude/memory/` — read when you need cross-session context or past decisions
- `specs/` — read when working on or near a feature that has a spec
- `.claude/docs/` — read when the user asks how to replicate or explain the SDD setup
- Context Hub MCP tools (`chub_search`, `chub_get`) — available automatically for third-party API docs

## SDD Workflow
1. `/kiro:steering`         — bootstrap/refresh project memory
2. `/kiro:steering-custom`  — add domain-specific steering (auth, DB, API, etc.)
3. `/kiro:idea-refine`      — refine vague ideas into spec-ready briefs (optional)
4. `/kiro:spec-init`        — start a new feature
5. `/kiro:spec-quick`       — fast path (requirements→design→grill→tasks in one command)
6. `/kiro:spec-impl`        — implement from approved spec
7. `/kiro:debug`            — systematic 6-step bug triage
8. `/kiro:simplify`         — behavior-preserving code simplification
9. `/kiro:verify`           — 6-stage verification pipeline
10. `/kiro:ship`            — launch readiness check with rollout planning
11. `/kiro:reflect`         — review session, extract patterns, update memory
12. `/kiro:evolve`          — audit harness rules, propose improvements

## Rules
- Keep context under 40% before moving from planning to implementation
- Always plan before coding — use Plan mode for back-and-forth
- Every feature needs an approved spec in `specs/` before implementation
- Atomic commits per task (one task = one commit, code only)
- Never skip the human review gate between spec phases
- Never commit SDD files — harness is local only
- Read `.claude/memory/hot-memory.md` and `meta/patterns.md` at session start
- Observations are append-only; never edit past entries
- Hot memory stays under 50 lines; patterns under 70 lines
- Each fact lives in ONE file; reference via paths, don't duplicate

## Quality Gates (automated)
- `ruff check`: on every `.py` file write
- `pytest -x --ignore=tests/integration`: after each impl task
- doc sync: on every git commit
- harness guide sync: at end of any session where harness files changed
- memory reflect: after significant sessions (spec completion, major impl)
- memory housekeeping: when observations.md exceeds 50 entries
```

> After creating this file, run `/codebase-legibility` inside Claude Code to complete the setup: subdirectory CLAUDE.md files for services and modules, `.claudeignore` for noise exclusion, and a codebase map if the repo has many top-level directories.

---

## Step 6: Create .claude/settings.json

**Linux / macOS / WSL2:**
```bash
mkdir -p .claude/hooks
```

**Windows (PowerShell — native, no WSL2):**
```powershell
New-Item -ItemType Directory -Force -Path .claude\hooks
```

> **Windows hook paths**: The `command` values in the hooks below use `/bin/bash /path/to/...`. On native Windows, replace `/bin/bash` with the Git Bash path: `"C:/Program Files/Git/bin/bash.exe" /path/to/...`. On WSL2, the Linux paths work as-is.

Create `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_TASK_LIST_ID": "your-project-name"
  },
  "mcpServers": {
    "context-hub": {
      "command": "npx",
      "args": ["-y", "@aisuite/chub-mcp"]
    }
  },
  "permissions": {
    "allow": [
      // Pre-approved ruff lint commands
      "Bash(ruff check:*)",
      "Bash(python -m ruff check <file>)",
      // Edit + Write permissions for doc sync + harness updater subagents (spawned by post-commit hook).
      // Pair a Write(...) rule with every Edit(...) rule so the subagents can create new files, not just edit existing ones.
      "Edit(docs/**)",
      "Write(docs/**)",
      "Edit(specs/**)",
      "Write(specs/**)",
      "Edit(.claude/docs/**)",
      "Write(.claude/docs/**)",
      "Edit(.claude/steering/**)",
      "Write(.claude/steering/**)",
      "Edit(.claude/memory/**)",
      "Write(.claude/memory/**)",
      // Allow Edit/Write on any markdown file so doc-update hooks (doc-sync, harness-updater) proceed without an approval prompt
      "Edit(**/*.md)",
      "Write(**/*.md)",
      // WebFetch for domains Claude needs to access
      "WebFetch(domain:raw.githubusercontent.com)",
      // Skill permissions (add as needed)
      "Skill(kiro:your-skill-name)",
      "Skill(kiro:your-skill-name:*)"
    ],
    "additionalDirectories": [
      // Directories outside the repo root that Claude should have read access to
      "/path/to/.claude/kiro/settings/templates/memory",
      "/path/to/.claude/memory",
      "/path/to/.claude/docs",
      "/path/to/.claude"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$CLAUDE_TOOL_INPUT_path\" | grep -q '\\\\.py$' && uv run ruff check --fix \"$CLAUDE_TOOL_INPUT_path\" 2>/dev/null || true"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/impeccable-detect-hook.sh"
          },
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/hook-added-notify.sh"
          }
        ]
      },
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/lean-ctx-nudge-hook.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [{ "type": "command", "command": "/bin/bash /path/to/.claude/hooks/session-start-hook.sh" }]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/stop-hook.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/memory-discipline-hook.sh"
          },
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/protected-path-hook.sh"
          },
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/skill-validate-hook.sh"
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/gbrain-agent-spawn.sh"
          }
        ]
      },
      {
        "matcher": "mcp__plugin_claude-mem_mcp-search__save_observation",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/gbrain-memory-write.sh"
          }
        ]
      },
      {
        "matcher": "WebFetch|WebSearch",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/gbrain-external-search.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/compaction-discipline-hook.sh"
          }
        ]
      }
    ]
  }
}
```

> Replace `/path/to/` with your repo's absolute path, or let `setup-git-hooks.sh` (Step 8) do it automatically.

---

## Step 7: Create .claude/hooks/stop-hook.sh

Create `.claude/hooks/stop-hook.sh` and make it executable:

```bash
chmod +x .claude/hooks/stop-hook.sh
```

The stop hook runs lightweight checks at the end of every Claude session:

1. **Harness update check** — if the harness has new commits since last install, prints a nudge to run `update.sh`.
2. **Memory health check** — if `.claude/memory/observations.md` has >50 entries, prints a nudge to run `/kiro:housekeeping`.
3. **Agent failure pattern detection** — if `.claude/memory/trace.log` shows 3+ consecutive failures for the same agent, prints a nudge to run `/kiro:evolve` to investigate friction patterns.
4. **Session signal detection** — runs `scripts/detect_reexplanation.py` against the session transcript (Haiku-based LLM). Drain signals append a `[memory-gap]` observation; charge signals (unambiguous approval) append a `[session-charge]` observation. Both at most once per calendar day. When drain signals are found, `scripts/micro_reflect.py` is immediately called to extract durable facts and append them to `hot-memory.md` as `[auto-learn, YYYY-MM-DD]` entries. These are probationary — housekeeping promotes them to `patterns.md` after 7 days if reinforced, or removes them. The detector is skipped when `SDD_HEADLESS=1` (set by `daily-runner.sh`) to prevent recursive spawning.

Doc sync and harness updates are **not** triggered here — they fire from the git post-commit hook (Step 8) instead.

**Design principle**: Doc sync belongs in the git lifecycle, not the Claude session lifecycle. Running `claude --print` background agents on every session stop blocks Claude Code and spawns subprocesses on every message. The post-commit hook fires exactly once per commit, with a clear scope (the changed files in that commit).

See the full script in `.claude/hooks/stop-hook.sh`.

---

## Step 8: Install Git Hooks

**Linux / macOS / WSL2:**
```bash
chmod +x scripts/setup-git-hooks.sh
./scripts/setup-git-hooks.sh
```

**Windows (Git Bash):**
```bash
# Run from Git Bash (not PowerShell or CMD):
./scripts/setup-git-hooks.sh
```
The `chmod +x` is not needed on Windows; Git Bash handles executable bit for shell scripts automatically when called via bash.

This script:
1. Installs `.git/hooks/post-commit` — triggers **both doc sync and harness updater** on every commit
2. Patches `.claude/settings.json` with the repo's absolute path (replacing `/path/to/`)

The post-commit hook:
- **Doc sync** — runs if any non-`.md`, non-`.claude/` files changed; invokes `claude --dangerously-skip-permissions --print` in background to update relevant `.md` files and steering docs.
- **Harness updater** — runs if any `.claude/` files changed (excluding `.claude/memory/` to avoid noise from session writes); invokes `claude --dangerously-skip-permissions --print` in background to update `SDD-SETUP-GUIDE.md`.
- Both agents run in the background (`&`) so they don't block your terminal.
- The `--dangerously-skip-permissions` flag is required: the background agents run non-interactively (no terminal to answer permission prompts), so without it the doc sync would stall on the first `Edit`/`Write` and never apply changes.

The script is idempotent — safe to run multiple times.

---

## Step 9: Add Custom Subagents

Create two custom subagent definitions in `.claude/agents/kiro/`:

### doc-sync.md
Documentation synchronization agent. Reviews `git diff HEAD~1` and updates relevant `.md` files in `specs/` and `.claude/steering/` to prevent documentation drift.

Triggered by: `/kiro:sync-docs` command or the post-commit hook.

### harness-updater.md
Harness documentation maintenance agent. Updates this file (`SDD-SETUP-GUIDE.md`) whenever Claude Code harness files change.

Triggered by: the git post-commit hook when `.claude/` files (excluding `.claude/memory/`) are in the commit.

See the full agent definitions in `.claude/agents/kiro/doc-sync.md` and `.claude/agents/kiro/harness-updater.md`.

---

## Step 10: Bootstrap Steering

In a fresh Claude Code session:

```
/kiro:steering
```

Generates `.claude/steering/product.md`, `tech.md`, `structure.md` from the codebase.

Optionally run `/kiro:steering-custom` for domain-specific steering:
```
/kiro:steering-custom auth
/kiro:steering-custom database
/kiro:steering-custom api-standards
```

---

## Step 11: Generate Usage Guide

The usage guide (`.claude/docs/SDD-USAGE.md`) is a quick-reference for all SDD commands with examples. It should be generated as part of setup so that users (and AI agents replicating the harness) know how to use the workflow immediately.

Copy the usage guide from this project, or generate one by asking Claude:

```
Create .claude/docs/SDD-USAGE.md — a quick-reference listing every /kiro: command,
what it does, and an example invocation. Include a "Typical Workflow" section at the end.
```

This file is read-on-demand (not loaded at session start) and lives under `.claude/docs/` alongside this guide.

---

## Step 12: Bootstrap Memory

The memory system provides persistent cross-session context using a cog-inspired architecture
(temperature-based tiers, progressive condensation, structured observations).

### Directory Structure

```
.claude/memory/
├── hot-memory.md              # <50 lines, read at session start — priorities, active specs, decisions
├── observations.md            # Append-only session log (max 50 entries before archival)
├── action-items.md            # Cross-session TODOs with due dates and priority
├── entities.md                # Project entity registry (services, APIs, databases)
├── meta/
│   ├── self-observations.md   # SDD workflow learnings (what worked, what didn't)
│   └── patterns.md            # Distilled workflow rules (<70 lines, read at session start)
└── glacier/                   # Archive for old observations (YAML frontmatter)
    └── index.md               # Auto-generated catalog
```

### Bootstrap

Run `/kiro:reflect` in any Claude session — it auto-creates `.claude/memory/` from templates
in `.claude/kiro/settings/templates/memory/` if the directory doesn't exist.

Or manually copy templates:

**Linux / macOS / WSL2:**
```bash
mkdir -p .claude/memory/meta .claude/memory/glacier
cp .claude/kiro/settings/templates/memory/*.md .claude/memory/
cp .claude/kiro/settings/templates/memory/meta/*.md .claude/memory/meta/
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path .claude\memory\meta, .claude\memory\glacier
Copy-Item .claude\kiro\settings\templates\memory\*.md .claude\memory\
Copy-Item .claude\kiro\settings\templates\memory\meta\*.md .claude\memory\meta\
```

Then seed `hot-memory.md` and `entities.md` with your project's current state.

### Memory Conventions

Conventions are defined in `.claude/kiro/settings/rules/memory-conventions.md`:

- **Observations**: `- YYYY-MM-DD [tags]: text` (append-only, max 5 per reflect)
- **Tags**: `spec`, `impl`, `design`, `debug`, `decision`, `friction`, `insight`, `pattern`, `enforceable`, `escaped`, `skill-update`
- **Action items**: `- [ ] task | due:YYYY-MM-DD | pri:high/medium/low | added:YYYY-MM-DD`
- **Entities**: 3-line max per entry
- **L0 headers**: Every memory file starts with `<!-- L0: summary (max 80 chars) -->`
- **SSOT**: Each fact lives in ONE file; others reference via paths, never copy
- **Caps**: hot-memory <50 lines, patterns <70 lines, observations <50 entries

### Memory Commands

| Command | When to run | What it does |
|---|---|---|
| `/kiro:reflect` | After significant sessions | Mines git log for observations, promotes patterns, updates hot-memory |
| `/kiro:housekeeping` | When observations >50 or periodically | Archives old observations to glacier, prunes caps, validates formats |
| `/kiro:evolve` | On demand | Audits harness rules against friction patterns, proposes improvements |

---

## Slash Commands

| Command | Purpose |
|---|---|
| `/kiro:steering` | Bootstrap/refresh project memory from codebase |
| `/kiro:steering-custom` | Add domain-specific steering (auth, database, API, etc.) |
| `/kiro:idea-refine "rough idea"` | Refine vague ideas into clear, spec-ready briefs |
| `/kiro:spec-init "description"` | Initialize new feature workspace in `specs/` |
| `/kiro:spec-requirements {feature}` | Generate EARS-format requirements (subagent) |
| `/kiro:spec-design {feature}` | Generate research notes + technical design (subagent) |
| `/kiro:spec-grill {feature}` | Domain grilling session — align terminology, crystallise decisions, update docs and ADRs inline (interactive) |
| `/kiro:spec-tasks {feature} [--sequential]` | Generate P-wave parallel task list (subagent); `--sequential` disables parallel `(P)` markers |
| `/kiro:spec-impl {feature}` | Implement from approved spec via TDD (subagent) |
| `/kiro:spec-quick "description"` | Fast path: requirements→design→grill→tasks in one command (grill skipped with `--auto`) |
| `/kiro:debug "bug description"` | Systematic 6-step bug triage (reproduce→fix→guard) |
| `/kiro:simplify <file-or-feature>` | Behavior-preserving code simplification |
| `/kiro:ship [feature]` | Launch readiness: verification + rollout planning |
| `/kiro:validate-gap {feature}` | Gap analysis: requirements vs. existing code |
| `/kiro:validate-design {feature}` | Design quality review (with remediation plan on NO-GO) |
| `/kiro:validate-impl {feature}` | Implementation vs. spec validation (with remediation) |
| `/kiro:validate-adversarial {feature}` | Three-pass adversarial review with +1/-2 scoring |
| `/kiro:spec-status {feature}` | Show current phase, approvals, and open tasks |
| `/kiro:sync-docs` | Sync docs with ALL code changes (uncommitted + staged + committed) |
| `/kiro:reflect` | Review session, extract observations, update memory (subagent) |
| `/kiro:housekeeping` | Prune memory, archive old observations to glacier (subagent) |
| `/kiro:evolve` | Audit harness rules effectiveness, propose improvements (subagent) |
| `/kiro:harness-fix` | Encode a behavioral prevention rule from a specific mistake |
| `/kiro:harness-validate` | Check structural integrity of harness installation |
| `/kiro:harness-test` | Haiku smoke-test to expose vague prompts |
| `/kiro:guardrails` | Audit/scaffold linter complexity rules for deterministic enforcement |
| `/kiro:ci-scaffold` | Generate CI configuration mirroring the verify pipeline |
| `/kiro:autoresearch-init` | Interactive ML project setup — generates program.md, train.py, prepare.py |
| `/kiro:autoresearch [N]` | Run autonomous ML experiment loop (N iterations or continuous) |
| `/kiro:macro-eval-sweep [days-back] [name-filter]` | Population-scale failure pattern sweep over Raindrop Workshop traces; clusters recurring failures, ranks by impact, writes dated report, posts Workshop annotations |

---

## Subagents

| Agent | Trigger | Purpose |
|---|---|---|
| `@agents-spec-requirements` | `/kiro:spec-requirements` | EARS requirements generation; approval via Proof collaborative review session |
| `@agents-spec-design` | `/kiro:spec-design` | Research + technical design; approval via Proof collaborative review session |
| `@agents-spec-tasks` | `/kiro:spec-tasks` | P-wave task breakdown; approval via Proof collaborative review session |
| `@agents-spec-impl` | `/kiro:spec-impl` | TDD implementation per task |
| `@agents-spec-refactor` | After each impl task (auto, spawned by spec-impl agent) | Post-task self-review: reuse, quality, efficiency, 3-tier security checks + test re-run |
| `@agents-idea-refine` | `/kiro:idea-refine` | Structured ideation: problem framing → divergent/convergent thinking → spec-ready brief |
| `@agents-debug` | `/kiro:debug` or via jira-solve BUG routing | 6-step systematic debugging: reproduce → localize → reduce → fix → guard → verify |
| `@agents-simplify` | `/kiro:simplify` or via spec-refactor complexity findings | Behavior-preserving simplification with Chesterton's Fence principle |
| `@agents-ship` | `/kiro:ship` | Staged rollout planning with decision thresholds and rollback procedures |
| `@agents-validate-gap` | `/kiro:validate-gap` | Requirements vs. code gap analysis |
| `@agents-validate-design` | `/kiro:validate-design` | Design quality review (with remediation) |
| `@agents-validate-impl` | `/kiro:validate-impl` | Implementation validation (with backlink checks) |
| `@agents-validate-adversarial` | `/kiro:validate-adversarial` | Three-pass adversarial review |
| `@agents-validate-production` | After all impl tasks complete (auto, spawned by spec-impl agent) | Production readiness scan: env config, deployment, resilience, observability, data safety, security posture, staging/CI + human attestation checklist |
| `@agents-steering` | `/kiro:steering` | Project memory bootstrap |
| `@agents-steering-custom` | `/kiro:steering-custom` | Domain-specific steering |
| `@agents-doc-sync` | git post-commit hook or `/kiro:sync-docs` | Code→doc drift prevention for committed changes |
| `@agents-harness-updater` | git post-commit hook (when `.claude/` files committed) | Harness→guide sync |
| `@agents-reflect` | `/kiro:reflect` | Session mining → observations, patterns, hot-memory |
| `@agents-housekeeping` | `/kiro:housekeeping` | Memory archival, pruning, format validation |
| `@agents-evolve` | `/kiro:evolve` | Rule audit, friction analysis, trace log analysis, improvement proposals, linter graduation |
| `@agents-guardrails` | `/kiro:guardrails` | Linter complexity rule auditing and scaffolding |
| `@agents-ci-scaffold` | `/kiro:ci-scaffold` | CI configuration generation (GitHub Actions, GitLab CI, Azure Pipelines) |
| `@agents-harness-validate` | `/kiro:harness-validate` | Structural integrity check, component index generation |
| `@agents-autoresearch-init` | `/kiro:autoresearch-init` | Interactive interview → file generation |
| `@agents-autoresearch` | `/kiro:autoresearch` | Autonomous ML experiment loop |

---

## Automated Hooks

| Hook | Trigger | Action |
|---|---|---|
| PostToolUse (lint) | Every `.py` write in Claude | `uv run ruff check --fix {file}` |
| PostToolUse (impeccable) | Every frontend file Write/Edit (`.tsx/.jsx/.css/.vue/.svelte/.html`) | Runs `impeccable detect {file}` and surfaces anti-pattern violations. No-ops silently if CLI not installed. Requires one-time `npm install -g impeccable`. |
| spec-refactor (internal) | After each impl task's SELF-REVIEW step (Step 5) | Spawned by spec-tdd-impl-agent; reviews touched files, fixes issues, re-runs tests |
| PostToolUse (Jira comment) | Every `git push` Bash command | Posts Jira comment with branch/commits/docs summary if a `jira-solve` session is active |
| UserPromptSubmit (Jira capture) | Every user prompt | Captures ticket ID from `/kiro:jira-solve TICKET-ID` prompts, writes to `~/.claude/state/active_jira_ticket` |
| UserPromptSubmit (context priming) | Every user prompt | Injects `.claude/memory/hot-memory.md` contents (wrapped in `--- Active Context ---` markers) so the agent always primes on current state before responding. Fast (<1s); no-ops if hot-memory is missing or empty. Implemented in `.claude/hooks/prompt-hook.sh`. |
| SessionStart (maintenance check) | Every Claude session start | **macOS:** clears `com.apple.macl` xattrs from `.claude/hooks/` (Write/Edit tools set this attribute, blocking subprocess execution of edited hook files). Then two modes: (1) if no local `daily-runner.sh` is installed — checks if today's `[judge]` sentinel is absent from `observations.md` and asks Claude to run `/kiro:daily-maintenance`; (2) if `daily-runner.sh` is installed and stale (>24h or never ran) — fires it in the background via `nohup` silently, without consuming session context. Also checks if the per-repo CLAUDE.md review is >2 weeks stale (`.claude/memory/.last-claudemd-review`) and asks Claude to run `/claudemd-review` if so. |
| Stop (memory health) | Every Claude session end | Nudges `/kiro:housekeeping` if observations >50; nudges `/kiro:evolve` if agent failure patterns detected |
| Stop (session signal detector) | Every Claude session end | Runs `scripts/detect_reexplanation.py` (Haiku LLM); appends `[memory-gap]` observation for drain signals (re-explanation) and `[session-charge]` for charge signals (approval). Each written at most once per day. When drains are found, `scripts/micro_reflect.py` immediately writes `[auto-learn]` facts to `hot-memory.md`. Skipped when `SDD_HEADLESS=1`. |
| PostToolUse (revert detector) | Every git revert/reset/restore Bash call | Immediately appends `[revert]` drain observation to `observations.md` — gives trust-battery Judge concrete evidence. Script: `.claude/hooks/revert-detect-hook.sh`. |
| PostToolUseFailure (tool-failure capture) | Every failing Bash/MCP tool call | Records the failure into a per-repo ledger `.claude/memory/tool-failures.jsonl`, keyed by a normalized command signature so the same failure shape clusters and its `count` climbs. Capture half of the tool-failure-memory loop. Script: `.claude/hooks/tool-failure-capture.sh`; see the `tool-failure-memory` skill. |
| PreToolUse (tool-failure recall) | Every Bash/MCP tool call | Soft advisory (never blocks): if this command shape has failed ≥2× and is still open, injects the failure count, last error, and any recorded remedy so Claude reconsiders before repeating it. Once-per-session-per-signature dedupe + 45-day recency gate. Script: `.claude/hooks/tool-failure-recall.sh`. |
| Windows Task Scheduler + SessionStart (daily maintenance) | Nightly at 18:00 local (Israel); SessionStart catch-up if >24h stale | Runs per-repo `daily-runner.sh` → `/kiro:daily-maintenance` — Judge → Reflect → Housekeeping → Trust Score → Augment Skills. Auto-registered by `install.sh` / `update.sh` (WSL + schtasks.exe). Opt out: `SDD_SKIP_ROUTINE=1` at install time; `schtasks.exe /Delete /TN "SDD Daily Orchestrator"` globally; `rm .claude/scripts/daily-runner.sh` per-repo. See `SDD-USAGE.md` → "Daily Maintenance". |
| PreToolUse (ztk) | Every Bash tool call by any agent | Rewrites matching commands to `ztk run <cmd>`, compressing output before it reaches the LLM (78–90%+ token reduction). Passes through commands without filters unchanged. Global — fires in all sessions and projects. |
| PreToolUse (GitNexus) | Every file Read/Edit by any agent | Enriches file operations with 360° symbol graph context (callers, dependencies, process participation); no-ops gracefully when GitNexus is not installed |
| PreToolUse (memory-discipline) | Every Write/Edit to `*/memory/*.md` or `MEMORY.md` | Gates memory writes with discipline rules — valid content: workflow patterns, user preferences, reusable lessons. Invalid: case-specific facts, citations, investigation outcomes. Claude sees the rules before executing the write and can revise content. Implemented in `.claude/hooks/memory-discipline-hook.sh`. |
| PreToolUse (protected path) | Every Write/Edit to a sensitive path (`.env`, crypto keys, credentials, `.aws/`, `.ssh/`) | Injects a confirmation banner; Claude must pause and ask the user before proceeding. Prevents accidental overwrites of secrets files. Implemented in `.claude/hooks/protected-path-hook.sh`. |
| PreToolUse (skill-validate) | Every Write to `~/.claude/skills/<name>/SKILL.md` | Validates skill frontmatter before writing: `name:` must be kebab-case and match the file path slug; `description:` must exist and be ≥25 chars; warns on vague description starters. Exit 2 hard-blocks on errors. Implemented in `.claude/hooks/skill-validate-hook.sh`. |
| PreCompact (compaction-discipline) | Every context compaction | Injects boundary-timing principle and state-preservation checklist: compact at workflow phase boundaries (not arbitrary turn counts), preserve artifact paths, cited facts, open questions, and decisions. Use anchored iterative summarization. Implemented in `.claude/hooks/compaction-discipline-hook.sh`. |
| PostToolUse (hook-added-notify) | Every Write/Edit that creates a new `.claude/hooks/*.sh` | Injects a reminder to document the new hook in `docs/hooks/README.md` (and the Wiring Reference table) before the session ends. Stays silent if the hook is already documented. Implemented in `.claude/hooks/hook-added-notify.sh`. |
| PostToolUse (lean-ctx nudge) | Every Read of a file ≥16 KB (~4,000 tokens) | Suggests the optimal `ctx_read` mode for the file type (`signatures` for code, `reference` for prose, `aggressive` for unknown); silent for small files and data formats (`.json/.yaml/.toml/.lock`). Implemented in `.claude/hooks/lean-ctx-nudge-hook.sh`. |
| PostToolUse (ccr-routine-added-notify) | Every `CronCreate` tool call | Injects a reminder to document the new CCR routine in `docs/ccr-routines/README.md` (ID, schedule, purpose, output) before the session ends. Implemented in `.claude/hooks/ccr-routine-added-notify.sh`. |
| post-commit (doc sync) | Every `git commit` with non-`.md` source changes | Doc-sync: updates all `.md` files referencing changed code via `claude --dangerously-skip-permissions --print` (background) |
| post-commit (harness updater) | Every `git commit` with `.claude/` changes (excl. memory) | Updates `SDD-SETUP-GUIDE.md` via `claude --dangerously-skip-permissions --print` (background) |

---

## Jira Integration (Optional)

The harness includes an optional hook pair that automatically posts a Jira comment describing what was done every time you push code after a `jira-solve` session.

### How it works

1. **Ticket capture** (`UserPromptSubmit` hook — in `~/.claude/settings.json` globally):
   When you type `/kiro:jira-solve TICKET-ID`, the hook extracts the ticket ID and writes it to `~/.claude/state/active_jira_ticket`. This is a fire-and-forget async hook that never blocks Claude.

2. **Post-push comment** (`PostToolUse Bash` hook — in `.claude/settings.json`):
   After any `git push` command, the hook checks if a Jira session is active. If so, it calls `.claude/scripts/jira_push_comment.py`, which:
   - Reads `origin/main..HEAD` git log and diff stats
   - Finds the most recently modified `.md` in `docs/` mentioning the ticket
   - Assembles a Jira wiki-markup comment (branch, commits, approach, files changed)
   - Posts it via `jira_client.py` and deletes the state file (single-fire)

### Scripts

| Script | Location | Purpose |
|---|---|---|
| `jira_client.py` | `.claude/scripts/jira_client.py` | Stdlib-only Jira REST API client (fetch/comment/search) |
| `jira_capture_ticket.py` | `.claude/scripts/jira_capture_ticket.py` | Reads stdin JSON, extracts ticket ID from prompt, writes state file |
| `jira_push_comment.py` | `.claude/scripts/jira_push_comment.py` | Builds and posts Jira comment from git context + docs |

### Credentials

Create `~/.env.jira` with PAT authentication (Jira Data Center):

```
JIRA_URL=https://your-jira-instance.example.com
JIRA_PAT=your-personal-access-token
```

Or Basic auth (Jira Cloud):

```
JIRA_URL=https://your-jira-instance.example.com
JIRA_USERNAME=your.email@example.com
JIRA_API_TOKEN=your-api-token
```

### Settings.json additions

**`~/.claude/settings.json`** (global — captures ticket on prompt submit):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 /path/to/repo/.claude/scripts/jira_capture_ticket.py 2>/dev/null || true",
            "async": true
          }
        ]
      }
    ]
  }
}
```

**`.claude/settings.json`** (project — posts comment on git push):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.command' | grep -q '^git push' && python3 /path/to/repo/.claude/scripts/jira_push_comment.py /path/to/repo 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

> Replace `/path/to/repo` with the repo's absolute path. Merge with existing `PostToolUse` entries — do not replace the ruff lint hook.

### Usage

```
/kiro:jira-solve ZORAAI-1234     <- Claude captures the ticket ID
... work on the fix ...
git push                          <- hook fires, posts comment to ZORAAI-1234 automatically
```

The state file is deleted after the comment posts, so subsequent pushes won't double-post.

---

## AutoResearch (Optional — ML Experiment Automation)

The harness includes an optional autoresearch subsystem for autonomous ML experimentation, adapted from [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

### What it does

An AI agent iterates on a training script (`train.py`) guided by a research brief (`program.md`). Each iteration: propose hypothesis → edit code → run 5-min experiment → evaluate metric → keep or revert. Overnight, it runs dozens of experiments autonomously.

### Components

| File | Location | Purpose |
|---|---|---|
| `autoresearch-init.md` | `commands/kiro/` | Interactive setup command — asks leading questions, generates project files |
| `autoresearch.md` | `commands/kiro/` | Experiment loop command |
| `autoresearch-init-agent.md` | `agents/kiro/` | Interview agent — 8 questions across 3 phases, then file generation |
| `autoresearch-agent.md` | `agents/kiro/` | Experiment loop agent — modifies `train.py`, runs experiments, evaluates |

### Prerequisites

- `uv` — Python package manager
  - Linux / macOS / WSL2: `curl -LsSf https://astral.sh/uv/install.sh | sh`
  - Windows: `powershell -ExecutionPolicy BypassPolicy -c "irm https://astral.sh/uv/install.ps1 | iex"`
- Python 3.10+
- GPU recommended (CPU works but slower)
- git initialized in the project (for experiment revert via `git checkout`)

### Setup & Usage

```bash
# 1. Interactive setup (generates program.md, train.py, prepare.py)
/kiro:autoresearch-init

# 2. Prepare data (one-time)
uv run prepare.py

# 3. Run the experiment loop
/kiro:autoresearch          # continuous
/kiro:autoresearch 10       # 10 iterations
```

No settings.json changes needed — these are manual-only commands with no hooks.

### CLAUDE.md additions

Add to your project's `CLAUDE.md` if using autoresearch:

```markdown
## AutoResearch
- `/kiro:autoresearch-init`  — interactive setup (generates program.md, train.py, prepare.py)
- `/kiro:autoresearch [N]`   — run experiment loop (N iterations or continuous)
- `program.md` is read-only during experiments
- `prepare.py` is read-only during experiments
- `train.py` is the only file the agent modifies
```

See `docs/autoresearch/README.md` for full details.

---

## GitNexus (Optional — Code Intelligence + Visual Explorer)

The harness includes an optional integration with [GitNexus](https://github.com/abhigyanpatwari/GitNexus) — a zero-server code intelligence engine that builds a knowledge graph from your codebase and exposes it via MCP tools. When present, harness agents gain graph-backed context; when absent, everything works as before.

### What it does

GitNexus indexes your codebase into a knowledge graph (symbols, dependencies, call chains, execution flows) using Tree-sitter AST parsing. It then exposes MCP tools for querying the graph and a Web UI for visual exploration.

Once set up, **everything is automatic** — no extra commands needed in your daily workflow:

1. **PreToolUse context enrichment** — Every file read/edit by any agent is enriched with 360-degree symbol context (callers, dependencies, process participation)
2. **Auto-reindex on commit** — Post-commit hook keeps the knowledge graph fresh after every commit
3. **Impact detection in verify pipeline** — Stage 0 maps git diffs to affected processes with risk scores
4. **Blast radius in spec-impl** — Before TDD, scans all files to be modified for downstream dependents
5. **Call chain tracing in debug** — Localize step queries GitNexus instead of manual grep
6. **Community-seeded skill extraction** — Leiden-detected functional clusters as extraction candidates
7. **Visual exploration** — `/kiro:gitnexus-explore` launches browser-based WebGL graph (the only manual command)

### Components

| File | Location | Purpose |
|---|---|---|
| `gitnexus-setup.md` | `commands/kiro/` | Install, index, configure MCP and editor integration |
| `gitnexus-explore.md` | `commands/kiro/` | Launch Web UI to browse code connections |
| `gitnexus-impact.md` | `commands/kiro/` | Query blast radius for current changes |
| `gitnexus-setup-agent.md` | `agents/kiro/` | Setup agent — handles installation and configuration |

### Prerequisites

- Node.js 18+ (for `npx gitnexus`)
- npm (for global installation)
- Git initialized in the project

### Setup & Usage

```bash
# Option 1: Via Claude Code command (recommended)
/kiro:gitnexus-setup                    # Install, index, configure everything

# Option 2: During harness installation
~/.claude/sdd-harness/install.sh /path/to/project --with-gitnexus

# Option 3: Manual
npm install -g gitnexus
gitnexus analyze                        # index the repo
gitnexus setup                          # configure editor integration
```

### Using the Web UI

```bash
/kiro:gitnexus-explore                  # starts server + opens browser
# Or manually:
gitnexus serve                          # http://localhost:4567
```

The Web UI lets you:
- Browse symbols (functions, classes, methods) in an interactive graph
- Trace call chains from entry points through dependencies
- Inspect process flows and which symbols participate
- View Leiden-detected community clusters (color-coded)
- Explore incoming/outgoing relationships with confidence scores

### Using impact analysis

```bash
/kiro:gitnexus-impact                   # analyze uncommitted changes
/kiro:gitnexus-impact --from HEAD~3     # analyze last 3 commits
```

### What's automatic after setup

Once GitNexus is set up, you don't need to run any extra commands. The following happen automatically:

| What | When | How |
|---|---|---|
| **Context enrichment** | Every file read/edit | PreToolUse hook injects callers, dependencies, processes |
| **Reindex** | Every git commit | Post-commit hook runs `gitnexus analyze --skip-embeddings` |
| **Impact detection** | Every `/kiro:verify` | Stage 0 maps diff to affected processes |
| **Blast radius scan** | Every `/kiro:spec-impl` | Scans files-to-modify for downstream dependents |
| **Call chain tracing** | Every `/kiro:debug` | Localize step queries GitNexus for call chains |
| **Community seeding** | Every `/kiro:skill-extract-scan` | Leiden clusters as extraction candidates |

All enhancements degrade gracefully — if GitNexus is removed, agents fall back to grep/glob.

### CLAUDE.md additions

Add to your project's `CLAUDE.md` if using GitNexus:

```markdown
## GitNexus
- `/kiro:gitnexus-setup`     — one-time setup (install, index, configure MCP)
- `/kiro:gitnexus-explore`   — launch Web UI to browse code connections
- `/kiro:gitnexus-impact`    — query blast radius for current changes
- `.gitnexus/` is gitignored and regenerable via `gitnexus analyze`
```

See `docs/gitnexus/README.md` for full details.

---

## Raindrop Workshop (Automatic — AI-Agent Tracing)

The harness integrates [Raindrop Workshop](https://raindrop.sh) — a local AI-agent debugger that captures every LLM call, tool invocation, and latency trace from your agents. All registered repos are auto-instrumented. Traces are free; the self-healing eval loop is user-triggered and costs tokens.

### What it does

Three integration layers:

1. **Workshop tab in the harness dashboard** — per-repo trace viewer, start/stop Workshop, trigger the eval loop
2. **Auto-instrumentation** — entry points in all registered repos emit traces with `event=repo-name` for per-repo filtering
3. **Self-healing eval loop** — reads traces → writes pytest assertions → runs → auto-fixes (max 3 cycles)

### Setup (automatic after CLI install)

`install.sh` and `update.sh` call `scripts/raindrop-setup.sh` automatically. That script:
- Adds `RAINDROP_LOCAL_DEBUGGER=http://localhost:5899` to `~/.claude/settings.json` and `~/.bashrc` — **no repo `.env` files are touched**
- Installs `raindrop-ai` in each registered repo's detected virtualenv (`.venv/`, `venv/`, or `uv`-managed)

The only manual step is installing the CLI binary (once, globally):

```bash
curl -fsSL https://raindrop.sh/install | bash
source ~/.bashrc
```

### Using the Workshop tab

```bash
# Start the harness dashboard
python3 ~/.claude/sdd-harness/scripts/dashboard.py

# In the browser: click Workshop → select repo → Start raindrop workshop
# Traces appear in real-time as agents run
# Click "Run Eval Loop" to trigger the self-healing cycle
```

### Instrumented repos

| Repo | Entry point | `event=` label |
|---|---|---|
| `aiq-zora-ai-engine` | `AgentPipelineGraph.process()` | `aiq-zora-ai-engine` |
| `aiq-zora-agent-skills` | `DailyNewsHandler.handle()` | `aiq-zora-agent-skills` |
| `aiq-purina-salesorderintelligence-poc` | `event_generator()` in `query_portal.py` | `aiq-purina-salesorderintelligence-poc` |

All instrumentation uses graceful fallback — if `raindrop-ai` is not installed, the code is a silent no-op.

### Adding a new repo

```bash
# Install harness into the new repo (wires raindrop automatically)
~/.claude/sdd-harness/install.sh /path/to/new-repo

# Or instrument an existing registered repo
/raindrop-instrument-agent
```

### CLAUDE.md additions

Add to your project's `CLAUDE.md` if using Raindrop Workshop:

```markdown
## Raindrop Workshop
- Traces fire automatically when agents run (free)
- View in harness dashboard → Workshop tab
- `event=repo-name` for per-repo filtering
- Run eval loop from dashboard (costs tokens — always manual)
```

See `docs/raindrop/README.md` for full details, instrumentation patterns, and troubleshooting.

---

## Impeccable (Optional — Frontend Design Quality)

The harness integrates [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (25.6k ⭐) — a design quality system that catches the visual and functional flaws AI coding assistants routinely produce. Provides 27 deterministic anti-pattern rules + 12 LLM critique rules across 7 domains: typography, color, spatial design, motion, interaction, responsive, and UX writing.

### What it does

Three integration layers, each independent:

1. **`impeccable-audit` skill** (`~/.claude/skills/impeccable-audit/SKILL.md`) — On-demand 7-domain visual audit with PASS / NEEDS WORK / BLOCK verdict. Invoke as `/impeccable-audit` or with a focus area (`/impeccable-audit focus: motion`)
2. **`frontend-anti-patterns.md` rule** (`kiro/settings/rules/frontend-anti-patterns.md`) — Deterministic enforcement rules (AP-01 through UW-03) referenced by `/kiro:validate-design` and the adversarial agent when reviewing UI components
3. **`impeccable-detect-hook.sh`** (`.claude/hooks/impeccable-detect-hook.sh`) — PostToolUse hook that auto-scans frontend files on every Write/Edit and surfaces violations inline

### Prerequisites

```bash
npm install -g impeccable   # one-time; hook exits silently if not installed
```

Verify: `impeccable --version`

### Setup

The hook is already wired into `.claude/settings.json` via the PostToolUse entry above (Step 6). The skill and rules file are included in the harness and copied to every project by `update.sh`.

No `install.sh` or `setup-git-hooks.sh` changes are needed.

### Key anti-patterns flagged

| Code pattern | Rule ID | Problem |
|---|---|---|
| `background-clip: text` | AP-01 | Gradient text — AI fingerprint |
| `backdrop-filter: blur()` | AP-02 | Glassmorphism — dated, accessibility issues |
| `border-left: Npx solid accent` | AP-03 | Colored left border — AI fingerprint |
| `linear-gradient()` on hero/card bg | AP-04 | Gradient background — AI fingerprint |
| Card nested inside card | AP-05 | Spatial hierarchy collapse |
| 3-col identical card grid | AP-06 | Zero design intention |
| `background: #ffffff` | AP-07 | Pure white — use warm off-white |
| `ease-in` / `ease-out` | MO-01 | Stale easing — use `cubic-bezier` |
| No `:focus-visible` | IA-01 | Accessibility failure — BLOCK |
| Contrast < 4.5:1 | CO-01 | WCAG AA failure — BLOCK |

### CLAUDE.md additions

Add to your project's `CLAUDE.md` Quality Gates section:

```markdown
- impeccable detect: auto-runs on every frontend file write (requires `npm install -g impeccable`)
- `/impeccable-audit`: on-demand visual quality audit with PASS/NEEDS WORK/BLOCK verdict
```

### Transferring to a new repo

`install.sh` and `update.sh` propagate **every** hook in the harness's `hooks/` directory to each project's `.claude/hooks/` unconditionally — including `impeccable-detect-hook.sh` — and sync `kiro/settings/rules/frontend-anti-patterns.md` and `docs/` automatically. The skill lives at `~/.claude/skills/impeccable-audit/` (global, not per-project). No manual copy step is needed:

```bash
~/.claude/sdd-harness/update.sh        # re-syncs hooks + rules + docs to every registered repo
# or, for a brand-new repo:
~/.claude/sdd-harness/install.sh /path/to/project
```

The PostToolUse wiring ships in `templates/settings.json.template` and is installed automatically (see Step 6 above for the equivalent manual entry).

See `docs/design/impeccable/impeccable.md` for the full rule set and workflow placement.

---

## ztk (Automatic — Token Compression)

The harness includes a global integration with [ztk](https://github.com/codejunkie99/ztk) — a 346KB single-binary CLI proxy that intercepts Bash command output and compresses it before it enters the LLM context window. Claims 78–90%+ token reduction on typical development commands.

### What it does

A `PreToolUse` hook in `~/.claude/settings.json` intercepts every Bash tool call. If ztk has a filter for the command, it rewrites `git diff` to `ztk run git diff`, captures the output, compresses it, and returns the compressed version. Everything is automatic — no commands to invoke, no per-project setup.

**Filters cover:** git (diff/status/log/add/commit/push), pytest/cargo test/go test/npm test/jest/vitest/playwright, ls/cat/find/grep/rg/wc/head/tail/tree, cargo build/check/clippy, tsc, eslint/ruff/mypy, docker, kubectl, curl, gh, jq, python3, and 25+ regex-based patterns (make, terraform, helm, brew, pip, gradle, aws, and more).

### Installation

**Windows (native):** ztk has no Windows binary. Use WSL2 to get token compression — install WSL2 and follow the Linux instructions below from inside it.

**macOS** — use Homebrew (see Step 1 in [FIRST-TIME-SETUP.md](FIRST-TIME-SETUP.md)).

**Linux / WSL2 — build from source** (no prebuilt binary):

No prebuilt Linux binary is distributed. Build from source with Zig 0.16+:

```bash
# 1. Download Zig 0.16.0
curl -fL "https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz" -o /tmp/zig.tar.xz
tar -xf /tmp/zig.tar.xz -C /tmp/

# 2. Clone ztk
git clone https://github.com/codejunkie99/ztk /tmp/ztk-src
cd /tmp/ztk-src
```

Apply two required patches before building:

**Patch 1** — `src/proxy.zig`: Remove the `permissions.checkCommand` block (lines ~13–26). This check calls `isSuspicious()` which blocks any command with embedded newlines — including all multiline `python3 -c "..."` scripts.

**Patch 2** — `src/hooks/claude_rewrite.zig`: Change `"permissionDecision\":\"ask\""` to `"permissionDecision\":\"allow\""` in `emitRewrite()`. Without this, Claude Code pops a permission dialog for every rewritten command.

```bash
# 3. Build and install
/tmp/zig-x86_64-linux-0.16.0/zig build -Doptimize=ReleaseSmall
mkdir -p ~/.local/bin
cp zig-out/bin/ztk ~/.local/bin/ztk
chmod +x ~/.local/bin/ztk

# 4. Wire the global PreToolUse hook
ztk init -g
```

The hook is written to `~/.claude/settings.json` once. All projects and sessions inherit it automatically.

### macOS (Homebrew)

```bash
brew install codejunkie99/ztk/ztk
ztk init -g
```

Note: the `permissionDecision: "ask"` patch is still needed for truly transparent operation. Either build from source or accept confirmation dialogs on rewrites.

### Verifying it works

```bash
ztk stats                                    # cumulative savings
tail -20 ~/.local/share/ztk/hook-debug.log   # live hook activity
```

The debug log shows `rewrite` for intercepted commands and `passthrough` for commands without filters.

### CLAUDE.md additions

No CLAUDE.md changes needed — ztk is fully automatic and global.

See `docs/ztk/README.md` for full details, patch instructions, and troubleshooting.

---

## Context Hub (Automatic API Documentation)

The harness includes [Context Hub](https://github.com/andrewyng/context-hub) as an MCP server. It provides a curated registry of LLM-optimized documentation for third-party libraries and APIs (OpenAI, Stripe, Anthropic, etc.) so agents use accurate, up-to-date API signatures instead of hallucinating from training data.

### How it works

Context Hub runs as an MCP server (`chub-mcp`) configured in `.claude/settings.json`. It exposes tools that Claude Code can call automatically when needed:

| MCP Tool | Purpose |
|---|---|
| `chub_search` | Search docs/skills by keyword |
| `chub_get` | Fetch doc content by ID (with language/version selection) |
| `chub_list` | List all available documentation entries |
| `chub_annotate` | Read/write persistent annotations on docs |
| `chub_feedback` | Rate doc quality to inform maintainers |

**No manual invocation needed.** Claude Code sees these tools automatically and calls them when it encounters unfamiliar APIs or needs accurate documentation for code generation.

### Prerequisites

- **Node.js** — for npx (already required by the harness)

The MCP server is configured in Step 6 (`settings.json`). No additional installation steps required — `npx -y @aisuite/chub-mcp` downloads and runs the server on demand.

### CLAUDE.md additions

Add to your project's `CLAUDE.md` Context Resources section:

```markdown
- Context Hub MCP tools (`chub_search`, `chub_get`) — available automatically for third-party API docs
```

---

## Detailed Documentation

Each harness subsystem has a detailed reference doc:

| Subsystem | Location | Contents |
|---|---|---|
| Kiro (SDD engine) | `docs/kiro/README.md` | All commands, agents, rules, templates, workflows |
| Cog Memory | `docs/memory/README.md` | Tier architecture, file formats, conventions, data flow |
| Jira Integration | `docs/jira/README.md` | Hook architecture, scripts, credentials, troubleshooting |
| AutoResearch | `docs/autoresearch/README.md` | Interview protocol, loop mechanics, agent behavior |
| Trust Battery | `docs/trust-battery/README.md` | Nightly Judge/Reflector loop, rubric, scoreboard, `auto-score` session success ratio (uncorrected sessions earn passive positive credit, read from `.claude/memory/.session-history`), opt-out, non-goals |
| ztk | `docs/ztk/README.md` | Token compression proxy — filter coverage, patch details, session memory, upgrading |
| Context Hub | [github.com/andrewyng/context-hub](https://github.com/andrewyng/context-hub) | MCP server for third-party API docs (external) |
| Design Quality | `docs/design/README.md` | Visual design quality integrations index |
| Impeccable | `docs/design/impeccable/impeccable.md` | 27 anti-pattern rules, skill usage, hook setup, transfer instructions |
| Raindrop Workshop | `docs/raindrop/README.md` | AI-agent tracing — instrumented repos, eval loop, dashboard tab, troubleshooting |

---

## Troubleshooting: Doc-Sync Hooks That Block Claude Code

**Symptom**: Claude Code UI freezes or shows a new session spawned after every message. Session list floods with background agents.

**Root causes**:
1. A Stop hook calls `claude --print` — Stop fires on *every message completion*, not just true session end
2. The Stop hook uses `git diff HEAD~1` as a condition — this always returns output (even on a clean tree), so the condition always passes
3. The Stop hook watches `.claude/memory/` for changes — memory files are written every session

**Fix**: move all `claude --print` agents out of the Stop hook and into `.git/hooks/post-commit`:

```bash
# WRONG — Stop hook (fires every message)
# claude --print "..." &   ← never do this here

# RIGHT — post-commit hook (fires once per git commit)
# .git/hooks/post-commit
claude --dangerously-skip-permissions --print "..." 2>/dev/null &
```

**Rules to remember**:
- Never call `claude --print` from a Stop hook
- Never use `git diff HEAD~1` as a condition in Stop (always has output)
- Never watch `.claude/memory/` for mtime changes in Stop (written every session)
- Background doc agents belong in git hooks (commit-scoped) or manual slash commands

The Stop hook should only contain **passive checks** (e.g., nudging housekeeping when observations exceed a threshold). See `.claude/hooks/stop-hook.sh` for the reference implementation.
