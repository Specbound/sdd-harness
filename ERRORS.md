# ERRORS Log

Approaches that took 2+ attempts — what failed, what worked, and why.

---

## 2026-08-16 — `$HOME`-relative is not the same as portable (tool-layout guesses)

**Symptom:** `command -v headroom` failed while headroom was installed, running, and serving a healthy proxy — because `~/.local/bin` was not on PATH in the environment `install.sh`/`update.sh` run under. The first repair guessed the directory instead of discovering it.

**Root cause:** The harness's portability rule had been read as "no `/Users/<name>/…` literals", and `check-no-hardcoded-paths.sh` enforced exactly that much. But `$HOME/.local/share/uv/tools`, `$HOME/.local/bin`, `$HOME/.raindrop/bin` and `$HOME/.cargo/bin` are **defaults, not facts** — uv honours `UV_TOOL_DIR`/`UV_TOOL_BIN_DIR`/`XDG_*`, pipx honours `PIPX_HOME`, raindrop honours `RAINDROP_HOME`, cargo honours `CARGO_HOME`. Naming them passes the guard and still breaks on a clone whose user set any of them. Worse, `dashboard.py` listed `/opt/homebrew/bin` and `/usr/local/bin` literally: the first is Apple-Silicon-only and the second Intel-only, so the raindrop-installed check was guaranteed wrong on one Mac architecture or the other.

**Fix:** `scripts/lib/tool-paths.sh` — the one allowed namer of package-manager layouts, in the same role `resolve-harness-dir.sh` holds for the harness root. It *asks* (`uv tool dir`, `uv tool dir --bin`, `pipx environment`, `brew --prefix`), falls back to each tool's documented env var, and only then to XDG spec defaults. `dashboard.py` carries a Python twin (`_tool_bin_dirs` / `find_global_tool`). PATH is repaired for the current process by `ensure_tool_bin_on_path` and for future shells by `uv tool update-shell` — uv's own command, which edits whichever profile the user's shell actually reads, so the harness never guesses between `.zshrc`/`.zprofile`/`.bashrc`. `check-no-hardcoded-paths.sh` now bans the tool-layout literals so this cannot regress, exempting only documented-override fallbacks by variable name.

**Verification that matters:** `lib/tool-paths.test.sh` asserts the *relocation* cases — with `uv` forced off PATH, all four env overrides must win, and XDG must be honoured as last resort. A happy-path test proves nothing here: a hardcoded default passes it.

**Lesson:** "Contains no `/Users/<name>/`" is a much weaker property than "works on any machine". The question to ask of a path is not whether it is absolute but whether it is *discovered* — if the tool can be asked where it lives, asking is the only portable answer, and every convention it replaces is somebody's overridable default.

## 2026-08-16 — three harness features were dead on macOS/off-PATH and reported nothing

**Symptom:** None. That was the problem. Every affected feature printed success or said nothing at all.

**Root cause (three instances of the same shape — a probe that cannot fail loudly):**
1. `raindrop-setup.sh`'s auto-instrument pass gated on bare `timeout`, which **macOS does not ship**. Every probe exited 127, read as "not instrumented" by the grep and "SDK missing" by the import check, so the pass never ran on a Mac — while printing a plausible "SDK not importable — skipping" for each repo.
2. `headroom-setup.sh` gated its persistent-service install *and* the Claude routing on `command -v headroom`. `uv tool install` puts its shim in `~/.local/bin`, which is **off PATH** in the environment `install.sh`/`update.sh` run under, so the entire block was skipped silently on a machine where headroom was installed and running.
3. `headroom-setup.sh` also pip-installed `headroom-ai` into every repo venv behind `-q 2>/dev/null`. Measured across four registered repos: **zero** had it. It had never once worked, and nothing noticed because nothing needs it — headroom is machine-level (shell-rc `ANTHROPIC_BASE_URL` + proxy service), and the only Python consumer runs under headroom's own interpreter.

**Fix:** `lib/repo-venv.sh` carries a `timeout`/`gtimeout`/no-op shim used by every timed probe. headroom is resolved through `~/.local/bin` and the uv-tool/pipx layouts, not `command -v`. The per-repo headroom install was deleted rather than repaired — once `lib/repo-venv.sh` made venv discovery actually work, it would have started installing a maturin package plus its dependency tree into repos that never import it. `check-harness-deps.sh` now reports headroom binary / proxy / routing state so all three failures are visible.

**Second attempt needed:** the first `/readyz` health probe reported "routed but not responding" on a proxy with four days of uptime. `curl -m 8` returned exit 28 while the very next identical request returned HTTP 200 — the endpoint is slow while the compression model loads. Raised to `--connect-timeout 3 -m 25` with one retry, and split curl exit 7 (nothing listening — real failure) from 28 (listening but slow — fine).

**Lesson:** A probe whose failure mode is indistinguishable from its negative result is not a check, it is decoration — `timeout` missing, a binary off PATH, and an install failing all rendered as the same calm skip line. Assert the tool exists before trusting what its absence "means", and when a health check fails against something you have other evidence is alive, debug the check before believing it.

## 2026-08-16 — harness packages kept vanishing from installed repos (installed but never declared)

**Symptom:** A registered repo pruned its dependencies and lost packages the harness relies on. `raindrop-ai` was gone from `daa-llm-evaluation` and `whisper-pipeline`; `anthropic` was importable nowhere the harness could reach it. Nothing reported a problem — `install.sh`/`update.sh` printed "Done." on every run.

**Root cause (two halves):**
1. `raindrop-setup.sh` and `headroom-setup.sh` ran `pip install <pkg> -q 2>/dev/null` into each target repo's venv and wrote **nothing** to that repo's manifest. Undeclared, the package is an orphan to the repo's own tooling, so `uv sync` / lockfile regen / a dependency prune deletes it — then the next harness update silently reinstalls it, and the next prune deletes it again. An unbreakable loop.
2. `-q 2>/dev/null` plus `|| return` meant a failed install was indistinguishable from a successful one. `detect_reexplanation.py` imports `anthropic` under bare `python3`, i.e. whatever interpreter the *target repo* provides — an environment the harness does not own and cannot keep stocked.

**Fix:** Split dependencies by who owns the environment. `scripts/setup/harness-requirements.txt` → the harness-owned `.venv-tools` (no repo has these, so no repo can prune them); `scripts/setup/repo-requirements.txt` → installed into the repo venv **and** declared in the repo's own manifest by `setup/declare-repo-deps.py` (PEP 735 `[dependency-groups] harness`, or `requirements-harness.txt` + a `-r` line). `setup/check-harness-deps.sh` runs both passes on every install/update and reports every package as ok/healed/FAILED/skipped. `stop-hook.sh` now calls `.venv-tools`'s python for the detector.

**Second attempt needed:** the first heal run reported `daa-llm-evaluation/.venv/bin/python: No module named pip` — `uv venv` seeds no pip unless asked, so a perfectly healthy uv-managed venv rejects `python -m pip`. Added a `uv pip install --python <venv-python>` fallback in `lib/repo-venv.sh`.

**Lesson:** Installing a package into someone else's environment without declaring it there is not an install — it is a countdown. The declaration is what survives; the install is just the fast path. And the reason this ran undetected for months is the swallowed output: `-q 2>/dev/null` on an install turns "broken" and "fine" into the same terminal line. Report the outcome of every package, including the healthy ones — drift is only actionable if it is visible.

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
