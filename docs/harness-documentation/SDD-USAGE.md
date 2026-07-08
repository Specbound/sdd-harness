<!-- L0: Quick reference — all SDD commands with usage examples -->

# SDD Usage Guide

How to use the Spec-Driven Development harness day-to-day.

---

## Project Memory

### `/kiro:steering` — Bootstrap or refresh project knowledge
Scans the codebase and generates `.claude/steering/` files (product, tech, structure).

```
/kiro:steering
```
Run once on a new project, or after major architectural changes.

### `/kiro:steering-custom` — Add domain-specific steering
Creates a focused steering doc for a specific domain.

```
/kiro:steering-custom database
/kiro:steering-custom authentication
/kiro:steering-custom api-standards
```

---

## Ideation & Debugging

### `/kiro:idea-refine` — Refine a vague idea into a spec-ready brief
Takes a rough idea through structured divergent/convergent thinking to produce a clear problem statement, proposed solution, constraints, and a paste-ready description for `/kiro:spec-init`.

```
/kiro:idea-refine "something to help users track their spending"
/kiro:idea-refine "we need better error handling"
```

Wired into `/kiro:spec-quick` — in interactive mode, if the description is vague, you'll be prompted to refine first.

### `/kiro:debug` — Systematic 6-step bug triage
Follows: Reproduce → Localize → Reduce → Fix → Guard → Verify. Won't guess at a fix without reproduction first. Adds a regression test automatically.

```
/kiro:debug "TypeError: Cannot read property 'id' of undefined in user profile endpoint"
/kiro:debug "intermittent 500 errors on /api/tasks when payload is empty"
```

Wired into `/kiro:jira-solve` — BUG/DEFECT tickets route through the debug methodology automatically.

### `/kiro:simplify` — Behavior-preserving code simplification
Reduces complexity while preserving identical behavior. Follows Chesterton's Fence: understands why code exists before removing it. Runs tests before AND after.

```
/kiro:simplify src/services/auth.ts
/kiro:simplify revenue-trend-chart        # simplify files from a feature's tasks
```

Wired into spec-refactor — if 3+ complexity findings detected during self-review, you'll be prompted to run simplify.

### `/kiro:ship` — Launch readiness check
Coordinates verification → production validation → rollout planning. Generates staged rollout plan with decision thresholds and rollback procedure.

```
/kiro:ship revenue-trend-chart
/kiro:ship                                 # general project readiness
```

Wired into `/kiro:verify` — after successful pre-pr verification, suggested as next step for production deployment.

---

## Spec Workflow

### `/kiro:spec-init` — Start a new feature
Creates a spec workspace in `specs/` with metadata tracking.

```
/kiro:spec-init "Add revenue trend chart to dashboard"
```

### `/kiro:spec-requirements` — Generate requirements
Produces EARS-format requirements for an initialized spec. After generation, opens a **[Proof](https://github.com/anthropics/proof) collaborative review session** — a shared URL where you annotate, comment, and approve the requirements document. The approved version is written back before proceeding.

```
/kiro:spec-requirements revenue-trend-chart
```

### `/kiro:spec-design` — Generate technical design
Researches the codebase and produces a design doc with architecture decisions. After generation, opens a **Proof collaborative review session** for annotation and approval before proceeding to tasks.

```
/kiro:spec-design revenue-trend-chart
```

### `/kiro:spec-grill` — Domain grilling session
Runs an interactive domain-expert questioning session against the approved requirements and design. Asks one question at a time, waits for your answer, and updates `requirements.md`, `design.md`, and `CONTEXT.md` inline as decisions crystallise. Writes warranted Architecture Decision Records (ADRs) to `specs/\<feature\>/docs/adr/`. Requires design phase to be approved first.

```
/kiro:spec-grill revenue-trend-chart
```

Signal completion with "done", "looks good", or "move on". Also available as phase 3.5 in `/kiro:spec-quick` (interactive mode); skipped in `--auto` mode since it requires user interaction.

### `/kiro:spec-tasks` — Generate implementation tasks
Breaks the design into parallelizable tasks with dependencies. After generation, opens a **Proof collaborative review session** for approval before implementation begins. Pass `--sequential` to suppress parallel `(P)` markers when you want strictly ordered tasks.

```
/kiro:spec-tasks revenue-trend-chart
/kiro:spec-tasks revenue-trend-chart --sequential   # disable parallel task markers
```

### `/kiro:spec-quick` — Fast path (requirements → design → grill → tasks)
Runs all spec phases in one command: requirements → design → grill → tasks. Good for small features. In interactive mode, prompts at each phase and runs the grill session. Pass `--auto` to skip prompts and grill (which requires user interaction).

```
/kiro:spec-quick "Add retry logic to SQL query execution"
```

### `/kiro:spec-impl` — Implement from approved spec
Executes tasks via TDD (test first, then code, then verify). After each task's VERIFY step passes, a self-review agent automatically inspects the touched files for code reuse, quality, and efficiency issues, fixes confirmed issues (skipping false positives), and re-runs the tests — stopping and surfacing any failures before marking the task complete. The self-review findings appear in the final summary.

```
/kiro:spec-impl revenue-trend-chart
```

### `/kiro:spec-status` — Check spec progress
Shows current phase, approvals, and open tasks.

```
/kiro:spec-status revenue-trend-chart
```

---

## Verification & Error Recovery

### `/kiro:verify` — Run verification pipeline
Runs a multi-stage pipeline: build, type-check, lint, test, debug artifact audit, and git status. Reports structured PASS/FAIL per stage.

```
/kiro:verify              # full (all 6 stages)
/kiro:verify quick        # build + test only
/kiro:verify pre-commit   # build + types + lint + test
/kiro:verify pre-pr       # all stages with stricter thresholds
```

### `/kiro:fix-build` — Resolve build errors automatically
Runs diagnostics, categorizes errors, and applies minimal surgical fixes. Hard cap of 3 attempts.

```
/kiro:fix-build
```

### `/kiro:checkpoint` — Named workflow checkpoints
Create, compare, or restore named save points during long implementation sessions.

```
/kiro:checkpoint save task-1.2-done     # create checkpoint
/kiro:checkpoint compare task-1.2-done  # show changes since
/kiro:checkpoint list                   # show all checkpoints
/kiro:checkpoint restore task-1.2-done  # soft reset (with confirmation)
```

---

## Validation

### `/kiro:validate-gap` — Requirements vs. code gap analysis
Checks what's been implemented vs. what's required.

```
/kiro:validate-gap revenue-trend-chart
```

### `/kiro:validate-design` — Design quality review
Reviews the design doc for completeness and consistency.

```
/kiro:validate-design revenue-trend-chart
```

### `/kiro:validate-impl` — Implementation validation
Verifies code matches the spec (requirements + design + tasks). On NO-GO, provides a structured remediation plan with `filepath:line` references.

```
/kiro:validate-impl revenue-trend-chart
```

### `/kiro:validate-adversarial` — High-confidence adversarial review
Three-pass review: (1) neutral assessment, (2) adversarial refutation, (3) judge synthesis with asymmetric +1/-2 scoring. Use for high-stakes validations.

```
/kiro:validate-adversarial revenue-trend-chart design
/kiro:validate-adversarial revenue-trend-chart impl
```

### `/kiro:validate-perf` — Performance anti-pattern review
Checks for N+1 queries, unbounded operations, blocking I/O, missing indexes, and caching opportunities.

```
/kiro:validate-perf revenue-trend-chart
/kiro:validate-perf                           # auto-detect from git diff
```

### Production Readiness (Gate 5) — Auto-triggered
Scans for deployment gaps (env config, containerization, resilience, observability, data safety, security posture, staging/CI) and generates a human attestation checklist. **Auto-triggered** when `/kiro:spec-impl` completes all tasks for a feature — no manual invocation needed.

---

## Documentation Sync

### `/kiro:sync-docs` — Sync docs with code changes
Finds all `.md` files referencing changed code and updates them. Runs automatically at session end, but can be triggered manually.

```
/kiro:sync-docs
```

---

## Memory (Cog)

### `/kiro:reflect` — Mine session learnings
Reviews recent work, extracts observations, promotes patterns, updates hot-memory.

```
/kiro:reflect
```
Run after completing a spec, finishing a debugging session, or at end of a productive session.

### `/kiro:learn-eval` — Quality-gated pattern evaluation
Evaluates session patterns with quality scoring (specificity, actionability, evidence). Deduplicates against existing knowledge and produces save/absorb/route/drop verdicts (route = skill-tied lesson pushed into its skill instead of memory). Deeper than `/kiro:reflect` — use periodically.

```
/kiro:learn-eval              # evaluate current session
/kiro:learn-eval sprint       # evaluate since last learn-eval
/kiro:learn-eval feature      # evaluate patterns from a specific spec
```

### `/kiro:save-session` — Save session for later
Captures a structured Progress Tracker (feature, git baseline/head, tasks completed/remaining, blockers, next action) plus narrative sections: what worked, what didn't, untried approaches, file states, and the exact next step.

```
/kiro:save-session bug-fix-auth
/kiro:save-session                # auto-named with timestamp
```

### `/kiro:resume-session` — Resume a saved session
Loads and displays a session snapshot. If the session contains a Progress Tracker, auto-orients with a Pickup Briefing (commits since save, blocker status, suggested next action). You decide what to do next.

```
/kiro:resume-session bug-fix-auth
/kiro:resume-session              # most recent session
/kiro:resume-session list         # show all saved sessions
```

### `/kiro:context-budget` — Analyze context token usage
Measures token footprint of steering, memory, rules, and CLAUDE.md. Recommends optimizations.

```
/kiro:context-budget
```

### `/kiro:housekeeping` — Prune and archive memory
Archives old observations to glacier, enforces caps, validates formats.

```
/kiro:housekeeping
```
Run when the stop-hook nudges you, or periodically.

### `/kiro:evolve` — Audit harness rules and agent prompt quality
Measures memory health, detects friction patterns, proposes rule improvements. Includes:
- **Graduation pipeline** — identifies conventions suitable for promotion from docs to linter enforcement
- **Alignment analysis** — computes per-agent alignment scores from trace.log, flags underperformers
- **Prompt diagnosis** — for flagged agents, produces structured root cause analysis with specific instruction changes (ADD/REMOVE/SHARPEN)
- **Data-driven tiering** — recommends model tier promotions/demotions based on alignment evidence
- **Instruction architecture health** (Step 1d) — audits entry file for bloat (>200 lines), low SNR (<60%), hard constraints after line 50 (lost-in-middle), missing topic documents
- **Session clean state health** (Step 1e) — checks PROGRESS.md freshness, debug artifact presence, verify path documentation; output includes "Harness Architecture Health" scorecard

```
/kiro:evolve
```
Run on demand when something feels off about the workflow, or periodically to audit prompt quality. After approving proposals:
- `graduate-to-linter` → run `/kiro:guardrails scaffold`
- `add/remove/modify-instruction` → run `/kiro:harness-test regression`
- `adjust-tier` → run `/kiro:harness-test {agent-name}` at the new tier

### `/kiro:guardrails` — Audit and scaffold linter guardrails
Checks your project's linter configuration for complexity rules and scaffolds missing guardrails. Supports ESLint (JS/TS), ruff (Python), clippy (Rust), and golangci-lint (Go).

```
/kiro:guardrails              # audit: check existing config for complexity rules
/kiro:guardrails scaffold     # create or enhance linter config with recommended baselines
/kiro:guardrails report       # show enforcement maturity level (L0-L3)
```

Recommended baselines: `max-lines-per-function: 40`, `complexity: 10`, `max-depth: 3`, `max-params: 4`, with zero-warning tolerance (`--max-warnings=0`).

### `/kiro:ci-scaffold` — Generate CI configuration
Generates a CI configuration that mirrors the `/kiro:verify` pipeline stages. Auto-detects platform or accepts an explicit argument.

```
/kiro:ci-scaffold             # auto-detect platform from existing config
/kiro:ci-scaffold github      # generate GitHub Actions workflow
/kiro:ci-scaffold gitlab      # generate GitLab CI config
/kiro:ci-scaffold azure       # generate Azure Pipelines config
```

The generated pipeline enforces: build, type-check, lint (with zero-warning tolerance), tests, and debug artifact audit.

### `/kiro:harness-validate` — Check harness structural integrity
Validates command→agent references, template existence, memory caps, L0 headers, and generates a component relationship index. Also includes:
- **Step 8: Instruction architecture audit** — entry file line count vs. 50–200 target, hard constraint count vs. 15 max, topic document adoption, hard-constraint phrases after line 50 (lost-in-middle risk)
- **Step 9: Feature list primitive audit** — triple structure compliance (behavior+verification+state), WIP=1 discipline, pass-state gating evidence

```
/kiro:harness-validate
```
Run after `update.sh` or when something feels broken.

### `/kiro:harness-test` — Smoke-test and regression-test prompts
Runs key workflows at Haiku tier to expose vague instructions. Failures indicate prompt quality issues, not model issues.

```
/kiro:harness-test                        # smoke-test the standard suite
/kiro:harness-test steering               # smoke-test a specific agent
/kiro:harness-test regression             # run scenario-based regression tests
/kiro:harness-test regression steering    # regression test a specific agent
```

**Smoke mode** (default): Runs agents at Haiku tier and checks for structural correctness. Use after editing any agent or rule file.

**Regression mode**: Runs scenarios from `.claude/memory/meta/prompt-scenarios.md`, scores alignment against expected outcomes, and flags regressions. Use after approving instruction library changes from `/kiro:evolve`.

See `docs/prompt-improvement/README.md` for the full prompt optimization workflow.

### `/kiro:harness-fix` — Fix a specific agent mistake
When you observe the agent making a repeatable behavioral mistake, this command encodes a targeted prevention rule so it never happens again. Lighter than `/kiro:evolve` — fixes one thing immediately.

```
/kiro:harness-fix "agent keeps creating new utility files instead of reusing existing ones"
/kiro:harness-fix "agent runs the full test suite instead of targeted tests"
```
The rule is added to the appropriate agent file or rule file and distributed via `update.sh`.

---

## Daily Maintenance (Automated)

### `/kiro:daily-maintenance` — Nightly orchestrator

Runs the full maintenance cycle end-to-end: **Judge → Reflect → Housekeeping → Session Quality → Keep Rate → Trust Score → Augment Skills → Adversarial Check**. Designed to run on a nightly schedule (18:00 local) with a SessionStart hook as catch-up. The scheduler is registered automatically by `install.sh` / `update.sh`: Windows Task Scheduler on WSL (`setup-global-orchestrator.sh`), cron on Linux (`setup-linux-orchestrator.sh`), and launchd on macOS (`setup-mac-orchestrator.sh`).

```
/kiro:daily-maintenance
```

Pipeline:

1. **`session-judge`** — independent adversarial scorer. Reads the last 24h of `observations.md` + trace log, applies the rubric in `kiro/settings/rules/session-quality-rubric.md`, emits a JSON verdict (±1 charges, -2 drains, ±4.5%/day cap). **Proposes no fixes** — if the same agent scored and improved, it would optimize for score, not work.
2. **`/kiro:reflect`** — consumes the Judge's drains as priority signals, converts them into new memory entries or pattern promotions.
3. **`/kiro:housekeeping`** — prunes/archives observations, enforces memory caps.
4. **Memory-gap alert** — if any `[memory-gap]` observations remain unresolved after reflection, appends a `[routine-alert]` observation so the user sees it next session.
5. **Session quality** — scores the session via the `session-quality` rubric, writes a `[session-quality]` observation.
6. **Keep rate** — `keep-rate` skill evaluates pattern retention, writes a `[keep-rate]` observation.
7. **Trust Score update** — `scripts/session/trust_score.py` runs after session quality and keep rate are written so all signals (`[session-charge]`, `[memory-gap]`, `[session-quality]`, `[keep-rate]`) are visible. Rewrites the `## Harness Trust Score:` line in `hot-memory.md`, appends to `.claude/memory/trust-score.jsonl`.
8. **Skill augmentation** — `skill-augment-agent` reviews today's observations and judge drains, encodes up to 5 evidence-backed improvements (circuit breaker cap) into relevant `SKILL.md` files (append-only, ≤150 chars each). Logs each change as a `[skill-update]` observation. Also processes any `[seed-target:]` observations written by the action-capture hook during the session, and today's `type: feedback` memories (user corrections), which auto-qualify and are drafted before judge drains — human ground-truth outranks the LLM grader.
9. **Adversarial check** — a separate verification agent (no loyalty to step 8's output) reviews each `[skill-update]` written today: does it address the stated gap? does it contradict existing guidance? Flags failures as `[skill-update-flagged]`, confirms passes as `[skill-update-verified]`. Skipped if step 8 wrote nothing.

Idempotent per calendar day (uses today's `[judge]` observation as the sentinel). Each step is error-isolated: a bad Judge pass does not block housekeeping.

### Trust Score — observability only

The `## Harness Trust Score:` line at the top of `hot-memory.md` (e.g. `42.3% (▲ +0.8 today, 7d: ▼ -1.1)`) is a single-user health signal. **It never gates harness behavior** — spec phase gates still require explicit human approval regardless of score. Adapted from @nityeshaga's "trust battery" design (April 2026) but scoped down: one battery per project (single developer), informational only, no autonomy tiers.

Starts at 20% on fresh install. Daily cap ±4.5%. History lives in `.claude/memory/trust-score.jsonl` (one record per nightly run). The `auto-score` command incorporates a **session success ratio**: uncorrected sessions (no `session-quality ≤ 2/5` or `memory-gap` on that day) act as a multiplier on existing signals and contribute a ±1.0 baseline — so uneventful sessions now passively charge the battery rather than contributing zero.

### Opt out

```
SDD_SKIP_ROUTINE=1 ~/.claude/sdd-harness/install.sh /path/to/project
```

Or after install: `schtasks.exe /Delete /TN "SDD Daily Orchestrator"` (global) or `rm .claude/scripts/orchestration/daily-runner.sh` (per-repo).

### `scripts/session/detect_reexplanation.py` — session signal detector

Runs from `stop-hook.sh` after each session. Uses Claude Haiku to analyse user turns for two signal types:

- **Drain signals** — user had to re-explain context the AI should have saved (explicit: "I already told you"; implicit: "you're still doing that thing I asked you to stop"). Each drain → `[memory-gap]` observation. The Judge treats these as flagship drains.
- **Charge signals** — user gave unambiguous approval ("that's perfect", "exactly what I needed", "great work"). Each charge → `[session-charge]` observation. The rubric auto-scores these as +1 each.

Both types are written at most once per calendar day. The auto-scoring table in `kiro/settings/rules/session-quality-rubric.md` applies these mechanically — no Judge pass needed.

When drain signals are found, `scripts/session/micro_reflect.py` can be called to extract a durable, generalizable fact from each drain and append it to `hot-memory.md` under an `## Auto-learned` section, tagged `[auto-learn, YYYY-MM-DD]`. These are probationary entries — the housekeeping agent promotes them to `meta/patterns.md` after 7 days if reinforced, or removes them if not.

### Full reference: [`docs/trust-battery/`](trust-battery/)

Complete documentation of the trust-battery loop — origin, architecture diagram, rubric details, troubleshooting, and explicit non-goals. Start here if you are modifying any of the battery components.

### `/kiro:macro-eval-sweep` — Population-scale agent evaluation
Clusters recurring failure patterns across Raindrop Workshop traces, ranks by impact, backward-traces the suspect step per pattern, writes a dated report, and posts annotations back to Workshop. The **macro** layer above per-run grading.

```
/kiro:macro-eval-sweep              # last 4 days, all runs
/kiro:macro-eval-sweep 7            # last 7 days
/kiro:macro-eval-sweep 4 zora       # last 4 days, runs matching "zora"
```

Runs automatically twice weekly via `scripts/routines/macro-eval-runner.sh` (MIN_GAP_DAYS=3) inside the daily orchestrator. In headless or scheduler contexts, preflight confirms the Raindrop MCP server is reachable — fails loudly with a `*-SKIPPED.md` report rather than pretending success.

Output: `.claude/reports/macro-evals/YYYY-MM-DD.md` with a pattern leaderboard, top-3 diagnoses (focus event + suspect step), and a delta vs. previous sweep. Span-level and run-level Workshop annotations are posted for confirmed recurring failure patterns (cap: ~5 runs per pattern).

Skill: `evaluation/macro` (part of the `evaluation` skill family). Opt-out: `SDD_SKIP_MACRO_EVAL=1`.

---

### `/kiro:tool-failure-review` — Learn from failing tool calls
Reviews the per-repo tool-failure ledger and promotes recurring failures into memory: diagnoses *why* a command shape keeps failing and writes the cause + remedy as a durable memory entry (and `ERRORS.md`), so it stops happening. The **review** stage of the tool-failure-memory loop.

```
/kiro:tool-failure-review            # review signatures that failed >= 3x
/kiro:tool-failure-review 5          # only signatures that failed >= 5x
```

The loop runs continuously without you: two hooks capture every failing Bash/MCP call (`tool-failure-capture.sh`, PostToolUseFailure) and warn before a known-failing shape is repeated (`tool-failure-recall.sh`, PreToolUse). The review stage runs automatically ~twice weekly via `scripts/routines/tool-failure-review-runner.sh` (MIN_GAP_DAYS=3) inside the daily orchestrator — it no-ops unless the ledger has a signature that failed ≥3× and is still open, so calling it daily is cheap.

Ledger: `.claude/memory/tool-failures.jsonl` (local, per-repo). Report: `.claude/reports/tool-failures/YYYY-MM-DD.md`. Skill: `tool-failure-memory`. Opt-out: `SDD_SKIP_TOOL_FAILURE_REVIEW=1`. Source: ReMe (agentscope-ai/ReMe).

---

### Daily Security Scan (`security-report-runner.sh`)

Runs automatically every day via the daily orchestrator. Performs a static security scan of recent git changes using the `ai-security-workflow` skill: checks for OWASP patterns (injection sinks, XSS vectors, broken auth), exposed secrets, and unsafe patterns introduced in the last commit window. Writes a dated report to `.claude/reports/security/<date>-security-report.md`.

Visible in the dashboard **Scheduled Tasks** section (row 6) with last-run status, artifact diff, and any findings headline.

Self-paces to daily (`MIN_GAP_DAYS=1`). Applies to every repo. Opt-out: `SDD_SKIP_SECURITY_REPORT=1`.

---

## Jira Integration

### `/kiro:jira-solve` — Work on a Jira ticket with auto-commenting
Start a session tied to a Jira ticket. When you push code, a comment is automatically posted to the ticket describing what was done, why, and which files changed.

```
/kiro:jira-solve ZORAAI-1234
```

The ticket ID is captured at prompt time and stored in `~/.claude/state/active_jira_ticket`. After `git push`, a comment is posted automatically containing:
- Branch name and commit count
- Approach summary (extracted from `docs/` markdown if present)
- Files changed (from `git diff --name-only`)

The state is single-fire — subsequent pushes in the same session don't double-post.

**Prerequisites**: `~/.env.jira` with `JIRA_URL` and `JIRA_PAT` (or `JIRA_USERNAME` + `JIRA_API_TOKEN`).
See `.claude/docs/SDD-SETUP-GUIDE.md` → "Jira Integration" for full setup.

---

## AutoResearch (ML Experiments)

### `/kiro:autoresearch-init` — Interactive ML project setup
Asks leading questions about your research goal, data, model, metric, and constraints, then generates `program.md`, `train.py`, and `prepare.py`.

```
/kiro:autoresearch-init
/kiro:autoresearch-init "optimize a small transformer on our Python codebase"
```

### `/kiro:autoresearch` — Run autonomous experiment loop
Reads `program.md`, iterates on `train.py` (~5 min per experiment), keeps improvements, reverts failures.

```
/kiro:autoresearch          # run until stopped
/kiro:autoresearch 10       # run 10 iterations
```

**Prerequisites**: `uv` installed, `program.md` + `train.py` + `prepare.py` in project root. Run `uv run prepare.py` once before starting the loop.

See `docs/autoresearch/README.md` for full details.

---

## Skill Extraction (from Repositories)

### `/kiro:skill-extract-scan` — Analyze a repo for extractable skills
Scans a repository, scores candidate modules against the extraction rubric, and produces a reviewable plan.

```
/kiro:skill-extract-scan https://github.com/org/repo
/kiro:skill-extract-scan /path/to/local/repo
```

Output: `.claude/skill-extraction/<repo-name>/plan.md` with ranked candidates, scores, and rationale.

### `/kiro:skill-extract` — Generate SKILL.md files
Generates skills from an approved extraction plan, or runs the full pipeline with `-y`.

```
/kiro:skill-extract .claude/skill-extraction/repo/plan.md
/kiro:skill-extract https://github.com/org/repo -y
```

Output: `~/.claude/skills/<name>/SKILL.md` for each extracted skill.

Every new skill passes quality gates and a companion check before it is logged to the sources index:
- **Phase 5b — SkillOS Quality Gate**: task relevance, operational validity, content quality, compression (≤5,000 words). Failures block completion.
- **Phase 5c — Identity Alignment Check**: invokes `agent-identity` Mode B — validates description specificity, trigger sharpness, behavioral concreteness, and explicit exclusions. Vague skill identities cause the wrong skill to fire; this gate prevents them from entering the harness.
- **Phase 5d — Verification Companion Check**: asks whether the skill's domain involves manual checks a human would run after Claude's work (visual inspection, sampling output, checking logs). If yes, invokes `verification-skill-authoring` to create a companion `<domain>-verify` skill before proceeding.

See `docs/skill-extraction/README.md` for full details on scoring, workflow, and security.

### `/kiro:gitnexus-setup` — Install and configure GitNexus code intelligence

```
/kiro:gitnexus-setup                    # install, index, configure MCP
/kiro:gitnexus-setup --skip-embeddings  # faster indexing (no vectors)
/kiro:gitnexus-setup --force            # force re-index
```

### `/kiro:gitnexus-explore` — Launch visual code explorer

```
/kiro:gitnexus-explore                  # opens Web UI at localhost:4567
/kiro:gitnexus-explore --port 8080      # custom port
```

Browse symbols, call chains, process flows, and community clusters in a WebGL graph.

### `/kiro:gitnexus-impact` — Query blast radius for current changes

```
/kiro:gitnexus-impact                   # analyze uncommitted changes
/kiro:gitnexus-impact --from HEAD~3     # analyze last 3 commits
```

Maps changed code to affected execution flows with HIGH/MEDIUM/LOW risk classification. Falls back to grep-based tracing if GitNexus is not installed.

See `docs/gitnexus/README.md` for full details.

---

## Local Dashboard

A browser-based dashboard (`scripts/utils/dashboard.py`, stdlib only) that surfaces harness telemetry for all registered repos.

```bash
python3 ~/.claude/sdd-harness/scripts/utils/dashboard.py
```

Starts a local HTTP server at `http://localhost:4569` and opens the browser automatically. Use `--repo <name|path>` to pre-select a repo, `--no-open` to suppress browser launch, `--port <PORT>` to set a custom port, or `--static` to write a static `.dashboard/index.html` instead.

**Sections:**

| # | Section | What it shows |
|---|---|---|
| 1 | ⚡ Trust Battery | Arc gauge + 30-day bar chart of daily trust deltas |
| 2 | 🕸 GitNexus | Stats strip + embedded visual explorer (localhost:4567) |
| 3 | 🔬 Workshop | Raindrop Workshop trace browser; filter by repo, run eval loop, view agent traces |
| 4 | 🗜 Headroom | Compression savings totals for RTK + headroom proxy; per-session block history with checkpoint-level token savings |
| 5 | 🪝 Hooks History | Hook name, event type, last activity, active/inactive badge |
| 6 | 📅 Scheduled Tasks | OS scheduler health card + per-routine cards (schedule, last run + exit code, artifact, diff vs. previous run, reasoning excerpt). Includes the Daily Security Scan routine (`security-report-runner.sh`) which scans recent git changes for OWASP patterns, secrets, and injection sinks. |
| 7 | 🧠 Memory Changes | Per-file cards for hot-memory, observations, and meta/patterns with day-over-day diffs ("since yesterday") computed from dated snapshots; full content expanded when a file is unchanged |
| 8 | 🎯 Skill Changes | Skill usage stats (hot/cold from `skill-usage-tracker.sh` log — total/30d invocations, skills used, cold-skill count, top-skills bars, deprecate candidates) above the rendered skill-curation-report with audit age |
| 9 | 📊 Session Quality | Score/keep-rate/memory-gap summary + 30-day chart; ✨ **Prompt Quality** sub-tab — per-dimension PQ trends (7-day avg, weakest dimension, rolling score chart) |
| 10 | 💰 Model Cost | All-time and 30-day spend; 90-day daily cost bar chart; sessions table with model/tokens/cost; cross-provider "What if?" cost switcher |
| 11 | 🧵 Context Health | Sessions per day trend + `/compact` recommendations |
| 12 | 🔧 Maintenance Status | Per-repo orchestrator log tail and last-run status; **deferred-work banner** — count of `DEBT:` markers (deliberate shortcuts, per `karpathy-guidelines`) found by `git grep` across tracked code, recomputed each dashboard launch |
| 13 | 🤖 Automation Audit | Timeline of automated events — runs from every routine (daily-maintenance, macro-eval, skill-curator, harness-health, tool-failure, security, drift), each with its own icon/label; not-due checks (duration 0s) are hidden and daily-maintenance entries expand to show that day's brief; plus trust-judge scores, session signals, and scheduled task outcomes |

### 💰 Model Cost section

Reads session JSONL files from `~/.claude/projects/*/`. Pricing is fetched from `models.dev/api.json` and cached at `.dashboard/models-pricing-history.json`, refreshed bi-weekly. Historical snapshots accumulate so past sessions are costed at the rate in effect when they ran. Sessions where pricing has changed since the run are flagged with a ⚠ icon.

The **"What if?" switcher** lets you recalculate total projected cost against any supported provider (Anthropic, OpenAI, Google, Mistral, DeepSeek, xAI, Cohere, Amazon Bedrock, Azure, Perplexity, Groq) and model — select provider first, then model, and the projected vs. actual totals update instantly.

See `docs/workflow/superpowers/specs/2026-05-14-harness-dashboard-design.md` for the full section spec (gitignored — local only).

---

## Raindrop Workshop (Automatic Agent Tracing)

All registered repos emit traces automatically whenever agents run. No commands needed — just open the dashboard Workshop tab.

### Dashboard Workshop tab

```bash
python3 ~/.claude/sdd-harness/scripts/utils/dashboard.py
# → Workshop tab in the sidebar
```

| Action | How |
|---|---|
| Start Workshop | Click **Start raindrop workshop** button (or run `raindrop workshop` in terminal) |
| View traces | Workshop UI loads at `/workshop/` in the dashboard |
| Filter by repo | Use the `event=` label in Workshop sidebar (e.g. `aiq-zora-ai-engine`) |
| Run eval loop | Click **Run Eval Loop** — costs ~5k–30k tokens, always manual |

### What fires automatically

Traces emit whenever an instrumented agent processes a request:

| Repo | Trigger |
|---|---|
| `aiq-zora-ai-engine` | Any call to `AgentPipelineGraph.process()` |
| `aiq-zora-agent-skills` | Any call to `DailyNewsHandler.handle()` |
| `aiq-purina-salesorderintelligence-poc` | Any `/chat` request via `query_portal.py` |

### Self-Healing Eval Loop

Triggered manually from the dashboard. Claude reads Workshop traces, writes `pytest` assertions from them, runs the tests, and auto-fixes failures (max 3 cycles). Budget ~5k–30k tokens.

Skill: `~/.claude/skills/raindrop-eval-loop/SKILL.md`

### Instrumenting a new repo

```bash
/raindrop-instrument-agent
```

Or register the repo with the harness and `install.sh` handles it automatically.

See `docs/raindrop/README.md` for full details and troubleshooting.

---

## Frontend Design Quality (Impeccable)

### `/impeccable-audit` — Visual design audit for UI components
Audits frontend code across 7 domains: typography, color & contrast, spatial design, motion, interaction, responsive, and UX writing. Applies Impeccable's 27 deterministic anti-pattern rules + 12 LLM critique rules. Returns a PASS / NEEDS WORK / BLOCK verdict.

```
/impeccable-audit                            # full audit of current component
/impeccable-audit UserCard                   # audit a named component
/impeccable-audit focus: motion              # deep-dive on motion/animation only
/impeccable-audit focus: accessibility       # accessibility + interaction states
```

Use before committing UI work, or when a component "looks AI-generated."

### Auto-scan hook (PostToolUse)
If `impeccable` is installed globally, every Write/Edit to a frontend file (`.tsx`, `.jsx`, `.css`, `.vue`, `.svelte`, `.html`) is automatically scanned and violations are surfaced inline. No extra commands needed.

```bash
# One-time setup
npm install -g impeccable
```

### Key anti-patterns flagged

| Pattern | Code signature |
|---|---|
| Gradient text | `background-clip: text` |
| Glassmorphism | `backdrop-filter: blur()` |
| Colored left border | `border-left: 4px solid var(--accent)` |
| Pure white background | `background: #ffffff` |
| Identical card grid | 3-col, same height, same padding |
| Stale easing | `ease-in`, `ease-out` |
| Missing focus state | No `:focus-visible` styles |

See `docs/design/impeccable/impeccable.md` for the full rule set.

---

## Proof Collaborative Review (Spec Phase Gates)

Proof is the built-in review layer used by `spec-requirements`, `spec-design`, and `spec-tasks`. After each phase generates an artifact, the harness publishes it to a live Proof document and presents a browser URL for inline review.

### How it works

1. Phase subagent generates the artifact (requirements / design / task list)
2. `proof-collaborative-review` skill starts a local Proof server (port 4000) and publishes the document
3. A review URL is presented — open it in any browser to annotate, suggest edits, or rewrite inline
4. Come back to Claude and say "done" when finished
5. Skill retrieves the final human-edited version and writes it back to `specs/<feature>/`

### First-time setup (automatic)

No manual steps. The skill auto-installs the Proof SDK into `~/.claude/tools/proof-sdk/` on first use (requires Node.js). Subsequent runs skip the install.

### Remote server

Set `PROOF_SERVER_URL=http://your-host:4000` to point at a shared instance instead of localhost.

### Skill location

```
~/.claude/sdd-harness/skills/proof-collaborative-review/SKILL.md
```

Bundled in the harness — replicated to every machine via `install.sh`. No per-machine manual copy needed.

---

## Typical Workflow

```
1. /kiro:steering                        ← once per project (or after big changes)
2. /kiro:idea-refine "rough idea"        ← (optional) refine vague ideas
3. /kiro:spec-quick "Add feature X"      ← fast: requirements → design → tasks
   (review and approve each phase)
4. /kiro:spec-impl feature-x             ← implement via TDD
5. /kiro:verify                          ← confirm build, tests, lint all pass
6. /kiro:validate-impl feature-x         ← confirm spec alignment
7. /kiro:ship feature-x                  ← (optional) launch readiness check
8. /kiro:reflect                         ← capture what you learned
```

For larger features, use the individual spec phases (`spec-requirements` → `spec-design` → `spec-grill` → `spec-tasks`) instead of `spec-quick` to review each phase separately.

### Quality Gate Sequence (pre-completion)

```
/kiro:verify                             ← Gate 1: does it build and pass?
/kiro:validate-impl feature-x            ← Gate 2: does it match the spec?
/kiro:validate-adversarial feature-x     ← Gate 3: can we poke holes? (optional)
/kiro:validate-perf feature-x            ← Gate 4: will it perform? (optional)
                                         ← Gate 5: production readiness (auto-triggered after spec-impl)
/kiro:ship feature-x                     ← Gate 6: rollout plan & decision thresholds (optional)
```

### Long Session Management

```
/kiro:checkpoint save task-1-done        ← save progress after each task
/kiro:save-session                       ← save full session state before leaving
/kiro:resume-session                     ← pick up where you left off
/kiro:context-budget                     ← check if context is getting bloated
```

### Prompt Improvement (When Agents Misbehave)

Use this when agents consistently produce poor output — wrong conclusions, bad format, missing context, or misunderstanding tasks.

```
/kiro:evolve                             ← analyze alignment scores, diagnose underperformers
                                           (review and approve instruction proposals)
/kiro:harness-test regression            ← verify changes don't regress other scenarios
/kiro:harness-test regression steering   ← test a specific agent after changes
```

This applies to all prompt layers — not just sub-agents:
- **Agent prompt is wrong** → evolve diagnoses it automatically
- **Command passes bad context** → review the command's prompt block
- **Rule is too vague** → sharpen it or add an instruction library bullet
- **Your feature descriptions are misunderstood** → capture effective patterns in the instruction library

See `docs/prompt-improvement/README.md` for the full guide.

---

## GBrain Patterns (Automatic Agent Protocols)

Four protocols extracted from [garrytan/gbrain](https://github.com/garrytan/gbrain) fire automatically via hooks — no commands needed.

### What fires automatically

| Trigger | Hook | Protocol injected |
|---|---|---|
| Every `Agent()` call | `gbrain-agent-spawn.sh` | Model tier selection + background routing + memory-first brief |
| Every `save_observation` | `gbrain-memory-write.sh` | Compiled-truth two-zone structure + source citation format |
| Every `WebFetch` / `WebSearch` | `gbrain-external-search.sh` | Reminder to search claude-mem before external calls |

### The four patterns

**Memory-First Lookup** (`~/.claude/skills/memory-first-lookup/`) — Always run `mcp__plugin_claude-mem_mcp-search__search` before reaching for external APIs. The lookup chain: keyword search → semantic search → get_observations → external only if memory is empty.

**Model Tiers** (`~/.claude/skills/model-tiers/`) — Match model to task type:
- `haiku-4-5` for classification, validation, dedup (utility)
- `sonnet-4-6` for generation, synthesis, agent work (default)
- `opus-4-8` only for deep multi-step reasoning (upgrade when sonnet consistently fails)
- `fable-5` for long, multi-sitting autonomous sessions (`/model fable`)
- Subagents always use `sonnet`, not opus — latency compounds in tool loops

**Background Work Routing** (`~/.claude/skills/background-work-routing/`) — Stay inline unless a pain signal fires: gateway restart, state drop, parallel > 3, runtime > 5 min, or user frustration. Offer the switch explicitly; never switch silently.

**Compiled Truth Pattern** (`~/.claude/skills/compiled-truth-pattern/`) — Every memory observation has two zones: `## State` (rewrite in place when evidence changes, each fact cited) and `## Evidence / Timeline` (append-only dated log, never edited).

Full reference: `docs/gbrain-patterns/gbrain-patterns.md`

_Last synced: 2026-07-06_
