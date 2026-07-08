# scripts/

Utility scripts used by the harness. All Python scripts use stdlib only (no virtualenv required unless noted).

## Setup & Stack

| Script | Purpose |
|---|---|
| `generate-project-stack.sh` | Auto-detect project language, runtime, package manager, deps, test commands, Docker services → writes `PROJECT_STACK.md`. Called by `install.sh` and `update.sh` automatically. |

## Daily Maintenance & Evaluation

| Script | Purpose |
|---|---|
| `daily-runner.sh` | Per-repo entry point for daily maintenance. Fires `/kiro:daily-maintenance` headlessly. Installed by `install.sh`; triggered nightly by Windows Task Scheduler (WSL) or `session-start-hook.sh` catch-up. |
| `daily-orchestrator.sh` | Global orchestrator that iterates all registered projects and calls their `daily-runner.sh`. |
| `setup-global-orchestrator.sh` | Register `daily-orchestrator.sh` with Windows Task Scheduler (schtasks). |
| `setup-linux-orchestrator.sh` | Register `daily-orchestrator.sh` with cron (Linux). |
| `setup-mac-orchestrator.sh` | Register `daily-orchestrator.sh` with launchd (macOS). |
| `macro-eval-runner.sh` | Runs `/kiro:macro-eval-sweep` headlessly for trend analysis. |
| `harness-health-runner.sh` | Runs the bi-weekly harness health routine (CLAUDE.md review + skill repair). |
| `skill-curator-runner.sh` | Runs `/kiro:skill-extract` to curate and augment skills from session learnings. |
| `tool-failure-review-runner.sh` | Promotes recurring tool failures from `.claude/memory/tool-failures.jsonl` into `ERRORS.md` + memory. |
| `security-report-runner.sh` | Daily security scan: runs the security-report prompt headlessly, writes report to `.claude/reports/security/`. Runs at most once per day (`SECURITY_REPORT_GAP_DAYS`). Opt out with `SDD_SKIP_SECURITY_REPORT=1`. |
| `routines/startup-payload-audit.sh` | Deterministic (no LLM) daily audit of the fixed per-session startup token tax (`CLAUDE.md` + `@imports` + `.claude/rules/*` + auto-loaded `MEMORY.md`). Writes `.claude/reports/context/startup-payload.json`, read by the dashboard's Context Health tab. Self-paces to daily via its own state-file guard. Wired into `daily-orchestrator.sh` `run_one()`. Opt out with `SDD_SKIP_STARTUP_AUDIT=1`. |

## Session Intelligence

| Script | Purpose |
|---|---|
| `detect_reexplanation.py` | Haiku-based session signal detector. Classifies sessions as drain (re-explanation) or charge (approval). Called by `hooks/claude/stop-hook.sh`. |
| `micro_reflect.py` | Extracts durable facts from drain sessions → writes `[auto-learn]` entries to `hot-memory.md`. Can be invoked standalone on drain signals. |
| `trust_score.py` | Applies Judge score delta to the trust score line in `hot-memory.md`. |

## Integrations

| Script | Purpose |
|---|---|
| `jira_client.py` | Jira REST API client (supports PAT + Basic Auth). |
| `jira_capture_ticket.py` | Capture active Jira ticket from session context into memory. |
| `jira_push_comment.py` | Post implementation summary as a Jira comment. |
| `raindrop-setup.sh` | Auto-installs `raindrop-ai` in registered repo virtualenvs. |
| `ollama_model_test.py` | Smoke-test local Ollama model endpoints. |
| `integrations/blackhole/blackhole-cursor.py` | Opt-in Ghostty context-fill gauge: encodes context-window fill into cursor color (OSC 12) for `blackhole.glsl`. Dormant unless `SDD_BLACKHOLE=1`. See [docs/integrations/blackhole](../docs/integrations/blackhole/README.md). |
| `integrations/channels/notify.py` | Stdlib-only outbound webhook sender for Slack / Discord / Teams. Reads `~/.env.channels`; clean no-op when absent. Powers the `/notify` command and the daily-runner summary post. See [docs/integrations/channels](../docs/integrations/channels/README.md). |

## Utilities

| Script | Purpose |
|---|---|
| `dashboard.py` | Local harness dashboard (browser-based). Includes Workshop tab for Raindrop traces. Maintenance Status section also shows a deferred-markers count via `count_debt_markers()`, which git-greps comment-anchored `DEBT:` markers across tracked non-md code (convention from the karpathy-guidelines skill). |
| `check-no-hardcoded-paths.sh` | CI guard — fails if any harness script contains a machine-specific absolute path (`/home/`, `/Users/`, `/c/Users/`, `/mnt/c/Users/`, `C:\Users\`, or hardcoded `$HOME/.claude/sdd-harness`). Every path must be self-located via `lib/resolve-harness-dir.sh`. |
| `lib/ship-safety-scan.sh` | Pre-ship gate run by `install.sh` / `update.sh` before any source is copied into a repo. Hard-blocks on leaked secrets / populated `.env` files (exit 1); soft-warns on over-broad permission rules in settings templates. Opt out with `SDD_SKIP_SHIP_SCAN=1`; promote warnings to failures with `SDD_SHIP_STRICT=1`. |
| `headroom-setup.sh` | Configure disk/memory headroom thresholds for the daily runner. |
| `sync-memories-to-headroom.py` | Bidirectional sync: harness markdown memories ↔ headroom SQLite DB. Called at session start when headroom is installed. |

## Prompts (used by runners)

| File | Purpose |
|---|---|
| `daily-maintenance-prompt.md` | Prompt injected by `daily-runner.sh` for `/kiro:daily-maintenance`. |
| `harness-health-prompt.md` | Prompt for the bi-weekly harness health routine. |
| `macro-eval-prompt.md` | Prompt for macro evaluation sweeps. |
| `security-report-prompt.md` | Prompt for the security report runner. |
| `skill-curator-prompt.md` | Prompt for skill curation runs. |

_Last synced: 2026-07-08
