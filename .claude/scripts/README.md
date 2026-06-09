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

## Session Intelligence

| Script | Purpose |
|---|---|
| `detect_reexplanation.py` | Haiku-based session signal detector. Classifies sessions as drain (re-explanation) or charge (approval). Called by `hooks/claude/stop-hook.sh`. |
| `micro_reflect.py` | Extracts durable facts from drain sessions → writes `[auto-learn]` entries to `hot-memory.md`. Called by `stop-hook.sh` on drain signals. |
| `trust_score.py` | Applies Judge score delta to the trust score line in `hot-memory.md`. |

## Integrations

| Script | Purpose |
|---|---|
| `jira_client.py` | Jira REST API client (supports PAT + Basic Auth). |
| `jira_capture_ticket.py` | Capture active Jira ticket from session context into memory. |
| `jira_push_comment.py` | Post implementation summary as a Jira comment. |
| `raindrop-setup.sh` | Auto-installs `raindrop-ai` in registered repo virtualenvs. |
| `ollama_model_test.py` | Smoke-test local Ollama model endpoints. |

## Utilities

| Script | Purpose |
|---|---|
| `dashboard.py` | Local harness dashboard (browser-based). Includes Workshop tab for Raindrop traces. |
| `check-no-hardcoded-paths.sh` | CI guard — fails if any harness script contains a hardcoded `/home/` path. |
| `headroom-setup.sh` | Configure disk/memory headroom thresholds for the daily runner. |

## Prompts (used by runners)

| File | Purpose |
|---|---|
| `daily-maintenance-prompt.md` | Prompt injected by `daily-runner.sh` for `/kiro:daily-maintenance`. |
| `harness-health-prompt.md` | Prompt for the bi-weekly harness health routine. |
| `macro-eval-prompt.md` | Prompt for macro evaluation sweeps. |
| `security-report-prompt.md` | Prompt for the security report runner. |
| `skill-curator-prompt.md` | Prompt for skill curation runs. |
