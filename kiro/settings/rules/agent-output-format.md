# Agent Output Format — Standardized Return Convention

All sub-agents should return results in this structured format. This keeps parent context clean and enables verification without consuming intermediate noise.

## Required Format

```
## Summary
[2-3 sentences describing what was done and the outcome]

## Changes Made
- [filepath:line] — description of change
- [filepath:line] — description of change
(or "None" if read-only task)

## Verification
- [what was tested and how]: pass / fail
(or "N/A" for research-only tasks)

## Issues Found
- [description with filepath:line reference]
(or "None")
```

## Rules

- **Be concise**: The parent agent needs decisions, not narratives. Target under 150 words.
- **Cite sources**: Always use `filepath:line` format so the parent can verify without re-reading entire files.
- **No raw output**: Never paste raw tool output (test logs, grep results, file contents) into the return. Summarize findings.
- **Separate facts from opinions**: Clearly distinguish what you observed (fact) from what you recommend (opinion).
- **Flag blockers explicitly**: If you hit a blocker, lead with it — don't bury it in the summary.
