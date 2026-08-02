# scripts/

Utility scripts used by the harness. All Python scripts use stdlib only (no virtualenv required unless noted).

## Setup & Stack

| Script | Purpose |
|---|---|
| `generate-project-stack.sh` | Auto-detect project language, runtime, package manager, deps, test commands, Docker services → writes `PROJECT_STACK.md`. Called by `install.sh` and `update.sh` automatically. |

## Daily Maintenance & Evaluation

| Script | Purpose |
|---|---|
| `orchestration/daily-runner.sh` | Per-repo entry point for daily maintenance. Fires `/kiro:daily-maintenance` headlessly. Installed by `install.sh`; triggered nightly by Windows Task Scheduler (WSL) or `session-start-hook.sh` catch-up. |
| `orchestration/daily-orchestrator.sh` | Global orchestrator that iterates all registered projects and calls their `daily-runner.sh`. |
| `orchestration/setup-global-orchestrator.sh` | Register `daily-orchestrator.sh` with Windows Task Scheduler (schtasks). |
| `orchestration/setup-linux-orchestrator.sh` | Register `daily-orchestrator.sh` with cron (Linux). |
| `orchestration/setup-mac-orchestrator.sh` | Register `daily-orchestrator.sh` with launchd (macOS). |
| `routines/macro-eval-runner.sh` | Runs `/kiro:macro-eval-sweep` headlessly for trend analysis. |
| `routines/harness-health-runner.sh` | Runs the bi-weekly harness health routine (CLAUDE.md review + skill repair). |
| `routines/skill-curator-runner.sh` | Runs `/kiro:skill-extract` to curate and augment skills from session learnings. |
| `routines/tool-failure-review-runner.sh` | Promotes recurring tool failures from `.claude/memory/tool-failures.jsonl` into `ERRORS.md` + memory. |
| `routines/security-report-runner.sh` | Daily security scan: runs the security-report prompt headlessly, writes report to `.claude/reports/security/`. Runs at most once per day (`SECURITY_REPORT_GAP_DAYS`). Opt out with `SDD_SKIP_SECURITY_REPORT=1`. |
| `routines/code-review-learning-runner.sh` | Self-improving code-review learning sweep: compares pr-babysit's logged reviews (`.claude/memory/pr-reviews/pr-<n>.md`) against real human review activity on merged PRs, promotes low-risk findings (conventions, dismissed-flag patterns) straight into memory, and reports higher-risk methodology changes to `docs/code-review-learning-report.md` for human approval. No-ops unless there's a merged+logged PR not yet processed; self-paces to weekly (`CODE_REVIEW_LEARNING_GAP_DAYS`, default 7) once there is. Applies to any repo. Wired into `orchestration/daily-orchestrator.sh` `run_one()`. Opt out with `SDD_SKIP_CODE_REVIEW_LEARNING=1`. |
| `routines/startup-payload-audit.sh` | Deterministic (no LLM) daily audit of the fixed per-session startup token tax (`CLAUDE.md` + `@imports` + `.claude/rules/*` + auto-loaded `MEMORY.md`). Writes `.claude/reports/context/startup-payload.json`, read by the dashboard's Context Health tab. Self-paces to daily via its own state-file guard. Wired into `orchestration/daily-orchestrator.sh` `run_one()`. Opt out with `SDD_SKIP_STARTUP_AUDIT=1`. |

## Session Intelligence

| Script | Purpose |
|---|---|
| `detect_reexplanation.py` | Haiku-based session signal detector. Classifies sessions as drain (re-explanation) or charge (approval). Called by `hooks/claude/stop-hook.sh`. |
| `micro_reflect.py` | Extracts durable facts from drain sessions → writes `[auto-learn]` entries to `hot-memory.md`. Can be invoked standalone on drain signals. |
| `trust_score.py` | Applies Judge score delta to the trust score line in `hot-memory.md`. |
| `session/write_handoff.py` | Deterministic (non-LLM) transcript-to-markdown session handoff. Reads the transcript path from stdin JSON, extracts branch/cwd/recent messages, writes `.claude/memory/handoff/latest.md`. Invoked with `--trigger precompact` from `compaction-discipline-hook.sh`, `--trigger agent-spawn` from `gbrain-agent-spawn.sh`, and `--trigger cache-cost` from `stop-hook.sh` when cache tokens hit ≥70% of session spend after ≥1 compaction; surfaced (if <24h fresh) by `session-start-hook.sh`. Never invoked manually. |

## PR Automation

| Script | Purpose |
|---|---|
| `pr/detect_base_and_create.sh` | Shared logic behind PR-babysitting automation. Auto-detects a feature branch's true fork-point base (via `git merge-base` + most-recent-commit-date comparison across all local/remote refs, falling back to the repo's default branch) and idempotently opens a draft PR (`gh pr create --fill --draft`) if one isn't already open. Also checks for a `PULL_REQUEST_TEMPLATE.md` and backgrounds `pr/log_review.sh` via `nohup` once the PR exists. No-ops cleanly if `gh` isn't installed or the branch isn't inside a git work tree. Invoked from `hooks/claude/pr-auto-create-hook.sh` (after a successful non-force `git push`) and `hooks/claude/pr-mention-nudge.sh` (when the user's prompt mentions opening/creating a PR). Hands off to the `pr-babysit` skill (replaces the retired `iterate-pr` skill). |
| `pr/log_review.sh` | Headless `claude --print` invocation of the `gitnexus-pr-review` skill against an open PR. Writes `.claude/memory/pr-reviews/pr-<n>.md` (human-readable review) and `pr-<n>.review.json` (structured verdict/body/comments). Never posts to GitHub itself — backgrounded by `pr/detect_base_and_create.sh`, and re-runnable by the `pr-babysit` skill. |
| `pr/validate_review_json.py` | Schema validator for `pr-<n>.review.json` — checks `verdict` (APPROVE/REJECT), `body` (overview/concerns/issue_count/recommendation), and `comments[]` (path/line/side/start_line/start_side/body, with `body` required to start with `CRITICAL:`/`IMPORTANT:`/`SUGGESTION:`/`NIT:`). Run via `python3 .claude/scripts/pr/validate_review_json.py <path>` after `log_review.sh` writes the file, and by the `review-pull-requests.yml` GitHub Action's read-only "review" job before handing off to the write-permission "publish" job. |

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
| `headroom-setup.sh` | Installs `headroom-ai` globally + per registered-repo virtualenv, installs the persistent proxy service (launchd on macOS, systemd on Linux), and wires Claude Code to route through it durably (`headroom init --global --memory claude`) once the proxy's `/readyz` check passes. Removes any legacy `~/.bashrc`/`~/.zshrc` `alias claude='headroom wrap claude'` on re-run. |
| `sync-memories-to-headroom.py` | Bidirectional sync: harness markdown memories ↔ headroom SQLite DB. Called at session start when headroom is installed. |

## Prompts (used by runners)

| File | Purpose |
|---|---|
| `routines/daily-maintenance-prompt.md` | Prompt injected by `daily-runner.sh` for `/kiro:daily-maintenance`. |
| `routines/harness-health-prompt.md` | Prompt for the bi-weekly harness health routine. |
| `routines/macro-eval-prompt.md` | Prompt for macro evaluation sweeps. |
| `routines/security-report-prompt.md` | Prompt for the security report runner. |
| `routines/skill-curator-prompt.md` | Prompt for skill curation runs. |
| `routines/code-review-learning-prompt.md` | Prompt for the self-improving code-review learning sweep. |

_Last synced: 2026-08-02
