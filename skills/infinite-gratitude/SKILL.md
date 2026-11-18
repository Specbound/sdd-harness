---
name: infinite-gratitude
description: Use when a research question is wide enough to split into independent angles that can run in parallel — competitor benchmarks, tool/library comparisons, literature reviews, market or due-diligence research. Installs and runs the external `/infinite-gratitude` multi-agent research command (5-10 dispatched agents per wave).
risk: safe
source: https://github.com/sstklen/infinite-gratitude
---

# Infinite Gratitude

## When to Use

Trigger when a research question decomposes into N independent angles that don't depend on each other's findings — e.g. "compare these 6 vector DBs," "survey the last 3 years of papers on X," "map every competitor's pricing model." Each angle becomes one dispatched agent's job.

Do **not** use for a question with a single linear investigation path, or where each step depends on the previous step's result — parallel dispatch adds coordination overhead with no speedup there.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sstklen/infinite-gratitude/main/install.sh | bash
# installs the skill file into ~/.claude/skills/
```
Verify the install script URL against the repo's own README before running — this is a third-party curl-to-shell install, not a package-manager-verified one.

## Run

```
/infinite-gratitude "your research topic"
/infinite-gratitude "your research topic" --agents 10 --depth deep --waves 5
```

- `--agents N` (1–10, default 5) — how many angles get a dispatched agent this wave
- `--depth quick|normal|deep` — per-agent research thoroughness
- `--waves N` (default 3) — how many dispatch-report-refine cycles to run; after each wave you can direct a follow-up wave at a specific finding ("go deeper on X") instead of re-running the default split

## Workflow

1. State the topic and let the tool propose its angle split (or supply your own N angles if the topic has an obvious natural decomposition)
2. First wave dispatches — each agent investigates one angle independently and returns its own report
3. Read the per-agent reports; if one surfaces something worth chasing further, direct the next wave at it by name rather than re-running the same split
4. Repeat for `--waves` cycles or until the reports converge / stop surfacing new information
5. Synthesize the wave reports yourself — the tool returns per-agent findings, not one merged summary

## Anti-Patterns

- Running with the default `--agents 5` on a topic with only 2-3 real independent angles — idle agents produce redundant or padded reports
- Treating wave 1's output as final — the tool's own design assumes at least one "go deeper" follow-up wave on whatever wave 1 surfaces
- Using this for a question that isn't actually parallelizable — see When to Use above; a single-threaded research task will be slower here, not faster, because of per-agent report reconciliation overhead
