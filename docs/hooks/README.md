# SDD Harness — Hooks Reference

All hooks live in `.claude/hooks/` and are wired in `.claude/settings.json`.
Hook output is injected into Claude's context as system messages — Claude reads it before acting.

**Hook types used in this harness:**

| Type | When it fires |
|---|---|
| `SessionStart` | Once, before the first user message in each session |
| `Stop` | Once, when Claude finishes responding (end of turn) |
| `PreToolUse` | Before a specific tool is invoked |
| `PostToolUse` | After a specific tool returns |
| `PostToolUseFailure` | After a specific tool returns an error |
| `PreCompact` | Before context compaction summarizes the conversation |

---

## Active Event Hooks

### `session-start-hook.sh`
**Event:** `SessionStart` — **Matcher:** _(all sessions)_

**Purpose:** On macOS, first clears `com.apple.macl` extended attributes from `.claude/hooks/` so that hook files modified by Claude Code's Write/Edit tools remain executable by subprocesses. (The Write/Edit tools set `com.apple.macl`, which blocks subsequent subprocess reads. `session-start-hook.sh` itself is immune — `update.sh` always refreshes it via `cp`, not the Write tool.) Then ensures the daily maintenance pipeline doesn't go unrun: checks whether today's `[judge]` sentinel exists in `observations.md`. If the local `daily-runner.sh` is installed and its state file is stale (>24h or missing), fires the runner in the background without blocking session start. If no local runner is installed and maintenance is overdue, injects a reminder for Claude to run `/kiro:daily-maintenance` interactively.

**Why it's needed:** The Task Scheduler fires at 11:30 IST daily, but the machine may be off or the WSL session closed at that time. The session-start hook is the catch-up path that guarantees maintenance runs at least once per developer day, with zero user friction.

**Output / side effect:**
- Nothing, if maintenance is current (happy path)
- `[SDD-MAINTENANCE-CATCHUP]` — silently fires `daily-runner.sh` in background via `nohup`
- `[SDD-MAINTENANCE-DUE]` — injected reminder to run `/kiro:daily-maintenance` (no local runner case)

**Respects:** `SDD_PROFILE=minimal` env var — skips entirely in minimal profile.

---

### `stop-hook.sh`
**Event:** `Stop` — **Matcher:** _(all sessions)_

**Purpose:** Six end-of-session health checks, all lightweight:

1. **Harness update check** — compares the harness repo’s latest commit timestamp to `.claude/.last-harness-check`. Prints a `Run: update.sh` nudge if the harness has changes since last install.
2. **Memory health** — counts entries in `observations.md`. If >50, suggests `/kiro:housekeeping` to prune before the file bloats.
3. **Session signal detection** — runs `scripts/detect_reexplanation.py` on the session transcript in two passes (Haiku-based LLM). Drain pass: phrases like "I already told you", "you’re doing it again" → appends a `[memory-gap]` observation. Charge pass: unambiguous approval like "that’s perfect", "great work" → appends a `[session-charge]` observation. Both are written at most once per calendar day.
4. **Agent failure pattern** — scans `trace.log` for 3+ consecutive failures for the same agent type. Surfaces a `/kiro:evolve` nudge to investigate the friction pattern.
5. **Session depth tracking** — appends an ISO timestamp to `.claude/memory/.session-history`, keeping the last 30 entries. This file is read by the dashboard’s **Context Health** section to show sessions/week, a sessions/day trend chart, and tips for `/compact` and subagent delegation.
6. **Setup sequence capture** — reads `.claude/memory/.setup-session-buffer.log` (populated during the session by `setup-buffer-hook.sh`). If ≥2 setup commands were accumulated, appends them as a dated `bash` code block under `## <project> — <date>` in `.claude/memory/setup-knowledge.md` (creating the file if needed), then clears the buffer. Threshold of 2 prevents trivial one-off installs from polluting the knowledge file.

**Why it’s needed:** Session-end is the only consistent window to look back at what happened without adding latency to the conversation. These checks surface problems that accumulate across sessions rather than within them. Session depth tracking gives the dashboard a lightweight signal for context load without requiring transcript analysis. Setup sequence capture ensures environment bootstrap steps are never lost — they are captured automatically without requiring Claude to remember to save them.

**Output / side effect:**
- Text nudges printed to Claude’s context (harness update, housekeeping)
- Appends `[memory-gap]` drain entries to `observations.md` (async, non-blocking)
- Appends `[session-charge]` charge entries to `observations.md` (async, non-blocking)
- Appends ISO timestamp to `.claude/memory/.session-history` (always, at session end)
- Appends setup command block to `.claude/memory/setup-knowledge.md` and clears buffer (when ≥2 setup commands captured)

**Respects:** `SDD_PROFILE=minimal` env var — skips entirely.

---

### `frontend-security-nudge.sh`
**Event:** `UserPromptSubmit` — **Matcher:** _(all prompts, keyword-gated)_

**Purpose:** Detects when the user is about to build frontend, UI, or design work and injects a reminder to invoke the `secure-agent-design` skill before starting. Fires on every prompt but exits in <5ms if no keywords match.

**Trigger logic:** Two conditions must BOTH be true:
1. **Build intent** — prompt contains: `build a`, `create a`, `add a`, `implement a`, `write a`, `scaffold`, `set up`
2. **Frontend subject** — prompt contains framework names (`react`, `vue`, `angular`, `svelte`, `nextjs`, `nuxt`, `remix`, `astro`…) or design keywords (`frontend`, `ui`, `ux`, `component`, `css`, `tailwind`, `form`, `button`, `modal`, `page`, `responsive`…)

**Why it's needed:** Security considerations (XSS, injection, input sanitization, prompt injection in agent-fed forms) are easiest to address before the first file is written. A question-only prompt like "how does React work?" does not trigger the nudge — only prompts with build intent.

**Output:** `╔══ Security Nudge ══╗` banner with the instruction to invoke `Skill("secure-agent-design")`. Silent on non-matching prompts.

---

### `memory-discipline-hook.sh`
**Event:** `PreToolUse` — **Matcher:** `Write|Edit`

**Purpose:** Gates any write to a memory file (`.claude/memory/*.md` or `MEMORY.md`) with discipline rules, printed before the write executes. Claude sees the rules and can revise the content before proceeding.

**Rules enforced:**
- Store only reusable patterns, preferences, and heuristics — not case-specific findings
- Transfer test: "Would this help a _different_ future task?" If not → write to an artifact, not memory

**Why it's needed:** Without a gate, Claude naturally stores investigation outcomes and entity-specific facts in memory. These pollute future context with stale, non-transferable data and cause the memory system to drift toward a case-log rather than a reusable knowledge base.

**Output:** Rules banner (`╔══ Memory Discipline Gate ══╗`) injected before the write executes.

---

### `impeccable-detect-hook.sh`
**Event:** `PostToolUse` — **Matcher:** `Write|Edit`

**Purpose:** Runs [Impeccable](https://github.com/nicholasgasior/impeccable) anti-pattern detector on the written file immediately after any Write or Edit to a frontend file (`tsx`, `jsx`, `css`, `scss`, `less`, `vue`, `svelte`, `html`).

**Why it's needed:** Frontend anti-patterns (e.g., CSS property ordering, accessible-name violations, layout anti-patterns) accumulate silently across edits. Catching them at write time, rather than at PR review, costs far fewer tokens and less rework.

**Output:** Anti-pattern warnings with severity; green check if clean. Fails silently if Impeccable is not installed — install with `npm install -g impeccable`.

---

### `action-capture.sh`
**Event:** `PostToolUse` — **Matcher:** `Bash` — _(soft gate, never blocks)_

**Purpose:** After high-signal Bash commands complete, performs two functions: (1) prompts Claude to consider saving a memory observation from the outcome; (2) **automatically** writes Wake-phase weakness markers when commands fail.

**Signal types:**

| Signal | Trigger | Action |
|--------|---------|--------|
| `git-commit` | `^git commit` | Advisory banner — prompt to save workflow lesson |
| `test-failure` | `pytest` + FAILED/ERROR in output | Advisory banner — prompt to save breakage pattern |
| `deploy` | docker/kubectl/helm deploy commands | Advisory banner — prompt to save env gotcha |
| `struggle` | Any Bash with non-zero exit code (new) | **Auto-writes** `[seed-target:<domain>]` observation to `observations.md` + advisory banner |

**Wake-phase tagging (Sleep Cycle Protocol):** The `struggle` signal is the harness implementation of the paper's Wake-phase weakness identification (Behrouz et al., 2026). When any Bash command fails, the hook infers a skill domain from the command content, auto-writes a `[seed-target:<domain>]` entry to `.claude/memory/observations.md`, then emits an advisory banner. No Claude decision required — the observation is written unconditionally. The nightly `skill-augment-agent` (Step D of daily maintenance) consumes these entries as seeding targets for the Sleep phase.

**Domain inference table:**

| Command contains | Inferred domain |
|-----------------|----------------|
| `pip`, `npm`, `yarn`, `poetry`, `uv` | `dependency-management` |
| `docker`, `kubectl`, `helm` | `deployment-engineer` |
| `git` | `git-advanced-workflows` |
| `curl`, `wget`, `http` | `api-patterns` |
| `python`, `.py` | `python-pro` |
| `node`, `npm`, `.ts`, `.tsx` | `nodejs-best-practices` |
| _(default)_ | `systematic-debugging` |

**Design principle:** "Memory from what agents DO, not just what they say" — extracted from Memori's architecture. The struggle extension adds automatic capture without requiring Claude to decide.

**Why it's needed:** Git commits, test failures, and deploys are high-signal moments. Failed commands are even higher-signal — they reveal exactly where skills are weak. Without automatic capture, these weakness signals evaporate at session end and the nightly improvement pipeline has no targets.

**Noise control:** Advisory signals only fire on the four specific patterns; silent on all other Bash commands. Test passes are intentionally excluded (low signal). The hook exits 0 always.

**Output:** `╔══ Action Capture ══╗` banner (advisory) for all signal types. `[seed-target:]` observation written silently to `observations.md` for `struggle` signal only.

**Location:** `~/.claude/hooks/action-capture.sh` (global — fires across all projects)

---

### `setup-buffer-hook.sh`
**Event:** `PostToolUse` — **Matcher:** `Bash`

**Purpose:** After every Bash command, checks whether the command matches a setup-like pattern and, if so, appends it to a per-session accumulation buffer (`.claude/memory/.setup-session-buffer.log`). The buffer is consumed at session end by `stop-hook.sh`, which writes the captured commands to `.claude/memory/setup-knowledge.md`.

**Patterns detected** (prefix-matched, case-insensitive):
- Package managers: `pip install`, `pip3 install`, `npm install`, `npm ci`, `yarn install`, `yarn add`, `pnpm install`, `pnpm add`, `brew install`, `apt-get install`, `apt install`, `cargo build`, `go mod download`, `bundle install`, `composer install`, `gem install`, `uv sync`, `uv pip install`, `poetry install`, `conda install`
- Docker: `docker-compose`, `docker compose`, `docker build`, `docker pull`
- Database setup: `createdb`, `dropdb`, `psql ... CREATE/DROP`, `mysql`
- Migrations: `python manage.py migrate`, `rails db:`, `alembic upgrade`, `prisma migrate`, `prisma db push`
- Environment: `source *.env`, `cp *.env* ...`, `export VAR=`
- Repo bootstrap: `git clone`, `git submodule update`, `make install`, `make setup`, `make init`, `make bootstrap`

**Noise control:** Skips multi-line commands (>3 lines) — these are typically inline scripts, not atomic setup steps. Silent on all non-matching commands.

**Why it's needed:** Environment bootstrap steps (dependencies, DB setup, env config) are the most-forgotten class of knowledge across sessions. Running the same `pip install` sequence when re-visiting a project, or onboarding someone, typically requires re-reading docs or asking. Automatic capture at the moment the commands run means `setup-knowledge.md` is always current without requiring Claude to remember to save them. Paired with `stop-hook.sh` (write) to keep the buffer-flush logic together at a natural session boundary.

**Output / side effect:** Appends command line to `.claude/memory/.setup-session-buffer.log`. No context output — silent capture.

---

### `revert-detect-hook.sh`
**Event:** `PostToolUse` — **Matcher:** `Bash`

**Purpose:** Immediately appends a `[revert]` drain observation to `observations.md` when Claude runs `git revert`, `git reset --hard/--mixed/HEAD`, or `git restore --` / `git checkout --`.

**Why it's needed:** The trust-battery Judge scores session quality at the end of each day. Revert events are significant negative signals (they indicate a plan that had to be walked back). Without real-time capture, the Judge has to infer reverts from transcript analysis — less reliable and potentially missed. Writing the observation at the moment the command runs gives the Judge concrete, timestamped evidence.

**Output / side effect:** Appends `YYYY-MM-DD [revert]: git-revert|git-reset|git-restore — <command>` to `observations.md`. De-duplicates within the same day.

---

### `tool-failure-capture.sh`
**Event:** `PostToolUseFailure` — **Matcher:** `Bash|mcp__.*`

**Purpose:** Records every failing Bash or MCP tool call into a per-repo ledger (`.claude/memory/tool-failures.jsonl`), keyed by a normalized command *signature*. Bash commands are collapsed — quoted strings → `<str>`, slash-bearing tokens → `<path>`, hashes → `<hash>`, numbers → `<n>` — so the *same kind* of failure clusters under one entry whose `count` climbs. MCP calls key on `tool_name(sorted,arg,keys)`. A failure that recurs after being marked `resolved` is automatically re-opened.

**Why it's needed:** Without a durable record, the harness re-runs the same broken command shape across sessions (wrong flag, missing dep, bad path) and re-learns the failure each time. This is the **capture** half of the tool-failure-memory loop — adapted from ReMe's procedural/tool memory, made deterministic via a hook so it fires on every failure, not when Claude remembers to.

**Output / side effect:** Upserts a JSON line into `.claude/memory/tool-failures.jsonl` (`{sig, tool, count, first_seen, last_seen, last_error, samples, status, remedy, promoted}`). No context output — silent capture. Paired with `tool-failure-recall.sh` (recall) and the `tool-failure-review` routine (promote-to-memory). See the `tool-failure-memory` skill.

---

### `tool-failure-recall.sh`
**Event:** `PreToolUse` — **Matcher:** `Bash|mcp__.*` — _(soft gate, never blocks)_

**Purpose:** Before a Bash/MCP call runs, computes the same signature as the capture hook and looks it up. If that shape has failed ≥2× and is still `open`, it injects a short advisory showing the failure count, last error, and any recorded remedy — then exits 0. This is the **recall** half that makes failures "not happen again."

**Noise control:** Warns at most once per session per signature (dedupe file `.claude/memory/.tool-failure-recall-seen`) and ignores entries whose last failure is older than 45 days. Silent on everything else. Tunable via `TOOL_FAILURE_MIN_FAILS` / `TOOL_FAILURE_MAX_AGE_DAYS`.

**Why it's needed:** Capturing failures is useless unless the memory surfaces *before* the repeat. The soft gate keeps Claude in control — it advises reconsidering, never blocks — so a genuinely-now-fixed command can still proceed.

**Output:** `⚠️  Tool-failure memory — this command shape has failed N× …` banner with signature, last error, and remedy. Silent (exit 0) when no recent open failure matches.

---

### `gbrain-agent-spawn.sh`
**Event:** `PreToolUse` — **Matcher:** `Agent`

**Purpose:** Injects model-tier selection and background-routing guidance before every subagent spawn. Part of the GBrain patterns suite.

**Rules enforced:**
- **Model tiers:** Haiku for classification/validation, Sonnet for generation/synthesis (default), Opus only for high-stakes deep reasoning. Subagents should default to Sonnet — latency compounds in loops and Opus rarely adds value there.
- **Background routing:** Inline unless a pain signal fires (gateway restart, dropped state, >3 parallel agents, >5 min expected runtime, user frustration).
- **Memory-first brief:** Run `mcp__plugin_claude-mem_mcp-search__search` before writing the agent prompt, to avoid re-discovering known context.

**Why it's needed:** Without guidance, the default is to pick whatever model feels right (often Opus) and always run inline. Both choices compound token cost and latency across multi-agent sessions without a commensurate quality benefit.

**Output:** GBrain protocol banner injected before the Agent tool executes.

---

### `gbrain-external-search.sh`
**Event:** `PreToolUse` — **Matcher:** `WebFetch|WebSearch`

**Purpose:** Reminds Claude to check `claude-mem` before calling external APIs. Part of the GBrain patterns suite.

**Why it's needed:** External web calls are expensive (tokens + latency) and often unnecessary — prior research sessions have already fetched and stored the relevant content in memory. A quick memory search first can avoid the external call entirely.

**Output:** 4-step memory-first checklist: search → semantic search if thin → get_observations for hits → external only if nothing useful found.

---

### `raindrop-best-practices.sh`
**Event:** `PreToolUse` — **Matcher:** `mcp__raindrop__`

**Purpose:** Before any Raindrop Workshop MCP tool call, injects active observability best practices that reduce token cost and improve cluster quality.

**Rules injected:**
1. **Batch facets** — run multiple analytical dimensions in one LLM call (not one call per dimension)
2. **Facet-first** — summarize each trace in 1-2 sentences before clustering (raw traces produce noisy clusters)
3. **Cap input** — preprocess to ≤128K tokens before LLM analysis (walk spans, deduplicate messages, drop scorer/metric spans)
4. **No-LLM classify** — at classification time use nearest-summary lookup (~100ms; no LLM call needed once a topic map exists)
5. **Long tail** — don't sample aggressively; bugs live in rare clusters (HDBSCAN with no pre-specified count; outliers → `no_match`, not forced)

**Why it's needed:** Raindrop trace analysis is token-heavy. Without guidance, the natural pattern is to feed raw trace payloads into LLMs one at a time — multiplying cost. These patterns compress the input surface and batch analytical work so trace evaluation runs at ~10–20% of the naïve cost.

**Output:** `╔══ Active Observability (Raindrop) ══╗` rules banner before every Raindrop MCP call.

---

### `gbrain-memory-write.sh`
**Event:** `PreToolUse` — **Matcher:** `mcp__plugin_claude-mem_mcp-search__save_observation`

**Purpose:** Injects compiled-truth structure guidance before every MCP memory write. Part of the GBrain patterns suite.

**Rules enforced:**
- **STATE zone (top):** Current synthesis. Rewrite in place when new evidence arrives. Every fact needs a source citation.
- **EVIDENCE / TIMELINE zone (bottom):** Append-only dated log. Never edit past entries.
- Source precedence: user statements > compiled truth > timeline entries > external sources.

**Why it's needed:** Without structure guidance, observations tend to be pure append-only logs. Over time, the STATE zone drifts (stale facts never get updated) while the TIMELINE grows unboundedly. The two-zone pattern keeps the current understanding clean and the historical record intact.

**Output:** Compiled-truth pattern banner injected before the save_observation call.

---

### `compaction-discipline-hook.sh`
**Event:** `PreCompact` — **Matcher:** _(all compactions)_

**Purpose:** Injects boundary-timing, state-preservation, and domain-aware compression principles before every context compaction.

**Rules enforced:**
- **Timing:** Compact at workflow boundaries (end of phase, task completion) — not arbitrary message counts.
- **Preserve:** Working state, open questions, artifact paths, unresolved concerns, decisions + rationale.
- **Do not over-compress:** Never strip file paths, function names, error messages, specific values.
- **Domain-aware strategy:** Code → chunk-level (keep signatures, drop implementations already acted on). Prose → sentence-level (keep topic sentences, drop elaboration). RAG results → query-aware (filter to last user intent). Conversation → keep decisions and user corrections, drop filler. Tool output → keep errors and key metrics, drop passing output.
- **Method:** Merge new content into existing summary sections — do not regenerate from scratch.

**Why it's needed:** Default compaction regenerates the summary from scratch on each pass. Research on consolidation loop failure modes ([faulty-memory](https://dylanzsz.github.io/faulty-memory/)) shows that full regeneration causes LLM sampling drift — each pass shifts content toward the model's prior, away from ground truth. Anchored iterative summarization (merge, not regenerate) is the mitigation. Domain-specific strategy selection is grounded in [Redis context pruning research](https://redis.io/blog/context-pruning-llm-tokens/) showing chunk-level pruning outperforms token-level for code (preserves syntactic validity), while sentence-level is better for prose.

**Output:** Compaction discipline banner injected before compaction executes.

---

### `lean-ctx-nudge-hook.sh`
**Event:** `PostToolUse` — **Matcher:** `Read`

**Purpose:** After every Read tool call on a large file (≥16 KB ≈ 4,000 tokens), prints a one-line suggestion for the optimal `ctx_read` mode from lean-ctx, along with the token cost context.

**Mode selection logic:**
- Code files (`.py`, `.ts`, `.js`, `.go`, `.rs`, etc.) → `signatures` mode (~3–5% of full-file tokens)
- Prose / docs (`.md`, `.txt`, `.rst`) → `reference` mode (quote-ready excerpts)
- Unknown types → `aggressive` mode (maximum compression)
- Data formats (`.json`, `.yaml`, `.toml`, `.lock`) → silently skipped (lean-ctx intentionally skips these)

**Why it's needed:** RTK handles Bash output compression automatically, and lean-ctx handles file reads — but only if Claude chooses `ctx_read` over the built-in Read tool. Without a nudge, Claude defaults to Read and pays full token cost for large files. This hook closes that gap by surfacing the right `ctx_read` mode immediately after an expensive Read, so the next re-read or similar file uses the efficient path. The mode guidance follows [Redis context pruning research](https://redis.io/blog/context-pruning-llm-tokens/): chunk-level for code, sentence-level for prose, query-aware (`task` mode) for precision work.

**Output:** `╔══ lean-ctx Opportunity (~N tokens) ══╗` banner with the recommended mode and alternatives. Exits silently for files under threshold.

---

### `skill-permissions-gate.sh`
**Event:** `PostToolUse` — **Matcher:** `Write|Edit` — _(soft gate, never blocks)_

**Purpose:** After any Write or Edit to a `*/skills/*/SKILL.md` path, prompts Claude to invoke `agent-permissions-design` and verify four dimensions before marking skill creation complete: (1) tool access — does the skill direct Claude to use destructive tools? (2) irreversible action gates — are high-risk steps preceded by a verification instruction? (3) scope boundary — are trigger conditions specific enough to prevent misfire? (4) external access — does the skill touch external services or credentials least-privilege?

**Design principle:** Skills are mini-agents — they direct Claude to take actions with tools. The same rigor applied to AI agent authorization systems (`agent-permissions-design`) applies to skill design: scope it, gate destructive actions, keep triggers tight. Extracted from the VentureBeat article "The AI agent bottleneck isn't model performance — it's permissions" (2026-05-29).

**Why it's needed:** Without this gate, newly created skills could instruct Claude to run shell commands, overwrite files, or call external APIs without scoping, verification steps, or explicit "Do Not Use" guards. The hook catches these at write time rather than during a later security audit.

**Noise control:** Only fires on `*/skills/*/SKILL.md` paths — silent on all other Write/Edit operations. Never blocks (exits 0 always).

**Output:** `╔══ Skill Permissions Gate ══╗` reminder banner listing the four review dimensions. Silent on no match.

**Location:** `~/.claude/sdd-harness/.claude/hooks/skill-permissions-gate.sh`

---

### `caveman-activate.js`
**Event:** `SessionStart` — **Matcher:** _(all sessions)_

**Purpose:** Activates Caveman response compression at the configured intensity level at the start of every session. Reads `~/.config/caveman/config.json` (or `CAVEMAN_DEFAULT_MODE` env var) to determine the level. Emits the full Caveman ruleset filtered to the active level as session context, anchoring Claude's response style for the entire session. Writes a flag file (`~/.claude/.caveman-active`) for statusline display.

**Default level:** `lite` — strips filler words, pleasantries, and hedging while keeping full technical substance. User can upgrade (`/caveman full`, `/caveman ultra`) or disable (`normal mode`) at any point mid-session.

**Levels:**
- `lite` — light trim: removes pleasantries and hedging; fragments allowed
- `full` — moderate compression: terse prose, short synonyms, no elaboration (default upstream)
- `ultra` — telegraphic: maximum brevity, every non-essential word removed
- `wenyan` — classical Chinese compression (stress test of brevity)

**Why it's needed:** Caveman only applies for a session if explicitly invoked with `/caveman`. A SessionStart hook makes it the default behavior without requiring the user to remember to activate it. The full ruleset is emitted (not a short summary) because the 2-sentence version drifts mid-session; full rules with examples anchor the style reliably even after compaction.

**Output:** `CAVEMAN MODE ACTIVE — level: lite` followed by the filtered ruleset. If statusline is not configured, appends a setup nudge.

**Location:** `~/.claude/hooks/caveman-activate.js` (global, installed by `npx github:JuliusBrussee/caveman`)

---

### `address-check-hook.sh`
**Event:** `Stop` — **Matcher:** _(all turns)_

**Purpose:** Verifies that every assistant response addressed the user as "Husband". Fires after each turn. Reads the latest session transcript, extracts the last assistant message, and checks for the word "husband" (case-insensitive).

**Outputs:**
- Nothing, if "Husband" present — exit 0, stop proceeds normally
- `[address-check]` correction banner — exit 2 (blocks stop) if "Husband" absent, injecting a prompt that instructs Claude to run `/compact`, re-read CLAUDE.md, and re-respond correctly

**Why a hook and not a prompt:** CLAUDE.md instructions are subject to context degradation — Claude eventually stops following them as context fills. A Stop hook fires unconditionally after every turn regardless of context state. The exit 2 path creates a self-correcting loop: the injected message reaches Claude as its next input, and the next response is forced to include "Husband". Absence of the term is also a reliable early signal that CLAUDE.md is being ignored, triggering `/compact` before other rules degrade too.

**Location:** `~/.claude/hooks/address-check-hook.sh` (global, all projects)

---

### `hook-added-notify.sh`
**Event:** `PostToolUse` — **Matcher:** `Write|Edit`

**Purpose:** Detects when a new hook file is written to `.claude/hooks/` and injects a reminder into Claude's context to document it in this file before the session ends.

**Why it's needed:** Hook files are written infrequently, which means documentation often lags. A real-time reminder at the moment of creation ensures the docs stay in sync without requiring a separate workflow step.

**Output:** Documentation reminder banner if the written file path matches `*.claude/hooks/*.sh` and the hook is not yet listed in `docs/hooks/README.md`.

---

### `protected-path-hook.sh`
**Event:** `PreToolUse` — **Matcher:** `Write|Edit`

**Purpose:** Guards writes to sensitive files. When a write targets a known-sensitive path, Claude is shown a confirmation banner and must pause to ask the user before proceeding.

**Paths covered:**
- `.env` and `.env.*` variants
- Cryptographic keys and certs: `.pem`, `.key`, `.p12`, `.pfx`, `.cert`, `.crt`, `.jks`, `.keystore`
- Credentials files: `credentials`, `.secrets`, `secrets`
- AWS credentials: `.aws/credentials`, `.aws/config`
- SSH directory: `.ssh/`

**Why it is needed:** LLM agents can write to any path they have access to. A misrouted write to `.env` or `.aws/credentials` could silently overwrite secrets. This hook adds an explicit human confirmation step before any write to a known-sensitive path pattern.

**Output:** Confirmation required banner (`╔══ Protected Path — Confirmation Required ══╗`) injected into Claude's context before the write. Claude must pause and explicitly ask the user before proceeding.

---

### `skill-validate-hook.sh`
**Event:** `PreToolUse` — **Matcher:** `Write|Edit`

**Purpose:** Quality gate for skill file authoring. Before any Write to `~/.claude/skills/<name>/SKILL.md`, validates that the YAML frontmatter is structurally correct and meets quality thresholds. Hard-blocks (exit 2) on errors; warns (exit 0) on vague phrasing.

**Rules enforced:**
- `name:` field must exist and be kebab-case (`[a-z][a-z0-9-]*`)
- `name:` value must match the file path slug (e.g. `name: my-skill` in `~/.claude/skills/my-skill/SKILL.md`)
- `description:` field must exist and be at least 25 characters
- Warns if description starts with vague starters: `a skill that`, `this skill`, `skill for`, `use this skill`, `provides`

**Exit codes:**
- `0` — valid (or file not in skills dir — hook is a no-op)
- `0` with warning banner — valid but description starts with a vague phrase
- `2` — hard block: one or more errors must be fixed before write proceeds

**Why it is needed:** Skill descriptions are the primary signal Claude uses to decide when to activate a skill. Vague, too-short, or mismatched names silently degrade trigger accuracy across all sessions. Catching these at write time is zero-cost compared to diagnosing misfired or missed skill activations later.

**Output:**
- On error: `╔══ Skill Quality Gate — BLOCKED ══╗` banner listing each error with the required frontmatter format
- On warning only: `╔══ Skill Quality Gate — WARNING ══╗` banner with advisory message
- On pass: no output (silent)

---

## Hook Wiring Reference

From `.claude/settings.json`:

```
SessionStart   → session-start-hook.sh
SessionStart   (all)                                        → caveman-activate.js  [global, ~/.claude/hooks/]
Stop           → stop-hook.sh
Stop           (all)                                        → address-check-hook.sh
UserPromptSubmit (all, keyword-gated)                       → frontend-security-nudge.sh
PreToolUse     Bash                                          → rtk hook claude  [global, ~/.claude/settings.json — token compression]
PreToolUse     Write|Edit                                    → memory-discipline-hook.sh
PreToolUse     Write|Edit                                    → protected-path-hook.sh
PreToolUse     Write|Edit                                    → skill-validate-hook.sh
PreToolUse     Agent                                         → gbrain-agent-spawn.sh
PreToolUse     mcp__raindrop__                               → raindrop-best-practices.sh
PreToolUse     mcp__plugin_claude-mem_mcp-search__save_obs  → gbrain-memory-write.sh
PreToolUse     WebFetch|WebSearch                            → gbrain-external-search.sh
PostToolUse    Write|Edit                                    → impeccable-detect-hook.sh
PostToolUse    Write|Edit                                    → hook-added-notify.sh
PostToolUse    Write|Edit  (*/skills/*/SKILL.md only)        → skill-permissions-gate.sh
PostToolUse    Bash                                          → action-capture.sh
PostToolUse    Bash                                          → revert-detect-hook.sh
PostToolUse    Bash                                          → setup-buffer-hook.sh
PostToolUse    Read                                          → lean-ctx-nudge-hook.sh
PreToolUse     Bash|mcp__.*                                  → tool-failure-recall.sh
PostToolUseFailure Bash|mcp__.*                              → tool-failure-capture.sh
PreCompact     (all)                                         → compaction-discipline-hook.sh
```

The `tool-failure-*` pair plus the `tool-failure-review` routine form the **tool-failure-memory loop** (capture → recall → review). See the `tool-failure-memory` skill and `docs/harness-documentation/SDD-SETUP-GUIDE.md`.

---

## Adding a New Hook

1. Write the script to `.claude/hooks/<name>.sh` and `chmod +x` it.
2. Add the wiring entry to `.claude/settings.json` under the appropriate event.
3. Document it in this file (the `hook-added-notify.sh` hook will remind you if you forget).
4. Update the Wiring Reference table above.

_Last synced: 2026-06-02 — added `caveman-activate.js` (SessionStart — auto-activates caveman lite every session; user adjusts via /caveman full|ultra or disables with "normal mode"); added `rtk hook claude` to wiring reference (PreToolUse Bash — replaces ztk, 60–90% Bash output compression, global)._

