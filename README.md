# SDD Harness

**Spec-Driven Development harness for Claude Code** — a portable framework that enforces structured, phase-gated feature development with persistent cross-session memory, automated documentation sync, and Jira integration.

One harness, many projects. Install once, keep every repo in sync.

---

## Table of Contents

- [What It Does](#what-it-does)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [The SDD Workflow](#the-sdd-workflow)
- [Commands Reference](#commands-reference)
- [Agents](#agents)
- [Cog Memory System](#cog-memory-system)
- [Steering (Project Knowledge)](#steering-project-knowledge)
- [Jira Integration](#jira-integration)
- [Skill Extraction](#skill-extraction)
- [Prompt Mastery](#prompt-mastery)
- [AutoResearch (ML Experiments)](#autoresearch-ml-experiments)
- [GitNexus (Code Intelligence)](#gitnexus-code-intelligence)
- [Privacy Filter (PII Scanning)](#privacy-filter-pii-scanning)
- [Impeccable (Frontend Design Quality)](#impeccable-frontend-design-quality)
- [Context Hub (MCP Integration)](#context-hub-mcp-integration)
- [RTK (Token Compression)](#rtk-token-compression)
- [Automation & Hooks](#automation--hooks)
- [Multi-Project Management](#multi-project-management)
- [Local Dashboard](#local-dashboard)
- [Documentation Index](#documentation-index)
- [Design Principles](#design-principles)
- [Built With](#built-with)

---

## What It Does

| Capability | Built On | Description |
|---|---|---|
| **Spec-Driven Development** | [cc-sdd](https://www.npmjs.com/package/cc-sdd) | Requirements → Design → Tasks → TDD Implementation, with human approval gates between every phase |
| **Cross-Session Memory** | [CogMem](https://arxiv.org/abs/2512.14118) | Temperature-tiered memory (hot/warm/meta/cold) that persists context across Claude Code sessions |
| **Project Steering** | Custom | Auto-generated architecture, tech stack, and structure docs that ground every conversation |
| **Doc Sync** | Custom | Automatically updates `.md` files when code changes on every git commit |
| **Jira Integration** | [Jira REST API v2](https://developer.atlassian.com/cloud/jira/platform/rest/v2/) | Fetch tickets, route to the right workflow (bug/feature/task), auto-comment on push |
| **Skill Extraction** | [arXiv:2603.11808](https://arxiv.org/abs/2603.11808) | Analyze repos and extract reusable `SKILL.md` files for Claude Code |
| **AutoResearch** | [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | Autonomous ML experiment loop with hypothesis-driven iteration |
| **GitNexus** | [abhigyanpatwari/GitNexus](https://github.com/abhigyanpatwari/GitNexus) | Knowledge-graph code intelligence with visual explorer, blast radius analysis, and MCP tools |
| **Privacy Filter** | [openai/privacy-filter](https://github.com/openai/privacy-filter) | Local ML-based PII detection and redaction (8 categories: secrets, emails, phones, addresses, account numbers, and more). Fully on-premises via CLI or Python API |
| **Impeccable** | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 27 deterministic anti-pattern rules + 7-domain visual design quality system. Catches AI design fingerprints in frontend code (gradient text, glassmorphism, nested cards, contrast failures). PostToolUse hook + on-demand skill |
| **Context Hub** | [andrewyng/context-hub](https://github.com/andrewyng/context-hub) | MCP server providing curated, LLM-optimized docs for third-party libraries |
| **RTK** | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | Global PreToolUse proxy (Rust Token Killer) that compresses Bash command output before it enters the context window — 60–90%+ token reduction on git, tests, file ops, and more. Automatic, zero per-project setup |
| **Portable Installation** | Custom | Single `install.sh` bootstraps any project; `update.sh` keeps them all in sync |

---

## Quick Start

### Install into a new project

```bash
# Clone anywhere — $SDD_HARNESS is written to ~/.bashrc and ~/.zshrc automatically on first run.
# On subsequent shells you can run from anywhere:
$SDD_HARNESS/install.sh /path/to/project
# defaults to current directory if no path given
```

> **First run only:** `$SDD_HARNESS` isn't set yet, so bootstrap with a direct path:
> ```bash
> bash /path/to/your/sdd-harness-clone/install.sh /path/to/project
> ```
> After that, open a new shell and `$SDD_HARNESS` is available everywhere.

> **Windows:** `install.sh` is a bash script — it cannot be run directly from PowerShell or CMD (you'll get `Missing expression after unary operator '!'`, or `not recognized as the name of a cmdlet`). Easiest path: open a **Git Bash** terminal, `cd` into the repo, and run the scripts directly. From **PowerShell**, invoke Git Bash with the call operator from inside the repo directory (`bash` is usually not on PATH):
> ```powershell
> # cd to the sdd-harness repo first, then:
> & "C:\Program Files\Git\bin\bash.exe" install.sh --all --with-gitnexus
> # with an explicit project path:
> & "C:\Program Files\Git\bin\bash.exe" install.sh /c/dev/my-project
> ```

This will:
- Create the `.claude/` directory structure with commands, agents, hooks, skills, docs, templates, and `.claude/rules/` (context-engineering rules synced from the top-level `rules/` source dir)
- Initialize memory files from templates
- Generate `CLAUDE.md` (the project constitution)
- Create `.claude/settings.json` from the template — but only after `scripts/setup/check-settings-json.sh` confirms the template is strict JSON, since Claude Code silently drops every permission rule and hook in a settings file it cannot parse
- Create `.claude/settings.notes.md` for notes that cannot live inside `settings.json` (JSON allows no comments and no trailing content)
- Run `scripts/setup/repair-settings-json.py` to self-heal any existing `settings.json` broken by a trailing `//` comment block, moving it into the notes sidecar (`update.sh` does this too)
- Run `scripts/setup/reconcile-settings-templates.py --sync` **before** generating the harness's own `.claude/settings.json`, so the harness template is derived from the project template plus an explicit harness-only allowlist rather than drifting from it (`update.sh` does this too). The two had silently diverged, and in the harmful direction: hooks were firing in every installed repo while not firing in the repo where they are written and tested. A failure here warns and continues rather than aborting the install
- Register the project in `projects.txt`
- Install the git post-commit hook
- Append the harness-local entries to the project's `.gitignore` (`.claude/`, `specs/`, `CLAUDE.md`, `AGENTS.md`, `ERRORS.md`) — all regenerable output, not source. The list lives in `scripts/lib/project-gitignore.sh` and `update.sh` re-applies it on every sync, so projects installed before an entry existed backfill it automatically

### Bootstrap project knowledge

Once installed, start a Claude Code session in the project and run:

```
/kiro:steering
```

This scans your codebase and generates steering docs (product vision, tech stack, codebase structure) that ground every future conversation.

### Start your first spec

```
/kiro:spec-quick "Add user dashboard"
```

This runs the full spec pipeline — requirements, design, and task breakdown — in one command.

---

## Repository Structure

```
sdd-harness/
├── install.sh                    # Bootstrap a new project
├── update.sh                     # Sync harness to all registered projects
├── VERSION                       # Last harness update date (auto-managed)
├── projects.txt                  # Registry of installed projects (gitignored)
│
├── commands/kiro/                # 39 slash commands (user-facing)
│   ├── idea-refine.md            #   Refine vague ideas into spec-ready briefs
│   ├── spec-init.md              #   Initialize a spec workspace
│   ├── spec-requirements.md      #   Generate EARS-format requirements
│   ├── spec-design.md            #   Generate technical design
│   ├── spec-tasks.md             #   Break design into parallelizable tasks
│   ├── spec-quick.md             #   Fast path: requirements → design → grill → tasks
│   ├── spec-grill.md             #   Domain grilling session (interactive terminology + decision alignment)
│   ├── spec-impl.md              #   TDD implementation of tasks
│   ├── spec-status.md            #   Check spec phase and progress
│   ├── verify.md                 #   6-stage verification pipeline (build/types/lint/test/audit/git)
│   ├── fix-build.md              #   Surgical build error resolver (3-attempt cap)
│   ├── checkpoint.md             #   Named workflow checkpoints (save/compare/list/restore)
│   ├── debug.md                  #   Systematic 6-step bug triage (reproduce→fix→guard)
│   ├── simplify.md               #   Behavior-preserving code simplification
│   ├── ship.md                   #   Launch readiness: verification + rollout planning
│   ├── validate-gap.md           #   Requirements vs. code gap analysis
│   ├── validate-design.md        #   Design quality review (with remediation on NO-GO)
│   ├── validate-impl.md          #   Implementation vs. spec validation (with remediation)
│   ├── validate-adversarial.md   #   Three-pass adversarial review (+1/-2 scoring)
│   ├── validate-perf.md          #   Performance anti-pattern detection (N+1, unbounded, etc.)
│   ├── converge.md               #   Spec ↔ code reconciliation (bidirectional drift)
│   ├── steering.md               #   Bootstrap/sync project knowledge
│   ├── steering-custom.md        #   Add domain-specific docs (auth, DB, etc.)
│   ├── reflect.md                #   Mine session learnings, update memory
│   ├── learn-eval.md             #   Quality-gated pattern evaluation (save/absorb/route/drop)
│   ├── housekeeping.md           #   Prune memory, enforce caps
│   ├── evolve.md                 #   Audit harness rules, propose improvements
│   ├── save-session.md           #   Save resumable session snapshot
│   ├── resume-session.md         #   Resume a previously saved session
│   ├── context-budget.md         #   Analyze token consumption across context files
│   ├── harness-fix.md            #   Encode behavioral prevention rules
│   ├── harness-validate.md       #   Structural integrity check
│   ├── harness-test.md           #   Haiku smoke-test for prompt quality
│   ├── sync-docs.md              #   Sync .md files with code changes
│   ├── jira-solve.md             #   Fetch and route Jira tickets
│   ├── skill-extract-scan.md     #   Analyze repo for extractable skills
│   ├── skill-extract.md          #   Generate SKILL.md files
│   ├── guardrails.md             #   Audit/scaffold linter complexity rules
│   ├── ci-scaffold.md            #   Generate CI config mirroring verify pipeline
│   ├── autoresearch-init.md      #   Interactive ML research setup
│   ├── autoresearch.md           #   Run autonomous experiment loop
│   ├── gitnexus-setup.md         #   Install GitNexus + configure MCP
│   ├── gitnexus-explore.md       #   Launch GitNexus Web UI
│   └── gitnexus-impact.md        #   Query blast radius via knowledge graph
│
├── agents/kiro/                  # 34 subagents (autonomous workers)
│   ├── spec-requirements.md      #   Requirements generation agent
│   ├── spec-design.md            #   Design generation agent
│   ├── spec-tasks.md             #   Task breakdown agent
│   ├── spec-impl.md              #   TDD implementation agent (with spec backlinks)
│   ├── spec-refactor.md          #   Post-task code review agent (with 3-tier security)
│   ├── idea-refine-agent.md      #   Pre-spec ideation agent (divergent/convergent thinking)
│   ├── debug-agent.md            #   Systematic debugging agent (6-step triage)
│   ├── simplify-agent.md         #   Behavior-preserving simplification (Chesterton's Fence)
│   ├── ship-agent.md             #   Rollout planning agent (staged deployment, thresholds)
│   ├── prompt-diagnosis-agent.md #   Agent prompt quality diagnosis
│   ├── steering.md               #   Steering file generation agent
│   ├── steering-custom.md        #   Custom steering agent
│   ├── verify-agent.md           #   6-stage verification pipeline agent (Haiku)
│   ├── fix-build-agent.md        #   Surgical build error resolver (Sonnet)
│   ├── validate-gap.md           #   Gap analysis agent
│   ├── validate-design.md        #   Design review agent (with remediation plans)
│   ├── validate-impl.md          #   Implementation review agent (with backlink checks)
│   ├── validate-adversarial.md   #   Three-pass adversarial review agent
│   ├── validate-perf-agent.md    #   Performance anti-pattern detector (with MEASURE→GUARD cycle)
│   ├── validate-production-agent.md # Production readiness scanner
│   ├── save-session-agent.md     #   Session state capture agent (Haiku)
│   ├── learn-eval-agent.md       #   Pattern quality evaluation agent (Sonnet)
│   ├── reflect-agent.md          #   Session learning extraction agent
│   ├── housekeeping-agent.md     #   Memory pruning agent
│   ├── evolve-agent.md           #   Harness improvement agent (with trace analysis)
│   ├── doc-sync.md               #   Automatic doc update agent (with reverse validation)
│   ├── harness-updater.md        #   Harness self-update agent
│   ├── harness-fix-agent.md      #   Behavioral rule encoding agent
│   ├── harness-validate-agent.md #   Structural integrity checker
│   ├── jira-solve-agent.md       #   Jira ticket analysis agent
│   ├── skill-extract-agent.md    #   Skill extraction agent
│   ├── guardrails-agent.md       #   Linter complexity rule auditing/scaffolding (Haiku)
│   ├── ci-scaffold-agent.md      #   CI config generation (Haiku)
│   ├── autoresearch-agent.md     #   ML experiment loop agent
│   ├── autoresearch-init-agent.md#   ML research setup agent
│   ├── gitnexus-setup-agent.md   #   GitNexus installation and configuration agent
│   └── skill-augment-agent.md    #   Post-maintenance skill improvement agent
│
├── kiro/settings/                # Spec engine configuration
│   ├── rules/                    #   26 rule files (EARS syntax, design principles,
│   │   │                         #   task generation, gap analysis, memory conventions,
│   │   │                         #   agent tracing, quality gates, loop safety, hook
│   │   │                         #   profiles, model tiering, anti-rationalization,
│   │   │                         #   red flags, context engineering, agent swarm
│   │   │                         #   topologies, etc.)
│   └── templates/                #   16 templates across 4 categories:
│       ├── specs/                #     Spec phase templates (init, requirements, design, tasks)
│       ├── steering/             #     Project knowledge templates (product, tech, structure)
│       ├── steering-custom/      #     Domain templates (auth, DB, API, testing, deployment, security)
│       └── memory/               #     Memory file templates (hot, observations, action-items, entities, patterns)
│
├── rules/                        # Context-engineering rules (synced to .claude/rules/ by install/update)
│   └── lean-ctx.md               #   lean-ctx tool mapping, read modes, workflow, risk gate
│
├── scripts/                      # Utility scripts (Python, stdlib only)
│   ├── integrations/jira/        #   Jira REST API integration
│   │   ├── jira_client.py        #     Jira REST API client (PAT + Basic Auth)
│   │   ├── jira_capture_ticket.py#     Capture active ticket from session context
│   │   └── jira_push_comment.py  #     Post implementation summary to Jira
│   ├── orchestration/            #   Daily maintenance scheduling
│   │   ├── daily-orchestrator.sh #     Global orchestrator (all repos)
│   │   ├── daily-runner.sh       #     Per-repo daily maintenance loop (idempotent, race-safe)
│   │   └── setup-*-orchestrator.sh #   OS scheduler registration (global/linux/mac) — each preflights that the orchestrator can actually run under its scheduler, not just that it registered
│   ├── lib/                      #   Sourced helpers (not run directly)
│   │   ├── resolve-harness-dir.sh #    Self-locate $HARNESS_DIR from a script's own position on disk
│   │   └── harness-pointer.sh    #     Owns ~/.sdd-harness-root — THE single stored pointer to the harness, for cross-repo hooks that cannot self-locate
│   ├── routines/                 #   Scheduled routine prompts + runners
│   │   ├── daily-maintenance-prompt.md
│   │   ├── macro-eval-runner.sh
│   │   ├── skill-curator-runner.sh
│   │   ├── harness-health-runner.sh
│   │   ├── tool-failure-review-runner.sh
│   │   └── security-report-runner.sh
│   ├── session/                  #   Session signal processing
│   │   ├── detect_reexplanation.py #   Haiku-based drain/charge classifier (via `claude --print`, subscription auth)
│   │   ├── record_metric.py        #   Writes one measurement per day to .claude/memory/metrics.jsonl
│   │   ├── micro_reflect.py        #   Extracts durable facts → [auto-learn] in hot-memory.md
│   │   └── trust_score.py          #   Applies Judge score delta to hot-memory.md (numbers read from metrics.jsonl); `apply` accepts repeated --delta (one per judge run), applies the median, and records the day inconclusive with delta 0.0 when the samples spread past 2.0
│   ├── setup/                    #   One-time project setup helpers
│   │   ├── generate-project-stack.sh # Auto-detect tech stack
│   │   ├── check-settings-json.sh    # Strict-JSON validation of settings files and templates
│   │   ├── repair-settings-json.py   # Moves a trailing // comment block out of settings.json into settings.notes.md
│   │   ├── fix-inert-write-rules.py  # Retires Write(path) permission rules Claude Code silently ignores (only Edit(path) is consulted, and it already covers Write/Edit/MultiEdit). Allow rules with an Edit twin are dropped, without one renamed; deny rules are always renamed, never dropped. Dry-run by default, --apply to write
│   │   ├── reconcile-settings-templates.py # Keeps the two settings templates from drifting: hooks(harness) == hooks(project) + HARNESS_ONLY. --check blocks in /kiro:harness-validate; --sync is run by install.sh and update.sh before either copies a template
│   │   ├── headroom-setup.sh         # Install headroom memory proxy
│   │   └── raindrop-setup.sh         # Auto-installs raindrop-ai in virtualenvs
│   ├── skill-listing-budget.py   #   Measures the aggregate skill-listing cost (every skill's name + description, paid on every session) against a 1%-of-context-window ceiling
│   └── utils/                    #   Standalone utilities
│       ├── dashboard.py          #     Local harness dashboard (14 sections, Workshop + Headroom + Herder tabs); token totals deduplicated on requestId before summing
│       ├── herder.py             #     Spawns and supervises real interactive Claude Code sessions behind the dashboard's Herder tab (Herdr backend, JSON-only, no text pattern-matching); permission modes and model ids are discovered, never hardcoded, and each spawn is attributed to its own transcript
│       ├── token-forensics.py    #     Where the tokens actually went, from ~/.claude/projects/**/*.jsonl — dedup, per-tool amplification, peak rolling 5h window, session shape, automation split
│       ├── dashboard-usage-dedup.test.sh # Tests dashboard.py's usage dedup + a format-drift canary that fails if real transcripts stop showing duplicates
│       ├── ollama_model_test.py  #     Zero-dependency Ollama model test runner
│       ├── sync-memories-to-headroom.py # Bidirectional harness memory ↔ headroom sync
│       ├── check-no-hardcoded-paths.sh  # Verify no machine-specific paths in harness sources (*.sh, *.py, *.json, *.template + the generated .claude/settings.json); run by the harness repo's .git/hooks/pre-commit
│       ├── check-no-regex.py    #     Extends the repo-wide regex ban to Python embedded in shell heredocs, where ruff's TID251 cannot reach. Runs in .git/hooks/pre-commit against a shrinking debt ledger
│       ├── no-regex-debt.txt    #     The ledger check-no-regex.py reads. Listed files are known debt and do not fail; a file that is fixed but still listed DOES fail, so the ledger can only shrink
│       └── check-fleet-registration.sh  # Find harness-installed repos missing from projects.txt (they get no routines and appear on no dashboard)
│
├── hooks/                        # Claude Code and Git lifecycle hooks
│   ├── claude/                   # Claude Code session hooks (synced to .claude/hooks/ on install/update; *.test.sh suites stay here, never shipped)
│   │   ├── session-start-hook.sh #     On session start: maintenance check, CLAUDE.md review, headroom sync (background)
│   │   ├── stop-hook.sh          #     On session exit: check updates, memory health, re-explanation detection, agent failure patterns
│   │   ├── prompt-hook.sh        #     On prompt submit: inject hot-memory context
│   │   ├── action-capture.sh     #     PostToolUse(Bash): prompts memory capture after git-commit, test-failure, deploy, or struggle
│   │   ├── test-integrity-guard.sh #   PostToolUse(Write/Edit/MultiEdit): soft gate flagging "gradient descent to green" — weakened test assertions, added skips, lowered coverage thresholds. Detection is literal-token membership plus pathlib, not regex (2026-09-03)
│   │   ├── pr-evidence-hook.sh   #     PreToolUse(Bash): soft gate on `gh pr create` — nudges when the PR body carries no `## Evidence` section. Never blocks; the command is tokenized with shlex and matched token-by-token
│   │   ├── setup-buffer-hook.sh  #     PostToolUse(Bash): buffers setup-pattern commands to .claude/memory/.setup-session-buffer.log (flushed by stop-hook)
│   │   ├── skill-permissions-gate.sh # PostToolUse(Write/Edit): soft gate on */skills/*/SKILL.md — prompts agent-permissions-design review
│   │   ├── js-quality-gate-hook.sh #   PostToolUse(Write/Edit/MultiEdit): runs oxlint (or eslint) on .ts/.tsx/.js/.jsx writes — the JS half of the ruff gate; no-ops when neither linter is installed
│   │   ├── todo-focus-hook.sh    #     PostToolUse(TodoWrite): names competing in_progress items when more than one is active (soft, exit 2)
│   │   ├── headless-envelope-hook.sh # SessionStart: injects a stricter operating envelope, but only when SDD_HEADLESS=1 (unattended `claude --print` routine runs)
│   │   ├── subagent-context-hook.sh #  SubagentStart: injects harness conventions into the child via JSON hookSpecificOutput.additionalContext
│   │   ├── doc-parse-nudge.sh    #     UserPromptSubmit: nudges document-parsing skill on PDF/RAG/OCR prompts
│   │   ├── pre-tool-use-gitnexus.sh #  On file read/edit: enrich with GitNexus symbol graph context (callers, deps, processes)
│   │   └── scan-pii.sh           #     PII scanner: scan staged files or a path with OPF (exits 1 on secrets/account numbers)
│   ├── global/                   # User-global hooks (wired via ~/.claude/settings.json; not project-synced)
│   │   ├── caveman-activate.js   #     SessionStart: activates caveman terse-mode, emits ruleset as session context
│   │   ├── caveman-config.js     #     Shared config module for caveman hooks (mode, flag file path)
│   │   ├── caveman-mode-tracker.js #   UserPromptSubmit: injects active caveman level into every prompt
│   │   ├── caveman-stats.js      #     Tracks caveman usage metrics across sessions
│   │   ├── caveman-statusline.sh #     Statusline command: emits [CAVEMAN] / [CAVEMAN:ULTRA] badge + live context-usage meter (color-coded %ctx)
│   │   └── lean-ctx-rewrite.sh  #     PreToolUse(Bash): rewrites common shell commands to lean-ctx equivalents
│   └── git/                      # Git lifecycle hooks (copied to .git/hooks/ on install/update)
│       ├── pre-commit            #     Harness repo only: runs check-no-hardcoded-paths.sh (machine-specific paths) and check-no-regex.py (regex in embedded Python). Both run and both verdicts print — it does not short-circuit on the first failure — and either one blocks the commit. Never propagated to downstream projects
│       └── post-commit           #     On commit: detects doc-sync/harness-update work, then runs it in ONE detached job (log: .git/post-commit-docsync.log) that auto-commits/pushes only the .md files touched; serialized on .git/post-commit-docsync.lock so concurrent commits skip instead of racing the git index
│
├── templates/                    # Project-level templates
│   ├── CLAUDE.md.template        #   Project constitution (context paths, rules, quality gates)
│   ├── settings.json.template    #   Claude Code permissions and hooks config (per-project installs) — strict JSON, no comments
│   ├── settings.notes.md.template #  Sidecar notes for settings.json (copied to .claude/settings.notes.md on install/update)
│   └── settings.harness.json.template # Same config for the harness repo itself (portable hook paths)
│
└── docs/                         # Reference documentation
    ├── SDD-USAGE.md              #   Quick command reference with examples
    ├── SDD-SETUP-GUIDE.md        #   Comprehensive setup walkthrough
    ├── kiro/README.md            #   Spec engine deep dive
    ├── memory/README.md          #   Memory architecture guide
    ├── jira/README.md            #   Jira integration setup
    ├── channels/README.md        #   Outbound Slack/Discord/Teams webhook notifications
    ├── autoresearch/README.md    #   ML experiment loop guide
    ├── gitnexus/README.md        #   Code intelligence + visual explorer guide
    ├── context-management/rtk/README.md  #   Token compression proxy — filters, install, upgrading
    ├── privacy-filter/README.md  #   PII scanning setup, CLI usage, integration checkpoints
    ├── skill-extraction/README.md#   Skill extraction methodology
    ├── prompt-master/README.md   #   Prompt engineering skill with JSON prompting
    └── design/                   #   Visual design quality integrations
        ├── README.md             #     Design quality index + workflow overview
        └── impeccable/           #     Impeccable anti-pattern detection
            └── impeccable.md     #       Rules reference, skill usage, CLI setup
```

---

## The SDD Workflow

The spec engine is built on [cc-sdd](https://www.npmjs.com/package/cc-sdd) — a Spec-Driven Development framework for Claude Code. We adapted it with custom path mapping, additional agents (doc-sync, harness-updater, reflect, housekeeping, evolve), and extended it with memory, steering, and Jira subsystems.

The core workflow enforces deliberate planning before coding, with human review gates at every transition:

```
 ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
 │ Requirements │────▶│   Design    │────▶│   Tasks     │────▶│   Implement │
 │  (EARS fmt)  │     │  (research  │     │ (parallel-  │     │  (TDD +     │
 │              │     │   backed)   │     │  aware)     │     │  self-review│
 └─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
        │ ✅ approve        │ ✅ approve        │ ✅ approve        │ ✅ done
```

**Standard path** (maximum control):
```
/kiro:spec-init "Feature name"        # Create spec workspace
/kiro:spec-requirements               # Generate EARS requirements → Proof review → approve
/kiro:spec-design                     # Generate design with codebase research → Proof review → approve
/kiro:spec-grill <spec-name>           # Domain grilling session → align terminology, update docs inline → approve
/kiro:spec-tasks                      # Break into parallelizable tasks → Proof review → approve
/kiro:spec-impl <spec-name>           # TDD implementation with auto self-review
```

Each spec phase ends with a **[Proof](https://github.com/anthropics/proof) collaborative review session** — a shared URL where you annotate, comment, and approve the document before the next phase begins. Proof is installed automatically on first use.

**Fast path** (one command):
```
/kiro:spec-quick "Feature name"       # All phases in one shot (interactive or auto mode)
```

**Validation** (at any point):
```
/kiro:validate-gap                    # What's specified but not built?
/kiro:validate-design                 # Is the design sound? (remediation plan on NO-GO)
/kiro:validate-impl                   # Does the code match the spec? (remediation plan on NO-GO)
/kiro:validate-adversarial            # High-confidence three-pass adversarial review
```

---

## Commands Reference

| Command | Purpose |
|---|---|
| `/kiro:idea-refine` | Refine vague ideas into clear, spec-ready briefs |
| `/kiro:spec-init` | Initialize a new spec workspace |
| `/kiro:spec-requirements` | Generate EARS-format requirements |
| `/kiro:spec-design` | Generate technical design with codebase research |
| `/kiro:spec-grill` | Interactive domain grilling session — aligns terminology, updates requirements + design, writes ADRs |
| `/kiro:spec-tasks` | Break design into parallelizable tasks (`--sequential` to disable parallel markers) |
| `/kiro:spec-quick` | Fast path: all spec phases in one command |
| `/kiro:spec-impl` | TDD implementation with automatic self-review |
| `/kiro:spec-status` | Check current spec phase and progress |
| `/kiro:verify` | 6-stage verification pipeline (build, types, lint, test, audit, git status) |
| `/kiro:fix-build` | Surgical build error resolution (3-attempt cap, minimal changes) |
| `/kiro:checkpoint` | Named workflow checkpoints (save, compare, list, restore) |
| `/kiro:debug` | Systematic 6-step bug triage (reproduce → localize → reduce → fix → guard → verify) |
| `/kiro:simplify` | Behavior-preserving code simplification with Chesterton's Fence principle |
| `/kiro:ship` | Launch readiness check (verification + production validation + rollout planning) |
| `/kiro:validate-gap` | Requirements vs. existing code gap analysis |
| `/kiro:validate-design` | Design quality review (with remediation plan on NO-GO) |
| `/kiro:validate-impl` | Implementation vs. spec validation (with remediation plan) |
| `/kiro:validate-adversarial` | Three-pass adversarial review with +1/-2 scoring |
| `/kiro:validate-perf` | Performance anti-pattern detection (N+1 queries, unbounded ops, etc.) |
| `/kiro:converge` | Spec ↔ code reconciliation — detects bidirectional drift (spec-ahead / code-ahead / contradiction); reuses `validate-impl-agent` |
| `/kiro:steering` | Bootstrap/sync project knowledge docs |
| `/kiro:steering-custom` | Add domain-specific steering (auth, DB, API, etc.) |
| `/kiro:reflect` | Extract session learnings, update memory |
| `/kiro:learn-eval` | Quality-gated pattern evaluation with save/absorb/route/drop verdicts (route = skill-tied lesson pushed into its skill, not memory) |
| `/kiro:housekeeping` | Prune memory, archive old observations |
| `/kiro:evolve` | Audit harness rules, detect friction, propose improvements (includes graduation pipeline) |
| `/kiro:guardrails` | Audit and scaffold linter complexity rules for deterministic enforcement |
| `/kiro:ci-scaffold` | Generate CI configuration mirroring the verify pipeline |
| `/kiro:save-session` | Save resumable session snapshot with Progress Tracker and narrative sections |
| `/kiro:resume-session` | Resume a previously saved session |
| `/kiro:context-budget` | Analyze token consumption across steering, memory, rules |
| `/kiro:harness-fix` | Encode a behavioral prevention rule from a specific mistake |
| `/kiro:harness-validate` | Check structural integrity of the harness installation |
| `/kiro:harness-test` | Smoke-test prompts with Haiku to expose vague instructions |
| `/kiro:sync-docs` | Sync `.md` files with code changes (with reverse validation) |
| `/kiro:jira-solve` | Fetch Jira ticket and route to correct workflow |
| `/kiro:skill-extract-scan` | Analyze repo for extractable skills |
| `/kiro:skill-extract` | Generate `SKILL.md` files from scored plan |
| `/kiro:autoresearch-init` | Interactive setup for ML research projects |
| `/kiro:autoresearch` | Run autonomous ML experiment loop |
| `/kiro:gitnexus-setup` | Install GitNexus, index repo, configure MCP + hooks |
| `/kiro:gitnexus-explore` | Launch GitNexus Web UI to browse code connections |
| `/kiro:gitnexus-impact` | Query blast radius of current changes via knowledge graph |
| `/kiro:macro-eval-sweep` | Twice-weekly macro-eval sweep over Raindrop Workshop traces — clusters failure patterns, ranks by impact, backward-traces suspects, writes report and posts annotations |

For usage examples, see [docs/harness-documentation/SDD-USAGE.md](docs/harness-documentation/SDD-USAGE.md).

---

## Agents

Each command delegates to one or more autonomous subagents. Agents receive a prompt, execute their protocol, and return structured output. Key agents:

- **Spec pipeline agents** — Handle requirements, design, tasks, and implementation phases (all enhanced with anti-rationalization tables)
- **`idea-refine-agent`** — Structured ideation: problem framing → divergent exploration → convergent filtering → spec-ready brief
- **`debug-agent`** — Systematic 6-step debugging: reproduce → localize → reduce → fix → guard → verify. Classifies recovery strategy (transient/LLM-recoverable/user-fixable/unexpected). Won't fix without reproduction
- **`simplify-agent`** — Behavior-preserving code simplification with Chesterton's Fence (understands why code exists before changing it)
- **`ship-agent`** — Generates staged rollout plans with decision thresholds, rollback procedures, and feature flag recommendations
- **`spec-refactor`** — Auto-spawned after each implementation task; reviews for reuse, quality, efficiency, and 3-tier security boundaries (Always/Ask/Never)
- **`verify-agent`** — Runs 6-stage verification pipeline (build, types, lint, test, debug audit, git status) with structured PASS/FAIL reporting
- **`fix-build-agent`** — Diagnoses build errors, categorizes by type, applies minimal surgical fixes with a hard 3-attempt cap
- **`validate-adversarial`** — Three-pass adversarial review: neutral assessment → refutation → judge synthesis with asymmetric +1/-2 scoring
- **`validate-perf-agent`** — Detects performance anti-patterns: N+1 queries, unbounded operations, blocking I/O, missing indexes, and caching opportunities
- **`save-session-agent`** — Captures resumable session snapshots with a structured Progress Tracker (feature, git baseline/head, tasks completed/remaining, blockers, next action) plus narrative sections
- **`learn-eval-agent`** — Evaluates session patterns with quality gates (specificity, actionability, evidence) plus hard gates (falsifiability, anti-paraphrase) and deduplicates against existing knowledge
- **`reflect-agent`** — Mines git log for observations, promotes recurring themes to patterns (3+ distinct observations required, falsifiable), updates hot-memory; includes Step 6 session clean-state check (five-dimension table: build/tests/progress/artifacts/startup path)
- **`housekeeping-agent`** — Archives observations to cold storage, enforces memory caps
- **`evolve-agent`** — Measures memory health, detects friction patterns, analyzes agent trace logs, proposes rule changes and linter rule graduations; Step 1d audits instruction architecture health (entry file bloat, SNR, middle placement, topic doc adoption); Step 1e checks session clean-state discipline (PROGRESS.md freshness, debug artifacts, verify path); output includes "Harness Architecture Health" scorecard
- **`guardrails-agent`** — Audits project linter configs for complexity rules, scaffolds missing guardrails per ecosystem (ESLint, ruff, clippy, golangci-lint)
- **`ci-scaffold-agent`** — Generates CI configurations (GitHub Actions, GitLab CI, Azure Pipelines) mirroring the verify pipeline stages
- **`doc-sync`** — Triggered by post-commit hook; finds and updates stale `.md` files after code changes; detects stale doc-to-code references; and enforces resource coverage — every added/changed capability (skill, command, agent, hook, rule, script) must be documented in the sources index (`docs/sources/<category>/`), `.claude/docs/**`, `README.md`, and `SDD-USAGE.md`
- **`harness-updater`** — Triggered when harness source files change (`agents/`, `commands/`, `hooks/`, `kiro/`, `scripts/`, `rules/`, `templates/`, `skills/`, `CLAUDE.md`); keeps `docs/harness-documentation/SDD-SETUP-GUIDE.md` current
- **`harness-validate-agent`** — Checks structural integrity: command→agent references, template existence, memory caps, L0 headers, generates component index; Step 8 audits instruction architecture (entry file line count, constraint count, topic doc adoption, middle-placement check); Step 9 audits feature list primitive compliance (triple structure, WIP=1, pass-state gating)
- **`gitnexus-setup-agent`** — Installs GitNexus, indexes the repo, configures MCP server and editor integration
- **`jira-solve-agent`** — Analyzes ticket type and routes to the appropriate workflow
- **`skill-augment-agent`** — After each daily-maintenance run (Step E), collects judge drains plus `[seed-target:]` observations auto-written by the action-capture hook during the Wake phase. Also loads today's `type: feedback` memories (user corrections) as **highest-trust, auto-qualifying evidence ranked above the LLM judge** — human ground-truth drives the skill diff (Warp self-improvement-loop pattern). Runs a Dreaming phase to generate synthetic worked examples for each skill gap. Encodes up to 3 evidence-backed improvements into relevant `SKILL.md` files (append-only, ≤150 chars each). Logs changes as `[skill-update]` observations.

---

## Cog Memory System

The memory system is called **Cog Memory** — a cross-session persistent memory architecture inspired by [CogMem](https://arxiv.org/abs/2512.14118) ("A Cognitive Memory Architecture for Sustained Multi-Turn Reasoning in Large Language Models"). CogMem proposes a hierarchical memory system where LLMs maintain coherent reasoning across extended conversations using three layers: Long-Term Memory (distilled patterns), Direct-Access Memory (session working notes), and Focus of Attention (bounded context reconstruction at each turn).

We adapted this into a temperature-tiered filesystem architecture for Claude Code. Information flows through tiers with progressive condensation at each level — hot memory is small and always loaded (like CogMem's Focus of Attention), warm memory captures session observations (like Direct-Access), and cold/glacier storage preserves historical knowledge (like Long-Term Memory). This prevents token bloat while maintaining full historical access.

| Tier | File | Purpose | Cap | Loaded |
|---|---|---|---|---|
| **Hot** | `hot-memory.md` | Current priorities, active specs, recent decisions | 50 lines | Every session |
| **Warm** | `observations.md` | Append-only session log with tagged entries | 50 entries | On demand |
| **Warm** | `action-items.md` | Cross-session TODOs with due dates | — | On demand |
| **Warm** | `entities.md` | Project entity registry (services, APIs, DBs) | — | On demand |
| **Meta** | `meta/patterns.md` | Distilled workflow rules | 70 lines | Every session |
| **Meta** | `meta/self-observations.md` | SDD workflow learnings | — | On demand |
| **Cold** | `glacier/` | Archived observations (YAML frontmatter) | Unlimited | Rarely |

**Lifecycle — progressive condensation**:
```
Session work → /kiro:reflect    → observations.md (append new learnings)
                                → patterns.md (promote recurring themes)
                                → hot-memory.md (update current state)

observations.md (>50) → /kiro:housekeeping → glacier/YYYY-MM.md (archive)
                                            → observations.md (pruned)
```

This creates a self-improving loop: observations compound over time, patterns emerge from repetition, and the workflow gets better as more data flows through the system.

For the full memory architecture, see [docs/memory/README.md](docs/memory/README.md).

---

## Steering (Project Knowledge)

Steering files are auto-generated docs that ground every conversation in your project's reality:

| File | Contents |
|---|---|
| `steering/product.md` | Product vision, goals, user personas |
| `steering/tech.md` | Tech stack, architectural patterns, key dependencies |
| `steering/structure.md` | Codebase structure, module relationships, entry points |

**Custom steering** adds domain-specific docs: `authentication.md`, `database.md`, `api-standards.md`, `testing.md`, `deployment.md`, `security.md`, `error-handling.md`.

Additionally, `scripts/generate-project-stack.sh` auto-detects your language, runtime, package manager, dependencies, test commands, and Docker services — producing a `PROJECT_STACK.md` summary.

---

## Jira Integration

Connect Claude Code to your Jira board for ticket-driven development:

```
/kiro:jira-solve PROJ-123
```

The agent fetches the ticket, classifies it, and routes to the appropriate workflow:
- **Bug** → Systematic debugging via `/kiro:debug` (6-step triage with regression guard)
- **Feature** → Full SDD spec pipeline (requirements → design → tasks → implement)
- **Task** → Implementation plan and execution

On `git push`, an auto-comment is posted to the ticket with a summary of changes (single-fire, no duplicates).

**Setup**: Create `~/.env.jira` with your credentials (PAT or Basic Auth). See [docs/integrations/jira/README.md](docs/integrations/jira/README.md).

---

## Skill Extraction

Based on the methodology from ["Automating Skill Acquisition through Large-Scale Mining of Open-Source Agentic Repositories"](https://arxiv.org/abs/2603.11808) — a research paper on extracting reusable procedural knowledge from codebases. We implement their 4-criteria scoring rubric (Recurrence, Code Quality, Domain Expertise, Generalizability) as a 3-stage pipeline within the harness.

```
/kiro:skill-extract-scan            # Analyze repo, score modules, produce plan
/kiro:skill-extract                  # Generate SKILL.md files from approved plan
```

**3-stage pipeline**:
1. **Structural analysis** — Map repo architecture and module boundaries
2. **Semantic scoring** — Score against the 4-criteria rubric from the paper
3. **SKILL.md generation** — Produce standalone skill files for `~/.claude/skills/`

**Quality gates** (applied to every new skill before it is logged):
- **Phase 5b — SkillOS Quality Gate**: scores task relevance, operational validity, content quality, and compression. Failures block completion until fixed.
- **Phase 5c — Identity Alignment Check**: invokes the `agent-identity` skill in Mode B to validate description specificity, trigger sharpness, behavioral concreteness, and explicit exclusions. Prevents vague skill identities from accumulating in the harness.

**Bundled harness skills** — shipped in `skills/` and propagated to every project by `install.sh`/`update.sh`. Recent additions:

| Skill | Source | Description |
|---|---|---|
| `instruction-architecture` | walkinglabs.github.io/learn-harness-engineering | Lean entry-file + topic-doc architecture, SNR audit, "lost in the middle" countermeasures, instruction maintenance metadata |
| `feature-list-primitive` | walkinglabs.github.io/learn-harness-engineering | Machine-readable feature state machine (not_started/active/blocked/passing), triple structure, WIP=1, pass-state gating |
| `session-clean-state` | walkinglabs.github.io/learn-harness-engineering | Five-dimension clean state, clock-in/clock-out protocols, PROGRESS.md/DECISIONS.md/QUALITY.md templates, entropy management |
| `agent-harness-design` | arXiv:2605.26112 | 6-component framework (ℛℳ𝒞𝒮𝒪𝒢), temporal scaling tiers; Phase 4 adds Operational Diagnostics (Fresh Session Test, Controlled Ablation, Affordance Analysis, Rot Detection) |
| `evaluation` (family) | Multiple sources | Router + 4 sub-skills: `micro` (per-run), `macro` (population patterns), `funnel` (A/B decisions), `long-trajectory` (stateful/long-horizon agents) |
| `local-llm-eval` | Custom (OMT) | Zero-dependency CLI for testing prompts against local Ollama models; multi-model comparison keyed on prompt hash; temperature variance testing; fully offline |
| `active-observability` | Braintrust/Clio | Batch-LLM facet pipeline for discovering unknown patterns in agent trace collections; clusters summaries via HDBSCAN; feeds Raindrop Workshop eval loop |
| `ai-security-workflow` | Custom | 5-phase interactive security workflow (threat-model → vuln-scan → triage → patch → close); produces standardized artifacts; wired into `security-report-runner.sh` |
| `secure-agent-design` | VentureBeat 2026 | Prompt injection mitigation, find/verify isolation, serial dedup, egress control for agents that process untrusted input or run in multi-agent pipelines |
| `structured-web-dataset` | Custom | Build structured tabular datasets from NL descriptions via parallel research agents (web mode) or constraint-driven generation (synthetic mode); outputs rows/columns, not prose |
| `verification-skill-authoring` | Custom | Turn manual domain checks into a reusable `<domain>-verify` skill; auto-invoked after skill creation (skill-extraction Phase 5d); encodes review checklists as Claude-executable steps |
| `ai-native-org-patterns` | Custom | Organizational design patterns for AI-first teams: context engineering, async agent pipelines, skill-based modularity, evaluation loops, and human-in-the-loop governance |
| `surfacing-unknowns` | Thariq — "Field Guide to Fable" | Pre-execution discovery routine: run before a spec/design/large change to close the map-vs-territory gap — surfaces blind spots and tacit taste before building; skip for well-specified mechanical tasks |
| `pr-babysit` | Compound Engineering v3.20 | Monitor-tool background watch of a PR's CI/reviews after auto-create; branch-currency check; explicit authority boundary (fix/commit/push only — never merge/rebase/force-push/CI-approve). Merged with incumbent `iterate-pr` |
| `diff-teach` | Compound Engineering v3.20 | Two-turn predict-then-reveal drill for diffs/commits/time-windows — closes comprehension debt on agent-written code the user never read line-by-line. Merged with incumbent `code-documentation-code-explain` |

See [docs/skills/skill-extraction/README.md](docs/skills/skill-extraction/README.md) for the full extracted skills index.

---

## Prompt Mastery

The harness ships with **prompt-master** — a prompt-writing skill (v1.7.0, 7.2k GitHub stars) that generates production-ready prompts for 30+ AI tools. Instead of pattern references or prompting theory, it routes your intent to tool-specific templates and outputs a single paste-ready prompt on the first try.

### JSON Prompting

The skill natively detects and generates **JSON-structured prompts** — the fastest way to eliminate the model's guessing surface:

```
"Write a tweet about dopamine detox"
→ The model guesses tone, length, audience, style. Output feels generic.
```

```json
{
  "task": "write a tweet",
  "topic": "dopamine detox",
  "tone": "punchy and contrarian",
  "length": "under 280 characters",
  "style": "viral"
}
→ Zero guessable dimensions. Model executes instead of guessing.
```

Nested JSON locks structured outputs (threads, reports, multi-section docs):

```json
{
  "task": "write a thread",
  "platform": "twitter",
  "topic": "founder productivity",
  "structure": {
    "hook": "curiosity-driven, under 10 words",
    "body": "3 insights with examples",
    "cta": "question that sparks replies"
  }
}
```

If you write your request as a JSON object, the skill maps keys to intent dimensions automatically and skips clarifying questions for covered ones.

**Pre-installed at:** `~/.claude/skills/prompt-master/`

See [docs/prompts/prompt-master/README.md](docs/prompts/prompt-master/README.md).

---

## AutoResearch (ML Experiments)

Adapted from [karpathy/autoresearch](https://github.com/karpathy/autoresearch) — Andrej Karpathy's tool for autonomous ML experimentation where an AI agent iterates on training code in a loop, making hypotheses, running experiments, and keeping what works. We adapted this into the harness as slash commands with an interactive setup flow and integration with our memory system so experiment results persist across sessions.

Requires [uv](https://docs.astral.sh/uv/) (Astral's fast Python package manager) for running training scripts.

```
/kiro:autoresearch-init             # Interactive setup (asks about your model, metrics, constraints)
/kiro:autoresearch                   # Run the experiment loop
```

Each iteration: hypothesize → modify code → train (5-minute bounded) → evaluate → keep improvements / revert failures.

See [docs/research/autoresearch/README.md](docs/research/autoresearch/README.md).

---

## GitNexus (Code Intelligence)

Integrates [abhigyanpatwari/GitNexus](https://github.com/abhigyanpatwari/GitNexus) — a zero-server code intelligence engine that builds a knowledge graph from your codebase (symbols, dependencies, call chains, execution flows) and exposes it via MCP tools. The integration is **opt-in**: when GitNexus is present, harness agents gain graph-backed context; when absent, everything works as before.

Once set up, **everything is automatic** — no extra commands in your daily workflow:

1. **PreToolUse context enrichment** — Every file read/edit by any agent is enriched with 360-degree symbol context (callers, dependencies, process participation)
2. **Auto-reindex** — Post-commit hook keeps the knowledge graph fresh after every commit
3. **Impact detection** — `verify-agent` Stage 0 maps git diffs to affected processes with risk levels
4. **Blast radius in TDD** — `spec-impl` scans files-to-modify for downstream dependents before writing tests
5. **Call chain tracing** — `debug-agent` queries GitNexus for call chains instead of manual grep
6. **Community-seeded skill extraction** — `skill-extract-agent` uses Leiden-detected functional clusters as candidates
7. **Visual exploration** — `/kiro:gitnexus-explore` launches a browser-based WebGL graph (the only manual command)

```
/kiro:gitnexus-setup              # Install, index, configure MCP (one-time)
/kiro:gitnexus-explore            # Launch visual Web UI
/kiro:gitnexus-impact             # Query blast radius for current changes
```

Setup can also be done during harness installation:
```
$SDD_HARNESS/install.sh /path/to/project --with-gitnexus
```

`install.sh --with-gitnexus` now wires the MCP server itself via `scripts/setup/gitnexus-reconcile.sh --wire` — writing the server into `.mcp.json` and adding it to `enabledMcpjsonServers` in `.claude/settings.json` — instead of printing a note telling you to paste the `mcpServers` JSON by hand. It then runs `gitnexus setup` **only** if `gitnexus-reconcile.sh --check` confirms both the index and the MCP server exist — otherwise the managed block (written into `CLAUDE.md`, or `AGENTS.md` for projects that relocated their conventions there) was written with MUST/NEVER rules ordering the agent to call `gitnexus_*` tools that were never registered. When the check fails, install prints why and points at `/kiro:gitnexus-setup` to finish wiring. `update.sh` runs the same reconciler on every sync: the managed block is committed while `.gitnexus/` is gitignored and the MCP server lives in local config, so a fresh clone inherits rules for tools it cannot call — the reconciler strips the block when it's dead and, when it's live, repairs its skill paths and rewrites any bare `gitnexus_*` tool names to the `mcp__gitnexus__*` form the MCP server exposes; it no-ops for projects that never ran `gitnexus setup`.

See [docs/integrations/gitnexus/README.md](docs/integrations/gitnexus/README.md).

---

## Privacy Filter (PII Scanning)

Integrates [openai/privacy-filter](https://github.com/openai/privacy-filter) — a 1.5B-parameter (50M active, sparse MoE) bidirectional transformer that detects and redacts PII in text across 8 categories: secrets/API keys, account numbers, emails, phone numbers, names, addresses, dates, and URLs. Runs entirely on-premises; no data leaves your machine. Apache 2.0 licensed.

The integration adds two artifacts:

1. **`privacy-filter` skill** — Guided workflow for installing OPF, scanning files or strings, interpreting findings by severity, and redacting before commits or external sharing
2. **`.claude/hooks/scan-pii.sh`** — Standalone bash scanner that exits `1` on high-severity findings (`secret`, `account_number`); designed to gate `git commit` as a pre-commit hook

```bash
# Scan staged files before committing
bash .claude/hooks/scan-pii.sh --staged

# Scan a specific file or directory
bash .claude/hooks/scan-pii.sh path/to/file.txt

# Ad-hoc from CLI
opf "my token is sk-proj-abc123" --format json
```

Wire as a git pre-commit hook to block commits with exposed secrets:
```bash
echo 'bash "$(git rev-parse --show-toplevel)/.claude/hooks/scan-pii.sh" --staged' \
  >> .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

> **In the harness repo itself**, `.git/hooks/pre-commit` is owned by `hooks/git/pre-commit` (the hardcoded-path guard, and since 2026-09-03 the embedded-Python regex guard alongside it), which `install.sh` / `update.sh` rewrite on every run — a line appended there is lost at the next install or update. Add the scan-pii line to `hooks/git/pre-commit` in the source tree instead. In any other project the slot is free: the harness guard is deliberately not propagated downstream, and the installer leaves a pre-commit it doesn't recognise alone.

See [docs/security/privacy-filter/README.md](docs/security/privacy-filter/README.md).

---

## Impeccable (Frontend Design Quality)

Integrates [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (25.6k ⭐) — a design quality system built to counter the visual and functional flaws AI coding assistants routinely produce. It provides 27 deterministic anti-pattern rules + 12 LLM critique rules across 7 design domains (typography, color, spatial, motion, interaction, responsive, UX writing).

The integration adds three artifacts:

1. **`impeccable-audit` skill** — Full 7-domain visual audit with PASS/NEEDS WORK/BLOCK verdict. Catches gradient text, glassmorphism, nested cards, contrast failures, stale easing curves, missing focus states, and more
2. **`kiro/settings/rules/frontend-anti-patterns.md`** — Deterministic enforcement rules referenced by `/kiro:validate-design` and the adversarial agent when reviewing UI components
3. **`.claude/hooks/impeccable-detect-hook.sh`** — PostToolUse hook that auto-scans `.tsx`, `.jsx`, `.css`, `.vue`, `.svelte`, `.html` files after every Write/Edit

```bash
# One-time CLI setup (enables the auto-scan hook)
npm install -g impeccable

# On-demand audit
/impeccable-audit [component name or "focus: motion"]
```

The hook exits silently if the CLI is not installed — nothing blocks. Once installed, violations surface immediately after writing frontend files, before the next action.

Key anti-patterns caught: `background-clip: text` gradient text, `backdrop-filter` glassmorphism, colored left borders, identical card grids, nested cards, pure white backgrounds (`#ffffff`), gray text on colored backgrounds, `ease-in`/`ease-out` easing, missing `:focus-visible` states.

See [docs/design/impeccable/impeccable.md](docs/design/impeccable/impeccable.md).

---

## Context Hub (MCP Integration)

Integrates [andrewyng/context-hub](https://github.com/andrewyng/context-hub) — Andrew Ng's MCP server that provides curated, LLM-optimized documentation for third-party libraries and APIs (OpenAI, Stripe, Anthropic, etc.). Instead of Claude hallucinating API signatures or working from stale training data, Context Hub serves up-to-date, verified documentation on demand.

Runs as an MCP server via `npx -y @aisuite/chub-mcp` and is configured in the project's `.claude/settings.json`. Exposes tools like `chub_search`, `chub_get`, and `chub_list` that Claude Code can call during any workflow.

See the Context Hub section in [docs/harness-documentation/SDD-SETUP-GUIDE.md](docs/harness-documentation/SDD-SETUP-GUIDE.md) for configuration.

---

## RTK (Token Compression)

Integrates [rtk-ai/rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer) — a 6.6MB single-binary CLI proxy that intercepts Bash command output and compresses it through a multi-stage filter pipeline before it reaches the LLM context window. Typical reduction: 60–90% on development commands.

A `PreToolUse` hook in `~/.claude/settings.json` invokes `rtk hook claude` on every Bash tool call. When the command has a registered filter, the hook rewrites `git diff` to `rtk git diff`, the proxy captures the output, applies the filter, and returns the compressed version. **Everything is automatic** — no per-project setup, no commands to invoke.

Filters cover 100+ commands: git, all major test runners (pytest, cargo test, jest, vitest, playwright…), file ops (ls, find, grep, tree…), build tools (cargo, tsc, go build, next build…), linters (ruff, mypy, eslint, clippy, prettier…), docker, kubectl, aws, curl, gh, jq, and package managers.

```bash
rtk gain              # cumulative token savings summary
rtk gain --history    # per-command breakdown
rtk gain --graph      # ASCII graph of daily savings
rtk discover          # scan Claude Code history for missed opportunities
```

Install once with Homebrew (`brew install rtk && rtk init -g`) and the global hook covers every project and every session — see [docs/context/rtk/README.md](docs/context/rtk/README.md) for full filter coverage, config, and troubleshooting.

---

## Automation & Hooks

### Session Start Hook (`hooks/claude/session-start-hook.sh`)

Runs when a Claude Code session starts (SessionStart). First reads `$HOME/.sdd-harness-root` — the single stored pointer to the harness — and, if it names a directory that no longer exists, prints `[HARNESS-POINTER-STALE]` with the dead path and the fix (`bash <harness>/update.sh`), since a moved harness silently deactivates every cross-repo hook on the machine. Then self-heals `.claude/settings.json` by running `scripts/setup/repair-settings-json.py` (located via that same pointer) against the current project, ahead of every other check — Claude Code silently drops a malformed settings file, so every permission rule and hook in it stops working with no in-session error. When the repair changes something it prints `[SETTINGS-REPAIRED]` plus a note that this session's rules are inactive until the next session start; a healthy or missing file produces no output. Then two modes: (1) if no local `daily-runner.sh` is installed — checks if today's `[judge]` sentinel is absent from `observations.md` and asks Claude to run `/kiro:daily-maintenance`; (2) if `daily-runner.sh` is installed and stale (>24h or never ran) — fires it in the background via `nohup` silently, without consuming session context. Also checks if the per-repo CLAUDE.md review is >2 weeks stale (`.claude/memory/.last-claudemd-review`) and asks Claude to run `/claudemd-review` if so. Also surfaces a fresh (<24h) session-handoff snapshot at `.claude/memory/handoff/latest.md` — written by `scripts/session/write_handoff.py` from `compaction-discipline-hook.sh` and `gbrain-agent-spawn.sh` — with a reminder to read it before responding. Additionally runs a background headroom memory sync (`scripts/utils/sync-memories-to-headroom.py`) when headroom is installed — bidirectional: harness memories to headroom SQLite and new headroom extractions to MEMORY.md.

### Context Priming Hook (`hooks/claude/prompt-hook.sh`)

Runs before every user prompt (UserPromptSubmit). Injects the contents of `hot-memory.md` into context so the agent always has current priorities, active specs, and recent decisions.

### Frontend Security Nudge (`hooks/claude/frontend-security-nudge.sh`)

Runs before every user prompt (UserPromptSubmit). When the prompt contains build intent (build/create/implement/scaffold) combined with frontend or design keywords (React, Vue, Svelte, CSS, component, form, modal, etc.), injects a reminder to invoke the `secure-agent-design` skill before starting. Exits in <5ms on non-matching prompts — zero overhead for non-frontend work.

### Doc Parse Nudge (`hooks/claude/doc-parse-nudge.sh`)

Runs before every user prompt (UserPromptSubmit). When the prompt combines build intent with document-parsing or RAG keywords (PDF, DOCX, OCR, embedding, vector store, chunk, ingest, Pinecone, Chroma, Qdrant, etc.), injects a reminder to invoke the `document-parsing` skill before starting. Covers format selection (text vs JSON+bbox), OCR config, liteparse, and RAG handoff patterns. Exits in <5ms on non-matching prompts.

### Raindrop Best Practices (`hooks/claude/raindrop-best-practices.sh`)

Fires before any Raindrop Workshop MCP tool call (`mcp__raindrop__` matcher). Injects five active-observability patterns: batch facets (multiple dimensions → one LLM call), facet-first summarization before clustering, 128K token cap on input, no-LLM nearest-summary classification, and long-tail sampling with HDBSCAN. Ensures trace analysis runs at a fraction of the naïve cost.

### Headless Envelope (`hooks/claude/headless-envelope-hook.sh`)

Fires on `SessionStart`, but produces zero bytes unless `SDD_HEADLESS=1` — that is, unless the session is an unattended `claude --print` routine run. The seven unattended entry points (the `scripts/routines/*-runner.sh` set and `daily-orchestrator.sh`'s drift review) all run with `--permission-mode bypassPermissions`, so the least-supervised sessions had the widest permissions and no human backstop. The injected envelope is stricter than the interactive rules and overrides anything looser: one unit of work, no history-rewriting or publishing git, writes confined to the routine's own lane, a two-strike loop guard that escalates instead of retrying a third time, honest reporting of partial completion, and no new dependencies. Advisory — `SessionStart` output becomes context and cannot block. Opt out per-runner with `SDD_SKIP_HEADLESS_ENVELOPE=1` (never globally).

### Subagent Context (`hooks/claude/subagent-context-hook.sh`)

Fires on `SubagentStart` — inside the child — and injects harness conventions via JSON `hookSpecificOutput.additionalContext` (plain stdout is not injected for this event). `CLAUDE.md`, `.claude/rules/` and `SessionStart` output are all parent-thread only, so before this a subagent started without them and re-derived or violated conventions the main thread already knew. The older `gbrain-agent-spawn.sh` can only ask the *parent* to brief the child; this is the guarantee. Kept deliberately short — the text is prepended to every spawn. Requires `jq`; opt out with `SDD_SKIP_SUBAGENT_CONTEXT=1`.

The injected text carries a **BLAST RADIUS** block that names one check to run, in order, rather than a list of three: `mcp__serena__find_referencing_symbols` for a Python symbol (LSP-accurate, authoritative), `mcp__gitnexus__impact` for anything else, and `ctx_callgraph(action="callers")` when the index errors or reports a version mismatch — a broken index is an unknown answer, never "no callers". The TOOLS block states that native Grep/Glob are policy-denied instead of re-listing the whole `ctx_*` mapping, and what was formerly a second "blast radius" bullet under SCOPE is now called **change size**, so the two senses of the phrase stop colliding.

### JS Quality Gate (`hooks/claude/js-quality-gate-hook.sh`)

The sibling of `ruff-quality-gate-hook.sh` for the other half of the languages the harness installs into. Fires on `PostToolUse` Write/Edit/MultiEdit to `.ts/.tsx/.js/.jsx` (and `.mts/.cts/.mjs/.cjs`), preferring `oxlint` and falling back to `eslint`, skipping `.d.ts` and `node_modules`/`dist`/`build` paths. Advisory only — the write already happened. A finding naming an anti-slop low-evidence rule (`no-unknown-parameters`, `no-unsafe-dictionary-type`, `no-chained-type-assertions`, …) gets an extra callout: that means type evidence was thrown away, and the fix is to recover the real type rather than silence the rule. Silent no-op when neither linter is installed.

### Todo Focus (`hooks/claude/todo-focus-hook.sh`)

Fires on `PostToolUse` with matcher `TodoWrite`. `TodoWrite` accepts any number of concurrent `in_progress` entries and enforces nothing, which lets an agent start four items at once and finish none cleanly. When more than one is active the hook names the competing items and asks for one to be picked. Soft — the write already happened and the hook does not undo it — but it exits 2, because `PostToolUse` stdout is not injected into context at exit 0. Reads `.tool_input.todos[].status` as structured JSON via `jq`; it does not pattern-match free text. Requires `jq`; opt out with `SDD_SKIP_TODO_FOCUS=1`.

### Session Exit Hook (`hooks/claude/stop-hook.sh`)

Runs when a Claude Code session ends. Checks for:
- Harness updates available (prompts to run `update.sh`)
- Memory health (warns if observations exceed cap)
- Re-explanation detection (scans transcript via `scripts/session/detect_reexplanation.py`; appends a `[memory-gap]` observation for drains, `[session-charge]` for approvals; both written at most once per calendar day). Classification runs through `claude --print` on the user's subscription rather than the `anthropic` SDK, so no API key is involved. The check is skipped when `SDD_HEADLESS=1` — the detector sets it on its own child session, which is what stops this hook from recursing, and routine runners set it so unattended sessions are not measured. A detector that cannot run writes a `[detector-down]` observation and exits 4 instead of reporting zero gaps, and every run records its count (zero included) to `.claude/memory/metrics.jsonl`
- Agent failure patterns (3+ consecutive failures for the same agent in `trace.log` — suggests running `/kiro:evolve`)

Respects the `SDD_PROFILE` environment variable — skipped entirely when profile is `minimal`.

### Hook Profiles

Control automation intensity via `SDD_PROFILE` environment variable:

| Profile | Session Hooks | Git Hooks | Description |
|---|---|---|---|
| `minimal` | Skipped | Active | Rapid prototyping, exploratory work |
| `standard` | Active | Active | Normal development (default) |
| `strict` | Active | Active | Production-bound code, release prep |

Set with: `export SDD_PROFILE=minimal` (defaults to `standard` if unset).

### PII Scanner (`hooks/claude/scan-pii.sh`)

Runs OPF on a set of files and exits non-zero if high-severity PII is found. Designed for manual use or as a git pre-commit hook:

- `--staged` — scan only git-staged files (use in pre-commit)
- `<path>` — scan a file or directory (text-like files: `.md`, `.json`, `.log`, `.py`, `.ts`, `.sh`, etc.)
- Exits `0` for clean or low-severity-only findings, `1` for `secret`/`account_number`, `2` if OPF is not installed (soft-fail to not break CI without OPF)

Requires OPF (OpenAI privacy-filter — not on PyPI, install from source): `uv tool install --python 3.13 git+https://github.com/openai/privacy-filter.git`. Model weights (~2.8GB) auto-download to `~/.opf/` on first use.

### Caveman Mode Hook (`hooks/global/caveman-activate.js`)

Fires on every `SessionStart`. Reads the configured default mode from `caveman-config.js`, writes a flag file at `$CLAUDE_CONFIG_DIR/.caveman-active` (consumed by the statusline), and emits the full caveman ruleset as hidden session context. Reads `skills/caveman/SKILL.md` at runtime so edits to the skill propagate automatically without requiring hook changes. Falls back to a hardcoded minimal ruleset when the skill file isn't present (standalone installs). Companion hooks: `caveman-mode-tracker.js` injects the active level into every prompt; `caveman-stats.js` records usage. `caveman-statusline.sh` is a statusline command (not a lifecycle hook) that emits the `[CAVEMAN]` / `[CAVEMAN:ULTRA]` badge, plus a color-coded `%ctx` live context-usage meter parsed from `context_window.used_percentage` on stdin — renders regardless of whether caveman mode is active, and persists the last-seen % per repo to `dashboard-context/<hash>.json` so `scripts/utils/dashboard.py`'s Context Health tab can show a "live" reading (state older than 15 minutes is treated as a closed session and not shown).

All caveman hooks are user-global — wired in `~/.claude/settings.json`, not installed per project.

### lean-ctx Rewrite Hook (`hooks/global/lean-ctx-rewrite.sh`)

A `PreToolUse` hook in `~/.claude/settings.json` that fires on every Bash tool call. When the command matches a registered tool (`git`, `gh`, `cargo`, `npm`, `pnpm`, `pytest`, `rg`, `ls`, `find`, and others), rewrites it to `lean-ctx -c "<original>"` so output passes through the lean-ctx compression layer. Commands not in the match list exit immediately with no rewrite. Complements RTK — RTK compresses output from a broad set of dev tools, lean-ctx rewrites the command to use its own caching and mode-selection layer.

This is a user-global hook — applies to every session and every project automatically. No per-project setup needed.

### Global Token Compression Hook (RTK)

A `PreToolUse` hook in `~/.claude/settings.json` fires on every Bash tool call. `rtk hook claude` reads the JSON payload, checks if the command has a registered filter (git, test runners, file ops, linters, etc.), and if so emits a rewrite directive (`permissionDecision: "allow"`) telling Claude Code to run `rtk <original>` instead. The proxy executes, compresses the output, and returns it. Commands without filters pass through unchanged.

This is a global hook — it applies to every session and every project automatically. No per-project configuration needed.

### Git Post-Commit Hook (`hooks/git/post-commit`)

Runs after every commit — except its own `docs: auto-sync (<date>)` commits, which it detects by commit subject and bails on immediately (before every stage, GitNexus reindex included) so an auto-sync commit cannot re-fire the agents. Otherwise it detects what needs syncing, then hands all of it to **one fully-detached background job** so `git commit` returns immediately:
1. **Doc Sync** — If non-`.md` files changed, finds and updates affected documentation. The scan skips `.venv/`, `.git/`, `__pycache__/`, and `.claude/` — the installed `.claude/` mirror is regenerated output, so doc sync no longer edits it
2. **Harness Updater** — If harness source files changed (`agents/`, `commands/`, `hooks/`, `kiro/`, `scripts/`, `rules/`, `templates/`, `skills/`, or `CLAUDE.md`), updates `docs/harness-documentation/SDD-SETUP-GUIDE.md`
3. **Detached runner + docs auto-push** — If either check above fired, a single background job (stdin from `/dev/null`, output appended to `.git/post-commit-docsync.log`, `disown`ed) runs the doc-sync agent, then the harness updater, then stages, commits (`docs: auto-sync (<date>)`), and pushes **only `.md` files**. Non-`.md` changes sitting in the tree are never staged or pushed. A failed push is reported in the log, not retried.

Each `claude` invocation inside the job is bounded by `timeout 900` (`gtimeout` fallback where only coreutils provides it), and a failing agent is swallowed so the commit-and-push stage always runs. The only terminal output is a one-line notice at commit time (`post-commit: doc-sync + auto-push running in background (log: .git/post-commit-docsync.log)`, plus a matching line when the GitNexus reindex fires); all agent, commit, and push output goes to the log — watch progress with `tail -f .git/post-commit-docsync.log`, where each run is delimited by `=== doc-sync run <date> ===` / `=== done <date> ===`. The `.md`-only auto-sync commit re-fires the hook, but the self-commit guard matches its `docs: auto-sync` subject and exits — no loop. The GitNexus reindex stage is likewise detached with its output discarded.

The trigger for step 2 keys off the top-level source tree, not `.claude/` — `.claude/` is regenerated output rebuilt by `install.sh`/`update.sh` and is fully gitignored.

---

## Multi-Project Management

The harness is installed at `$SDD_HARNESS` (wherever you cloned it) and shared across all your projects.

Both `install.sh` and `update.sh` write `export SDD_HARNESS="<clone path>"` into `~/.zshrc` and `~/.bashrc` (whichever exist) — appended under a comment on first run, rewritten in place on later runs. Moving the clone therefore needs no manual edit: re-run either script from the new location and the exported path follows it.

### Register projects

Projects are automatically registered in `projects.txt` when you run `install.sh`. One absolute path per line.

### Install into all registered projects

Run `install.sh --all` to install the harness into every project listed in `projects.txt` in one pass. Projects that are already installed (those with a `.claude/kiro/` directory) are **skipped** automatically:

```bash
# Git Bash / WSL2 / macOS / Linux
$SDD_HARNESS/install.sh --all

# From PowerShell (Windows), invoke Git Bash with the call operator,
# run from inside the sdd-harness repo directory:
& "C:\Program Files\Git\bin\bash.exe" install.sh --all
```

| Command | What it does |
|---|---|
| `install.sh --all` | Install into every project in `projects.txt`; skip already-installed ones |
| `install.sh --all --force` | Re-sync **every** project, including installed ones — use this to roll out harness updates everywhere |
| `install.sh --all --with-gitnexus` | Batch install and configure GitNexus on each project |
| `install.sh --all --with-gitnexus --skip-embeddings` | Batch install with GitNexus indexing but skip the (slow) embeddings step |

Missing directories and non-git paths are reported and skipped; one failing project never aborts the batch. A final tally prints `installed / skipped / failed`. Machine-global setup (skills, global commands, Raindrop, the OS daily orchestrator) runs **once**, not per project.

### Update all projects

```bash
$SDD_HARNESS/update.sh
```

Updates commands, agents, rules, templates, scripts, and docs in every registered project. Also regenerates `PROJECT_STACK.md` for each.

### Update a single project

```bash
$SDD_HARNESS/update.sh /path/to/project
```

### Sync across machines

```bash
cd $SDD_HARNESS
git remote add origin git@github.com:<you>/sdd-harness.git
git push -u origin main
```

`projects.txt` and `VERSION` are gitignored — they contain machine-local state. So are `CLAUDE.md`, `AGENTS.md` (written by `lean-ctx setup`) and `ERRORS.md` (the 2+-attempts failure log), which are regenerated per machine rather than authored. So are the scheduler state files (`.last-harness-sync`, `.last-drift-review`) and `reports/`, the directory generated routines write into (the drift-review sweep among them), so a generated report is never pushed.

---

## Local Dashboard

A browser-based dashboard that shows trust battery, GitNexus stats, Raindrop Workshop traces, compression savings (RTK + headroom), hooks history, scheduled tasks, memory and skill changes, session quality, model spend, and an automation audit timeline across all registered repos.

```bash
python3 $SDD_HARNESS/scripts/utils/dashboard.py
```

This starts a local HTTP server on `http://localhost:4569` and opens the dashboard in your browser. On WSL it uses `wslview` or `explorer.exe` to open the URL.

**Options:**

| Flag | Description |
|---|---|
| `--repo <name\|path>` | Pre-select a specific repo on load |
| `--no-open` | Start the server without opening the browser |
| `--static` | Write a static `$SDD_HARNESS/.dashboard/index.html` instead of starting a server |

```bash
# Open dashboard scoped to a specific repo
python3 $SDD_HARNESS/scripts/utils/dashboard.py --repo aiq-zora-ai-engine

# Generate a static file (no server, no browser)
python3 $SDD_HARNESS/scripts/utils/dashboard.py --static --no-open
```

Requires at least one project registered in `projects.txt` (added automatically by `install.sh`). The companion server on port 4569 stays alive until you press `Ctrl+C`.

**Sections (sidebar order):**

| # | Section | What it shows |
|---|---|---|
| 1 | ⚡ Trust Battery | Arc gauge + 30-day bar chart of daily trust deltas |
| 2 | 🕸 GitNexus | Stats strip + embedded visual explorer. `gitnexus serve` is API-only (it answers `/api/*` and 404s at `/`), so the tab iframes the hosted app `https://gitnexus.vercel.app/?repo=<name>` — which talks to `http://localhost:4747` — and probes `http://localhost:4747/api/repos` in real CORS mode to detect whether the backend is up. A non-OK status now reports the HTTP code instead of reading as "not running" |
| 3 | 🔬 Workshop | Raindrop Workshop trace browser; filter by repo, run eval loop, view agent traces |
| 4 | 🗜 Headroom | Compression savings totals for RTK + lean-ctx + Caveman (response-style, sampled once/day via `caveman-savings-hook.sh`) + headroom proxy, folded into a combined-savings total; per-session block history with checkpoint-level token savings |
| 5 | 🪝 Hooks History | Hook name, event type, last activity, active/inactive badge |
| 6 | 📅 Scheduled Tasks | OS-scheduler health card + per-routine schedule, last run, next expected, artifact diff, overdue alerts. Includes the Daily Security Scan routine (`security-report-runner.sh`) which scans recent git changes for OWASP patterns, secrets, and injection sinks. |
| 7 | 🧠 Memory Changes | Per-file cards for hot-memory, observations, and meta/patterns with day-over-day diffs ("since yesterday") computed from dated snapshots; full content expanded when a file is unchanged |
| 8 | 🎯 Skill Changes | Rendered skill-curation-report with audit age; in companion mode, "🔍 Analyze & Propose" / "✅ Apply Approved" buttons run the skill-curator's propose/apply phases in a headless `claude --print` session, backing up `~/.claude/skills/` before any apply |
| 9 | 📊 Session Quality | Avg session score, avg keep-rate and memory-gap totals + recent-score chart, all read from `.claude/memory/metrics.jsonl` (never re-extracted from observation prose). Idle-routine days are recorded but excluded from the score average; an unmeasured memory-gap detector shows `—` rather than `0`, and each gap day expands to the topics that were re-explained. The "AI adoption" card was removed on 2026-08-20 — in a single-developer repo it measured `Co-Authored-By` trailer hygiene, not authorship |
| 10 | 💰 Model Cost | All-time and 30-day spend; 90-day daily cost bar chart; sessions table with model/tokens/cost; cross-provider "What if?" cost switcher |
| 11 | 🧵 Context Health | Sessions per day trend + `/compact` recommendations |
| 12 | 🔧 Maintenance Status | Per-repo orchestrator log tail and last-run status |
| 13 | 🤖 Automation Audit | Timeline of automated events — runs from every routine (daily-maintenance, macro-eval, skill-curator, harness-health, tool-failure, security, drift), each with its own icon/label; not-due checks (duration 0s) are hidden and daily-maintenance entries expand to show that day's brief; plus trust-judge scores, session signals, and scheduled task outcomes |

The Model Cost section reads session data from `~/.claude/projects/*/`. Pricing is fetched from `models.dev/api.json`, cached at `.dashboard/models-pricing-history.json`, refreshed bi-weekly, with historical snapshots accumulated so past sessions use the rates that were in effect at the time. The "What if?" switcher supports Anthropic, OpenAI, Google, Mistral, DeepSeek, xAI, Cohere, Amazon Bedrock, Azure, Perplexity, and Groq.

---

## Documentation Index

| Document | Description |
|---|---|
| [SDD-USAGE.md](docs/harness-documentation/SDD-USAGE.md) | Quick command reference with examples |
| [SDD-SETUP-GUIDE.md](docs/harness-documentation/SDD-SETUP-GUIDE.md) | Comprehensive setup and configuration walkthrough |
| [Kiro Engine](docs/workflow/kiro/README.md) | Spec engine components, rules, and templates |
| [Memory Architecture](docs/memory/README.md) | Temperature-tiered memory system guide |
| [Jira Integration](docs/integrations/jira/README.md) | Jira setup, credentials, and troubleshooting |
| [AutoResearch](docs/research/autoresearch/README.md) | ML experiment loop methodology |
| [GitNexus](docs/integrations/gitnexus/README.md) | Code intelligence, visual explorer, and blast radius analysis |
| [RTK Token Compression](docs/context/rtk/README.md) | Token compression proxy — filter coverage, install, config, upgrading |
| [Privacy Filter](docs/security/privacy-filter/README.md) | PII scanning setup, CLI usage, integration checkpoints, and troubleshooting |
| [Skill Extraction](docs/skills/skill-extraction/README.md) | Skill extraction pipeline and scoring |
| [Prompt Master](docs/prompts/prompt-master/README.md) | Prompt engineering skill with JSON prompting, 30+ tool profiles, 14 templates |
| [Design Quality](docs/design/README.md) | Visual design quality integrations index |
| [Impeccable](docs/design/impeccable/impeccable.md) | Anti-pattern rules, skill usage, CLI setup for frontend design quality |
| [Local LLM Eval](docs/evaluation/local-llm-eval/README.md) | Offline prompt evaluation with Ollama via OMT — multi-model comparison, variance testing |
| [Structured Web Dataset](docs/research/structured-web-dataset/README.md) | Building tabular datasets from NL descriptions — web research mode and synthetic mode |
| [Hooks Reference](docs/hooks/README.md) | Complete hook documentation — event types, purpose, wiring reference |

---

## Design Principles

1. **Phase-gated workflow** — Plan deliberately before coding. Human approval gates prevent skipping phases.
2. **TDD discipline** — Test first, code second, verify third. No exceptions during spec implementation.
3. **Persistent memory** — Context flows from hot (active) to cold (archived). Patterns compound over time.
4. **Automate the tedious** — Doc sync, memory archival, self-review, and harness updates happen automatically.
5. **Portable and reproducible** — Single harness directory, installable to any project, updateable via one command.
6. **Human-in-the-loop** — Every spec phase requires explicit approval. No silent automation of decisions.
7. **Decoupled components** — Specs, steering, memory, skills, and Jira are independent. Use what you need.

---

## Built With

| Component | Source | Role in Harness |
|---|---|---|
| [cc-sdd](https://www.npmjs.com/package/cc-sdd) | npm package | Spec engine foundation — provides the requirements → design → tasks → implement pipeline. We extended it with custom agents, memory, and Jira integration. |
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | GitHub | Autonomous ML experiment loop. Adapted into harness slash commands with interactive setup and persistent memory. |
| [andrewyng/context-hub](https://github.com/andrewyng/context-hub) | GitHub / MCP | LLM-optimized third-party API documentation server. Runs as an MCP server (`@aisuite/chub-mcp`) so Claude Code gets accurate, up-to-date library docs. |
| [CogMem (arXiv:2512.14118)](https://arxiv.org/abs/2512.14118) | Research paper | Cognitive memory architecture for LLMs. Inspired our temperature-tiered memory system (hot/warm/meta/cold) with progressive condensation across tiers. |
| [arXiv:2603.11808](https://arxiv.org/abs/2603.11808) | Research paper | Methodology for skill extraction — 4-criteria scoring rubric for identifying and extracting reusable procedural knowledge from repositories. |
| [uv](https://docs.astral.sh/uv/) | Astral | Fast Python package manager. Required runtime for autoresearch experiments and Python project tooling. |
| [Jira REST API v2](https://developer.atlassian.com/cloud/jira/platform/rest/v2/) | Atlassian | Ticket fetching, comment posting, JQL search. Custom Python client in `scripts/` (stdlib only, no pip deps). |
| [SonarQube](https://www.sonarsource.com/products/sonarqube/) | SonarSource | Security hotspot review integration via the `sonar-hotspot-review` skill. |
| [OpenAI Privacy Filter](https://github.com/openai/privacy-filter) | GitHub | Local ML-based PII detection (1.5B param, 50M active). Identifies 8 categories including secrets, emails, account numbers, addresses. Fully on-premises via CLI (`opf`) or Python API. Apache 2.0. |
| [prompt-master](https://github.com/nidhinjs/prompt-master) | GitHub (nidhinjs) | Active prompt factory for 30+ AI tools. Adapted with JSON prompting mode (Template N), JSON intent detection, and pattern 38. Pre-installed at `~/.claude/skills/prompt-master/`. |
| [Impeccable](https://github.com/pbakaus/impeccable) | GitHub (pbakaus) | Frontend design quality system with 27 deterministic anti-pattern rules + 7-domain design principles. Integrated as a skill, harness rule, and PostToolUse hook. Apache 2.0. |
| [RTK](https://github.com/rtk-ai/rtk) | GitHub (rtk-ai) | Rust Token Killer — CLI proxy that compresses Bash output before it reaches the LLM. 6.6MB Rust binary. Global PreToolUse hook via `rtk hook claude` with native `permissionDecision: "allow"` so rewrites are transparent (no permission dialogs). MIT. |

**Runtime**: Claude Code (CLI)
**Scripts**: Python 3 (standard library only)
**Hooks**: Bash
**Configuration**: JSON + Markdown

---

## License

Private repository. Contact the maintainer for access.

_Last synced: 2026-09-03_
