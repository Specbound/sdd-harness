# Model Tiering — Cost Optimization for Sub-Agents

Use expensive models (Opus) for orchestration and decision-making. Use cheaper models (Sonnet/Haiku) for mechanical, research, and scanning work. This can reduce cost significantly without quality loss.

## Tier 1: Opus (decision-heavy, design judgment)
These agents make architectural decisions or evaluate quality:
- `spec-design` — architectural decisions
- `spec-refactor` — code quality evaluation (skeptical evaluator)
- `evolve-agent` — harness rule design
- `spec-requirements` — requirement analysis

## Tier 2: Sonnet (structured execution, moderate judgment)
These agents follow clear protocols with some judgment:
- `spec-impl` — TDD execution (protocol-driven)
- `spec-tasks` — task breakdown from design
- `validate-gap` — gap analysis (structured comparison)
- `validate-design` — design checklist review
- `validate-impl` — implementation vs spec comparison
- `jira-solve-agent` — ticket classification and routing
- `harness-fix-agent` — rule encoding from mistake description
- `skill-extract-agent` — scoring and extraction

## Tier 3: Haiku (mechanical, scanning, low-judgment)
These agents do mostly mechanical work:
- `steering` — codebase scanning and summarization
- `steering-custom` — document generation from templates
- `doc-sync` — diffing code changes against docs
- `housekeeping-agent` — archival and pruning
- `reflect-agent` — log mining and pattern extraction
- `autoresearch-agent` — experiment loop execution
- `harness-updater` — file copying and sync

## How to Apply

When spawning a sub-agent via the Agent tool, set the `model` parameter:
- Tier 1: omit (inherits parent Opus)
- Tier 2: `model: "sonnet"`
- Tier 3: `model: "haiku"`

This is guidance, not enforcement. If a Tier 3 agent produces poor results, promote it to Tier 2.
