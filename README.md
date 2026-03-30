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
- [Memory System](#memory-system)
- [Steering (Project Knowledge)](#steering-project-knowledge)
- [Jira Integration](#jira-integration)
- [Skill Extraction](#skill-extraction)
- [AutoResearch (ML Experiments)](#autoresearch-ml-experiments)
- [Automation & Hooks](#automation--hooks)
- [Multi-Project Management](#multi-project-management)
- [Documentation Index](#documentation-index)
- [Design Principles](#design-principles)

---

## What It Does

| Capability | Description |
|---|---|
| **Spec-Driven Development** | Requirements → Design → Tasks → TDD Implementation, with human approval gates between every phase |
| **Cross-Session Memory** | Temperature-tiered memory (hot/warm/meta/cold) that persists context across Claude Code sessions |
| **Project Steering** | Auto-generated architecture, tech stack, and structure docs that ground every conversation |
| **Doc Sync** | Automatically updates `.md` files when code changes on every git commit |
| **Jira Integration** | Fetch tickets, route to the right workflow (bug/feature/task), auto-comment on push |
| **Skill Extraction** | Analyze repos and extract reusable `SKILL.md` files for Claude Code |
| **AutoResearch** | Autonomous ML experiment loop with hypothesis-driven iteration |
| **Portable Installation** | Single `install.sh` bootstraps any project; `update.sh` keeps them all in sync |

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
├── commands/kiro/                # 21 slash commands (user-facing)
│   ├── spec-init.md              #   Initialize a spec workspace
│   ├── spec-requirements.md      #   Generate EARS-format requirements
│   ├── spec-design.md            #   Generate technical design
│   ├── spec-tasks.md             #   Break design into parallelizable tasks
│   ├── spec-quick.md             #   Fast path: requirements → design → tasks
│   ├── spec-impl.md              #   TDD implementation of tasks
│   ├── spec-status.md            #   Check spec phase and progress
│   ├── validate-gap.md           #   Requirements vs. code gap analysis
│   ├── validate-design.md        #   Design quality review
│   ├── validate-impl.md          #   Implementation vs. spec validation
│   ├── steering.md               #   Bootstrap/sync project knowledge
│   ├── steering-custom.md        #   Add domain-specific docs (auth, DB, etc.)
│   ├── reflect.md                #   Mine session learnings, update memory
│   ├── housekeeping.md           #   Prune memory, enforce caps
│   ├── evolve.md                 #   Audit harness rules, propose improvements
│   ├── sync-docs.md              #   Sync .md files with code changes
│   ├── jira-solve.md             #   Fetch and route Jira tickets
│   ├── skill-extract-scan.md     #   Analyze repo for extractable skills
│   ├── skill-extract.md          #   Generate SKILL.md files
│   ├── autoresearch-init.md      #   Interactive ML research setup
│   └── autoresearch.md           #   Run autonomous experiment loop
│
├── agents/kiro/                  # 19 subagents (autonomous workers)
│   ├── spec-requirements.md      #   Requirements generation agent
│   ├── spec-design.md            #   Design generation agent
│   ├── spec-tasks.md             #   Task breakdown agent
│   ├── spec-impl.md              #   TDD implementation agent
│   ├── spec-refactor.md          #   Post-task code review agent
│   ├── steering.md               #   Steering file generation agent
│   ├── steering-custom.md        #   Custom steering agent
│   ├── validate-gap.md           #   Gap analysis agent
│   ├── validate-design.md        #   Design review agent
│   ├── validate-impl.md          #   Implementation review agent
│   ├── reflect-agent.md          #   Session learning extraction agent
│   ├── housekeeping-agent.md     #   Memory pruning agent
│   ├── evolve-agent.md           #   Harness improvement agent
│   ├── doc-sync.md               #   Automatic doc update agent
│   ├── harness-updater.md        #   Harness self-update agent
│   ├── jira-solve-agent.md       #   Jira ticket analysis agent
│   ├── skill-extract-agent.md    #   Skill extraction agent
│   ├── autoresearch-agent.md     #   ML experiment loop agent
│   └── autoresearch-init-agent.md#   ML research setup agent
│
├── kiro/settings/                # Spec engine configuration
│   ├── rules/                    #   11 rule files (EARS syntax, design
│   │   │                         #   principles, task generation, gap
│   │   │                         #   analysis, memory conventions, etc.)
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
│   └── stop-hook.sh              #   On session exit: check for updates, memory health
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
    ├── skill-extraction/README.md#   Skill extraction methodology
    └── security/                 #   Security integration docs
        └── sonar-hotspot-review.md
```

---

## The SDD Workflow

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
/kiro:validate-design                 # Is the design sound?
/kiro:validate-impl                   # Does the code match the spec?
```

---

## Commands Reference

| Command | Purpose |
|---|---|
| `/kiro:spec-init` | Initialize a new spec workspace |
| `/kiro:spec-requirements` | Generate EARS-format requirements |
| `/kiro:spec-design` | Generate technical design with codebase research |
| `/kiro:spec-tasks` | Break design into parallelizable tasks |
| `/kiro:spec-quick` | Fast path: all spec phases in one command |
| `/kiro:spec-impl` | TDD implementation with automatic self-review |
| `/kiro:spec-status` | Check current spec phase and progress |
| `/kiro:validate-gap` | Requirements vs. existing code gap analysis |
| `/kiro:validate-design` | Design quality and completeness review |
| `/kiro:validate-impl` | Implementation vs. spec validation |
| `/kiro:steering` | Bootstrap/sync project knowledge docs |
| `/kiro:steering-custom` | Add domain-specific steering (auth, DB, API, etc.) |
| `/kiro:reflect` | Extract session learnings, update memory |
| `/kiro:housekeeping` | Prune memory, archive old observations |
| `/kiro:evolve` | Audit harness rules, detect friction, propose improvements |
| `/kiro:sync-docs` | Sync `.md` files with code changes |
| `/kiro:jira-solve` | Fetch Jira ticket and route to correct workflow |
| `/kiro:skill-extract-scan` | Analyze repo for extractable skills |
| `/kiro:skill-extract` | Generate `SKILL.md` files from scored plan |
| `/kiro:autoresearch-init` | Interactive setup for ML research projects |
| `/kiro:autoresearch` | Run autonomous ML experiment loop |

For usage examples, see [docs/SDD-USAGE.md](docs/SDD-USAGE.md).

---

## Agents

Each command delegates to one or more autonomous subagents. Agents receive a prompt, execute their protocol, and return structured output. Key agents:

- **Spec pipeline agents** — Handle requirements, design, tasks, and implementation phases
- **`spec-refactor`** — Auto-spawned after each implementation task to review touched files for reuse, quality, and efficiency
- **`reflect-agent`** — Mines git log for observations, promotes recurring themes to patterns, updates hot-memory
- **`housekeeping-agent`** — Archives observations to cold storage, enforces memory caps
- **`evolve-agent`** — Measures memory health, detects friction patterns, proposes rule changes
- **`doc-sync`** — Triggered by post-commit hook; finds and updates stale `.md` files after code changes
- **`harness-updater`** — Triggered when `.claude/` files change; keeps `SDD-SETUP-GUIDE.md` current
- **`jira-solve-agent`** — Analyzes ticket type and routes to the appropriate workflow

---

## Memory System

A temperature-tiered memory architecture that persists context across Claude Code sessions:

| Tier | File | Purpose | Cap |
|---|---|---|---|
| **Hot** | `hot-memory.md` | Current priorities, active specs, recent decisions | 50 lines |
| **Warm** | `observations.md` | Append-only session log with tagged entries | 50 entries |
| **Warm** | `action-items.md` | Cross-session TODOs with due dates | — |
| **Warm** | `entities.md` | Project entity registry (services, APIs, DBs) | — |
| **Meta** | `meta/patterns.md` | Distilled workflow rules (loaded at session start) | 70 lines |
| **Meta** | `meta/self-observations.md` | SDD workflow learnings | — |
| **Cold** | `glacier/` | Archived observations (unlimited) | — |

**Lifecycle**: Observations flow from warm → cold via `/kiro:housekeeping`. Recurring themes get promoted to patterns. Hot memory is always loaded at session start.

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
- **Bug** → Direct fix with test coverage
- **Feature** → Full SDD spec pipeline (requirements → design → tasks → implement)
- **Task** → Implementation plan and execution

On `git push`, an auto-comment is posted to the ticket with a summary of changes (single-fire, no duplicates).

**Setup**: Create `~/.env.jira` with your credentials (PAT or Basic Auth). See [docs/jira/README.md](docs/jira/README.md).

---

## Skill Extraction

Extract reusable patterns from any repository into standardized `SKILL.md` files:

```
/kiro:skill-extract-scan            # Analyze repo, score modules, produce plan
/kiro:skill-extract                  # Generate SKILL.md files from approved plan
```

**3-stage pipeline**:
1. **Structural analysis** — Map repo architecture and module boundaries
2. **Semantic scoring** — Score against recurrence, code quality, expertise, and generalizability
3. **SKILL.md generation** — Produce standalone skill files for `~/.claude/skills/`

See [docs/skill-extraction/README.md](docs/skill-extraction/README.md).

---

## AutoResearch (ML Experiments)

An autonomous experiment loop for ML training code, inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch):

```
/kiro:autoresearch-init             # Interactive setup (asks about your model, metrics, constraints)
/kiro:autoresearch                   # Run the experiment loop
```

Each iteration: hypothesize → modify code → train (5-minute bounded) → evaluate → keep improvements / revert failures.

See [docs/autoresearch/README.md](docs/autoresearch/README.md).

---

## Automation & Hooks

### Session Exit Hook (`hooks/stop-hook.sh`)

Runs when a Claude Code session ends. Checks for:
- Harness updates available (prompts to run `update.sh`)
- Memory health (warns if observations exceed cap)

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

## Tech Stack

- **Runtime**: Claude Code (CLI)
- **Spec Engine**: Based on [cc-sdd](https://www.npmjs.com/package/cc-sdd) with custom extensions
- **Scripts**: Python 3 (standard library only — no pip install required)
- **Hooks**: Bash
- **Configuration**: JSON + Markdown

---

## License

Private repository. Contact the maintainer for access.
