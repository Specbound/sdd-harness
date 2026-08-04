# SDD Harness — Scheduled Tasks Reference

All scheduled tasks run **locally** via the OS-level scheduler and the daily orchestrator. They work on any machine, have full access to gitignored files (`~/.claude/skills/`, `.claude/memory/`), and require no GitHub App or cloud authentication.

---

## Active Scheduled Tasks

All tasks are wired into `scripts/orchestration/daily-orchestrator.sh`. The orchestrator fires at 18:00 via launchd (macOS) or crontab (Linux), once daily. On WSL/Windows, Task Scheduler (`setup-global-orchestrator.sh`) fires at 18:00 and repeats every 4h for the rest of the day (6x/day total) — each sub-routine self-gates on its own last-run state, so 5 of 6 fires are cheap no-ops. Catch-up runs if the machine was off: the session-start hook fires the per-repo runner in the background if the state file is >24h stale.

Each routine's stderr is captured to a per-run buffer; on a non-zero exit, the buffer is appended to `logs/orchestrator-errors.log` (in addition to the usual one-line summary in `logs/orchestrator.log`) so a failing run leaves a diagnosable trace instead of a silent exit=1.

The orchestrator itself is fail-loud: every non-dry-run invocation logs a `run started (mode=...)` line to `logs/orchestrator.log` and, via an `EXIT` trap, a `run finished exit=<code> repos=<count>` line — so a crash before the repo loop even starts (bad args, missing `projects.txt`) leaves a diagnosable trace in `logs/orchestrator-errors.log` instead of looking identical to a zero-work success.

---

### Daily Maintenance
**Runner:** `.claude/scripts/orchestration/daily-runner.sh`
**Prompt:** `.claude/scripts/routines/daily-maintenance-prompt.md`
**Cadence:** Every day (idempotent; skips if already ran today)
**Scope:** Every registered repo

**What it does (five steps, error-isolated):**
- **A** — Judge + Reflect + Housekeep: score the previous day's observations via the session-quality rubric; convert drain entries into memory updates; archive `observations.md` if >50 entries
- **B** — Session Quality Assessment: collect git activity; score session 1–5; append `[session-quality]` observation
- **C** — Keep Rate Evaluation: find Claude-co-authored commits older than 7 days; compute lines still in HEAD; append `[keep-rate]` observation
- **D** — Trust Score update: run `trust_score.py auto-score` after B and C are written, so all signals (`[session-charge]`, `[memory-gap]`, `[session-quality]`, `[keep-rate]`) are visible to the scorer
- **E** — Skill Augmentation (Sleep-Phase Knowledge Seeding): invoke `skill-augment-agent` with today's judge verdict. The agent collects `[seed-target:]` observations written by the `action-capture.sh` hook during the Wake phase (failed Bash commands), maps them to skill domains, and loads today's `type: feedback` memories (user corrections) as highest-trust evidence ranked above the LLM judge, generates synthetic worked examples (Dreaming), and applies up to 3 evidence-backed skill improvements. Logs each as `[skill-update]`. Idempotent — skips if `[skill-update]` entries already exist for today. This step closes the full Wake→Sleep cycle: struggles during active sessions automatically become targeted skill updates overnight.

**Channel summary (optional):** after the run, `daily-runner.sh` posts the last ~20 lines of output to your chat channels via `scripts/integrations/channels/notify.py` (title `Daily maintenance — <repo> (exit=<code>)`). No-op unless `~/.env.channels` exists, so the call stays unconditional. Opt out with `SDD_SKIP_CHANNEL_NOTIFY=1`. See [docs/integrations/channels](../integrations/channels/README.md).

**Opt-out:** `rm .claude/scripts/orchestration/daily-runner.sh` in that repo; or `SDD_SKIP_ROUTINE=1` to skip registration at install time.

---

### Daily Security Scan
**Runner:** `.claude/scripts/routines/security-report-runner.sh`
**Cadence:** Every day (`MIN_GAP_DAYS=1`; applies to every repo)
**Scope:** Every registered repo

**What it does:**
- Static security scan of recent git changes using the `ai-security-workflow` skill
- Checks for OWASP patterns (injection sinks, XSS vectors, broken auth), exposed secrets, and unsafe patterns introduced in the last commit window
- Writes a dated report to `.claude/reports/security/<date>-security-report.md`
- Visible in the dashboard **Scheduled Tasks** section with last-run status, artifact diff, and any findings headline
- Race-safe via `mkdir` lock; a lock older than 2h (left by a killed run) is auto-removed on the next run

**Opt-out:** `SDD_SKIP_SECURITY_REPORT=1` env var.

---

### Startup Payload Audit
**Runner:** `.claude/scripts/routines/startup-payload-audit.sh`
**Cadence:** Every day (own state-file guard `.claude/memory/.last-startup-payload-audit`; deterministic — no LLM call)
**Scope:** Every registered repo

**What it does:**
- Measures the **fixed per-session token tax** — the layered `CLAUDE.md` + `@imports` + `.claude/rules/*` + auto-loaded `MEMORY.md` that load before you do anything. RTK/lean-ctx/Headroom only reduce *runtime* cost and never see this startup payload.
- Estimates per-file tokens and age, flags files over the budget (`SDD_STARTUP_PAYLOAD_BUDGET`, default 8000), stale files (`SDD_STARTUP_STALE_DAYS`, default 45), and **ghost references** (`@paths` in CLAUDE.md that don't resolve)
- Writes `.claude/reports/context/startup-payload.json`
- Surfaced in the dashboard **Budget & Efficiency → Context Health** tab as a Startup Payload card (tokens, budget status, stale/ghost counts, top files) and as a card on the **Scheduled Tasks** tab
- Enforces the harness's own "read on demand, not upfront" rule by measuring whether it's actually followed. See the `context-optimization` skill (Startup vs Runtime axis).

**Opt-out:** `SDD_SKIP_STARTUP_AUDIT=1` env var. Force a run with `--force`.

---

### Macro-Eval Sweep
**Runner:** `.claude/scripts/routines/macro-eval-runner.sh`
**Prompt:** `.claude/scripts/routines/macro-eval-prompt.md`
**Cadence:** ~Twice weekly (MIN_GAP_DAYS=3; override with `MACRO_EVAL_GAP_DAYS`)
**Scope:** Every registered repo (no-ops if Raindrop MCP is unreachable)

**What it does:**
- Pulls Raindrop Workshop traces from the last 4 days
- Clusters failure patterns by type and impact
- Writes a dated report to `.claude/reports/macro-evals/YYYY-MM-DD.md`
- Posts annotations to Workshop for top failing patterns
- Race-safe via `mkdir` lock; a lock older than 2h (left by a killed run) is auto-removed on the next run

**Opt-out:** `SDD_SKIP_MACRO_EVAL=1` env var; or preflight writes a `*-SKIPPED.md` report if MCP unreachable.

---

### Tool-Failure Review
**Runner:** `.claude/scripts/routines/tool-failure-review-runner.sh`
**Command:** `.claude/commands/kiro/tool-failure-review.md` (`/kiro:tool-failure-review`)
**Cadence:** ~Twice weekly (MIN_GAP_DAYS=3; override with `TOOL_FAILURE_GAP_DAYS`; force with `TOOL_FAILURE_FORCE=1`)
**Scope:** Every registered repo (no-ops unless the ledger has a promotable signature)

**What it does:**
- Reads the per-repo tool-failure ledger `.claude/memory/tool-failures.jsonl` (populated by the `tool-failure-capture.sh` PostToolUseFailure hook)
- Promotes recurring, understood failures (count ≥ `TOOL_FAILURE_MIN_COUNT`, default 3, open, not yet promoted) into durable memory + `ERRORS.md`, diagnosing *why* the command shape keeps failing
- Marks promoted entries resolved so the `tool-failure-recall.sh` PreToolUse hook stops warning about them
- Self-paces via MIN_GAP_DAYS and a `mkdir` lock; pre-flights that the `claude` CLI is on PATH before running; a lock older than 2h (left by a killed run) is auto-removed on the next run

This is the **review** stage of the tool-failure-memory loop (capture → recall → review). See the `tool-failure-memory` skill.

**Opt-out:** `SDD_SKIP_TOOL_FAILURE_REVIEW=1` env var.

---

### Code-Review Learning Sweep
**Runner:** `.claude/scripts/routines/code-review-learning-runner.sh`
**Prompt:** `.claude/scripts/routines/code-review-learning-prompt.md`
**Cadence:** Weekly (`CODE_REVIEW_LEARNING_GAP_DAYS`, default 7; force with `CODE_REVIEW_LEARNING_FORCE=1`)
**Scope:** Every registered repo (no-ops unless there's a merged PR with a logged automated review not yet processed)

**What it does:**
- Discovers merged PRs with a logged `.claude/memory/pr-reviews/pr-<n>.md` (written by `scripts/pr/log_review.sh` via the `gitnexus-pr-review` skill, backgrounded from `scripts/pr/detect_base_and_create.sh` when the PR is created) not yet processed, via `gh pr view --json state`
- For each: diffs the logged review against real human review activity (`gh api .../comments`, `.../reviews`) to find **missed** flags, **false positives**, or **convention gaps**
- **Low-risk** findings (team conventions, dismissed-flag patterns) are written directly into `.claude/memory/` as `project`/`feedback` facts
- **Higher-risk** findings (changes to the `code-reviewer` skill's methodology) are never auto-applied — only reported to `docs/code-review-learning-report.md` for human approval
- Race-safe via `mkdir` lock; marks processed PRs in `.claude/memory/.code-review-learning-processed` only on a successful run; a lock older than 2h (left by a killed run) is auto-removed on the next run

**Opt-out:** `SDD_SKIP_CODE_REVIEW_LEARNING=1` env var.

---

### Weekly Skill-Curator Sweep
**Runner:** `.claude/scripts/routines/skill-curator-runner.sh`
**Prompt:** `.claude/scripts/routines/skill-curator-prompt.md`
**Cadence:** Weekly (MIN_GAP_DAYS=7; override with `SKILL_CURATOR_GAP_DAYS`; force with `SKILL_CURATOR_FORCE=1`)
**Scope:** Harness repo only (exits 0 in non-harness repos via `docs/scheduled-tasks/` guard)

**What it does:**
0. **Forward-pattern intake** — reads `.claude/memory/forward-patterns.md` from every registered repo; surfaces confidence 4–5 entries as incorporate/promote/defer candidates; included in the curation report
1. **Skill quality audit** — scores all `~/.claude/skills/*/SKILL.md` against four SkillOS dimensions; flags low-quality candidates and duplicate pairs
2. **Description budget audit** — measures description field length; flags >150 chars for compression
3. **Memory governance health** — checks five compaction-discipline hook failure modes
4. Writes `docs/skill-curation-report.md` (full weekly snapshot, replaced each run)
- Race-safe via `mkdir` lock; a lock older than 2h (left by a killed run) is auto-removed on the next run

**How to use:** After the routine runs, invoke `/skill-curator` locally to review findings and apply approved changes (merge/compress/delete) with human approval at every step.

**Opt-out:** `SDD_SKIP_SKILL_CURATOR=1` env var.

---

### Bi-Weekly Harness Health
**Runner:** `.claude/scripts/routines/harness-health-runner.sh`
**Prompt:** `.claude/scripts/routines/harness-health-prompt.md`
**Cadence:** Bi-weekly (MIN_GAP_DAYS=13; override with `HARNESS_HEALTH_GAP_DAYS`; force with `HARNESS_HEALTH_FORCE=1`)
**Scope:** Harness repo only (exits 0 in non-harness repos via `docs/scheduled-tasks/` guard)

**What it does:**
1. **CLAUDE.md review** — reads all repos in `~/.claude/sdd-harness/projects.txt`; audits for stale instructions, model-assumption drift, and over-constraining rules from pre-Claude-4.x habits; rates each repo `clean` / `minor` / `needs-update`; writes `docs/claudemd-review-report.md`. This is the *harness-wide* pass. Its *per-repo* counterpart is the `/claudemd-review` global command (`commands/global/claudemd-review.md`), which `session-start-hook.sh` fires when a single repo's `.claude/memory/.last-claudemd-review` is >14 days stale; that command audits only the current repo (adding a 200-line size budget, an "inferable from the manifest" filter, and an `@AGENTS.md` import/dedup check) and writes `.claude/memory/claudemd-review-report.md` — do not confuse the two report paths.
2. **Iterative skill repair** — reads `docs/skill-curation-report.md` for low-quality flags; applies a Review→Repair→Validate loop (up to 3 skills per run, max 3 repair iterations per skill); writes repaired `SKILL.md` files directly; appends a `## Iterative Repair Run — [date]` section to the curation report
- Race-safe via `mkdir` lock; a lock older than 2h (left by a killed run) is auto-removed on the next run

**How to use:** `git pull` after the routine runs, then read `docs/claudemd-review-report.md`. Stalled skills in the repair report need manual intervention — invoke the relevant skill locally with domain context the automated run couldn't supply.

**Opt-out:** `SDD_SKIP_HARNESS_HEALTH=1` env var.

---

### Wednesday Drift Review
**Mechanism:** Inline in `scripts/orchestration/daily-orchestrator.sh` (harness-level section)
**Cadence:** Once per Wednesday (week-number dedup via `~/.claude/sdd-harness/.last-drift-review`)
**Scope:** Harness-level (not per-repo)

**What it does:** Invokes the `repo-drift-review` skill to sweep the SDD harness for drift. Auto-fixes what it can. Writes `~/.claude/sdd-harness/docs/drift-review-report.md`.

---

## OS Scheduler Setup

| OS | Scheduler | Registered by | Remove with |
|---|---|---|---|
| **macOS** | launchd LaunchAgent | `install.sh` / `update.sh` | `launchctl unload -w ~/Library/LaunchAgents/com.sdd.daily-orchestrator.plist` |
| **WSL / Windows** | Windows Task Scheduler | `install.sh` / `update.sh` | `schtasks.exe /Delete /TN "SDD Daily Orchestrator" /F` |
| **Linux** | crontab | `install.sh` / `update.sh` | `crontab -l \| grep -vF sdd-daily-orchestrator \| crontab -` |

Registration is automatic and idempotent — re-running `install.sh` or `update.sh` is safe.

The dashboard's **Scheduled Tasks** tab shows live status for each task, scoped to whichever repo's dashboard is open: schedule, last run + exit code, artifact path, diff vs. previous run, and the reasoning excerpt from the artifact. Harness-only routines (skill-curator, harness-health) always show the harness's own state regardless of which repo is open; per-repo routines show that repo's state file and log entries. It also surfaces the OS scheduler's last-launch exit status.

---

## Adding a New Scheduled Task

1. Create `scripts/routines/<name>-prompt.md` — prompt template with `TODAY_PLACEHOLDER`
2. Create `scripts/routines/<name>-runner.sh` — copy the `scripts/routines/macro-eval-runner.sh` pattern; set `MIN_GAP_DAYS`; add a harness guard (`docs/scheduled-tasks/`) if harness-only
3. Add a call block in `run_one()` in `scripts/orchestration/daily-orchestrator.sh` with a `SDD_SKIP_<NAME>` opt-out guard
4. Add a `chmod +x` line in **both** `install.sh` and `update.sh` (the runner loop lists every `*-runner.sh` by name)
5. Add an entry to `_scheduled_task_registry()` in `scripts/dashboard.py` so the routine shows up as a card on the dashboard's **Scheduled Tasks** tab (set `runner_log_token` to match how the orchestrator logs it)
6. Sync both to `.claude/scripts/`: `cp scripts/routines/<name>-* .claude/scripts/routines/`
7. Document it in this file

---

_Last synced: 2026-08-04_

