# SDD Setup Guide

> This file is managed by the SDD harness (`sdd-harness/docs/`).
> It is the single source of truth — do not edit copies in individual projects.
> _Last synced: 2026-08-20_

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
- **Serena** _(optional, for Python code intelligence)_ — `claude mcp add serena --scope user -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --open-web-dashboard False`. The `--open-web-dashboard False` flag is load-bearing at user scope: every agent spawn starts its own Serena process, and without it each one opens a browser tab. The dashboard still runs at `http://localhost:24282/dashboard/` (port climbs per extra instance).

**Windows users:** The recommended setup is **WSL2** — run everything from a WSL2 terminal and Claude Code will use the Linux environment. If running Claude Code natively on Windows, see the notes in Steps 6 and 8 regarding bash hooks and path differences. See [FIRST-TIME-SETUP.md](FIRST-TIME-SETUP.md) for the platform support summary.

---

## Step 1: Gitignore Configuration

Add to `.gitignore`:

```gitignore
# ── Installed harness output — NEVER commit ──────────────────────────────────
# .claude/ is regenerable output, not source. install.sh / update.sh rebuild it
# on every machine from the harness source tree. Per-machine settings.json and
# memory content also live here and stay local.
.claude/
specs/
scripts/setup-git-hooks.sh
scripts/remap-ccsdd-paths.sh

# SDD harness — local-only, never committed
CLAUDE.md
# Generated per machine: AGENTS.md by `lean-ctx setup`, ERRORS.md by the
# 2+-attempts logging rule. Same class as CLAUDE.md — regenerated, not source.
AGENTS.md
ERRORS.md

# Serena symbol index — regenerable per machine via `serena project index`
.serena/
```

One `.claude/` line replaces the previous per-subdirectory list (`.claude/hooks/`, `.claude/commands/`, `.claude/agents/`, `.claude/kiro/`, `.claude/steering/`, `.claude/settings.json`, `.claude/memory/**` + its `!` re-includes). Already-tracked `.claude/memory/**/.gitkeep` files persist as clone scaffolding — the broad ignore does not untrack them.

`CLAUDE.md` is ignored again in the harness repo (under a `# SDD harness — local-only, never committed` header), matching the entries the harness writes into every project's `.gitignore` (`.claude/`, `specs/`, `CLAUDE.md`, `AGENTS.md`, `ERRORS.md`). Note that the git post-commit hook still lists `^CLAUDE\.md$` among the harness-updater triggers — that trigger simply never fires while the file is ignored.

That list lives in one place, `scripts/lib/project-gitignore.sh` (`SDD_GITIGNORE_ENTRIES`), sourced by both `install.sh` and `update.sh`. `install.sh` runs once per project, so an entry added later would never reach an already-installed project; `update.sh` calls the same `ensure_gitignore` on every sync (git repos only), so new entries backfill automatically. Appending is idempotent — each entry is added only if an exact matching line is absent, and the `# SDD harness — local-only, never committed` header is written at most once.

`AGENTS.md` and `ERRORS.md` joined the list because both are generated per machine rather than authored: `AGENTS.md` is written by `lean-ctx setup`, `ERRORS.md` by the 2+-attempts logging rule. They are the same class of file as `CLAUDE.md` — regenerated output, not source.

This library has its own test, `scripts/lib/project-gitignore.test.sh` — run it with `bash scripts/lib/project-gitignore.test.sh` (no framework, exits non-zero on failure). It builds throwaway project trees under `mktemp -d` and asserts three cases: a project with an existing `.gitignore` keeps its content and gains each entry exactly once; a project with no `.gitignore` gets one created whose first line is the header; a partial (legacy) `.gitignore` already listing `.claude/`, `specs/`, `CLAUDE.md` gains only the missing `AGENTS.md` and `ERRORS.md`, with no duplicates. The re-run case is the one that matters operationally: `update.sh` runs under `set -e` and calls `ensure_gitignore` on every sync, so `ensure_gitignore` always returns 0 — a non-zero "nothing to add" would abort every update of an already-configured project.

`.serena/` is ignored for the same reason as `.claude/`: it is Serena's symbol index, regenerable per machine with `serena project index`, so it is machine-local state rather than source.

The harness repo's own `.gitignore` additionally carries `reports/` (under a `# Generated reports — local only, never push` header) and the scheduler state files `.last-harness-sync` / `.last-drift-review`. `reports/` is where generated routine output lands — the drift-review sweep writes `reports/drift-review-report.md` there rather than into `docs/`, so a machine-local generated report cannot be committed or picked up by doc-sync as if it were documentation.

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
- `.claude/behaviors/` — read when reviewing agent conduct or grading a trace, not upfront; kept blind from the agent whose trajectory it grades
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
- Plan before multi-file or design-affecting changes — use Plan mode for back-and-forth. Sketch 2-3 approaches when the design is genuinely open; otherwise pick one and say why
- Features with clear correctness criteria need an approved spec in `specs/` before implementation — prefer an executable spec (failing test suite) or reference implementation over plain markdown. Markdown stays the default for open-ended/UX work. Bugfixes, perf work, and tooling do not need a spec
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

Create `.claude/settings.json`.

> **Strict JSON — no comments, nothing after the closing brace.** Claude Code parses this file as strict JSON and fails *quiet*: a malformed file is dropped whole, so every permission rule and hook in it silently stops working while the session looks normal. Keep explanatory notes in a `.claude/settings.notes.md` sidecar instead (`install.sh` and `update.sh` create one from `templates/settings.notes.md.template`). The annotations below the JSON block are documentation only — do not paste them into the file. Validate any settings file or template with:
>
> ```bash
> scripts/setup/check-settings-json.sh .claude/settings.json
> ```

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
      "Bash(ruff check:*)",
      "Bash(python -m ruff check <file>)",
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
      "Edit(**/*.md)",
      "Write(**/*.md)",
      "WebFetch(domain:raw.githubusercontent.com)",
      "Skill(kiro:your-skill-name)",
      "Skill(kiro:your-skill-name:*)"
    ],
    "additionalDirectories": [
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
          },
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/skill-permissions-gate.sh"
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
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/revert-detect-hook.sh"
          },
          {
            "type": "command",
            "command": "/bin/bash /path/to/.claude/hooks/setup-buffer-hook.sh"
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

What the entries above are for (keep this in `settings.notes.md`, not in the JSON):

- `Bash(ruff check:*)`, `Bash(python -m ruff check <file>)` — pre-approved ruff lint commands.
- `Edit(...)` / `Write(...)` pairs on `docs/**`, `specs/**`, `.claude/docs/**`, `.claude/steering/**`, `.claude/memory/**` — permissions for the doc-sync and harness-updater subagents spawned by the post-commit hook. Pair a `Write(...)` rule with every `Edit(...)` rule so the subagents can create new files, not just edit existing ones.
- `Edit(**/*.md)` / `Write(**/*.md)` — lets the doc-update hooks proceed without an approval prompt.
- `WebFetch(domain:...)` — domains Claude is allowed to fetch.
- `Skill(kiro:...)` — skill permissions, added as needed.
- `additionalDirectories` — directories outside the repo root that Claude should have read access to.

> `/path/to/` above is a placeholder for readability only — **do not** hand-write an absolute path there. What the installers actually render is `bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/<hook>.sh"`, which needs no editing at all.

> **Canonical source**: this JSON is an illustrative excerpt. The authoritative hook wiring lives in the harness source tree at `templates/settings.json.template` (per-project) and `templates/settings.harness.json.template` (the harness's own repo). Both now emit `bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/..."` — absolute when Claude Code exports `CLAUDE_PROJECT_DIR`, CWD-relative otherwise, machine-specific never. The harness template previously carried `{{HARNESS_DIR}}`-prefixed commands that `install.sh` substituted with the installing machine's absolute path; that substitution is what baked 23 machine-specific hook paths into `.claude/settings.json` and silently disabled every hook the moment the harness directory moved. Every command string is also quoted, so a harness or project path containing spaces no longer word-splits. `install.sh` / `update.sh` render these templates — edit the templates, not a generated `settings.json`. Both templates register `skill-permissions-gate.sh` on `PostToolUse Write|Edit` and `setup-buffer-hook.sh` on `PostToolUse Bash`. `caveman-savings-hook.sh` is wired on `Stop` in `templates/settings.harness.json.template` only (the harness's own dogfood repo) — not in the generic per-project `settings.json.template`. `templates/settings.json.template` also registers `reject-feedback-hook.sh` on `UserPromptSubmit` and `ai-writing-guard-hook.sh` on `PreToolUse Write|Edit|MultiEdit|Bash` (both new; see Automated Hooks below).

> **Templates are validated on the way out.** `install.sh` runs `scripts/setup/check-settings-json.sh templates/settings.json.template` before copying and refuses to create `.claude/settings.json` if the template is not strict JSON; `update.sh` runs the same check against the regenerated harness `settings.json` and the per-project template. Until 2026-08-12 the per-project template carried a trailing `//` comment block documenting the optional ktx MCP server, which made every settings file installed from it unparseable — that block now lives in `templates/settings.notes.md.template`, copied to `.claude/settings.notes.md` on install and update. `scripts/setup/repair-settings-json.py <project>` backfills projects installed before the fix (idempotent; `--dry-run` to preview). `/kiro:harness-validate` runs the checker as a blocking step.

---

## Step 7: Create .claude/hooks/stop-hook.sh

Create `.claude/hooks/stop-hook.sh` and make it executable:

```bash
chmod +x .claude/hooks/stop-hook.sh
```

**No path editing required.** The hook reads the harness root from `~/.sdd-harness-root` — **the** single stored pointer to the harness, written by `install.sh` / `update.sh` via `scripts/lib/harness-pointer.sh`. It is the only file on the machine that records where the harness lives, and it stays a plain file rather than a symlink because Windows and Git Bash need elevated privileges to create symlinks (`~/.claude/sdd-harness` is a convenience symlink *derived* from it, never read as an independent source). This makes the hook fully portable: rename the harness directory, move to a new machine, or change install depth — it resolves correctly without modification.

The two failure states are distinguished. An **absent** pointer means the harness was never installed globally, and the hook exits silently — correct. A pointer naming a directory that **no longer exists** means the harness moved, which deactivates every cross-repo hook on the machine; the hook (and `session-start-hook.sh`) prints `[HARNESS-POINTER-STALE]` with the dead path and the fix (`bash <harness>/update.sh`) before exiting 0. Both used to be an indistinguishable silent `exit 0`, so a move could disable the harness fleet-wide with no symptom for weeks.

**`$SDD_HARNESS` (human-facing counterpart).** `~/.sdd-harness-root` is what *scripts* read; `$SDD_HARNESS` is what *you* type. Both `install.sh` and `update.sh` export `SDD_HARNESS="$HARNESS_DIR"` and write it into `~/.zshrc` and `~/.bashrc` (whichever exist) at the end of the globals stage — appending an `export SDD_HARNESS="..."` line under a comment on first run, and rewriting the existing line in place (via `sed`) on later runs so the value follows the repo if it moves. No manual setup is needed, and every documented command can then be written as `$SDD_HARNESS/install.sh …` regardless of where the harness was cloned. On the very first run the variable isn't set yet in the current shell, so bootstrap with a direct path to the clone; open a new shell afterwards and it's available everywhere.

The stop hook runs lightweight checks at the end of every Claude session:

1. **Harness update check** — if the harness has new commits since last install, prints a nudge to run `update.sh`.
2. **Memory health check** — if `.claude/memory/observations.md` has >50 entries, prints a nudge to run `/kiro:housekeeping`.
3. **Agent failure pattern detection** — if `.claude/memory/trace.log` shows 3+ consecutive failures for the same agent, prints a nudge to run `/kiro:evolve` to investigate friction patterns.
4. **Session signal detection** — runs `scripts/session/detect_reexplanation.py` against the session transcript (Haiku-based LLM). Drain signals append a `[memory-gap]` observation; charge signals (unambiguous approval) append a `[session-charge]` observation. Both at most once per calendar day.
5. **learnings.jsonl promoter** — once per day, ranks today's `observations.md` entries by tag priority and appends the top-ranked one to `.claude/memory/learnings.jsonl`.
6. **Stale action-item escalator** — parses `.claude/memory/action-items.md` for overdue `- [ ] <desc> | due:YYYY-MM-DD` items and appends a `[stale-action-item]` observation for the most-overdue one, once per day.
7. **Cache-cost dominance nudge** — if cache tokens are ≥70% of the session's token spend and the session compacted at least once, appends a `[cache-cost]` observation and invokes `scripts/session/write_handoff.py --trigger cache-cost` to write a resumable snapshot to `.claude/memory/handoff/latest.md`.

See `docs/hooks/README.md` for the full nine-check reference (this list omits two lower-signal checks — session depth tracking, setup sequence capture — kept out of this walkthrough for brevity).

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

The post-commit hook applies a self-commit guard first, then runs three stages:
- **Guard — self-commit bail** — if the subject of the commit just made starts with `docs: auto-sync`, the hook exits immediately, before every stage (GitNexus reindex included). Hook 3's auto-sync commits touch `.md` files under watched source dirs such as `skills/` and `hooks/`, which matched the harness-updater guard and re-fired the agents in a loop.
- **Hook 1 — Doc sync** — detects whether any non-`.md`, non-`.claude/` files changed and builds the doc-sync prompt. The prompt's `.md` scan excludes `.venv/`, `.git/`, `__pycache__/`, and `.claude/` — the installed `.claude/` mirror is regenerated output, so doc sync no longer edits it (and no longer updates `.claude/steering/`; use `/kiro:sync-docs` for steering). It no longer spawns `claude` itself — Hook 3 runs the prompt.
- **Hook 2 — Harness updater** — runs if the commit touched the harness **source tree**, matched by `^(agents|commands|hooks|kiro|scripts|rules|templates|skills)/` or `^CLAUDE\.md$`. (Previously this matched `.claude/`; `.claude/` is now generated output, rebuilt by `install.sh` / `update.sh`, so it is gitignored and never the trigger.) Builds the guide-sync prompt for `docs/harness-documentation/SDD-SETUP-GUIDE.md`; Hook 3 runs it. The prompt routes each changed path to its section: `commands/` → slash commands, `agents/` → subagents, `CLAUDE.md` → project constitution, `skills/` → skills, `hooks/` → automated hooks, `kiro/` → rules/templates, `rules/` → context engineering, `templates/settings*.template` → hooks/configuration.
- **Hook 3 — Detached runner (sync, then auto-commit + push `.md`)** — if either guard above fired, everything runs as **one fully-detached background job**: the doc-sync agent, then the harness-updater agent, then `git add -- '*.md'` → `git commit -m "docs: auto-sync (<date>)"` → `git push`, scoped to `*.md` only. Non-`.md` changes sitting in the working tree are never staged or pushed. If the push fails (no remote/auth), the commit still lands and the runner logs a warning instead of failing.
- **Why detached** — `git commit` returns immediately and the terminal is freed (no hang, no Ctrl-C). The job runs with stdin from `/dev/null`, is `disown`ed, and appends all output to `.git/post-commit-docsync.log`, so nothing reaches the tty. Each `claude` invocation is wrapped in `timeout 900` (or `gtimeout 900` where only coreutils provides it) when available, so a stuck agent cannot block; if neither binary exists the agents run unbounded.
- **Concurrency lock** — the detached job serializes itself on `.git/post-commit-docsync.lock`, created with `mkdir` (atomic). If a previous run still holds the lock, the new run logs `=== skipped <date>: another doc-sync run is active ===` and exits without running the agents. This keeps rapid successive commits from spawning parallel agents that race on the git index and drop each other's commits. A lock left behind by a killed run is stolen once it is older than 30 minutes (`find -mmin +30` then `rmdir`); on normal exit an `EXIT` trap removes it. Clear one by hand with `rmdir .git/post-commit-docsync.lock`.
- **Re-entrancy** — the `.md`-only commit made by Hook 3 re-fires the post-commit hook, but the self-commit guard matches its `docs: auto-sync` subject and exits immediately. No loop. (The older "both guards fail" reasoning was not enough: auto-sync commits touching `.md` under `skills/` or `hooks/` still matched the harness-updater guard.)
- **Debugging** — tail `.git/post-commit-docsync.log`; each run is delimited by `=== doc-sync run <date> ===` and `=== done <date> ===`. A `=== skipped <date>: another doc-sync run is active ===` line means the lock was held — that commit's doc sync is covered by the run already in flight, or by the next commit.
- The GitNexus incremental reindex (when `.gitnexus/` exists) is likewise backgrounded with stdin from `/dev/null` and stdout/stderr discarded, so it cannot print into or block the terminal.
- The `--dangerously-skip-permissions` flag is required: the background agents run non-interactively (no terminal to answer permission prompts), so without it the doc sync would stall on the first `Edit`/`Write` and never apply changes.
- **Executable bit** — the source file `hooks/git/post-commit` is *not* required to be executable in the harness tree (it is currently mode `100644`). `install.sh` and `update.sh` copy it to `.git/hooks/post-commit` and then run `chmod +x` on the copy, so the installed hook is always executable regardless of the source mode. If you install the hook by hand, `chmod +x .git/hooks/post-commit` yourself.

**`.git/hooks/pre-commit` (harness repo only).** `hooks/git/pre-commit` runs `scripts/utils/check-no-hardcoded-paths.sh` and blocks a commit that would bake a machine-specific path into harness source. It is installed by `install.sh` / `update.sh` (`install_harness_pre_commit()` in `scripts/lib/harness-pointer.sh`) into the harness repo only — never propagated to downstream projects, since a user's own project may legitimately reference absolute paths. Before this, the hook existed in the source tree but nothing ever copied it: both installers handled only `post-commit`, and the hook's own header documented a manual `cp` from a `git-hooks/` directory that does not exist — so the guard had never run automatically while two files advertised it as wired up.

The install is non-destructive: an existing `.git/hooks/pre-commit` that is *not* this guard is left alone with a note telling you the line to add. A pre-commit that already contains `check-no-hardcoded-paths` is overwritten on every install/update, so extra lines appended to it (e.g. the `scan-pii.sh --staged` call the README documents) belong in `hooks/git/pre-commit` in the source tree instead. Bypass for one commit with `git commit --no-verify`.

**What the guard scans.** `*.sh`, `*.py`, `*.json` and `*.template` under the harness root — config counts as code. It originally scanned only `*.sh`/`*.py` and excluded `.claude/**` wholesale, which made `.claude/settings.json` invisible on both counts while it held 23 absolute hook paths; the guard reported `✓ No hardcoded paths` the whole time. Exclusions are now narrow and each is deliberate: `.claude/**` (synced copies of this source — they would double-report), `docs/**` (prose and frozen historical records), `skills/**` (vendored third-party skills whose recorded benchmark output contains other people's home paths — 13 of them drowned the real findings), `scripts/lib/resolve-harness-dir.sh` (the one allowed depth marker), `scripts/lib/harness-pointer.sh` (the one allowed namer of `~/.sdd-harness-root` and its convenience symlink), and the guard script itself (it names the patterns it bans). Gitignored files that are generated per machine and must still be path-free are re-admitted explicitly via a `GENERATED_SCANNED` list — currently just `.claude/settings.json`, since `settings.local.json` is the user's own file and may legitimately hold absolute paths (e.g. `additionalDirectories`). `git ls-files` cannot see generated files, hence the explicit list.

The script is idempotent — safe to run multiple times.

---

## Step 9: Add Custom Subagents

Create two custom subagent definitions in `.claude/agents/kiro/`:

### doc-sync.md
Documentation synchronization agent. Reviews `git diff HEAD~1` and updates relevant `.md` files in `specs/` and `.claude/steering/` to prevent documentation drift.

Triggered by: `/kiro:sync-docs` command or the post-commit hook.

### harness-updater.md
Harness documentation maintenance agent. Updates this file (`SDD-SETUP-GUIDE.md`) whenever Claude Code harness files change.

Triggered by: the git post-commit hook when harness **source** files are in the commit — `agents/`, `commands/`, `hooks/`, `kiro/`, `scripts/`, `rules/`, `templates/`, `skills/`, or `CLAUDE.md`. Target file is `docs/harness-documentation/SDD-SETUP-GUIDE.md`.

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

The usage guide (`.claude/docs/harness-documentation/SDD-USAGE.md`) is a quick-reference for all SDD commands with examples. It should be generated as part of setup so that users (and AI agents replicating the harness) know how to use the workflow immediately.

Copy the usage guide from this project, or generate one by asking Claude:

```
Create .claude/docs/harness-documentation/SDD-USAGE.md — a quick-reference listing every /kiro: command,
what it does, and an example invocation. Include a "Typical Workflow" section at the end.
```

This file is read-on-demand (not loaded at session start) and lives under `.claude/docs/harness-documentation/` alongside this guide.

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
| `/kiro:idea-refine "rough idea"` | Refine vague ideas into clear, spec-ready briefs. First runs a **Scale Check**: if `specs/_maps/<slug>.md` already exists, or the idea is program-scale per `issue-triage-routing` axis 4 (spans multiple decisions, each deserving its own spec), it charts/updates that map (destination + ordered fog list) via `idea-refine-agent`, then decomposes and re-triages the first fog item as a normal feature-scale brief — one pass never dead-ends at just the map. Feature-scale ideas with no map skip straight to the single-brief flow |
| `/kiro:spec-init "description"` | Initialize new feature workspace in `specs/`. When run standalone (not via `spec-quick`), first runs `/kiro:pref-elicit {$ARGUMENTS}` unless `prefs.md` already exists — surfaces declarative vs. imperative preferences before the spec assumes defaults |
| `/kiro:spec-requirements {feature}` | Generate EARS-format requirements (subagent) |
| `/kiro:spec-design {feature}` | Generate research notes + technical design (subagent) |
| `/kiro:spec-grill {feature}` | Domain grilling session — align terminology, crystallise decisions, update docs and ADRs inline (interactive) |
| `/kiro:spec-tasks {feature} [--sequential]` | Generate P-wave parallel task list (subagent); `--sequential` disables parallel `(P)` markers. On tasks approval, also greps `specs/_maps/*.md` for a fog line matching this feature and, if found, moves it from "Not yet specified" to "Decisions so far" (linking `specs/{feature}/`) — keeps a charted program map in sync as its slices get spec'd |
| `/kiro:spec-impl {feature}` | Implement from approved spec via TDD (subagent) |
| `/kiro:spec-quick "description"` | Fast path: requirements→design→grill→tasks in one command (grill skipped with `--auto`). Pre-check applies `issue-triage-routing` — routes to ONE-SHOT (implement directly, no spec) / DEFER / CLARIFY before spec'ing; proceeds to full spec generation only on SPEC. In Interactive Mode, Step 1.5 now runs 1.5a Preference Elicitation (`/kiro:pref-elicit {description}`, mandatory, writes `prefs.md` used by phases 2–5) before 1.5b Idea Refinement |
| `/kiro:debug "bug description"` | Systematic 6-step bug triage (reproduce→fix→guard) |
| `/kiro:simplify <file-or-feature>` | Behavior-preserving code simplification |
| `/kiro:ship [feature]` | Launch readiness: verification + rollout planning |
| `/kiro:validate-gap {feature}` | Gap analysis: requirements vs. existing code |
| `/kiro:validate-design {feature}` | Design quality review (with remediation plan on NO-GO) |
| `/kiro:validate-impl {feature}` | Implementation vs. spec validation (with remediation) |
| `/kiro:validate-adversarial {feature}` | Three-pass adversarial review with +1/-2 scoring |
| `/kiro:converge [feature]` | Spec ↔ code reconciliation — detects bidirectional drift (spec-ahead / code-ahead / contradiction); reuses `validate-impl-agent` |
| `/kiro:spec-status {feature}` | Show current phase, approvals, and open tasks |
| `/kiro:sync-docs` | Sync docs with ALL code changes (uncommitted + staged + committed). Filters out `.md` files and `.claude/` paths — `.claude/` is regenerated output (rebuilt by `install.sh` / `update.sh`) and gitignored; changes to the harness **source** tree (`agents/`, `commands/`, `hooks/`, `kiro/`, `scripts/`, `rules/`, `templates/`, `skills/`, `CLAUDE.md`) are the harness updater's job. This is the *manual* trigger — the stop-hook runs it at session end, and the post-commit git hook is the safety net: it runs doc sync, then the harness updater, then auto-commits and pushes **only** the `.md` files they touched, all inside one detached background job (each agent bounded by `timeout 900`), so `git commit` returns immediately and output lands in `.git/post-commit-docsync.log` |
| `/kiro:reflect` | Review session, extract observations, update memory (subagent) |
| `/kiro:learn-eval [scope]` | Quality-gate session/sprint/feature patterns before saving to memory — scores specificity/actionability/evidence (1-3 each, pass ≥6); verdicts Save/Absorb/Route/Drop (subagent). Use for deeper periodic evaluation vs. `/kiro:reflect`'s quick frequent capture |
| `/kiro:housekeeping` | Prune memory, archive old observations to glacier (subagent) |
| `/kiro:daily-maintenance` | Nightly orchestrator — wires Judge → Reflect → Housekeeping → Trust Score → Skill Augment → Behavior Spec Mining into one pipeline; idempotent per calendar day (guards on today's `[judge]` observation), surfaces unresolved `[memory-gap]`s as `[routine-alert]`. Never edits code/specs — memory and skills only |
| `/kiro:evolve` | Audit harness rules effectiveness, propose improvements (subagent) |
| `/kiro:harness-fix` | Encode a behavioral prevention rule from a specific mistake |
| `/kiro:harness-validate` | Check structural integrity of harness installation — broken references, missing files, memory caps, plus a blocking strict-JSON check of the settings templates and the live `.claude/settings.json` via `scripts/setup/check-settings-json.sh`. Also runs `scripts/utils/check-no-hardcoded-paths.sh` (same script the `.git/hooks/pre-commit` hook runs — that hook is now installed into the harness repo by `install.sh` / `update.sh`, where before it sat in the source tree with nothing ever copying it; invoke it by hand as `bash scripts/utils/check-no-hardcoded-paths.sh` — it lives under `scripts/utils/`, not `scripts/`) and `scripts/utils/check-fleet-registration.sh`, which reports harness-installed repos missing from `projects.txt` |
| `/kiro:harness-test` | Haiku smoke-test to expose vague prompts |
| `/kiro:tool-failure-review [min-count]` | Review the tool-failure ledger — diagnose recurring Bash/MCP failures and promote durable lessons into memory (default `min-count` 3). Review step of the tool-failure-memory loop (capture → recall → review) |
| `/kiro:guardrails` | Audit/scaffold linter complexity rules for deterministic enforcement |
| `/kiro:ci-scaffold` | Generate CI configuration mirroring the verify pipeline |
| `/kiro:autoresearch-init` | Interactive ML project setup — generates program.md, train.py, prepare.py |
| `/kiro:autoresearch [N]` | Run autonomous ML experiment loop (N iterations or continuous). If `recipe.md` exists in the project root, it's passed to the agent alongside `program.md` as a versioned record of signal-filtering policy and staged-autonomy level (see AutoResearch section below) |
| `/kiro:macro-eval-sweep [days-back] [name-filter]` | Population-scale failure pattern sweep over Raindrop Workshop traces; clusters recurring failures, ranks by impact, writes dated report, posts Workshop annotations |

### Global commands (`commands/global/`)

These live in the harness at `commands/global/` and are installed **machine-global** into `~/.claude/commands/` by `install_globals()` — they are not `kiro:`-namespaced and work in any repo, harness-installed or not.

| Command | Purpose |
|---|---|
| `/claudemd-review [--apply]` | Audits the **current repository's** always-loaded instruction files (`CLAUDE.md`, `@imports`, `.claude/rules/*`) against a lean-context rubric, writes a findings report, and stamps `.claude/memory/.last-claudemd-review` so the bi-weekly `session-start-hook.sh` reminder (`[CLAUDEMD-REVIEW-DUE]`, >14 days stale) resets. Defaults to propose-only; `--apply` writes the edits. It is the **per-repo** counterpart to the harness-health-runner routine, which audits *all* registered repos into `reports/claudemd-review-report.md` — the two write to different files and must not be confused |
| `/notify <message>` | Sends a message to the chat channels configured in `~/.env.channels`. Resolves the notifier as repo-local first (`.claude/scripts/integrations/channels/notify.py`), falling back to the harness source at `$SDD_HARNESS/scripts/integrations/channels/notify.py` — the fallback is written as `$SDD_HARNESS`, not a hardcoded `~/.claude/sdd-harness`, so it resolves wherever the harness was cloned |

---

## Subagents

| Agent | Trigger | Purpose |
|---|---|---|
| `@agents-spec-requirements` | `/kiro:spec-requirements` | EARS requirements generation; approval via Proof collaborative review session |
| `@agents-spec-design` | `/kiro:spec-design` | Research + technical design; approval via Proof collaborative review session |
| `@agents-spec-tasks` | `/kiro:spec-tasks` | P-wave task breakdown; approval via Proof collaborative review session |
| `@agents-spec-impl` | `/kiro:spec-impl` | TDD implementation per task |
| `@agents-spec-refactor` | After each impl task (auto, spawned by spec-impl agent) | Post-task self-review: reuse, quality, efficiency, 3-tier security checks + test re-run |
| `@agents-idea-refine` | `/kiro:idea-refine` | Structured ideation: problem framing → divergent/convergent thinking → spec-ready brief. For program-scale ideas, breadth-first charts the distinct decisions into a map instead of going deep on one. Renders approaches as a Mermaid diagram instead of bullets when the idea is visual/interface-shaped or has many plausible shapes — tangible comparisons surface reactions abstract text doesn't |
| `@agents-debug` | `/kiro:debug` or via jira-solve BUG routing | 6-step systematic debugging: reproduce → localize → reduce → fix → guard → verify |
| `@agents-jira-solve` (`jira-solve-agent`) | `/kiro:jira-solve` Step 3 | Analyzes a Jira issue JSON into a structured solve report: problem statement, acceptance criteria, and relevant codebase files found via Glob/Grep |
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
| `@agents-harness-updater` | git post-commit hook (when harness **source** files are committed — `agents/`, `commands/`, `hooks/`, `kiro/`, `scripts/`, `rules/`, `templates/`, `skills/`, `CLAUDE.md`) | Harness→guide sync |
| `@agents-reflect` | `/kiro:reflect` | Session mining → observations, patterns, hot-memory |
| `@agents-learn-eval` | `/kiro:learn-eval` | Scores candidate patterns on specificity/actionability/evidence (1-3 each, threshold ≥6 to pass), then deduplicates against `meta/patterns.md`. Verdicts: **Save** (score≥6, no duplicate — new entry in patterns.md), **Absorb** (score≥6, similar entry exists — merge evidence in), **Route** (score≥6 but tied to exactly one existing skill — skip memory, hand to `skill-augment-agent` instead), **Drop** (score<6 or exact duplicate) |
| `@agents-housekeeping` | `/kiro:housekeeping` | Memory archival (observations >50 entries → glacier, keep 25 recent; completed action items >10 → keep 5), pruning (hot-memory <50 lines, patterns <70 lines), format validation (L0 headers, entry formats), stale-item flagging (action items >14d, entities >30d), glacier index rebuild. Reviews `[auto-learn, YYYY-MM-DD]`-tagged hot-memory entries left by the micro-reflect stop hook: keep if <7d old, promote to `meta/patterns.md` if 7d+ with reinforcing evidence, else remove (no archive — ephemeral by design). Also flags patterns/hot-memory entries tied to exactly one skill and recommends routing them into that skill via `skill-augment-agent` — never auto-moves, archive-first discipline |
| `@agents-evolve` | `/kiro:evolve` | Rule audit, friction analysis, trace log analysis, improvement proposals, linter graduation |
| `@agents-guardrails` | `/kiro:guardrails` | Linter complexity rule auditing and scaffolding |
| `@agents-ci-scaffold` | `/kiro:ci-scaffold` | CI configuration generation (GitHub Actions, GitLab CI, Azure Pipelines) |
| `@agents-harness-validate` | `/kiro:harness-validate` | Structural integrity check, component index generation. Step 3 also runs `scripts/setup/check-settings-json.sh` over `templates/settings.json.template`, `templates/settings.harness.json.template`, and `.claude/settings.json` — non-zero exit is a blocker, since Claude Code drops every permission rule and hook in a malformed settings file without warning and a broken template propagates that to every project installed from it. Notes belong in `settings.notes.md`, not in the JSON |
| `@agents-autoresearch-init` | `/kiro:autoresearch-init` | Interactive interview → file generation |
| `@agents-autoresearch` | `/kiro:autoresearch` | Autonomous ML experiment loop |
| `@agents-skill-augment` | `/kiro:daily-maintenance` (nightly) | Encodes session learnings into SKILL.md files; max 3 skills/run, append-only, ≤150 chars/addition. Evidence-gated on observations, judge drains, or `type: feedback` memories — human-feedback auto-qualifies and is drafted before machine signals. Dreaming step writes synthetic worked examples to `resources/examples/` |
| `@agents-behavior-spec` (`behavior-spec-agent`) | `/kiro:daily-maintenance` Step 6b (nightly) | Reviews today's Judge verdict, `type: feedback` memories, and `[revert]`/`[drain]` observations for recurring **conduct** patterns (not skill-content gaps — that's `skill-augment-agent`'s job) and drafts/revises `.claude/behaviors/<name>/BEHAVIOR.md` — answer-key material for grading trajectories, deliberately never shown to the agent being graded. Max 3 specs/run; ≥2 occurrences required except `type: feedback` memories which auto-qualify at 1; every spec validated with `.claude/scripts/validate-behavior-spec.py` before being left in place; writes only under `.claude/behaviors/`, never `~/.claude/skills/` or `CLAUDE.md` |
| `@agents-save-session` (`save-session-agent`) | `/kiro:save-session` | Captures current session state (files touched, decisions, exact next step) into a resumable snapshot for `/kiro:resume-session`. Snapshot format includes a **Suggested Skills** section (which skill a resuming agent should call, e.g. `spec-tdd-impl` if mid-implementation) and follows two output-discipline rules: **no duplication** — reference specs/ADRs/commits/diffs by path rather than restating their content — and **redact secrets** — strip API keys/tokens/passwords from evidence before writing to the session file |

---

## Automated Hooks

| Hook | Trigger | Action |
|---|---|---|
| PostToolUse (lint) | Every `.py` write in Claude | `uv run ruff check --fix {file}` |
| PostToolUse (impeccable) | Every frontend file Write/Edit (`.tsx/.jsx/.css/.vue/.svelte/.html`) | Runs `impeccable detect {file}` and surfaces anti-pattern violations. No-ops silently if CLI not installed. Requires one-time `npm install -g impeccable`. |
| PostToolUse (test-integrity-guard) | Every Write/Edit/MultiEdit to a test file or CI/coverage config (`test_*`, `*_test.*`, `*.spec/.test.*`, `tests/`, `pytest.ini`, `pyproject.toml`, `.coveragerc`, jest/vitest config, CI YAML) | Soft gate (never blocks): flags "gradient descent to green" test weakening — added skip/xfail/`@Disabled` markers, tautological assertions (`assert True`), touched coverage thresholds (`--cov-fail-under`, `coverageThreshold`), or removed assertions. Asks Claude to confirm a deliberate spec change vs. a shortcut to pass. Script: `.claude/hooks/test-integrity-guard.sh`. |
| PostToolUse (ruff-quality-gate) | Every Write/Edit/MultiEdit to a `.py` file (soft gate, never blocks) | Runs `ruff check` on any Python file touched by Write/Edit/MultiEdit and surfaces findings back into context — closes the gap between `CLAUDE.md`'s Quality Gates claim ("`ruff check`: on every `.py` file write") and what was actually enforced: the pre-existing `Bash(ruff check *)` permission entry only ran if Claude remembered to invoke it. Silently no-ops if `ruff` isn't installed or the touched file isn't Python; output is a `⚠ ruff-quality-gate — <filename>` banner with raw findings, silent when clean. Wired into both `templates/settings.json.template` and `templates/settings.harness.json.template`. Script: `hooks/claude/ruff-quality-gate-hook.sh` → `.claude/hooks/ruff-quality-gate-hook.sh`. |
| spec-refactor (internal) | After each impl task's SELF-REVIEW step (Step 5) | Spawned by spec-tdd-impl-agent; reviews touched files, fixes issues, re-runs tests |
| PostToolUse (Jira comment) | Every `git push` Bash command | Posts Jira comment with branch/commits/docs summary if a `jira-solve` session is active |
| UserPromptSubmit (Jira capture) | Every user prompt | Captures ticket ID from `/kiro:jira-solve TICKET-ID` prompts, writes to `~/.claude/state/active_jira_ticket` |
| UserPromptSubmit (context priming) | Every user prompt | Injects `.claude/memory/hot-memory.md` contents (wrapped in `--- Active Context ---` markers) so the agent always primes on current state before responding. Fast (<1s); no-ops if hot-memory is missing or empty. Implemented in `.claude/hooks/prompt-hook.sh`. |
| SessionStart (settings.json self-heal) | Every Claude session start, before every other check in the hook | Runs `scripts/setup/repair-settings-json.py` (resolved from `$HOME/.sdd-harness-root`) against the current project whenever `.claude/settings.json` exists and `python3` is available. Claude Code parses that file as strict JSON and silently drops a malformed one whole — every permission rule and hook in it stops working with no in-session error — so repairing here caps the damage at one session instead of lasting until someone happens to run `update.sh`. Idempotent and cheap: valid files are read and left alone, and the `OK ` no-op line is filtered out so healthy repos print nothing. When a repair happens, prints `[SETTINGS-REPAIRED] <detail>` plus a note that Claude Code already read the old file, so the rules and hooks are inactive for **this** session and return at the next session start. Runs ahead of the memory-bootstrap gate because a broken settings file needs fixing whether or not the repo has memory yet. |
| SessionStart (maintenance check) | Every Claude session start | **macOS:** clears `com.apple.macl` xattrs from `.claude/hooks/` (Write/Edit tools set this attribute, blocking subprocess execution of edited hook files). Then two modes: (1) if no local `daily-runner.sh` is installed — checks if today's `[judge]` sentinel is absent from `observations.md` and asks Claude to run `/kiro:daily-maintenance`; (2) if `daily-runner.sh` is installed and stale (>24h or never ran) — fires it in the background via `nohup` silently, without consuming session context. Also checks if the per-repo CLAUDE.md review is >2 weeks stale (`.claude/memory/.last-claudemd-review`) and asks Claude to run `/claudemd-review` if so. Also checks for a `.claude/memory/.steering-bootstrap-pending` sentinel (dropped by `install.sh` for fresh installs with no steering files): if present and no steering `.md` files exist, injects `[STEERING-BOOTSTRAP-DUE]` prompting `/kiro:steering`. Claude removes the sentinel after steering completes. Finally, checks `.claude/memory/handoff/latest.md` — if present and <24h old (written by `scripts/session/write_handoff.py` from a prior compaction or subagent spawn), injects `[SESSION-HANDOFF-AVAILABLE]` prompting Claude to silently read it before responding to the user's first message. |
| Stop (memory health) | Every Claude session end | Nudges `/kiro:housekeeping` if observations >50; nudges `/kiro:evolve` if agent failure patterns detected |
| Stop (session signal detector) | Every Claude session end | Runs `scripts/session/detect_reexplanation.py` (Haiku LLM); appends `[memory-gap]` observation for drain signals (re-explanation) and `[session-charge]` for charge signals (approval). Each written at most once per day. |
| PostToolUse (action-capture) | Every Bash git-commit, test run, deploy, or failed command | Prompts memory capture after high-signal Bash actions (git-commit, test failures, deploys, struggle); auto-writes `[seed-target:]` observation on non-zero exit. Script: `.claude/hooks/action-capture.sh`. |
| UserPromptSubmit (doc-parse-nudge) | Every user prompt (keyword-gated) | Fires when prompt mentions document parsing or RAG pipeline building (PDF, DOCX, OCR, embed, ingest, vector store). Injects a reminder to invoke the `document-parsing` skill. When the nudge fires, also appends a `[doc-parse-nudge]` observation to `observations.md`. Exits <5ms on non-matching prompts. Script: `hooks/claude/doc-parse-nudge.sh`. |
| PostToolUse (revert detector) | Every git revert/reset/restore Bash call | Immediately appends `[revert]` drain observation to `observations.md` — gives trust-battery Judge concrete evidence. Script: `.claude/hooks/revert-detect-hook.sh`. |
| PostToolUseFailure (tool-failure capture) | Every failing Bash/MCP tool call | Records the failure into a per-repo ledger `.claude/memory/tool-failures.jsonl`, keyed by a normalized command signature so the same failure shape clusters and its `count` climbs. Capture half of the tool-failure-memory loop. Script: `.claude/hooks/tool-failure-capture.sh`; see the `tool-failure-memory` skill. |
| PreToolUse (tool-failure recall) | Every Bash/MCP tool call | Soft advisory (never blocks): if this command shape has failed ≥2× and is still open, injects the failure count, last error, and any recorded remedy so Claude reconsiders before repeating it. Once-per-session-per-signature dedupe + 45-day recency gate. Script: `.claude/hooks/tool-failure-recall.sh`. |
| daily-orchestrator (fleet harness sync) | Once per calendar day, harness-level, **before** the per-repo runners (gated by `$SDD_HARNESS/.last-harness-sync` using a portable day-string compare, not GNU-only `date -d`) | Runs `$HARNESS_DIR/update.sh` so every registered project picks up harness changes with no human step. Nothing else ever ran `update.sh` — `stop-hook.sh` only prints a `Run: update.sh` nudge and then waits for a human, so a harness fix could sit unapplied in an installed project indefinitely (this is how a `settings.json` broken by an old template survived for months in an installed repo). `bash -n update.sh` must pass first, so a half-written `update.sh` is never run across the whole fleet; a parse failure is logged to `logs/orchestrator.log` and `logs/orchestrator-errors.log` and the sync is skipped. `--repo <path>` is forwarded to `update.sh`; `--dry-run` prints a `[would-sync]` line only. The state file is written only on exit 0, so a failed sync retries the next run instead of consuming the day. Opt out with `SDD_SKIP_HARNESS_SYNC=1`. |
| daily-orchestrator (tool-failure review) | Once per day per repo via the daily orchestrator (self-paces to ~2×/week via `MIN_GAP_DAYS=3`; no-ops unless a promotable ledger entry exists) | Runs `.claude/scripts/tool-failure-review-runner.sh`, which invokes `/kiro:tool-failure-review` headlessly: diagnoses recurring failures (`count ≥ 3`, open, unpromoted) and promotes the understood, reusable ones into memory files + `ERRORS.md`, then marks them resolved on the ledger. Review (promotion) half of the tool-failure-memory loop. Opt out with `SDD_SKIP_TOOL_FAILURE_REVIEW=1`. |
| daily-orchestrator (code-review learning) | Once per day per repo via the daily orchestrator (self-paces to weekly via `CODE_REVIEW_LEARNING_GAP_DAYS=7`; no-ops unless a merged PR has a pr-babysit review log not yet processed) | Runs `.claude/scripts/routines/code-review-learning-runner.sh`: diffs pr-babysit's logged review (`.claude/memory/pr-reviews/pr-<n>.md`) against real human review activity (`gh api` comments/reviews) on merged PRs. Low-risk findings (conventions, dismissed-flag patterns) are promoted straight into memory; higher-risk methodology changes are only reported to `docs/code-review-learning-report.md` for human approval. Opt out with `SDD_SKIP_CODE_REVIEW_LEARNING=1`. |
| daily-orchestrator (security report) | Once per day per repo via the daily orchestrator (self-paces to daily via `MIN_GAP_DAYS=1`; applies to every repo) | Runs `.claude/scripts/routines/security-report-runner.sh`: static security scan of recent git changes using the `ai-security-workflow` skill — checks for OWASP patterns, secrets, injection sinks. Writes `.claude/reports/security/<date>-security-report.md`. Visible in the dashboard Scheduled Tasks section. Retries automatically on failure — the state file is only written after a successful run (exit 0), so a failed scan doesn't consume the gap-days window; stdout is also tee'd to `.claude/memory/.last-security-report-output.log` since the orchestrator wrapper redirects stdout to `/dev/null` and only captures stderr. Opt out with `SDD_SKIP_SECURITY_REPORT=1`. |
| daily-orchestrator (startup payload audit) | Once per day per repo via the daily orchestrator (deterministic, no LLM; self-paces to daily via its own state-file guard) | Runs `.claude/scripts/routines/startup-payload-audit.sh`: audits the fixed per-session startup token tax (`CLAUDE.md` + `@imports` + `.claude/rules/*` + auto-loaded `MEMORY.md`). Writes `.claude/reports/context/startup-payload.json`, read by the dashboard's Context Health tab. Wired into `daily-orchestrator.sh` `run_one()`. Opt out with `SDD_SKIP_STARTUP_AUDIT=1`. |
| daily-orchestrator (fleet registration check) | Every fleet run, after the per-repo loop (skipped under `--dry-run`) | Runs `scripts/utils/check-fleet-registration.sh --quiet`: finds repos that have the harness installed (`.claude/` present) but are missing from `projects.txt`. Such a repo gets zero routines and appears nowhere, because the dashboard only renders repos it is told about — absence is invisible unless something looks for it. Never fatal: it is a report, not a gate. A finding writes `orchestrator: unregistered harness repo(s) found` to `logs/orchestrator.log` and the detail to `logs/orchestrator-errors.log`. The same script is a step in `/kiro:harness-validate`. |
| OS Scheduler + SessionStart (daily maintenance) | 18:00 local, repeating every 4h (6x/day) on WSL/Windows (`setup-global-orchestrator.sh`); once daily on macOS/Linux; SessionStart catch-up if >24h stale | Runs per-repo `daily-runner.sh` → `/kiro:daily-maintenance` — Judge → Reflect → Housekeeping → Session Quality → Keep Rate → Trust Score → Augment Skills → Adversarial Check. The orchestrator skips `daily-runner.sh` if it already ran today (dedup via state-file date check), so the SessionStart catch-up never double-fires. Auto-registered by `install.sh` / `update.sh`: Windows Task Scheduler on WSL (`setup-global-orchestrator.sh`), cron on Linux (`setup-linux-orchestrator.sh`), launchd on macOS (`setup-mac-orchestrator.sh`). Each setup script **preflights** that the orchestrator can actually execute under its scheduler rather than trusting that registration succeeded — `launchctl load` returning 0 only means the job was registered, and with the harness under `~/Documents` launchd (holding no Full Disk Access) was refused at exec time with `Operation not permitted`, exiting 126 daily for four days behind a green install. macOS registers a throwaway probe LaunchAgent that runs `--dry-run` in the same launchd context; Linux runs `--dry-run` under an approximated cron environment (`env -i`, minimal PATH); both **exit 1** on failure, and the macOS path names TCC explicitly when `$HARNESS_DIR` is under `~/Documents`, `~/Desktop` or `~/Downloads`, offering both fixes (move the harness, or grant Full Disk Access to `/bin/bash`). The macOS LaunchAgent's `ProgramArguments` now wraps the orchestrator in **`caffeinate -i`** (`/bin/bash -lc "caffeinate -i <orchestrator>"`), so the unattended 18:00 fire is not cut short partway through by idle or display sleep — a laptop that dozes mid-run otherwise kills the routines still queued behind the one in flight, which reads afterwards as a partial run rather than a failure. WSL/Windows preflights through `wsl.exe -d <distro> -- bash -lc` but only **warns**, since the matching `schtasks /Run` + `LastTaskResult` check could not be tested. The preflight also runs on the "already registered / already loaded" path — that is exactly the state a silently-dead job reports. See `docs/scheduled-tasks/README.md` → "Preflight — registration is not execution". Opt out: `SDD_SKIP_ROUTINE=1` at install time; `schtasks.exe /Delete /TN "SDD Daily Orchestrator"` (Windows); `crontab -l | grep -vF sdd-daily-orchestrator | crontab -` (Linux); `launchctl unload ~/Library/LaunchAgents/com.sdd.daily-orchestrator.plist` (macOS); `rm .claude/scripts/orchestration/daily-runner.sh` per-repo. `daily-runner.sh` recovers from stale locks (removes a lock dir older than 2h, left by a SIGKILL'd run) and uses a single `EXIT` trap to release the lock (bash fires `EXIT` on `INT`/`TERM` too, so one trap covers all exit paths). Each routine's stderr is captured to a per-run buffer and appended to `logs/orchestrator-errors.log` only on non-zero exit (stdout still goes to `/dev/null`), so a failing routine leaves a diagnosable trace instead of a false-looking `exit=0` line in `logs/orchestrator.log`. `daily-orchestrator.sh` itself (the fleet-level dispatcher, one level above `daily-runner.sh`) now logs a start line to `logs/orchestrator.log` on every real invocation and, via an `EXIT` trap, a matching finish line with the exit code and repo count — plus an arg-validation error line to `logs/orchestrator-errors.log` for bad flags (`--repo` with no path, unknown args) — so a crash before the repo loop starts (bad env, `resolve-harness-dir.sh` failure, missing `projects.txt`) is structurally distinguishable from a zero-work success instead of leaving no trace at all. `daily-orchestrator.sh` sources `.claude/scripts/lib/env-detect.sh`, which detects host OS/WSL and classifies a registered repo path as `cross-fs` when it's under `/mnt/*` on WSL (the one confirmed real perf risk on that setup); cross-fs repos surface as a `WARNING` line in `logs/orchestrator.log` (no auto-reroute). The harness-level drift review it also runs is gated on elapsed days since the last **successful** run (`DRIFT_REVIEW_GAP_DAYS`, default 7) rather than a fixed day-of-week, so a machine asleep through Wednesday's trigger window no longer silently loses the week — see `docs/scheduled-tasks/README.md` → "Drift Review". That elapsed-days math now runs through `python3` (`datetime.date.fromisoformat`) instead of `date -d`, which is GNU-only: on macOS the epoch lookup always failed, the gate was skipped entirely, and the "weekly" review spawned a full `claude --print` session on every single orchestrator run. If `~/.env.channels` exists, it posts a 20-line tail summary of the run to chat channels via `.claude/scripts/integrations/channels/notify.py` (opt out with `SDD_SKIP_CHANNEL_NOTIFY=1`; no-ops silently when the env file or notifier is absent). See `SDD-USAGE.md` → "Daily Maintenance". |
| UserPromptSubmit (frontend-security-nudge) | Every user prompt (keyword-gated) | Fires when prompt contains build intent (`build a`, `create a`, `implement a`, `scaffold`, etc.) AND a frontend/UI keyword (React, Vue, Svelte, CSS, component, form, modal, etc.). Injects a reminder to invoke `secure-agent-design` before writing the first file. When the nudge fires, also appends a `[frontend-security-nudge]` observation to `observations.md`. Exits <5ms on non-matching prompts — zero overhead for non-frontend work. Script: `hooks/claude/frontend-security-nudge.sh`. |
| PreToolUse (prompt-quality-check) | Every `Agent` tool call | Scores the agent prompt against 6 PQ dimensions (context provision, request specificity, scope management, information timing, correction quality, overall) using fast Python heuristics — no LLM required. Outputs a scored report to Claude's context and appends a JSON entry to `~/.code-insights/pq-log.jsonl`. Scores < 3.5 surface improvement tips per dimension. Scores ≥ 4.0 confirm the prompt is ready. Script: `hooks/claude/prompt-quality-check.sh`. Dashboard: Session Quality → Prompt Quality (✨) sub-tab. |
| PostToolUse (skill-usage-tracker) | Every `Skill` tool invocation | Appends one `{"ts","skill"}` line to `logs/skill-usage.jsonl` — the evidence layer for skill deprecation (replaces guessing from file mtime). Consumed by the dashboard **Skill Changes → Skill Usage** panel (total/30d invocations, hot skills, cold-skill count where cold = no invocation in 30d) and the weekly skill-curator routine's Phase 1.5 Usage Evidence audit. No-ops if the log dir is unavailable. Script: `.claude/hooks/skill-usage-tracker.sh`. |
| Dashboard button (skill-curator controls) | Click **Analyze & Propose** / **Apply Approved** in the dashboard's **Skill Changes** panel (live/companion dashboard only — `python3 scripts/utils/dashboard.py`, not the `--static` export) | **Analyze & Propose** (`POST /api/skill-curator-propose`) spawns a detached headless `claude --print --permission-mode bypassPermissions` session that runs the `skill-curator` skill's Phases 1–4 against `reports/skill-curation-report.md` (rationale capped to 1–2 sentences per item), now including the report's `## Dependency Flags` section (Phase 1.6 — deletion/archive candidates cross-referenced by another skill, hook, agent, or command via `scripts/utils/skill-dependency-scan.sh`), and writes the numbered proposal to `.claude/memory/.skill-curator-proposal.md` instead of printing it to chat. The panel polls `GET /api/skill-curator-proposal` every 3s (up to ~40 tries, ~2 min) until the file appears, then renders it inline with an **Apply Approved** button, a **Re-analyze** button, and a free-text instruction box (default `apply all`). **Apply Approved** (`POST /api/skill-curator-apply?instruction=...`) first tars `~/.claude/skills/` to `.dashboard/skill-backups/skills-<timestamp>.tar.gz`, then spawns a second headless session that executes only the approved subset per Phases 5–6, appends the curation log entry to `reports/skill-curation-report.md`, and deletes the proposal file so it can't be re-applied. Both runs log for real — a timestamped header (prompt/instruction, backup path) plus the subprocess's full stdout/stderr go to `logs/skill-curator-propose.log` / `logs/skill-curator-apply.log`. Implemented in `scripts/utils/dashboard.py` (`_run_skill_curator_propose`, `_run_skill_curator_apply`, `_backup_skills_dir`, `read_skill_proposal`). |
| Dashboard (scheduler alarm banner) | Every render of the dashboard's **Scheduled Tasks** tab | A scheduler that is not installed, or whose last launch exited non-zero, now renders a full-width red banner **above** the routine cards (`_scheduler_banner()` in `scripts/utils/dashboard.py`), not a small yellow line inside the scheduler card. The banner states plainly that no routine below can run and that everything under it is stale regardless of its badge — the failure this exists for is a dead scheduler presenting as a page full of calm "PENDING" badges, which is how a fleet that had executed nothing for four days looked merely idle. launchd reports exit codes shifted left 8 bits (`32256` = exit 126), so the banner un-shifts before displaying, and on exit 126 it names the likely cause outright: the OS refused to execute the orchestrator, normally Full Disk Access when the harness sits under `~/Documents`, `~/Desktop` or `~/Downloads`. Footer points at `logs/orchestrator.stderr.log`. |
| PreToolUse (raindrop-best-practices) | Every `mcp__raindrop__` tool call | Injects five active-observability patterns before any Raindrop Workshop MCP call: batch facets (multiple dimensions → one LLM call), facet-first summarization before clustering, 128K token cap on input, no-LLM nearest-summary classification, and long-tail sampling with HDBSCAN. Reduces naïve trace analysis cost by ~80–90%. Script: `hooks/claude/raindrop-best-practices.sh`. |
| PreToolUse (rtk) | Every Bash tool call by any agent | `rtk hook claude` rewrites matching commands to `rtk <cmd>`, compressing output before it reaches the LLM (60–90%+ token reduction). Emits `permissionDecision: "allow"` so rewrites are silent. Passes through commands without filters unchanged. Global — fires in all sessions and projects. |
| PreToolUse (GitNexus) | Every file Read/Edit by any agent | Enriches file operations with 360° symbol graph context (callers, dependencies, process participation); no-ops gracefully when GitNexus is not installed |
| PreToolUse (memory-discipline) | Every Write/Edit to `*/memory/*.md` or `MEMORY.md` | Gates memory writes with discipline rules — valid content: workflow patterns, user preferences, reusable lessons. Invalid: case-specific facts, citations, investigation outcomes. Claude sees the rules before executing the write and can revise content. Implemented in `.claude/hooks/memory-discipline-hook.sh`. |
| PreToolUse (protected path) | Every Write/Edit to a sensitive path (`.env`, crypto keys, credentials, `.aws/`, `.ssh/`) | Injects a confirmation banner; Claude must pause and ask the user before proceeding. Prevents accidental overwrites of secrets files. Implemented in `.claude/hooks/protected-path-hook.sh`. |
| PreToolUse (git-destructive-guard) | Every Bash tool call | Hard block (exit 2, refuses the tool call — not a soft nudge): inspects the command text — with quoted segments (commit messages, PR bodies) stripped first, so a message that happens to mention "-f" or "force" inside quotes can't false-trip the block — for force-push variants (`--force`, `--force-with-lease`, `--force-if-includes`, `-f`), remote branch deletion (`--delete`, `--mirror`, empty-refspec `git push origin :branch`), local force branch delete (`git branch -D`), `gh repo delete`, or `git rebase` (rewrites shared history the same as a force-push; add a follow-up commit or a fresh branch instead). Built because the declarative allow/deny list alone was observed to not reliably block `git push --force` in some sessions. Implemented in `.claude/hooks/git-destructive-guard-hook.sh`. |
| PreToolUse (skill-validate) | Every Write to `~/.claude/skills/<name>/SKILL.md` | Validates skill frontmatter before writing: `name:` must be kebab-case and match the file path slug; `description:` must exist and be ≥25 chars; warns on vague description starters. Exit 2 hard-blocks on errors. Implemented in `.claude/hooks/skill-validate-hook.sh`. |
| PreCompact (compaction-discipline) | Every context compaction | Injects boundary-timing principle and state-preservation checklist: compact at workflow phase boundaries (not arbitrary turn counts), preserve artifact paths, cited facts, open questions, and decisions. Use anchored iterative summarization. Adds concrete, checkable fidelity requirements: mark every user question answered/partial/unanswered (with a "Pending Questions" subheading listing the rest verbatim); keep confirmed root causes (with file:line) separate from ruled-out hypotheses; group files into critical/referenced/mentioned tiers rather than a flat list; treat subagent/Task tool results as primary evidence to preserve in full, not compressible chatter; keep both sides plus the decision criteria of any A-vs-B comparison the user weighed. Also fires `scripts/session/write_handoff.py --trigger precompact`, writing a deterministic (non-LLM) snapshot of the session to `.claude/memory/handoff/latest.md` so working state survives independent of the in-context summary. Implemented in `.claude/hooks/compaction-discipline-hook.sh`. |
| PostToolUse (pr-auto-create) | Every successful non-force `git push` Bash command | Calls `scripts/pr/detect_base_and_create.sh`. If `.git/gh-stack` exists (a `stacking-pull-requests` stack is already active for this branch, initiated by `smart_commit.sh`), runs `gh stack submit --auto` to submit/update every layer's PR instead of bundling everything into one — covers a manual `git push` that bypassed `smart_commit.sh`'s own submit call. Otherwise, auto-detects the branch's true fork-point base (via `git merge-base` across all local/remote refs) and opens a single draft PR (`gh pr create --fill --draft`) if one isn't already open. Bails silently on force pushes, push failures, or if `gh` is missing. Implemented in `.claude/hooks/pr-auto-create-hook.sh`. |
| UserPromptSubmit (pr-mention-nudge) | Every user prompt (keyword-gated: `pr`, `pull request`, `open/create a pr`, `merge this`) | Calls the same shared `scripts/pr/detect_base_and_create.sh` as `pr-auto-create-hook.sh` — catches the case where a PR is requested before (or independent of) a push. Implemented in `.claude/hooks/pr-mention-nudge.sh`. |
| PostToolUse (hook-added-notify) | Every Write/Edit that creates a new `.claude/hooks/claude/*.sh` | Injects a reminder to document the new hook in `docs/hooks/README.md` (and the Wiring Reference table) before the session ends. Stays silent if the hook is already documented. Implemented in `.claude/hooks/hook-added-notify.sh`. |
| PostToolUse (lean-ctx nudge) | Every Read of a file ≥16 KB (~4,000 tokens) | Suggests the optimal `ctx_read` mode for the file type (`signatures` for code, `reference` for prose, `aggressive` for unknown); silent for small files and data formats (`.json/.yaml/.toml/.lock`). Implemented in `.claude/hooks/lean-ctx-nudge-hook.sh`. |
| post-commit (doc sync) | Every `git commit` with non-`.md` source changes | Doc-sync: updates all `.md` files referencing changed code via `claude --dangerously-skip-permissions --print`. The prompt is built here; the `claude` call itself is executed by the detached runner (stage 3). |
| post-commit (harness updater) | Every `git commit` touching harness source — `agents/`, `commands/`, `hooks/`, `kiro/`, `scripts/`, `rules/`, `templates/`, `skills/`, or `CLAUDE.md` | Updates `docs/harness-documentation/SDD-SETUP-GUIDE.md` via `claude --dangerously-skip-permissions --print`, executed by the detached runner (stage 3). Path-to-section routing is spelled out in the hook prompt (`rules/` → context engineering, `templates/settings*.template` → hooks/configuration, etc.) |

**Gotcha — `$TODAY_` vs `${TODAY}_`:** both the doc-sync and harness-updater prompts embed the literal instruction `Replace any existing '_Last synced' line with: _Last synced: ${TODAY}_`. Bash parses `$TODAY_` as a reference to a nonexistent variable named `TODAY_` (empty), not `$TODAY` followed by a literal underscore — this silently blanked the date stamp in every `.md` file the agents touched. Always brace variable references immediately followed by an underscore or other identifier character (`${VAR}_suffix`, not `$VAR_suffix`). Fixed in `hooks/git/post-commit`.
| post-commit (detached doc-sync runner + auto-sync `.md`) | Every `git commit` where the doc-sync or harness-updater guard fired — except commits whose subject starts with `docs: auto-sync` (the hook's own), which bail at the top, and commits arriving while a previous run still holds the lock | One fully-detached background job (`{ …; } </dev/null >>.git/post-commit-docsync.log 2>&1 &` + `disown`): takes an atomic `mkdir` lock on `.git/post-commit-docsync.lock`, then runs the doc-sync agent, then the harness-updater agent, then `git add -- '*.md'`, commits `docs: auto-sync (<date>)` scoped to `*.md`, and pushes. `git commit` returns immediately — nothing blocks the terminal. Only one run executes at a time: a concurrent run logs `=== skipped <date>: another doc-sync run is active ===` and exits, so rapid commits cannot spawn parallel agents that race on the git index and drop commits. The lock is released by an `EXIT` trap, and a stale one (>30 min) is stolen by the next run. Each agent is bounded by `timeout 900` / `gtimeout 900` when available. Never stages or pushes non-`.md` files; a failed push leaves the commit in place and logs a warning. The `.md`-only commit re-fires the hook, but the self-commit guard matches its `docs: auto-sync` subject and exits — no loop. Progress and errors go only to `.git/post-commit-docsync.log`. Runs at **every** `SDD_PROFILE` level, `minimal` included — git hooks are infrastructure, not enforcement (see Kiro Settings → Hook profiles). Script: `hooks/git/post-commit`. |
| Stop (address-check) | Every Claude session end | Checks the last assistant turn for the "Husband" address rule from `CLAUDE.md`. If missing, prints `[address-check] husband not found — compact needed` to stdout and exits 0 — a mechanical log line only, not fed back to Claude and not blocking the stop (no forced extra turn, no token cost). It used to exit 2 and inject a `/compact`-and-re-respond correction prompt; that self-correcting loop cost a full turn every time it fired, so the hook was demoted to a passive log. No-ops silently if transcript is unreadable. Script: `hooks/claude/address-check-hook.sh`. |
| Stop (caveman-savings) | Every Claude session end, once per calendar day, only when Caveman mode is active | Takes the last real assistant response and asks a cheap Haiku call to re-expand it into normal prose, then diffs response lengths (word-count heuristic, ~1.3 tokens/word) to produce a real sample of Caveman's token savings. Guarded against self-recursion via `SDD_CAVEMAN_MEASURING=1`. Appends a JSON line to `.claude/memory/caveman-savings.jsonl`, read by the dashboard's Budget & Efficiency → Compression Pipeline view and folded into the combined-savings total. Script: `hooks/claude/caveman-savings-hook.sh`. |
| PostToolUse (setup-buffer) | Every Bash command (atomic, ≤3 lines) | Detects setup-pattern commands (package installs, `docker compose`/`build`, DB create/migrate, `.env` sourcing/export, `git clone`, `make install`/`setup`/`init`) and appends them to `.claude/memory/.setup-session-buffer.log`; the Stop hook later folds the buffer into `.claude/memory/setup-knowledge.md`. Source: `hooks/claude/setup-buffer-hook.sh` → installed to `.claude/hooks/setup-buffer-hook.sh`; registered on `PostToolUse Bash` in both settings templates. |
| PostToolUse (skill-permissions-gate) | Every Write/Edit to `*/skills/*/SKILL.md` | Soft gate (never blocks): reminds Claude to run `agent-permissions-design` before marking a new/edited skill complete — checks tool access, irreversible-action gates, scope boundaries, and external-service access. Source: `hooks/claude/skill-permissions-gate.sh` → installed to `.claude/hooks/skill-permissions-gate.sh`; registered on `PostToolUse Write|Edit` in both settings templates. Fires only for paths matching `*/skills/*/SKILL.md`, so other `.md` writes are untouched. Its in-file `# REGISTRATION` comment now names `$SDD_HARNESS/.claude/settings.json` rather than a hardcoded `~/.claude/sdd-harness/...` path. |
| PreToolUse (ai-writing-guard) | Every Write/Edit/MultiEdit, and every Bash call that is a `git commit` or `gh` invocation | Hard deny (blocks the tool call): scans for AI-sounding buzzwords/clichés before they land in a file or a commit/PR body — scoped narrowly so it never flags real code. Markdown files (`.md/.markdown/.mdx/.txt`): whole text, minus fenced/inline code. Hash-comment languages (`.py/.sh/.yaml/...`): only `#` comments and docstrings. C-style languages (`.js/.ts/.java/...`): only `/* */` and `//` comments. Bash: only the `-m/--message/-b/--body/-t/--title` text or heredoc body of a `git commit`/`gh` command — never the rest of the command line. Flags buzzword swaps (`leverage`→`use`, `utilize`→`use`, `delve`→`look at`, etc.), AI-cliché phrases (`a testament to`, `it is important to note`, `in conclusion`, …), words like `crucial`/`significant`/`moreover` used ≥3× in one write, and stray `§` marks. Em-dash is deliberately exempt — it's this harness's own doc/hook house style. Ported from claude-codex-settings' "humanize" plugin. Implemented in `.claude/hooks/ai-writing-guard-hook.sh`. |
| UserPromptSubmit (reject-feedback) | Every user prompt | Soft (never blocks): walks the transcript backward for a just-rejected/interrupted tool call, and if the user's next prompt reads as an explanation for that reject, classifies it into a reason (`wrong_target`, `tool_steering`, `scope_drift`, `verify_first`, `rule_setting`, `factual_challenge`) and appends a `[friction]` observation to the same `observations.md` that `revert-detect-hook.sh` and `action-capture.sh` already write to — no new file or ledger. Noise (profanity, bare "no", "try again") is deliberately not logged. Distinct from the tool-failure-memory hooks, which fire on a command that *ran and errored*, not one the user declined before it ran. Ported from claude-codex-settings' claude-telemetry-hooks plugin (OTel export dropped — no backend configured). Implemented in `.claude/hooks/reject-feedback-hook.sh`. |

---

## Global Hooks (bundled — auto-installed by `install.sh`)

These hooks live in `~/.claude/hooks/` (not per-project `.claude/hooks/`) and fire from `~/.claude/settings.json`. They are stored in the harness at `hooks/global/` and installed by `install_globals()` during `install.sh`. No manual copy needed.

| Hook | Script | Purpose | Setup |
|---|---|---|---|
| **Caveman mode (activate)** | `~/.claude/hooks/caveman-activate.js` | Injects terse-response mode at session start. Reads `~/.claude/.caveman-active` for mode level (defaults to `lite`). Requires `node` in PATH. | Auto-installed by `install.sh`; default level `lite` created if not present |
| **Caveman mode (tracker)** | `~/.claude/hooks/caveman-mode-tracker.js` | Fires on `UserPromptSubmit` to sustain caveman mode across turns | Auto-installed by `install.sh` |
| **lean-ctx bash rewrite** | `~/.claude/hooks/lean-ctx-rewrite.sh` | Rewrites common shell commands through `lean-ctx` for compressed output | Auto-wired in `~/.claude/settings.json` by `install.sh` if `lean-ctx` CLI is detected |
| **lean-ctx read redirect** | `~/.claude/hooks/lean-ctx-redirect.sh` | No-op placeholder that allows native Read so Edit works | Auto-wired alongside lean-ctx rewrite hook |
| **Caveman statusline (badge + context meter)** | `~/.claude/hooks/caveman-statusline.sh` | Renders the `[CAVEMAN]` badge and savings suffix (gated on caveman mode being active), plus a **live context-usage meter** (`NN%ctx`, color-coded green/yellow/red at 70%/90%) parsed from `context_window.used_percentage` in the JSON Claude Code pipes to the statusline script on stdin — this part renders regardless of caveman mode. Best-effort persists the last-seen percentage per repo (keyed by `sha256(repo_path)[:16]`, since `CLAUDE_CONFIG_DIR` is machine-global) to `~/.claude/dashboard-context/<key>.json`, which `scripts/utils/dashboard.py`'s `_live_context_card()` reads (state older than 15 min is treated as a closed session and not shown). Opt out of the meter with `CAVEMAN_STATUSLINE_CONTEXT=0`; opt out of the savings suffix with `CAVEMAN_STATUSLINE_SAVINGS=0`. Requires `python3` for the JSON parse; no-ops silently without it. | Registered via `"statusLine"` in `~/.claude/settings.json`; auto-installed by `install.sh` |

> **Note:** `install.sh` copies `hooks/global/*` → `~/.claude/hooks/` and patches `~/.claude/settings.json` automatically. Caveman defaults to `lite`; override by writing `~/.claude/.caveman-active` with `full` or `ultra`. lean-ctx hooks only wire if the `lean-ctx` CLI is installed.

---

## Context Engineering Rules (`rules/`)

Context rules live in the harness source tree at `rules/` and are synced into every project at `.claude/rules/` by `install.sh` and `update.sh` (`sync_dir "$HARNESS_DIR/rules" "$PROJECT_DIR/.claude"`). They are loaded per session, so they count toward the startup token tax audited by `startup-payload-audit.sh` — keep them short.

| Rule file | Installed to | Purpose |
|---|---|---|
| `rules/lean-ctx.md` | `.claude/rules/lean-ctx.md` | Context Engineering layer. Mandatory mapping of native tools to `ctx_*` MCP equivalents (`ctx_read` / `ctx_search` / `ctx_shell`; editing is now `ctx_patch` after `ctx_read(mode="anchored")` — the old `ctx_edit` tool is gone), the `ctx_read` mode-selection table (`full`, `signatures`, `diff`, `map`, `lines:N-M`, `auto`), a **Profile: `standard`** section documenting the 17 tools actually advertised in the schema (`ctx_callgraph`, `ctx_compose`, `ctx_delta`, `ctx_execute`, `ctx_expand`, `ctx_explore`, `ctx_glob`, `ctx_graph`, `ctx_knowledge`, `ctx_overview`, `ctx_patch`, `ctx_read`, `ctx_search`, `ctx_session`, `ctx_shell`, `ctx_tree`, `ctx_url_read`) — the other ~66 tools are trimmed from the schema but still callable via `ctx_call {"name":"<tool>","arguments":{...}}`, discoverable with `ctx_call {"name":"ctx_discover_tools",...}`; deprecated names to avoid: `ctx_semantic_search`, `ctx_symbol`, `ctx_multi_read`, `ctx_smart_read` (semantic search is now `ctx_search(action="semantic")`); the bare `shell` alias was removed in favor of `ctx_shell`. The 6-step orient → locate → read → edit → verify → record workflow, proactive calls (`ctx_overview`, `ctx_knowledge(wakeup)`, `ctx_compress` via `ctx_call`), the compression-bypass escalation ladder, the pre-edit risk gate (`ctx_callgraph(action="callers")` + `ctx_graph` for file-level deps, `ctx_impact` via `ctx_call` for a wider blast radius, plus `mcp__serena__find_referencing_symbols` for Python symbols), and session start/end conventions. The closing rule now reads "prefer ctx_* over native Read/Grep/Shell/Glob" with two explicit exceptions — the edit gate (read-before-write) and `~/.claude/projects/<slug>/memory/` files — replacing the old unconditional "NEVER use native Read/Grep/Shell." Versioned by the `<!-- lean-ctx-rules-v11 -->` marker so `update.sh` can detect drift. |

Editing rule: change `rules/*.md` in the harness source tree, then run `update.sh`. Never edit `.claude/rules/*.md` in a project — it is regenerated output and will be overwritten.

> **Where lean-ctx keeps its savings data.** The dashboard's token-savings figures come from `$XDG_DATA_HOME/lean-ctx/stats.json` and `.../savings/ledger.jsonl`, defaulting to `~/.local/share/lean-ctx/` — **on macOS too**. lean-ctx does not follow the macOS "Application Support" convention that `dashboard.py`'s generic `_platform_data_dir()` assumes for other apps, and `~/.config/lean-ctx/` holds only `config.toml`. Resolving through the generic helper pointed the dashboard at a directory that never contains the ledger, so savings read as zero on macOS.

---

## Kiro Settings — Rules & Templates (`kiro/settings/`)

Harness-internal rules and document templates live at `kiro/settings/` in the source tree and are synced to `.claude/kiro/settings/` by `install.sh` / `update.sh` (see Step 4 path remap). Unlike `rules/`, these are **not** loaded every session — commands and agents reference them on demand, so they cost no startup tokens.

| Path | Purpose |
|---|---|
| `kiro/settings/rules/*.md` | Behavioral rules referenced by commands/agents on demand — spec phases, task generation, agent output format, alignment scoring, steering principles, test backlinks, frontend anti-patterns, memory conventions, hook profiles |
| `kiro/settings/templates/steering/` | Steering document templates used by `/kiro:steering` |
| `kiro/settings/templates/steering-custom/` | Templates for `/kiro:steering-custom` domain docs |
| `kiro/settings/templates/memory/` | Memory bootstrap templates copied into `.claude/memory/` (Step 12) |
| `kiro/settings/templates/skill-extraction-plan.md` | Plan scaffold used by `/kiro:skill-extract` |

### Hook profiles (`kiro/settings/rules/hook-profiles.md`)

Graduated automation levels selected with the `SDD_PROFILE` environment variable:

| Profile | Session hooks (`stop-hook.sh`) | Git hooks | Use for |
|---|---|---|---|
| `minimal` | Skipped entirely | Run normally | Rapid prototyping, exploratory work, small fixes |
| `standard` (default when unset/empty) | All checks run | Run normally | Normal development |
| `strict` | All checks run | Run normally | Production-bound code; also run `/kiro:verify quick` manually before committing |

```bash
export SDD_PROFILE=minimal          # persistent
SDD_PROFILE=strict git commit -m "release prep"   # per-invocation
```

Hook scripts guard at the top with `SDD_PROFILE="${SDD_PROFILE:-standard}"` and `exit 0` when it is `minimal`.

**Git hooks ignore the profile** — they are infrastructure, not enforcement. The one unconditional exit is the self-commit guard: a commit whose subject starts with `docs: auto-sync` (the hook's own) skips every stage at every profile level. Otherwise the post-commit third stage runs everywhere: the detached runner executes the doc-sync and harness-updater agents, then stages, commits, and **pushes** only `*.md` files at *every* profile level, `minimal` included. So a `minimal` session still touches the network and the remote on commit — asynchronously, after `git commit` has already returned, with the outcome recorded in `.git/post-commit-docsync.log` rather than the terminal.

That stage is also **serialized at every profile level** on `.git/post-commit-docsync.lock` (atomic `mkdir`). If a previous run still holds the lock, the new run logs `=== skipped <date>: another doc-sync run is active ===` and exits without running the agents, so rapid successive commits never spawn parallel agents that race on the git index. A lock older than 30 minutes is stolen; a normal exit removes it via an `EXIT` trap. Consequence for `minimal`: a fast commit burst may leave later commits' doc sync to the run already in flight or the next commit — not to a per-commit run.

---

## Skills (`skills/`)

Skills live in the harness source tree at `skills/<name>/SKILL.md` (999 skills currently). `install_globals()` in `install.sh` syncs each one into `~/.claude/skills/<name>/`, so skills are **machine-global**, not per-project — one install serves every repo.

- Adding a skill: create `skills/<name>/SKILL.md` with kebab-case `name:` matching the directory and a `description:` of ≥25 chars (enforced by the `skill-validate` PreToolUse hook), then run `install.sh` / `update.sh`.
- Every write to a `*/skills/*/SKILL.md` also trips the **skill-permissions-gate** PostToolUse hook — a soft reminder to run `agent-permissions-design` (tool access, irreversible-action gates, scope boundary, external access) before calling the skill done.
- Usage is logged to `logs/skill-usage.jsonl` by the `skill-usage-tracker` hook and reviewed by the weekly skill-curator routine.
- **Never hardcode the harness path inside a skill.** Skill bodies that need to point at the harness source write `$SDD_HARNESS/...`, not `~/.claude/sdd-harness/...` (and certainly not a literal `/home/<user>/...`, which `repo-drift-review` carried until it was caught). `$SDD_HARNESS` is exported by `install.sh` / `update.sh` into `~/.zshrc` / `~/.bashrc`, so it resolves on every machine regardless of where the harness was cloned; the `~/.claude/sdd-harness` symlink is a convenience derived from `~/.sdd-harness-root`, not a stable address to write into docs. Converted in this pass: `gitnexus`, `hook-design`, `privacy-filter`, `repo-drift-review`, `skill-curator`, `skill-extraction`, `verification-skill-authoring`. `scripts/utils/check-no-hardcoded-paths.sh` excludes `skills/**` (vendored third-party skills record other people's home paths in benchmark output), so this one is convention, not an enforced gate — check it by eye when authoring.
- **Generated reports go to `reports/`, not `docs/`.** Every skill and routine that writes a recurring machine-local report now targets the gitignored `reports/` directory: `skill-curator` and `skill-eval-gate` → `reports/skill-curation-report.md`, `repo-drift-review` → `reports/drift-review-report.md`, `sonar-hotspot-review` → `reports/sonar-hotspot-review.md`, and the harness-health routine → `reports/claudemd-review-report.md` (Phase 1) plus `reports/skill-curation-report.md` (Phase 2). `docs/` is committed documentation and is swept by doc-sync; a routine report landing there gets committed and treated as prose it isn't. See Step 1 for the matching `.gitignore` entry.
- `skills/writing-behavior-specs` — authors and revises `.claude/behaviors/<name>/BEHAVIOR.md` conduct specs: answer-key material for grading a completed trajectory, deliberately kept blind from the agent being graded (unlike `CLAUDE.md` rules or a `<domain>-verify` skill, both read by the agent mid-work). Invoked automatically by `behavior-spec-agent` during nightly maintenance, not meant to be run on demand. Covers deciding whether a candidate behavior belongs (`references/deciding-what-to-save.md` — needs a recognizable situation, a meaningful choice, and provable trajectory evidence; rejects generic virtues, tool syntax, one-off procedures, and disguised outcome rubrics), writing the spec (Intent/Evidence/Decision/Execution/Recovery/Failure-modes dimensions, used only where they add clarity), and calibrating it against positive/negative/outside-scope/lucky-correct-negative trajectories (`references/calibrating-with-trajectories.md`) before validating structurally with `scripts/validate-behavior-spec.py`. Source: [braintrustdata/agentbehavior](https://github.com/braintrustdata/agentbehavior).
- `skills/stacking-pull-requests` — reference skill for the harness's automated stacked-PR flow (GitHub's native stacked PRs via the `gh-stack` CLI extension, public preview 2026-07-30), mapping one SDD task commit to one stack layer instead of bundling a whole spec into a single PR. The automation itself lives in two scripts, not in this skill: `skills/git-pushing/scripts/smart_commit.sh` detects eligibility and inits/adds layers, `scripts/pr/detect_base_and_create.sh` runs `gh stack submit --auto` instead of `gh pr create` once a stack is active. Load this skill only when a stack needs manual intervention (sync conflict, reordering, abandoning), when tuning the auto-trigger threshold (`SDD_STACK_MIN_TASKS`, default 2; `SDD_SKIP_STACK` to disable), or when explaining why a branch did/didn't stack — not as a `gh stack` CLI tutorial.
- `skills/git-pushing` — `smart_commit.sh` now auto-detects a stacked-PR-eligible branch on its first task commit (per `stacking-pull-requests`) and routes every subsequent commit through `gh stack add` + `gh stack submit --auto` instead of a plain `git commit`, falling back to a plain commit if `gh stack add` ever fails mid-stream.
- `skills/issue-triage-routing` — added a fourth triage axis, **Scale** (program-scale: spans multiple decisions that each deserve their own spec, vs. feature-scale: maps to one spec), checked *before* ambiguity/complexity since a program-scale idea can read as simple in one sentence. New **PROGRAM** route (precedence: defer beats program beats clarify beats spec beats one-shot) sends program-scale, on-roadmap ideas to `/kiro:idea-refine`'s map-charting instead of straight into `spec-quick`.
- `skills/secure-agent-design` — added **Pattern 7: Provider-State Portability & Audit Trail**, covering stateful/hosted-provider LLM architectures (OpenAI Responses API, Anthropic extended thinking, Gemini Interactions API) where opaque server-bound state (encrypted reasoning, hosted-tool results, compaction summaries, encrypted subagent messages, server-keyed conversation IDs) silently breaks inspection, export, replay, audit, or deletion. Adds a five-criteria pre-ship checklist and the rule that every such agent keeps its own independently-held, human-readable transcript rather than relying solely on a provider-side ID.
- `skills/evaluation/micro` — added an **Error-Analysis Bootstrap** (extracted from Hamel Husain's `error-analysis` skill) to run *before* rubric design when there's no failure taxonomy yet: collect ~100 traces, read and note the first root-cause per failure, cluster into 5–10 categories once 30–50 are read, label every trace, compute failure rates, then decide per category (direct fix first; only build an evaluator — code-based for objective failures, LLM-judge for subjective ones — if the failure persists). Output goes to `.claude/memory/failure-taxonomy-<YYYY-MM-DD>.md`.
- `skills/csv-data-summarizer` — analyzes a CSV end to end without asking questions: pandas stats, missing-data audit, and only the charts the data supports (time-series only with a date column, correlation heatmap only with ≥2 numeric columns, frequency counts for categoricals), closing with 2–4 dataset-grounded insights. Ships a bundled `analyze.py` (`summarize_csv(file_path)`) run as `python ~/.claude/skills/csv-data-summarizer/analyze.py <file.csv>` — with no argument it falls back to `resources/sample.csv`. It writes fixed-name PNGs (`correlation_heatmap.png`, `time_series_analysis.png`, `distributions.png`, `categorical_distributions.png`) into the **current working directory**, and the skill's `.gitignore` ignores `*.png` so generated charts stay untracked. Fixtures: `resources/sample.csv` (21 rows of sales data) as the test fixture, `examples/showcase_financial_pl_data.csv` (45 rows = 15 months × 3 product lines, 25 financial metrics) as a larger demo input; if pandas/matplotlib/seaborn are missing, the skill writes the equivalent inline. Requires `python>=3.8`, `pandas`, `matplotlib`, `seaborn`. Upstream origin: [coffeefuelbump/csv-data-summarizer-claude-skill](https://github.com/coffeefuelbump/csv-data-summarizer-claude-skill). Tracked as **ordinary files in this repo** — edit under `skills/csv-data-summarizer/` and commit in the parent repo like any other skill, then run `install.sh` / `update.sh` to sync it to `~/.claude/skills/`. The skill's `.gitignore` un-ignores `csv-data-summarizer.zip` so the packaged bundle is committed alongside the source.
  - **Vendoring gotcha (fixed 2026-07-28)** — the skill was originally dropped in with its upstream `.git/` directory intact. Git treated `skills/csv-data-summarizer/` as an **embedded nested repo**, so only the files git happened to see (`SKILL.md`, `README.md`, `resources/README.md`) were tracked in the parent; the payload — `analyze.py`, `requirements.txt`, `.gitignore`, `csv-data-summarizer.zip`, `resources/sample.csv`, `examples/showcase_financial_pl_data.csv` — never traveled on clone. A fresh clone plus `install.sh` therefore installed a skill whose bundled script did not exist. The fix was to delete the nested `.git/` and commit the files as ordinary tracked files (`49882a5`). There is no `.gitmodules` entry and this skill is **not** a submodule. **When vendoring any external skill: remove its `.git/` first, then verify with `git ls-files skills/<name>/` that every payload file is actually tracked.**
  - **Reference shape for skill authoring**: `SKILL.md` was cut from ~149 lines to ~36 by deleting the shouty-prohibition block (`⚠️ CRITICAL BEHAVIOR REQUIREMENT`, the DO/NEVER-SAY/FORBIDDEN lists, worked example output, per-industry adaptation table) and stating the rule once positively — "run the full analysis immediately and present complete results in one response; do not ask what they want, list options, or offer choices" — followed by a 4-step **Procedure**, a **Bundled script** section, and two hard **Constraints** (report missing values rather than silently dropping; include every numeric column in the summary). Behavior is unchanged; the token cost is not. Prefer this shape for new skills.
  - The `name`/`description` frontmatter carries the trigger conditions (`Use when the user shares or references a CSV wanting a summary, analysis, or insights`) so routing no longer depends on a prose "When to Use This Skill" section. The `metadata.version` key was dropped — git is the version record — and `metadata.dependencies` is now unpinned (`python>=3.8, pandas, matplotlib, seaborn`); the pinned minimums (`pandas>=2.0.0`, `matplotlib>=3.7.0`, `seaborn>=0.12.0`) live in the skill's `requirements.txt`, which is the single source of truth for versions.
  - **Bundle layout** — a skill is not limited to `SKILL.md`. `install_globals()` calls `sync_dir` on the whole `skills/<name>/` directory, so every payload file lands in `~/.claude/skills/<name>/` with the same relative paths the `SKILL.md` references. `csv-data-summarizer` is the worked example:
    ```
    skills/csv-data-summarizer/
    ├── SKILL.md                              # skill definition (frontmatter + procedure)
    ├── README.md                             # human-facing docs (upstream origin, features, example output)
    ├── analyze.py                            # bundled script — summarize_csv(file_path), 150 dpi PNGs
    ├── requirements.txt                      # pandas>=2.0.0, matplotlib>=3.7.0, seaborn>=0.12.0 — source of truth for versions
    ├── .gitignore                            # Python/IDE/OS artifacts + *.png; un-ignores csv-data-summarizer.zip
    ├── csv-data-summarizer.zip               # packaged bundle for the Claude.ai Settings → Capabilities → Skills uploader
    ├── examples/showcase_financial_pl_data.csv   # larger demo input
    └── resources/
        ├── sample.csv                        # 21-row test fixture
        └── README.md                         # fixture columns + local testing steps
    ```
    Because the paths survive the sync, a bundled script must be invoked at its installed location (`python ~/.claude/skills/<name>/analyze.py …`), and any fixture the script defaults to must sit under the skill directory. The `.zip` is only for the Claude.ai web uploader — Claude Code loads the skill from `~/.claude/skills/` directly and never reads it.
- `skills/local-llm-eval` — the backing script `.claude/scripts/ollama_model_test.py` (OMT, sourced from `scripts/utils/ollama_model_test.py`) is no longer Ollama-only. Two additions:
  - **Custom runner (`--runner PATH`)** — points OMT at any CLI-wrapped model or agent instead of a local Ollama model. Requires `--model` (there's no model-discovery step for custom runners, unlike the Ollama path which lists installed models via `list_ollama_models()`). The runner executable is invoked once per run with the prompt on stdin and `OMT_MODEL`/`OMT_PROMPT`/`OMT_RUN_DIR` set in its environment; its stdout becomes the recorded response (`run_via_custom_runner()`). Example: `python3 .claude/scripts/ollama_model_test.py --model my-agent-v2 --runner ./scripts/my_agent_runner.sh --prompt-file prompt.txt --runs 3`.
  - **Automated grading (`--checker PATH`, Phase 6)** — replaces eyeballing output with a pass/fail verdict. The checker executable runs once after all generations for a model complete, with `OMT_RUN_DIR`/`OMT_MODEL` set in its environment, and must print JSON (`{"pass": bool, "score": number, "notes": str}`). `run_checker()` validates the JSON and the required `pass` key; `write_grades_file()` appends the verdict to `grades.json` in the run directory (parallel to `metadata.json`) and prints a `Checker verdict: PASS/FAIL` line to the console. Works with both the Ollama path and `--runner`. Omitting `--checker` preserves the original human-eyeballing workflow with no behavior change.
- `skills/skill-curator` — the weekly automated sweep (`scripts/routines/skill-curator-runner.sh` + `scripts/routines/skill-curator-prompt.md`) gained a **Phase 1.6 — Dependency Cross-Reference**, run *before* Phase 1's low-quality audit even fires. A new deterministic script, `scripts/utils/skill-dependency-scan.sh`, greps every skill name (word-boundary, `grep -rn -w`) across other skills' `SKILL.md` bodies plus `hooks/`, `agents/`, `commands/`, `kiro/settings/rules/`, `scripts/routines/`, and `CLAUDE.md`, emitting `path:line` locations only (never the matched line text, to avoid a common-word skill name burying the report in noise) and capping each skill to 8 referrers (`+N more` beyond that). The runner splices this map into the prompt's `DEPENDENCY_MAP_PLACEHOLDER` via a temp-file `sed` `r`/`d` insert rather than a variable substitution, since referrer paths can contain `&`/`\` that both `sed` and `awk` treat specially in replacement text. Phase 4's report now has a **mandatory** `## Dependency Flags` section (must appear even when empty, with an explicit "no dependency flags" fallback line) listing any skill that is BOTH a low-quality/cold candidate (Phase 1 / Phase 1.5) AND cross-referenced per the Phase 1.6 map. The interactive `skill-curator` skill treats this section as ground truth (never re-derives it) and gained a new **Delete + migrate references** action type distinct from a plain **Delete** — referrers must be updated or explicitly waived by the user before the flagged skill's directory is removed, never a bare delete.
- `skills/cma-advisor` **(new)** — lets a Claude Managed Agents (CMA) working agent consult a stronger model mid-turn on a single high-stakes/irreversible decision via a reserved `advisor` roster entry (`multiagent.agents`). Covers roster setup (at most one advisor per roster, reserved `anthropic.advisor` name, no per-input tool — consultation policy lives in the system prompt), bounding total spend via a session `budget` (no per-call cap exists), monitoring consultations as thread lifecycle events on the session stream, and retrieving per-consultation cost. Sibling to `cma-outcomes` (post-hoc grade-and-revise, a different mechanism) — don't conflate the two.
- `skills/prototype` **(new)** — build throwaway code to answer a design question the conversation can't settle by talking in circles: `LOGIC.md` (a single shareable HTML file exercising a state machine through hard-to-reason-about cases) for "does this logic feel right?", `UI.md` (several radically different UI variations on one route, switchable via URL param) for "what should this look like?". Rules for both: throwaway from day one and clearly marked, trivial to run, no persistence by default, no polish, surface full state after every action, and capture the validated decision back into real code (with the prototype itself committed to a scratch branch as a primary source) when done. Adapted from mattpocock/skills (MIT).
- `skills/wizard` **(new)** — generates an interactive bash wizard (`template.sh`) that walks a human step-by-step through a manual procedure an agent can't do itself: provisioning infrastructure, setting up credentials/CI secrets, clicking through an unfamiliar third-party dashboard, or a one-off migration/cutover. The template supplies the UX (stage progress, confirmation gates, cross-platform URL opening, hidden secret entry, idempotent `.env` upserts, `gh secret`/`gh variable` writes) — authoring a wizard means only scoping the procedure's stages and writing each stage's `open_url`/`ask`/`write_env`/`set_secret` calls, never hand-editing the library above the `STAGES` marker. Generic form of the pattern `scripts/setup/headroom-setup.sh` and `gitnexus-setup-agent` already hand-build. Adapted from mattpocock/skills (MIT).
- `skills/agent-manager-skill` — retargeted from a tmux-only tool to **Herdr-first**: Path 1 controls Herdr-managed panes (`herdr agent start/prompt/wait/get/read/send-keys`, gated on `HERDR_ENV=1` — never control a Herdr session from outside Herdr, never install/launch Herdr silently), falling back to the original tmux+python3 wrapper (Path 2) only when Herdr isn't available. Scope is explicitly *other terminal panes*, not in-process `Agent`/`Task` orchestration (`dispatching-parallel-agents`/`multi-agent-patterns` territory).
- `skills/git-advanced-workflows` — added a **Resolving Merge Conflicts** pointer to a new `references/git-conflict-resolution.md`: reconstruct why each side's change exists before resolving, preserve both intents where compatible, run project checks before finishing, and never `--abort` as an escape hatch (it just defers the same conflict to whoever merges next with less context).
- `skills/keep-rate` — added **AI Adoption %** (`claude_commits / total_commits` over a 30-day window), a distinct volume metric from Keep Rate's durability metric — a high adoption % with a low keep rate is a real, different signal from the reverse. Recorded alongside Keep Rate in Step 5/6 as a separate `[ai-adoption]` observation line. Surfaced in the dashboard's Session Quality panel as a 4th stat card + glossary entry (`scripts/utils/dashboard.py`).
- `skills/model-tiers` — added **Cascade Escalation**, the per-call counterpart to the existing session-level tier judgment: try the cheap tier first on every call, escalate only calls that fail a confidence/quality check (arXiv 2305.05176 reports up to 98% cost savings vs. always using the top tier). Scoped explicitly to this harness's own Claude-tier routing (haiku/sonnet/opus/fable) — not the cross-provider trained-classifier machinery of RouteLLM-style routers. Worth building only for a high-volume task class with a cheap, reliable confidence signal.
- `skills/prompt-caching` — Response Caching section now spells out the 3-step store/match/serve-or-call mechanism (one production case: 61.6–68.8% hit rate, 92.5–97.3% positive-hit accuracy per arXiv 2411.05276) and a **fit caveat for this harness**: the technique's premise (~30% semantically-similar traffic, arXiv 2508.07675) is a multi-user high-QPS assumption that doesn't obviously hold for a single-developer harness with no embedding/vector-store infra — treat the section as reference for products this harness helps build, not a recommendation to add caching to the harness's own operation.
- `skills/rtk-token-reduction` — added **TALE-EP** (estimate-then-constrain) for sizing a subagent token cap instead of guessing a fixed number: ask the model zero-shot for its minimum-needed tokens, then feed that back as the actual budget (~67% avg output reduction, <3% accuracy drop across 7 benchmarks per arXiv 2412.18547). Caveat: compression isn't uniformly safe — arithmetic/multi-step-math subtasks lose ~4 accuracy points at an 80% token cut where commonsense/symbolic tasks lose nothing, so don't apply a tight budget uniformly. Newer Claude models (Opus 4.7+) don't take a raw `budget_tokens` parameter — use `effort` instead.
- `skills/iterative-repair-loop` — added a **held-out set** guard: reserve ~20% of validation cases untouched during iteration (Phase 2 never sees them, Phase 3 doesn't score against them until after convergence), then re-run them once the loop reports `passed: true`. A visible-case pass that fails held-out cases means the loop gamed the rubric, not solved it — treat as FAIL, not a partial win; skip for artifacts with <5 total cases. Also added a **flaky-result rule**: if a case's pass/fail flips across two identical re-runs, don't average it away — stop the loop, report it as a finding, and fix the source of non-determinism before resuming. New terminal outcomes `Held-out FAIL` and `Flaky result` and a `Held-out check:` line added to the completion report template.
- `skills/agent-memory-systems` — added **File-Based vs Structured Memory: When Files Lose**, benchmarking this harness's own default (markdown + grep under `.claude/memory/`) against embedded atomic-fact stores on LongMemEval-S: 44.9% vs 73.6% accuracy, 665k vs 27k tokens per correct answer (~25x), with the gap widening a further 15pts at 500-session scale — files win only on abstention accuracy (88.9% vs 77.8%). The practical read is deliberately narrow: file-based memory is fine for what the harness actually uses it for (session-scoped recall, small fact counts, human-readable audit trail) and degrades specifically on cross-session joins and temporal aggregation over long history. Adding a structured layer is warranted when a real need to query "what changed across N sessions" appears — not before.
- `skills/memory-systems` — the "❌ Knowledge graphs for agent memory" anti-pattern gained a nuance line so it isn't read as "structure loses": the measured loss belongs to *LLM-distilled* graphs (Zep 74.6%, Graphiti 53.4% on LongMemEval), while raw dated-fact stores with no distillation step score ~78% — beating both files and distilled KGs at 6x less context and 400x less ingest cost. The failure mode is the distillation step's information loss, not structure itself.
- `skills/multi-agent-patterns` — added **"Scale scrutiny to blast radius, not nesting depth"**: the risk signal for a post-condition gate is an agent-generated artifact's graph position (fan-out to downstream consumers), not how deep it sits in the subagent delegation chain. A leaf node feeding one consumer tolerates a light post-condition; a node whose output fans out broadly (a plan several executors follow, a routing classification) needs a proportionally stronger gate — dedicated verifier, schema-constrained output, evidence traveling with the conclusion, N-way independent production, or human approval before further fan-out.
- `skills/gitnexus-debugging`, `skills/gitnexus-exploring`, `skills/gitnexus-impact-analysis`, `skills/gitnexus-pr-review`, `skills/gitnexus-refactoring` — every worked example and tool-call reference was rewritten from bare `gitnexus_query`/`gitnexus_context`/`gitnexus_impact`/`gitnexus_detect_changes`/`gitnexus_rename`/`gitnexus_cypher` to the `mcp__gitnexus__*`-prefixed form the MCP server actually exposes. The bare names never resolved as callable tools; `scripts/setup/gitnexus-reconcile.sh`'s new `fix_tool_names()` (see GitNexus section below) performs the equivalent rewrite on the managed block it writes into `CLAUDE.md`/`AGENTS.md`, so the skill bodies and the generated project block are now consistent.
- `skills/lean-ctx` — tool count bumped 69 → 83; the "Core Tools (10 always visible)" table was replaced with **"Advertised Tools (profile `standard` — 17)"**, listing all 17 schema-visible tools (adds `ctx_callgraph`, `ctx_compose`, `ctx_delta`, `ctx_execute`, `ctx_expand`, `ctx_explore`, `ctx_glob`, `ctx_graph`, `ctx_patch`, `ctx_url_read`; drops `ctx_edit` and `ctx_call` from the always-visible list) with a note that the other ~66 tools are reachable via `ctx_call {"name":"<tool>","arguments":{...}}`. File Editing now reads "Use native Edit/StrReplace. If unavailable, use `ctx_patch` after `ctx_read(mode="anchored")`" (was `ctx_edit`). The "More Tools" section spells out the `ctx_call`/`ctx_discover_tools` invocation syntax and notes `ctx_callgraph`/`ctx_graph` are already advertised (only `ctx_impact`, `ctx_architecture`, `ctx_routes`, `ctx_smells` need `ctx_call`); symbol lookups route through `ctx_search(action="symbol")`.

---

## Jira Integration (Optional)

The harness includes an optional hook pair that automatically posts a Jira comment describing what was done every time you push code after a `jira-solve` session.

### How it works

1. **Ticket capture** (`UserPromptSubmit` hook — in `~/.claude/settings.json` globally):
   When you type `/kiro:jira-solve TICKET-ID`, the hook extracts the ticket ID and writes it to `~/.claude/state/active_jira_ticket`. This is a fire-and-forget async hook that never blocks Claude.

2. **Post-push comment** (`PostToolUse Bash` hook — in `.claude/settings.json`):
   After any `git push` command, the hook checks if a Jira session is active. If so, it calls `.claude/scripts/integrations/jira/jira_push_comment.py`, which:
   - Reads `origin/main..HEAD` git log and diff stats
   - Finds the most recently modified `.md` in `docs/` mentioning the ticket
   - Assembles a Jira wiki-markup comment (branch, commits, approach, files changed)
   - Posts it via `jira_client.py` and deletes the state file (single-fire)

### Issue routing

Before doing any work, `/kiro:jira-solve` applies a pre-gate: `Skill("issue-triage-routing")` runs against the fetched issue first. If it routes to **DEFER** (off-roadmap) or **CLARIFY** (ambiguity blocks a spec), that verdict is honored immediately — type-based routing below only runs once triage yields **SPEC** or **ONE-SHOT**.

Once past the pre-gate, routing is by issue type:
- Bug / Defect → systematic debugging workflow (`@agents-debug`)
- Story / Feature / Epic → `/kiro:spec-quick` seeded from Jira context
- Task / Sub-task / Improvement / Chore → direct implementation plan

Issue analysis itself is delegated to the `jira-solve-agent` subagent (see Subagents section), which converts the issue JSON into a structured problem statement and searches the repo for relevant files.

### Scripts

| Script | Location | Purpose |
|---|---|---|
| `jira_client.py` | `.claude/scripts/integrations/jira/jira_client.py` | Stdlib-only Jira REST API client (fetch/comment/search) |
| `jira_capture_ticket.py` | `.claude/scripts/integrations/jira/jira_capture_ticket.py` | Reads stdin JSON, extracts ticket ID from prompt, writes state file |
| `jira_push_comment.py` | `.claude/scripts/integrations/jira/jira_push_comment.py` | Builds and posts Jira comment from git context + docs |

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
            "command": "python3 /path/to/repo/.claude/scripts/integrations/jira/jira_capture_ticket.py 2>/dev/null || true",
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
            "command": "jq -r '.tool_input.command' | grep -q '^git push' && python3 /path/to/repo/.claude/scripts/integrations/jira/jira_push_comment.py /path/to/repo 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

> Replace `/path/to/repo` with the repo's absolute path. Merge with existing `PostToolUse` entries — do not replace the ruff lint hook. The merged file must stay strict JSON (no comments, nothing after the closing brace); confirm with `scripts/setup/check-settings-json.sh .claude/settings.json` and keep any explanatory notes in `.claude/settings.notes.md`.

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

### Agent Recipe (Optional)

If `recipe.md` exists in the project root, `/kiro:autoresearch` passes it to the agent as additional context alongside `program.md`. It's a versioned artifact tracking the evolution of the research loop itself — not just current state but *why* decisions were made:

- **What we've tried** — dated log of experiments, results, and whether the change was kept or reverted
- **Signal filtering policy** — which result signals to act on vs. treat as noise, preventing "slop generation" (chasing metrics that don't represent real improvement)
- **Staged autonomy level** — 1 = human approves every change, 2 = human reviews batches, 3 = agent fully autonomous with daily review, plus the criteria for advancing a stage
- **What we've learned** — non-obvious findings from prior iterations

On first run, create a skeleton `recipe.md` with the initial signal-filtering policy and autonomy stage; the agent updates it after each batch of experiments. The inner loop (`/kiro:autoresearch` itself) optimizes `train.py`; the outer loop (`recipe.md` evolution) optimizes how the inner loop operates. (Source: Gavrilescu (2025) via Latent Space — "Autoresearch: The Feedback Loop Behind Self-Improving Agents".)

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
| `gitnexus-setup.md` | `commands/kiro/` | Install, index, configure MCP and editor integration. Does **not** hand-edit config — delegates MCP wiring and the `gitnexus setup` gate to `gitnexus-reconcile.sh` |
| `gitnexus-explore.md` | `commands/kiro/` | Launch Web UI to browse code connections |
| `gitnexus-impact.md` | `commands/kiro/` | Query blast radius for current changes |
| `gitnexus-setup-agent.md` | `agents/kiro/` | Setup agent — same six steps as the command, same delegation to `gitnexus-reconcile.sh` |
| `gitnexus-reconcile.sh` | `scripts/setup/` | The one writer of GitNexus config. `--wire` writes `.mcp.json` + enables the server in `.claude/settings.json` (idempotent, refuses an unparseable settings file); `--check` exits 0 only when index **and** MCP server both exist; no flag reconciles the managed block — in `CLAUDE.md`, or `AGENTS.md` for projects that relocated their conventions there — repairing skill paths and rewriting bare `gitnexus_*` tool names to the `mcp__gitnexus__*` form the MCP server exposes. Installed to projects as `.claude/scripts/setup/gitnexus-reconcile.sh` |

### Prerequisites

- Node.js 18+ (for `npx gitnexus`)
- npm (for global installation)
- Git initialized in the project

### Setup & Usage

```bash
# Option 1: Via Claude Code command (recommended)
/kiro:gitnexus-setup                    # Install, index, configure everything

# Option 2: During harness installation
$SDD_HARNESS/install.sh /path/to/project --with-gitnexus

# Option 3: Manual
npm install -g gitnexus
gitnexus analyze                                                   # index the repo
bash .claude/scripts/setup/gitnexus-reconcile.sh . --wire          # register the MCP server
bash .claude/scripts/setup/gitnexus-reconcile.sh . --check \
  && gitnexus setup \
  && bash .claude/scripts/setup/gitnexus-reconcile.sh .            # editor integration, gated
```

**What `/kiro:gitnexus-setup` (and `gitnexus-setup-agent`) does at Steps 3 and 5:** it no longer reads `.claude/settings.json` and merges an `mcpServers.gitnexus` block by hand. Step 3 runs `bash .claude/scripts/setup/gitnexus-reconcile.sh . --wire`, which writes the server to `.mcp.json`, enables it in `.claude/settings.json`, no-ops when the server is already configured in any scope, and leaves an unparseable settings file untouched. Step 5 gates `npx gitnexus setup` behind `gitnexus-reconcile.sh . --check` and re-runs the reconciler afterwards, because `gitnexus setup` writes a managed MUST/NEVER block into `CLAUDE.md` (or `AGENTS.md`, if that's where the project keeps its conventions) calling `gitnexus_*` tools — writing it before index and MCP server both exist leaves the agent under rules for tools it cannot call. The reconciler's live-block pass also repairs skill paths and rewrites any bare `gitnexus_*` tool names to the `mcp__gitnexus__*` form the MCP server actually exposes. If `--check` fails, the command skips Step 5 and reports which half is missing. The Step 6 report line therefore reads `MCP: [configured|already configured] in .mcp.json`, not `in .claude/settings.json`.

**What `install.sh --with-gitnexus` actually does now:** it wires the MCP server for real by calling `scripts/setup/gitnexus-reconcile.sh <project> --wire` (which writes the server into `.mcp.json` and adds it to `enabledMcpjsonServers` in `.claude/settings.json`), instead of the old behavior of printing a `NOTE:` telling the user to paste an `mcpServers` block into `.claude/settings.json` by hand. It then runs `gitnexus setup` **only** when `gitnexus-reconcile.sh <project> --check` confirms that both the index and the MCP server exist; otherwise `gitnexus setup` would write its managed MUST/NEVER `CLAUDE.md` block ordering the agent to call `gitnexus_*` tools that were never registered — which is exactly what happened on every install where nobody pasted the JSON. If the check fails, install prints `Skipped 'gitnexus setup' — index or MCP server missing.` and directs you to `/kiro:gitnexus-setup`. After a successful `gitnexus setup`, the reconciler runs once more to repair the managed block.

**`update.sh` reconciles the managed block on every sync.** The block is committed — to `CLAUDE.md`, or to `AGENTS.md` for projects that relocated their conventions there (`CLAUDE.md` wins on a tie) — but `.gitnexus/` is gitignored and the MCP server lives in local config, so a fresh clone inherits rules for tools it cannot call. `update.sh` runs `scripts/setup/gitnexus-reconcile.sh <project>` (non-fatal, `|| true`) to strip the block when it's dead and, when it's live, repair its skill paths and rewrite any bare `gitnexus_*` tool names to `mcp__gitnexus__*`; it no-ops for projects that never ran `gitnexus setup`.

### Using the Web UI

```bash
/kiro:gitnexus-explore                  # starts server + opens browser
# Or manually:
gitnexus serve                          # http://localhost:4567
```

The harness dashboard's **🕸 GitNexus** tab reaches the same UI differently: `gitnexus serve` answers only `/api/*` and 404s at `/`, so it is the API backend, not a web server for the UI. The tab therefore iframes the hosted app (`https://gitnexus.vercel.app/?repo=<name>`, which talks to `http://localhost:4747` by default) and probes `http://localhost:4747/api/repos` in real CORS mode to decide whether the backend is up — a `no-cors` probe of `/` returns an opaque response, so a 404 from a live server read as success. The iframe carries `allow="local-network-access"` because the hosted (https) app has to reach a `localhost` backend. The dashboard no longer proxies GitNexus through its own `/gn/` endpoint — the `_proxy_gitnexus` handler, its `/gn/` route, and the auto-repo-select script it injected are gone; the ports and URLs now live in one place at the top of `scripts/utils/dashboard.py` (`GN_PORT`, `GN_WEB_UI`, `GN_PROBE_URL`) and are substituted into the page JS as `__GN_WEB_UI__` / `__GN_PROBE_URL__`. Probe failures share one `gnOffline(message)` path, so an HTTP error surfaces as `GitNexus API returned HTTP <status>` instead of the generic "not running" text.

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

`install.sh` and `update.sh` call `scripts/setup/raindrop-setup.sh` automatically. That script:
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
python3 $SDD_HARNESS/scripts/utils/dashboard.py

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
$SDD_HARNESS/install.sh /path/to/new-repo

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

`install.sh` and `update.sh` propagate **every** hook in the harness's `hooks/claude/` directory to each project's `.claude/hooks/` unconditionally — including `impeccable-detect-hook.sh` — and sync `kiro/settings/rules/frontend-anti-patterns.md` and `docs/` automatically. The skill lives at `~/.claude/skills/impeccable-audit/` (global, not per-project). No manual copy step is needed:

```bash
$SDD_HARNESS/update.sh        # re-syncs hooks + rules + docs to every registered repo
# or, for a brand-new repo:
$SDD_HARNESS/install.sh /path/to/project
```

The PostToolUse wiring ships in `templates/settings.json.template` and is installed automatically (see Step 6 above for the equivalent manual entry).

See `docs/design/impeccable/impeccable.md` for the full rule set and workflow placement.

---

## Proof Collaborative Review (Built-in — Spec Phase Gates)

The harness uses [Proof](https://github.com/EveryInc/proof-sdk) (by Every Inc.) for human review gates at each SDD spec phase (`spec-requirements`, `spec-design`, `spec-tasks`). When a phase completes, the skill publishes the artifact to a live Proof document, presents a browser URL, and waits for your review before writing the approved version back.

### What it does

- Publishes the generated markdown artifact (requirements, design, task list) to a self-hosted Proof server
- Presents a URL — open in any browser to annotate, comment, or rewrite inline
- Waits for your "done" signal, then retrieves the final human-edited version
- Tears down the server only if the skill started it (PID-file guard)

### Where the skill lives

The skill ships with the harness — no separate installation needed:

```
$SDD_HARNESS/skills/proof-collaborative-review/SKILL.md   ← harness repo (replicated to all machines)
~/.claude/skills/proof-collaborative-review/SKILL.md               ← global (symlinked by install.sh)
```

`install.sh` propagates the skill to every project's skill lookup path automatically.

### Proof SDK (Node.js — auto-installed on first use)

The skill clones and installs the Proof SDK on first use into `~/.claude/tools/proof-sdk/`:

```bash
mkdir -p ~/.claude/tools
cd ~/.claude/tools
git clone https://github.com/EveryInc/proof-sdk
cd proof-sdk
npm install
```

The skill detects `~/.claude/tools/proof-sdk/node_modules/` — if present, it skips the install. Never runs `npm install` twice.

**Prerequisites:** Node.js (already required by the harness, see Prerequisites above).

### Remote Proof server (optional)

By default the skill starts a local server at `http://localhost:4000`. To use a shared remote instance instead:

```bash
export PROOF_SERVER_URL=http://your-server:4000
```

Add to `~/.bashrc` or `~/.claude/settings.json` → `env` block to persist across sessions.

### CLAUDE.md additions

No CLAUDE.md changes needed — the skill is invoked automatically by the kiro spec commands at each phase gate.

---

## RTK (Automatic — Token Compression)

The harness includes a global integration with [RTK](https://github.com/rtk-ai/rtk) (Rust Token Killer) — a 6.6MB single-binary CLI proxy that intercepts Bash command output and compresses it before it enters the LLM context window. Typical reduction: 60–90% on development commands.

### What it does

A `PreToolUse` hook in `~/.claude/settings.json` runs `rtk hook claude` on every Bash tool call. When RTK has a filter for the command, the hook emits a rewrite directive (`permissionDecision: "allow"`) telling Claude Code to run `rtk <original>` instead. The proxy executes the command, applies the filter, and returns the compressed version. Everything is automatic — no commands to invoke, no per-project setup.

**Filters cover 100+ commands:** git (diff/status/log/add/commit/push/pull), pytest/cargo test/go test/jest/vitest/playwright/rspec/rake, ls/find/grep/diff/tree/wc, cargo build/check/clippy, tsc, eslint/ruff/mypy/golangci-lint/rubocop/prettier, docker, kubectl, aws, curl, gh, glab, psql, jq, npm/pnpm/pip/bundle/prisma.

### Installation

**All platforms** — use Homebrew (macOS and Linux):

```bash
brew install rtk
rtk init -g
```

`rtk init -g` writes the `PreToolUse` hook to `~/.claude/settings.json` once. All projects and sessions inherit it automatically.

**Linux without Homebrew:**

```bash
curl -fsSL https://rtk-ai.app/install.sh | sh
rtk init -g
```

**Windows (native):** RTK does not ship a native Windows binary. Use WSL2 — install WSL2 and run the Linux instructions above from inside it.

### Verifying it works

```bash
rtk --version    # should show rtk 0.42.0
rtk gain         # cumulative savings (starts at 0 on fresh install)
```

Preview how a command would be rewritten without running it:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | rtk hook claude
# Should print: {"hookSpecificOutput":{"permissionDecision":"allow","updatedInput":{"command":"rtk git status"},...}}
```

### Bypassing compression

When exact raw output is needed (debugging, piping to other tools):

```bash
rtk proxy <cmd>        # run command unfiltered (still tracked in rtk gain)
rtk hook check <cmd>   # dry-run preview of the rewrite decision
```

### CLAUDE.md additions

No CLAUDE.md changes needed — RTK is fully automatic and global.

See `docs/context-management/rtk/README.md` for full filter coverage, configuration, ultra-compact mode, and troubleshooting.

---

## Headroom (Automatic — Prompt/Context Compression Proxy)

The harness includes a global integration with [headroom-ai](https://github.com/headroom-ai/headroom) — a process-level proxy that compresses prompts/messages before they reach the Claude API (60–95% savings). It is complementary to RTK, not a replacement: RTK compresses Bash *command output* on the way into context; Headroom compresses the *prompt/message stream itself* at the proxy layer. Both can run at once.

### What it does

`scripts/setup/headroom-setup.sh` is idempotent and safe to re-run; it is called automatically by `install.sh` and `update.sh`. On each run it:

1. Installs `headroom-ai` globally — tries `uv tool install` (Python 3.12 first, for prebuilt wheels of the Rust/maturin extension), then `pipx`, then `pip install --user`, first one that works.
2. Installs `headroom-ai` into each registered repo's detected virtualenv (uv + `pyproject.toml`, or a discovered `.venv`/`venv`), for Python API use.
3. Installs Headroom as a persistent background service — a launchd LaunchAgent on macOS, a systemd user service on Linux — via `headroom install apply --preset persistent-service --memory`. This keeps the proxy warm across sessions (cold start ~10s → ~1s) and auto-starts on login. Skipped on unsupported OSes or if a service already reports healthy.
4. Wires Claude Code to route through the proxy durably (`headroom init --global --memory claude`, all shells + GUI) — but **only after** confirming the proxy is healthy via `curl http://127.0.0.1:${HEADROOM_PORT:-8787}/readyz`, so `ANTHROPIC_BASE_URL` is never pointed at a dead proxy.
5. Removes any legacy `alias claude='headroom wrap claude'` line from `~/.bashrc` / `~/.zshrc` left by older installs — that approach was bash-only (never loaded under macOS's default zsh) and conflicted with the persistent service over the same port.

A companion script, `scripts/utils/sync-memories-to-headroom.py`, bidirectionally syncs harness markdown memories with Headroom's SQLite DB at session start when Headroom is installed.

### Verifying it works

```bash
headroom verify                                          # end-to-end proxy health check
curl -fsS http://127.0.0.1:8787/readyz                    # proxy readiness probe
headroom install status                                  # persistent service status
```

Savings and install status are visible in the harness dashboard's Headroom panel (`python3 scripts/utils/dashboard.py`), which reads `~/.headroom/proxy_savings.json`.

### CLAUDE.md additions

No CLAUDE.md changes needed — Headroom is fully automatic and global, wired the same way as RTK.

See `.claude/scripts/README.md` (Utilities section) for the canonical script description.

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
| RTK | `docs/context-management/rtk/README.md` | Token compression proxy — filter coverage, install, configuration, upgrading |
| Context Hub | [github.com/andrewyng/context-hub](https://github.com/andrewyng/context-hub) | MCP server for third-party API docs (external) |
| Design Quality | `docs/design/README.md` | Visual design quality integrations index |
| Impeccable | `docs/design/impeccable/impeccable.md` | 27 anti-pattern rules, skill usage, hook setup, transfer instructions |
| Proof Collaborative Review | `$SDD_HARNESS/skills/proof-collaborative-review/SKILL.md` | Spec phase-gate review sessions — Proof SDK setup, server lifecycle, API reference |
| Raindrop Workshop | `docs/raindrop/README.md` | AI-agent tracing — instrumented repos, eval loop, dashboard tab, troubleshooting |
| Headroom | `.claude/scripts/README.md` (Utilities) | Prompt/context compression proxy — install (global + per-repo venv), persistent service (launchd/systemd), durable Claude Code routing, `sync-memories-to-headroom.py` |
| Scheduled Tasks | `docs/scheduled-tasks/README.md` | All scheduled routines (daily maintenance, macro-eval, skill-curator, harness health, drift review); OS scheduler setup; dashboard **Scheduled Tasks** tab. The weekly skill-curator runs a Usage Evidence audit (Phase 1.5) over `logs/skill-usage.jsonl`, reporting deprecate candidates (no use in 30d) and archive candidates (90d); `pinned: true` skills are never flagged. A new Phase 1.6 — Dependency Cross-Reference — runs `scripts/utils/skill-dependency-scan.sh` *before* the prompt fires (deterministic `grep -rn -w` over other skills' SKILL.md bodies, hooks, agents, commands, CLAUDE.md, kiro rules, and routine scripts, capped at 8 referrers per skill), and `skill-curator-runner.sh` splices its output into the prompt's `DEPENDENCY_MAP_PLACEHOLDER` via a temp-file `sed` `r`/`d` insert (not a variable substitution, since referrer paths can contain `&`/`\`). Any skill that is BOTH a low-quality/cold candidate AND cross-referenced is surfaced in the report's mandatory `## Dependency Flags` section instead of being folded into a plain deletion candidate — the human-invoked `/skill-curator` skill treats that section as ground truth and requires **Delete + migrate references** (referrers updated first) rather than a bare delete. |
| Hooks Reference | `docs/hooks/README.md` | Complete hook documentation — event types, purpose, wiring reference for all active hooks |
| Local LLM Eval | `docs/local-llm-eval/README.md` | Offline prompt evaluation with Ollama via OMT — multi-model comparison, variance testing, custom CLI runners (`--runner`) for non-Ollama models/agents, automated grading (`--checker`) |
| Structured Web Dataset | `docs/structured-web-dataset/README.md` | Building tabular datasets from NL descriptions — web research mode and synthetic mode |

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

# RIGHT — post-commit hook (fires once per git commit), fully detached
# .git/hooks/post-commit
{
  timeout 900 claude --dangerously-skip-permissions --print "..." || true
} </dev/null >>"$REPO_ROOT/.git/post-commit-docsync.log" 2>&1 &
disown 2>/dev/null || true
```

**Rules to remember**:
- Never call `claude --print` from a Stop hook
- Never use `git diff HEAD~1` as a condition in Stop (always has output)
- Never watch `.claude/memory/` for mtime changes in Stop (written every session)
- Background doc agents belong in git hooks (commit-scoped) or manual slash commands
- Detach the git-hook job (`</dev/null`, output appended to a log, `disown`) so `git commit` returns immediately instead of waiting on the agent, and bound each `claude` call with `timeout 900` / `gtimeout 900` so a stuck agent cannot hold the terminal
- If the hook commits `.md` files itself, keep the guards narrow enough that the resulting `.md`-only commit fails them — otherwise the hook re-fires forever

The Stop hook should only contain **passive checks** (e.g., nudging housekeeping when observations exceed a threshold). See `.claude/hooks/stop-hook.sh` for the reference implementation.

_Last synced: 2026-08-20_

