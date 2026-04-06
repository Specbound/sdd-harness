# Kiro — Spec-Driven Development Engine

> Detailed reference for the Kiro SDD subsystem within the harness.

## What It Is

Kiro is the core spec-driven development (SDD) engine. It provides a structured, phase-gated workflow for turning feature descriptions into implemented, tested code — with human review gates between every phase.

The workflow enforces: **Requirements → Design → Tasks → Implementation**, each phase producing a concrete artifact that the next phase consumes.

## Origin

Based on [cc-sdd](https://www.npmjs.com/package/cc-sdd) (`npx cc-sdd@latest`), adapted with custom path remapping and additional agents (doc-sync, harness-updater, reflect, housekeeping, evolve).

## Components

### Slash Commands (`commands/kiro/`)

| Command | Phase | Description |
|---|---|---|
| `steering` | Setup | Bootstrap/refresh project memory from codebase scan |
| `steering-custom` | Setup | Add domain-specific steering (auth, DB, API, etc.) |
| `spec-init` | 1. Init | Create spec workspace in `specs/` with metadata |
| `spec-requirements` | 2. Requirements | Generate EARS-format requirements |
| `spec-design` | 3. Design | Research codebase + produce technical design |
| `spec-tasks` | 4. Tasks | Break design into parallelizable task list |
| `spec-impl` | 5. Implement | TDD implementation with self-review after each task |
| `spec-quick` | 2-4 (fast) | Requirements → Design → Tasks in one command |
| `spec-status` | Any | Show current phase, approvals, open tasks |
| `validate-gap` | Review | Requirements vs. existing code gap analysis |
| `validate-design` | Review | Design quality review (with remediation on NO-GO) |
| `validate-impl` | Review | Implementation vs. spec validation (with remediation) |
| `validate-adversarial` | Review | Three-pass adversarial review with +1/-2 scoring |
| `sync-docs` | Maintenance | Sync `.md` files with code changes |
| `reflect` | Memory | Mine session learnings, update observations/patterns |
| `housekeeping` | Memory | Prune memory, archive old observations |
| `evolve` | Meta | Audit harness rules, propose improvements |
| `harness-fix` | Meta | Encode behavioral prevention rule from a specific mistake |
| `harness-validate` | Meta | Structural integrity check of the harness |
| `harness-test` | Meta | Haiku smoke-test to expose vague prompts |
| `guardrails` | Meta | Audit/scaffold linter complexity rules for deterministic enforcement |
| `ci-scaffold` | Meta | Generate CI configuration mirroring the verify pipeline |

### Subagents (`agents/kiro/`)

Each command delegates to a specialized subagent. Agents are autonomous — they receive a prompt with file patterns, execute their protocol, and return a summary.

Key agents beyond the spec pipeline:
- **doc-sync** — Triggered by post-commit hook or `/kiro:sync-docs`. Diffs recent commits against `.md` files, updates stale docs, and detects stale doc-to-code references (reverse validation).
- **harness-updater** — Triggered by post-commit hook when `.claude/` files change. Updates `SDD-SETUP-GUIDE.md`.
- **reflect-agent** — Mines `git log` for observations, promotes patterns, updates hot-memory.
- **housekeeping-agent** — Archives observations to glacier, enforces memory caps.
- **evolve-agent** — Measures memory health metrics, analyzes agent trace logs, detects friction patterns, proposes rule changes and linter rule graduations.
- **guardrails-agent** — Audits project linter configs for complexity rules; scaffolds missing guardrails per ecosystem (ESLint, ruff, clippy, golangci-lint).
- **ci-scaffold-agent** — Generates CI configs (GitHub Actions, GitLab CI, Azure Pipelines) mirroring the verify pipeline stages.
- **validate-adversarial** — Three-pass adversarial review (neutral → refutation → judge synthesis with +1/-2 scoring).
- **harness-validate-agent** — Checks structural integrity: command→agent references, template existence, memory caps, L0 headers. Generates component relationship index.
- **spec-refactor** — Auto-spawned after each impl task's VERIFY step. Reviews touched files for reuse/quality/efficiency.

### Rules (`kiro/settings/rules/`)

Rules control agent behavior:
- `ears-format.md` — EARS requirement syntax
- `design-principles.md` — Design doc structure and quality criteria
- `design-discovery-light.md` / `design-discovery-full.md` — Codebase research depth
- `design-review.md` — Review checklist for designs
- `tasks-generation.md` — Task breakdown rules
- `tasks-parallel-analysis.md` — Parallelism detection (P-wave)
- `gap-analysis.md` — Gap analysis methodology
- `steering-principles.md` — Steering doc conventions (with L0 header requirement)
- `memory-conventions.md` — Memory format, caps, and lifecycle rules
- `agent-output-format.md` — Standardized agent return format with output recovery tiers
- `agent-tracing.md` — Invocation trace log for observability
- `test-backlinks.md` — Spec traceability convention in test files
- `model-tiering.md` — Cost optimization tiers (Opus/Sonnet/Haiku) with smoke testing
- `context-hygiene.md` — Context rot prevention with degradation detection
- `skill-extraction-scoring.md` — 4-criteria rubric for skill extraction
- `deterministic-enforcement.md` — Prefer linters over documentation for enforceable conventions
- `property-testing.md` — When and how to use property-based tests in TDD
- `self-tightening.md` — Self-improving feedback loop formalization (L0-L3 maturity)

### Templates (`kiro/settings/templates/`)

Starting-point files for specs, steering docs, and memory files. Used by `spec-init`, `steering`, and `reflect` to bootstrap new artifacts.

## Use Cases

1. **New feature development** — Full SDD pipeline from idea to implementation
2. **Brownfield features** — Use `validate-gap` to assess existing code before spec'ing the delta
3. **Bug fixes** — Use `spec-quick` for a lightweight spec, then `spec-impl` for TDD
4. **Codebase onboarding** — Run `steering` to generate project knowledge docs
5. **Quality audits** — Run `validate-impl` against existing specs to find drift

## How to Use

### Full workflow (large features)
```
/kiro:steering                          # once per project
/kiro:spec-init "Add feature X"        # create spec workspace
/kiro:spec-requirements feature-x       # generate requirements (review + approve)
/kiro:spec-design feature-x             # generate design (review + approve)
/kiro:spec-tasks feature-x              # generate tasks (review + approve)
/kiro:spec-impl feature-x              # implement via TDD
/kiro:reflect                           # capture session learnings
```

### Fast path (small features / bug fixes)
```
/kiro:spec-quick "Fix the broken auth redirect"
/kiro:spec-impl fix-auth-redirect
```

### Maintenance
```
/kiro:sync-docs                         # manual doc sync
/kiro:housekeeping                      # prune memory
/kiro:evolve                            # audit harness effectiveness
```

## Setup

Installed via `npx cc-sdd@latest --claude-agent --lang en`, then path-remapped with `scripts/remap-ccsdd-paths.sh`. See `SDD-SETUP-GUIDE.md` Steps 3–4 for details.
