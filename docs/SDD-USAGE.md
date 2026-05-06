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

### `/kiro:spec-tasks` — Generate implementation tasks
Breaks the design into parallelizable tasks with dependencies. After generation, opens a **Proof collaborative review session** for approval before implementation begins. Pass `--sequential` to suppress parallel `(P)` markers when you want strictly ordered tasks.

```
/kiro:spec-tasks revenue-trend-chart
/kiro:spec-tasks revenue-trend-chart --sequential   # disable parallel task markers
```

### `/kiro:spec-quick` — Fast path (requirements → design → tasks)
Runs all three spec phases in one command. Good for small features.

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
Evaluates session patterns with quality scoring (specificity, actionability, evidence). Deduplicates against existing knowledge and produces save/absorb/drop verdicts. Deeper than `/kiro:reflect` — use periodically.

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
Validates command→agent references, template existence, memory caps, L0 headers, and generates a component relationship index.

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

Runs the full maintenance cycle end-to-end: **Judge → Reflect → Housekeeping → Trust Score → Augment Skills**. Designed to run on a schedule via Claude Code [Routines](https://claude.com/blog/introducing-routines-in-claude-code), one Routine per installed project — `install.sh` and `update.sh` register this automatically.

```
/kiro:daily-maintenance
```

Pipeline:

1. **`session-judge`** — independent adversarial scorer. Reads the last 24h of `observations.md` + trace log, applies the rubric in `kiro/settings/rules/session-quality-rubric.md`, emits a JSON verdict (±1 charges, -2 drains, ±4.5%/day cap). **Proposes no fixes** — if the same agent scored and improved, it would optimize for score, not work.
2. **`/kiro:reflect`** — consumes the Judge's drains as priority signals, converts them into new memory entries or pattern promotions.
3. **`/kiro:housekeeping`** — prunes/archives observations, enforces memory caps.
4. **Trust Score update** — `scripts/trust_score.py` applies the Judge's `score_delta`, clamps it, rewrites the `## Harness Trust Score:` line at the top of `hot-memory.md`, appends to `.claude/memory/trust-score.jsonl`.
5. **Memory-gap alert** — if any `[memory-gap]` observations remain unresolved after reflection, appends a `[routine-alert]` observation so the user sees it next session.
6. **Skill augmentation** — `skill-augment-agent` reviews today's observations and judge drains, encodes up to 3 evidence-backed improvements into relevant `SKILL.md` files (append-only, ≤150 chars each). Logs each change as a `[skill-update]` observation.

Idempotent per calendar day (uses today's `[judge]` observation as the sentinel). Each step is error-isolated: a bad Judge pass does not block housekeeping.

### Trust Score — observability only

The `## Harness Trust Score:` line at the top of `hot-memory.md` (e.g. `42.3% (▲ +0.8 today, 7d: ▼ -1.1)`) is a single-user health signal. **It never gates harness behavior** — spec phase gates still require explicit human approval regardless of score. Adapted from @nityeshaga's "trust battery" design (April 2026) but scoped down: one battery per project (single developer), informational only, no autonomy tiers.

Starts at 20% on fresh install. Daily cap ±4.5%. History lives in `.claude/memory/trust-score.jsonl` (one record per nightly run).

### Opt out

```
SDD_SKIP_ROUTINE=1 ~/.claude/sdd-harness/install.sh /path/to/project
```

Or manually: `claude /schedule delete <routine-id>` once registered.

### `scripts/detect_reexplanation.py` — re-explanation detector

Runs from `stop-hook.sh` after each session. Scans the session's user turns for phrases like "I already told you", "as I said", "we discussed this" — each hit becomes a `[memory-gap]` observation. The Judge treats these as flagship drains (every re-explained preference is a memory the harness should have saved but didn't). Rationale: see the "Daily Maintenance" section above.

### Full reference: [`docs/trust-battery/`](trust-battery/)

Complete documentation of the trust-battery loop — origin, architecture diagram, rubric details, troubleshooting, and explicit non-goals. Start here if you are modifying any of the battery components.

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

For larger features, use the individual spec phases (`spec-requirements` → `spec-design` → `spec-tasks`) instead of `spec-quick` to review each phase separately.

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
