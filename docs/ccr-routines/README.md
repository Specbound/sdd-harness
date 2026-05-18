# SDD Harness — CCR Routines Reference

CCR (Claude Code Routines) are scheduled remote agents that run on a cron schedule via the Claude Code platform. They operate in Anthropic's cloud — they can read and write to GitHub repos (via the Claude GitHub App), but **cannot access locally gitignored files** (including `.claude/memory/`).

**To manage CCR routines:** [https://claude.ai/code/routines](https://claude.ai/code/routines)

---

## Active Routines

### Weekly Skill-Curator + Memory Governance
**ID:** `trig_018Wuof3a3z9vzacVX83sbga`
**Schedule:** Every Monday at 9:00 AM IDT (06:00 UTC) — cron `0 6 * * 1`
**Status:** Active
**Repo:** `dansashalesser/sdd-harness` (requires Claude GitHub App installed)

**What it does:** A combined audit covering two domains in one report:

1. **Skill quality audit** — Scans `~/.claude/skills/` (via the repo) and clusters skills by theme. Scores each against four SkillOS quality dimensions: task relevance, operational validity, content quality, and compression ratio. Proposes merge/compress/delete operations for low-quality or redundant skills. Compression heuristic: skill content should be ≤30% of the context it would replace manually.

2. **Memory governance health audit** — Checks the five compaction-discipline hook failure modes to verify that memory hooks are still enforcing their constraints and haven't drifted. Flags any hooks that have weakened, gone missing, or no longer match their documented intent.

**Output:** Writes `docs/skill-curation-report.md` to the `sdd-harness` repo each Monday.

**How to use:** After the routine runs, pull the repo (`git pull`) and read `docs/skill-curation-report.md`. Then invoke the `skill-curator` skill locally to act on the recommendations — it requires user approval before making any changes.

**Why it exists:** The SkillOS research (arXiv:2605.06614) shows that skill curation — not just accumulation — is the key bottleneck for self-evolving agents. High-quality, compressed, task-relevant skills outperform large libraries of unmanaged ones. Governance health auditing was added because the compaction-discipline hook protects against memory drift, and needs to be checked periodically to stay effective.

---

## Local Daily Maintenance (Task Scheduler)

This is not a CCR routine — it runs locally on the developer machine.

**Mechanism:** Windows Task Scheduler entry `SDD Daily Orchestrator` fires at 11:30 IST every day. It runs `~/.claude/sdd-harness/scripts/daily-orchestrator.sh`, which loops over every repo listed in `~/.claude/sdd-harness/scripts/projects.txt` and calls each repo's `.claude/scripts/daily-runner.sh`.

**Catch-up path:** If the machine is off at 11:30 IST, `session-start-hook.sh` fires the per-repo runner in the background the next time Claude opens in that repo (if the state file `.claude/memory/.last-routine-run` is >24h stale or missing). See `docs/hooks/README.md → session-start-hook.sh`.

**Per-repo runner:** `.claude/scripts/daily-runner.sh` — template at `~/.claude/sdd-harness/scripts/daily-runner.sh`. Self-contained; runs `claude --print --permission-mode bypassPermissions` with the daily maintenance prompt.

**Important:** `--permission-mode bypassPermissions` is required for headless `claude --print`. Without it, any write to `observations.md` triggers a permission prompt and the entire pipeline hangs silently.

**Pipeline steps (inside daily-maintenance-prompt):**
- **Step A:** Judge — score the previous day's sessions against trust-battery criteria
- **Step B:** Reflect — assess session quality signals (keep rate, re-explanation frequency)
- **Step C:** Evaluate — calculate keep rate trend and record metric observation
- **Step D:** Housekeep — prune observations.md if it exceeds 50 entries
- **Step E:** Augment — check skill audit queue for pending additions

**One-time setup:** Run `~/.claude/sdd-harness/scripts/setup-global-orchestrator.sh` on a new machine to register the Task Scheduler entry.

---

## Adding a New CCR Routine

1. Create the routine via `CronCreate` tool or the `/schedule` skill.
2. Document it in this file under **Active Routines** with: ID, schedule, status, what it does, output, and why it exists.
3. Add the ID to the routine URL: `https://claude.ai/code/routines/<ID>`
4. The `ccr-routine-added-notify.sh` hook will remind you to document it if you use `CronCreate` in a session.
