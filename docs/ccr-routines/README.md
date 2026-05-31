# SDD Harness — Routines Reference

All routines now run **locally** via the OS-level scheduler and the daily orchestrator. There are no active CCR (cloud-hosted) routines. Local routines work on any machine, have full access to gitignored files (`~/.claude/skills/`, `.claude/memory/`), and require no GitHub App or cloud authentication.

---

## Active Local Routines

All routines are wired into `scripts/daily-orchestrator.sh`. The orchestrator fires daily at 18:00 via launchd (macOS), Windows Task Scheduler (WSL/Windows), or crontab (Linux). Catch-up runs if the machine was off: the session-start hook fires the per-repo runner in the background if the state file is >24h stale.

---

### Daily Maintenance
**Runner:** `.claude/scripts/daily-runner.sh`
**Prompt:** `.claude/scripts/daily-maintenance-prompt.md`
**Cadence:** Every day (idempotent; skips if already ran today)
**Scope:** Every registered repo

**What it does:**
- Judge — score the previous day's observations via the session-quality rubric
- Reflect — convert drain entries into memory updates
- Housekeep — archive observations.md if >50 entries
- Trust Score — `trust_score.py auto-score` from observations.md signals
- Morning Brief — draft daily brief to `.claude/memory/daily/YYYY-MM-DD-brief.md`

**Opt-out:** `rm .claude/scripts/daily-runner.sh` in that repo; or `SDD_SKIP_ROUTINE=1` to skip registration at install time.

---

### Macro-Eval Sweep
**Runner:** `.claude/scripts/macro-eval-runner.sh`
**Prompt:** `.claude/scripts/macro-eval-prompt.md`
**Cadence:** ~Twice weekly (MIN_GAP_DAYS=3; override with `MACRO_EVAL_GAP_DAYS`)
**Scope:** Every registered repo (no-ops if Raindrop MCP is unreachable)

**What it does:**
- Pulls Raindrop Workshop traces from the last 4 days
- Clusters failure patterns by type and impact
- Writes a dated report to `.claude/reports/macro-evals/YYYY-MM-DD.md`
- Posts annotations to Workshop for top failing patterns

**Opt-out:** `SDD_SKIP_MACRO_EVAL=1` env var; or preflight writes a `*-SKIPPED.md` report if MCP unreachable.

---

### Weekly Skill-Curator Sweep
**Runner:** `.claude/scripts/skill-curator-runner.sh`
**Prompt:** `.claude/scripts/skill-curator-prompt.md`
**Cadence:** Weekly (MIN_GAP_DAYS=7; override with `SKILL_CURATOR_GAP_DAYS`; force with `SKILL_CURATOR_FORCE=1`)
**Scope:** Harness repo only (exits 0 in non-harness repos via `docs/ccr-routines/` guard)

**What it does:**
1. **Skill quality audit** — scores all `~/.claude/skills/*/SKILL.md` against four SkillOS dimensions; flags low-quality candidates and duplicate pairs
2. **Description budget audit** — measures description field length; flags >150 chars for compression
3. **Memory governance health** — checks five compaction-discipline hook failure modes
4. Writes `docs/skill-curation-report.md` (full weekly snapshot, replaced each run)

**How to use:** After the routine runs, invoke `/skill-curator` locally to review findings and apply approved changes (merge/compress/delete) with human approval at every step.

**Opt-out:** `SDD_SKIP_SKILL_CURATOR=1` env var.

---

### Bi-Weekly Harness Health
**Runner:** `.claude/scripts/harness-health-runner.sh`
**Prompt:** `.claude/scripts/harness-health-prompt.md`
**Cadence:** Bi-weekly (MIN_GAP_DAYS=13; override with `HARNESS_HEALTH_GAP_DAYS`; force with `HARNESS_HEALTH_FORCE=1`)
**Scope:** Harness repo only (exits 0 in non-harness repos via `docs/ccr-routines/` guard)

**What it does:**
1. **CLAUDE.md review** — reads all repos in `~/.claude/sdd-harness/projects.txt`; audits for stale instructions, model-assumption drift, and over-constraining rules from pre-Claude-4.x habits; rates each repo `clean` / `minor` / `needs-update`; writes `docs/claudemd-review-report.md`
2. **Iterative skill repair** — reads `docs/skill-curation-report.md` for low-quality flags; applies a Review→Repair→Validate loop (up to 3 skills per run, max 3 repair iterations per skill); writes repaired `SKILL.md` files directly; appends a `## Iterative Repair Run — [date]` section to the curation report

**How to use:** `git pull` after the routine runs, then read `docs/claudemd-review-report.md`. Stalled skills in the repair report need manual intervention — invoke the relevant skill locally with domain context the automated run couldn't supply.

**Opt-out:** `SDD_SKIP_HARNESS_HEALTH=1` env var.

---

### Wednesday Drift Review
**Mechanism:** Inline in `scripts/daily-orchestrator.sh` (harness-level section)
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

---

## Adding a New Local Routine

1. Create `scripts/<name>-prompt.md` — prompt template with `TODAY_PLACEHOLDER`
2. Create `scripts/<name>-runner.sh` — copy the `macro-eval-runner.sh` pattern; set `MIN_GAP_DAYS`; add a harness guard if harness-only
3. Add a call block in `run_one()` in `scripts/daily-orchestrator.sh` with a `SDD_SKIP_<NAME>` opt-out guard
4. Add a `chmod +x` line in `update.sh`
5. Sync both to `.claude/scripts/`: `cp scripts/<name>-* .claude/scripts/`
6. Document it in this file

---

## Retired CCR Routines (migrated 2026-05-31)

The following routines were previously hosted as CCR (Claude Code Routines) on `claude.ai/code/routines`. They were migrated to local runners on 2026-05-31 because local runs have access to gitignored files, require no GitHub App, and work on any machine.

| Routine | Former CCR ID | Migrated to |
|---------|--------------|-------------|
| Weekly Skill-Curator + Memory Governance | `trig_018Wuof3a3z9vzacVX83sbga` | `skill-curator-runner.sh` |
| Bi-Weekly Harness Health | `trig_014LpmVohefGRmySvBzaJsxk` | `harness-health-runner.sh` |
