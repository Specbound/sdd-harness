# Context Hygiene — Preventing Context Rot

Context rot describes how model reasoning quality degrades as the context window fills with noise. These rules mitigate it.

## Success Silent, Failure Loud

- When running tests, linters, or builds: capture output to a temp file
- Check the exit code only — if success, report "pass" without reading the file
- Only read the output file when the exit code indicates failure
- Never paste passing test suites, successful lint output, or clean build logs into context

## Offload Large Outputs

- If a tool returns more than ~200 lines, write it to a file and read a summary instead
- Prefer targeted file reads (specific line ranges) over reading entire large files
- When searching, use specific patterns — avoid broad searches that return hundreds of matches

## Use Sub-Agents for Exploration

- Spawn sub-agents for exploratory work (codebase scanning, research, pattern discovery)
- Sub-agents isolate noisy intermediate results in their own context window
- Only the condensed result returns to the parent — keeping the parent context clean

## Checkpoint Long Sessions

- After completing each spec task, write a brief progress summary to the spec's `tasks.md`
- Before starting complex work, note the current state so it can be recovered if context is compacted
- If you notice reasoning quality degrading, proactively checkpoint to filesystem and suggest continuing in a fresh session
