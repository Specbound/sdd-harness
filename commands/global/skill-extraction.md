---
description: Analyze an external resource (link, repo, doc, tool) and extract relevant capabilities into the harness as skills, hooks, scripts, commands, routines, or config changes
allowed-tools: Read, Write, Edit, Bash, WebFetch, WebSearch, Glob, Grep
argument-hint: <url-or-repo-or-local-path>
---

# Skill Extraction

Analyze the provided resource and integrate its capabilities into the harness with user approval at every step.

## Input Parsing

Parse `$ARGUMENTS`:
- If empty, show usage:
  ```
  Usage: /skill-extraction <url-or-repo-or-local-path>

  Examples:
    /skill-extraction https://github.com/org/repo
    /skill-extraction https://example.com/docs/some-tool
    /skill-extraction /path/to/local/tool
  ```
- Otherwise, treat the argument as the resource to analyze.

## Invoke the Skill

Load and follow the `skill-extraction` skill:

```
Skill("skill-extraction")
```

Pass the resource from `$ARGUMENTS` as the source for Phase 1 (Fetch & Understand the Resource).

Proceed through all phases of the skill — fetch, harness audit, gap analysis, proposal, and implementation — as described in the skill.
