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
- [AutoResearch (ML Experiments)](#autoresearch-ml-experiments)
- [GitNexus (Code Intelligence)](#gitnexus-code-intelligence)
- [Context Hub (MCP Integration)](#context-hub-mcp-integration)
- [Automation & Hooks](#automation--hooks)
- [Multi-Project Management](#multi-project-management)
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
| **Context Hub** | [andrewyng/context-hub](https://github.com/andrewyng/context-hub) | MCP server providing curated, LLM-optimized docs for third-party libraries |
| **Portable Installation** | Custom | Single `install.sh` bootstraps any project; `update.sh` keeps them all in sync |

---

## Quick Start

### Install into a new project

```bash
~/.claude/sdd-harness/install.sh /path/to/project
# defaults to current directory if no path given
```

This will:
- Create the `.claude/` directory structure with commands, agents, rules, and templates
- Initialize memory files from templates
- Generate `CLAUDE.md` (the project constitution)
- Register the project in `projects.txt`
- Install the git post-commit hook

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
├── generate-project-stack.sh     # Auto-detect project tech stack
├── VERSION                       # Last harness update date (auto-managed)
├── projects.txt                  # Registry of installed projects (gitignored)
│
├── commands/kiro/                # 38 slash commands (user-facing)
│   ├── idea-refine.md            #   Refine vague ideas into spec-ready briefs
│   ├── spec-init.md              #   Initialize a spec workspace
│   ├── spec-requirements.md      #   Generate EARS-format requirements
│   ├── spec-design.md            #   Generate technical design
│   ├── spec-tasks.md             #   Break design into parallelizable tasks
│   ├── spec-quick.md             #   Fast path: requirements → design → tasks
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
│   ├── steering.md               #   Bootstrap/sync project knowledge
│   ├── steering-custom.md        #   Add domain-specific docs (auth, DB, etc.)
│   ├── reflect.md                #   Mine session learnings, update memory
│   ├── learn-eval.md             #   Quality-gated pattern evaluation (save/absorb/drop)
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
│   └── gitnexus-setup-agent.md   #   GitNexus installation and configuration agent
│
├── kiro/settings/                # Spec engine configuration
│   ├── rules/                    #   25 rule files (EARS syntax, design principles,
│   │   │                         #   task generation, gap analysis, memory conventions,
│   │   │                         #   agent tracing, quality gates, loop safety, hook
│   │   │                         #   profiles, model tiering, anti-rationalization,
│   │   │                         #   red flags, context engineering, etc.)
│   └── templates/                #   16 templates across 4 categories:
│       ├── specs/                #     Spec phase templates (init, requirements, design, tasks)
│       ├── steering/             #     Project knowledge templates (product, tech, structure)
│       ├── steering-custom/      #     Domain templates (auth, DB, API, testing, deployment, security)
│       └── memory/               #     Memory file templates (hot, observations, action-items, entities, patterns)
│
├── scripts/                      # Utility scripts (Python, stdlib only)
│   ├── jira_client.py            #   Jira REST API client (PAT + Basic Auth)
│   ├── jira_capture_ticket.py    #   Capture active ticket from session context
│   └── jira_push_comment.py      #   Post implementation summary to Jira
│
├── hooks/                        # Session lifecycle hooks
│   ├── stop-hook.sh              #   On session exit: check for updates, memory health, agent failure patterns
│   └── prompt-hook.sh            #   On prompt submit: inject hot-memory context
│
├── git-hooks/                    # Git lifecycle hooks
│   └── post-commit               #   On commit: doc sync + harness update detection
│
├── templates/                    # Project-level templates
│   ├── CLAUDE.md.template        #   Project constitution (context paths, rules, quality gates)
│   └── settings.json.template    #   Claude Code permissions and hooks config
│
└── docs/                         # Reference documentation
    ├── SDD-USAGE.md              #   Quick command reference with examples
    ├── SDD-SETUP-GUIDE.md        #   Comprehensive setup walkthrough
    ├── kiro/README.md            #   Spec engine deep dive
    ├── memory/README.md          #   Memory architecture guide
    ├── jira/README.md            #   Jira integration setup
    ├── autoresearch/README.md    #   ML experiment loop guide
    ├── gitnexus/README.md        #   Code intelligence + visual explorer guide
    ├── skill-extraction/README.md#   Skill extraction methodology
    └── security/                 #   Security integration docs
        └── sonar-hotspot-review.md
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
/kiro:spec-requirements               # Generate EARS requirements → review → approve
/kiro:spec-design                     # Generate design with codebase research → review → approve
/kiro:spec-tasks                      # Break into parallelizable tasks → review → approve
/kiro:spec-impl <spec-name>           # TDD implementation with auto self-review
```

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
| `/kiro:spec-tasks` | Break design into parallelizable tasks |
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
| `/kiro:steering` | Bootstrap/sync project knowledge docs |
| `/kiro:steering-custom` | Add domain-specific steering (auth, DB, API, etc.) |
| `/kiro:reflect` | Extract session learnings, update memory |
| `/kiro:learn-eval` | Quality-gated pattern evaluation with save/absorb/drop verdicts |
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

For usage examples, see [docs/SDD-USAGE.md](docs/SDD-USAGE.md).

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
- **`learn-eval-agent`** — Evaluates session patterns with quality gates (specificity, actionability, evidence) and deduplicates against existing knowledge
- **`reflect-agent`** — Mines git log for observations, promotes recurring themes to patterns, updates hot-memory
- **`housekeeping-agent`** — Archives observations to cold storage, enforces memory caps
- **`evolve-agent`** — Measures memory health, detects friction patterns, analyzes agent trace logs, proposes rule changes and linter rule graduations
- **`guardrails-agent`** — Audits project linter configs for complexity rules, scaffolds missing guardrails per ecosystem (ESLint, ruff, clippy, golangci-lint)
- **`ci-scaffold-agent`** — Generates CI configurations (GitHub Actions, GitLab CI, Azure Pipelines) mirroring the verify pipeline stages
- **`doc-sync`** — Triggered by post-commit hook; finds and updates stale `.md` files after code changes; detects stale doc-to-code references
- **`harness-updater`** — Triggered when `.claude/` files change; keeps `SDD-SETUP-GUIDE.md` current
- **`harness-validate-agent`** — Checks structural integrity: command→agent references, template existence, memory caps, L0 headers, generates component index
- **`gitnexus-setup-agent`** — Installs GitNexus, indexes the repo, configures MCP server and editor integration
- **`jira-solve-agent`** — Analyzes ticket type and routes to the appropriate workflow

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

Additionally, `generate-project-stack.sh` auto-detects your language, runtime, package manager, dependencies, test commands, and Docker services — producing a `PROJECT_STACK.md` summary.

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

**Setup**: Create `~/.env.jira` with your credentials (PAT or Basic Auth). See [docs/jira/README.md](docs/jira/README.md).

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

See [docs/skill-extraction/README.md](docs/skill-extraction/README.md).

---

## AutoResearch (ML Experiments)

Adapted from [karpathy/autoresearch](https://github.com/karpathy/autoresearch) — Andrej Karpathy's tool for autonomous ML experimentation where an AI agent iterates on training code in a loop, making hypotheses, running experiments, and keeping what works. We adapted this into the harness as slash commands with an interactive setup flow and integration with our memory system so experiment results persist across sessions.

Requires [uv](https://docs.astral.sh/uv/) (Astral's fast Python package manager) for running training scripts.

```
/kiro:autoresearch-init             # Interactive setup (asks about your model, metrics, constraints)
/kiro:autoresearch                   # Run the experiment loop
```

Each iteration: hypothesize → modify code → train (5-minute bounded) → evaluate → keep improvements / revert failures.

See [docs/autoresearch/README.md](docs/autoresearch/README.md).

---

## GitNexus (Code Intelligence)

Integrates [abhigyanpatwari/GitNexus](https://github.com/abhigyanpatwari/GitNexus) — a zero-server code intelligence engine that builds a knowledge graph from your codebase (symbols, dependencies, call chains, execution flows) and exposes it via MCP tools. The integration is **opt-in**: when GitNexus is present, harness agents gain graph-backed context; when absent, everything works as before.

Three capabilities:

1. **Impact detection** — `verify-agent` gains an optional Stage 0 that maps git diffs to affected processes with risk levels before running build/test/lint
2. **Community-seeded skill extraction** — `skill-extract-agent` can use Leiden-detected functional clusters as extraction candidates instead of pure grep scanning
3. **Visual exploration** — `/kiro:gitnexus-explore` launches a browser-based WebGL graph to browse symbols, call chains, and process flows

```
/kiro:gitnexus-setup              # Install, index, configure MCP (one-time)
/kiro:gitnexus-explore            # Launch visual Web UI
/kiro:gitnexus-impact             # Query blast radius for current changes
```

Setup can also be done during harness installation:
```
~/.claude/sdd-harness/install.sh /path/to/project --with-gitnexus
```

See [docs/gitnexus/README.md](docs/gitnexus/README.md).

---

## Context Hub (MCP Integration)

Integrates [andrewyng/context-hub](https://github.com/andrewyng/context-hub) — Andrew Ng's MCP server that provides curated, LLM-optimized documentation for third-party libraries and APIs (OpenAI, Stripe, Anthropic, etc.). Instead of Claude hallucinating API signatures or working from stale training data, Context Hub serves up-to-date, verified documentation on demand.

Runs as an MCP server via `npx -y @aisuite/chub-mcp` and is configured in the project's `.claude/settings.json`. Exposes tools like `chub_search`, `chub_get`, and `chub_list` that Claude Code can call during any workflow.

See the Context Hub section in [docs/SDD-SETUP-GUIDE.md](docs/SDD-SETUP-GUIDE.md) for configuration.

---

## Automation & Hooks

### Context Priming Hook (`hooks/prompt-hook.sh`)

Runs before every user prompt (UserPromptSubmit). Injects the contents of `hot-memory.md` into context so the agent always has current priorities, active specs, and recent decisions.

### Session Exit Hook (`hooks/stop-hook.sh`)

Runs when a Claude Code session ends. Checks for:
- Harness updates available (prompts to run `update.sh`)
- Memory health (warns if observations exceed cap)
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

### Git Post-Commit Hook (`git-hooks/post-commit`)

Runs after every commit. Triggers two background processes:
1. **Doc Sync** — If non-`.md` files changed, finds and updates affected documentation
2. **Harness Updater** — If `.claude/` files changed, updates `SDD-SETUP-GUIDE.md`

---

## Multi-Project Management

The harness is installed once at `~/.claude/sdd-harness/` and shared across all your projects.

### Register projects

Projects are automatically registered in `projects.txt` when you run `install.sh`. One absolute path per line.

### Update all projects

```bash
~/.claude/sdd-harness/update.sh
```

Updates commands, agents, rules, templates, scripts, and docs in every registered project. Also regenerates `PROJECT_STACK.md` for each.

### Update a single project

```bash
~/.claude/sdd-harness/update.sh /path/to/project
```

### Sync across machines

```bash
cd ~/.claude/sdd-harness
git remote add origin git@github.com:<you>/sdd-harness.git
git push -u origin main
```

`projects.txt` and `VERSION` are gitignored — they contain machine-local state.

---

## Documentation Index

| Document | Description |
|---|---|
| [SDD-USAGE.md](docs/SDD-USAGE.md) | Quick command reference with examples |
| [SDD-SETUP-GUIDE.md](docs/SDD-SETUP-GUIDE.md) | Comprehensive setup and configuration walkthrough |
| [Kiro Engine](docs/kiro/README.md) | Spec engine components, rules, and templates |
| [Memory Architecture](docs/memory/README.md) | Temperature-tiered memory system guide |
| [Jira Integration](docs/jira/README.md) | Jira setup, credentials, and troubleshooting |
| [AutoResearch](docs/autoresearch/README.md) | ML experiment loop methodology |
| [GitNexus](docs/gitnexus/README.md) | Code intelligence, visual explorer, and blast radius analysis |
| [Skill Extraction](docs/skill-extraction/README.md) | Skill extraction pipeline and scoring |
| [Sonar Integration](docs/security/sonar-hotspot-review.md) | SonarQube security hotspot review |

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

**Runtime**: Claude Code (CLI)
**Scripts**: Python 3 (standard library only)
**Hooks**: Bash
**Configuration**: JSON + Markdown

---

## License

Private repository. Contact the maintainer for access.
