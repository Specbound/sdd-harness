# ERRORS Log

Approaches that took 2+ attempts — what failed, what worked, and why.

---

## 2026-08-12 — "weekly" drift review ran on every orchestrator run (macOS `date -d`)

**Symptom:** A test of `daily-orchestrator.sh` in a throwaway harness tree hung past 300s with a same-day `.last-drift-review` in place — the gate that should have said "not due" let the review through, and it spawned a real `claude --print` session.

**Root cause:** The gate used `date -d "$LAST_DRIFT_RAW" +%s`. `-d` is GNU-only; on macOS it errors, the `|| echo 0` fallback set `LAST_DRIFT_EPOCH=0`, and the elapsed-days comparison was inside `if [ "$LAST_DRIFT_EPOCH" -gt 0 ]` — so on macOS the comparison never ran and `DRIFT_DUE` stayed `true`. The review fired every single run instead of every 7 days, burning a full Claude session each time. The comment above it explains at length why an elapsed-days gate beats a day-of-week gate, which is correct and was never the problem.

**Fix:** Replaced the `date -d` arithmetic with the portable `python3` epoch math already used by the CLAUDE.md review gate in `session-start-hook.sh`. Test now asserts the review stays gated.

**Lesson:** `date -d` and `date -r` are not portable — `date -d` is GNU, `date -r` is BSD. Anywhere the harness needs date math, use `python3 -c` or compare `YYYY-MM-DD` day strings via `cut -dT -f1`. A `|| echo 0` fallback that feeds a guard clause turns a portability failure into a silently-inverted gate, which is worse than a crash.

## 2026-08-12 — every new project got an unparseable settings.json (comments in JSON)

**Symptom:** Opening a freshly installed project shows "Settings file failed to parse: `<project>/.claude/settings.json` — Invalid or malformed JSON. Permission rules and other settings from this file are not in effect." No other error; hooks and permissions just silently do nothing.

**Root cause:** `templates/settings.json.template` closed its root object at line 269, then carried 19 `//` comment lines documenting the optional ktx MCP server. JSON permits neither comments nor trailing content. `install.sh` copied that template verbatim into every new project, so every install produced a dead settings file. Ironically `install.sh` already stripped `//` comments before merging `~/.claude/settings.json` — the project-copy path skipped that step. `update.sh` never touches project settings, so bad files never self-healed.

**Fix:** Comments removed from the template; notes moved to `templates/settings.notes.md.template`, copied to `.claude/settings.notes.md` on install/update. `scripts/setup/check-settings-json.sh` validates templates before `install.sh` copies and after `update.sh` regenerates; `scripts/setup/repair-settings-json.py` peels a trailing comment block into the sidecar and runs idempotently on every install/update. Backfilled `whisper-pipeline` (JSON body byte-identical to the original lines 1-269).

**Lesson:** Claude Code fails *quiet* on malformed settings — the file parses to nothing and the session looks normal. Never annotate a `.json` file, even with content after the final brace; use a `.notes.md` sidecar. Any template copied verbatim by the installer needs a parse check in the copy path.

## 2026-07-12 — launchd daily-orchestrator never ran (stale plist path + macOS TCC)

**Symptom:** Dashboard Automation tab: Drift Review / Skill-Curator "never" ran; Daily Maintenance last real run ~May 27 (46 days). `launchctl list com.sdd.daily-orchestrator` showed `LastExitStatus = 32512` (exit 127); `orchestrator.stderr.log` was a wall of "No such file or directory".

**Root cause (two layered bugs):**
1. Plist pointed at `~/.claude/sdd-harness/scripts/daily-orchestrator.sh`, but the script moved to `scripts/orchestration/` during the scripts reorg. `setup-mac-orchestrator.sh` was updated, but never re-run → the installed LaunchAgent kept the dead path. Exit 127 daily since ~May 26.
2. After regenerating the plist (`setup-mac-orchestrator.sh --force`), launchd still failed with exit 126 "Operation not permitted": **macOS TCC blocks launchd-spawned processes from `~/Documents`**. Verified with a minimal probe (`launchctl submit -- /bin/ls ~/Documents` → EPERM). Since `~/.claude/sdd-harness` is a symlink into `~/Documents/sdd-harness`, the scheduled job has NEVER worked — TCC blocked it from day one; only manual runs and session-start catch-ups ever executed.

**Fix:** (1) `bash scripts/orchestration/setup-mac-orchestrator.sh --force` after any script move. (2) Grant Full Disk Access to `/bin/bash` (System Settings → Privacy & Security → Full Disk Access → + → Cmd+Shift+G → `/bin/bash`), then `launchctl start com.sdd.daily-orchestrator` to verify.

**Lesson:** "43s ago" on the dashboard was a decoy — `daily-runner.sh` stamps `.last-routine-run` at START, and the session-start catch-up had just fired; absence of artifacts (`daily/` had no briefs) was the honest signal. On macOS, any launchd/cron job touching `~/Documents`/`~/Desktop` needs an FDA grant for the interpreter — a symlink from an unprotected path does NOT bypass TCC (it keys on the real path).

## 2026-06-14 — headroom proxy fails on terminal `claude` launch (missing deps)

**Symptom:** `claude` from terminal shows "Proxy exited with code 1: FastAPI required" or "h2 package not installed".

**Root cause:** `headroom-setup.sh` uv tool install was missing two deps:
1. `uvicorn` — FastAPI needs this to serve (was never in `--with` list)
2. `httpx[http2]` — headroom proxy uses `http2=True`; bare `httpx` doesn't include `h2`

**Fix:** Re-install with all deps:
```bash
uv tool install headroom-ai --python 3.12 \
  --with numpy --with sqlite-vec --with sentence-transformers \
  --with fastapi --with uvicorn --with "httpx[http2]"
```
Then patched `scripts/setup/headroom-setup.sh` to include `--with uvicorn --with "httpx[http2]"` on both uv install lines so it won't regress.

**Lesson:** When headroom proxy errors, check the uv tool env for missing packages first:
`ls ~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/ | grep -iE "fastapi|uvicorn|httpx|h2"`

---

## 2026-05-31 — `update.sh` wiped global skills into spilled files (macOS BSD `cp`)

**Symptom:** After running `update.sh`, `~/.claude/skills/` lost every named skill dir (evaluation, macro-evals, …) and the root filled with loose files (`SKILL.md`, `analyze.py`, `resources/`, `scripts/`) — the *contents* of skills dumped at top level, each overwriting the last.

**Root cause (two bugs, found together):**
1. `update.sh`/`install.sh` sync skills via `for skill_dir in "$HARNESS_DIR/skills"/*/` — the `*/` glob yields paths **with a trailing slash**. Passing `evaluation/` to `cp -r "$src" "$dst/"` triggers the macOS BSD `cp` behavior: a trailing slash on the source copies its **contents** into the destination instead of creating `dst/evaluation/`. (GNU cp on Linux/WSL does not do this, so it was latent until run on macOS.) `sync_dir`'s own comment warned about exactly this, but the trailing slash defeated it.
2. `update.sh` `do_update` also aborted on the first entry when the harness repo itself was in `projects.txt`: `cp impeccable-detect-hook.sh` onto itself errors "are identical", and `set -e` killed the whole run before the real repos updated.

**Fix:**
- `sync_dir` now strips the trailing slash internally: `local src="${1%/}"`. Callers also pass `${skill_dir%/}` (belt + suspenders).
- `do_update` skips when `$proj` resolves to `$HARNESS_DIR` (harness source is self-managed by the tail block).
- Recovery: source `skills/` was intact (it's the truth); rebuilt `~/.claude/skills` by purging spillage (keeping symlinks + the scientific pack) and re-copying each source dir without a trailing slash.

**Lesson:** Any `cp -r` of a globbed `*/` path on macOS must strip the trailing slash, or it content-dumps. Test installer changes on macOS, not just Linux. The harness must never be a `do_update` target of its own `update.sh`.

---

## 2026-08-16 — Scheduler dead for 4 days: TCC + three guards that were never wired

**Symptom:** Dashboard showed `never` for most routines across the fleet. Repos other than the one being worked in received no scheduled runs at all. Presented as intermittent ("sometimes works on old machines, never on new ones").

**Root cause (one trigger, four independent silent failures):**
1. **TCC.** The harness lived under `~/Documents/GitHub/`. macOS protects `~/Documents`, `~/Desktop`, `~/Downloads` — a LaunchAgent has no Full Disk Access, so launchd was refused at *exec* time: `/bin/bash: .../daily-orchestrator.sh: Operation not permitted`, exit 126, four days running. `launchctl load` returned 0 and `launchctl list` showed the job present the whole time. The grant is per-machine and never travels with a clone, which is why every new machine looked broken and no config diff explained it.
2. **`.claude/settings.json` held 23 absolute hook paths**, manufactured by a `{{HARNESS_DIR}}` substitution in `templates/settings.harness.json.template`. Moving the harness left 23 dead hook paths.
3. **`check-no-hardcoded-paths.sh` could not see them.** It scanned only `*.sh`/`*.py` (settings.json is JSON) *and* excluded `^\.claude/`. Double-blind over exactly the file that broke. It also had 13 pre-existing violations from vendored `skills/`, so it was red anyway.
4. **`hooks/git/pre-commit` was never installed anywhere.** It existed in the source tree; `install.sh`/`update.sh` copied only `post-commit`. Its own header documented a manual `cp` against a path (`git-hooks/`) that does not exist. So the guard in (3) had never run automatically — and both it and the hook advertised themselves as wired.

Bonus: `~/.sdd-harness-root` (the cross-repo pointer) went stale on the move and both hooks reacted with `|| true` → `exit 0`, i.e. silently.

**Fix:**
- Moved the tree to `~/GitHub/` (unprotected). Verified with a throwaway probe LaunchAgent running `--dry-run`: exit 0, all repos enumerated.
- Hook commands in both templates are now `bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/x.sh"` — absolute when Claude Code exports it, CWD-relative otherwise, machine-specific never. `install.sh`/`update.sh` `cp` the template instead of `sed`-substituting it.
- Single stored pointer consolidated into `scripts/lib/harness-pointer.sh`; hooks now print `[HARNESS-POINTER-STALE]` instead of exiting silently.
- Guard extended to `*.json`/`*.template`, re-admits generated `.claude/settings.json`, excludes vendored `skills/`. Regression-tested in both directions.
- `install_harness_pre_commit` installs the guard automatically (non-destructively — it will not clobber a pre-commit it does not own).
- `setup-mac-orchestrator.sh` / `setup-linux-orchestrator.sh` now run a preflight and **exit 1** if the scheduler cannot actually execute; the macOS one names TCC explicitly when `$HARNESS_DIR` is under a protected folder.
- Dashboard renders a full-width red banner above the routine cards when the scheduler is down, instead of small yellow text beside a page of calm `PENDING` badges.

**Lessons:**
- Never put anything a scheduler must execute under `~/Documents`, `~/Desktop`, or `~/Downloads` on macOS. Registration success ≠ execution success; always preflight by *running* the thing.
- A guard that has never been observed to fail is not a guard. Regression-test guards in both directions, and verify the hook that runs them is actually installed — `.git/hooks/` is not version-controlled, so "wired into pre-commit" in a comment proves nothing.
- Config counts as code. A path scanner that skips JSON and generated files will report green over the exact file that breaks.
- `grep` through the Bash tool is rtk-proxied and respects `.gitignore`, so it silently skips `.claude/`. Use `ctx_shell` when auditing gitignored trees — the two disagreed and the discrepancy nearly hid finding (2).
