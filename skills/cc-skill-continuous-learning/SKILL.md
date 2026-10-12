---
name: cc-skill-continuous-learning
description: Apply during or after a development session to extract generalizable learnings, update working knowledge, and prevent the same friction from recurring. Triggers on surprising failures, non-obvious solutions, or any task that required 2+ attempts.
author: affaan-m
version: "1.1"
risk: safe
source: community
---

# Continuous Learning

## When to Use

Trigger when:
- A task required 2+ attempts (the second attempt reveals a constraint or gap)
- A tool, API, or framework behaved unexpectedly (error, undocumented limit, schema surprise)
- The user corrected your approach in a way that generalizes beyond the current task
- You discover a project-specific invariant not captured anywhere in docs or code

Do **not** trigger for tasks that went as expected — learning overhead on routine work is waste.

## Extraction Protocol

After a qualifying event:

1. **State the surprise.** What did you expect, and what actually happened? One sentence each.
2. **Name the root cause.** Missing constraint? Wrong assumption? Undocumented behavior?
3. **Write the rule.** One sentence that prevents the same friction next time: "When X, do Y instead of Z."
4. **Check for overlap.** Does this contradict or duplicate an existing memory entry? Update the old one rather than creating a redundant entry.
5. **Classify and save.** Use the right memory type:
   - `feedback` — the user corrected your approach
   - `project` — environment state, tooling constraint, path or API detail
   - `user` — preference or knowledge level shift

## Anti-Patterns

- Saving ephemeral task state ("currently working on feature X") — memory captures patterns, not progress
- Recording something already inferrable by reading the code or documentation
- Creating a new entry when an existing one already covers the lesson — update instead
- Writing a narrative instead of a generalizable rule

## Output

A memory entry (new or updated). No summary text unless the user asked. Test: would a cold-start session benefit from reading this? If not, skip it.
