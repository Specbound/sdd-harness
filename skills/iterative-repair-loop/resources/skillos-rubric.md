# SkillOS Quality Gate — Full Rubric

Source: arXiv:2605.06614

## Four Dimensions

| Dimension | Pass condition | Common fail patterns |
|---|---|---|
| **Task relevance** | Addresses a real, repeated task in this user's context — not hypothetical. Has explicit "When to use" and "When NOT to use" sections. | "This skill handles any general situation..." / no trigger conditions / aspirational scope |
| **Operational validity** | All steps use real Claude Code tools: Bash, Read, Edit, Write, WebFetch, Glob, Grep. No dead references, broken links, or non-existent tool calls. | References to `cat`, `sed` instead of Read/Edit; outdated API paths; `curl` for things WebFetch handles |
| **Content quality** | Clear frontmatter (name, description, risk, source). Named workflow phases. Actionable steps — not narration. User can follow the skill without the original context. | Wall-of-text prose; "think about X" instead of "run `bash cmd`"; no phase structure |
| **Compression** | SKILL.md ≤5,000 words. `description` field ≤200 chars. Verbose reference content (tables, appendices, examples) in `resources/` subdirectory, not inline. | Entire API reference inlined; exhaustive option tables; repeated examples |

## Compression Heuristic

Total skill content (SKILL.md + resources/) should be ≤30% of the context it would take to accomplish the task manually without the skill. A skill that doesn't save proportional context is net-negative.

**Example:** If accomplishing the task manually requires reading 10 files and writing 2,000 words of analysis (≈20k tokens), the skill should cost ≤6k tokens to load and follow.

## Repair Actions by Failing Dimension

| Dimension | Targeted fix |
|---|---|
| Task relevance | Add "When to use" / "When NOT to use" with concrete trigger examples. Narrow scope to tasks that actually recur. |
| Operational validity | Replace `cat`/`sed`/`awk` with Read/Edit. Remove links that 404. Fix tool names to match Claude Code's actual tool list. |
| Content quality | Add named phases (## Phase 1, ## Phase 2...). Convert narration to imperative steps. Add frontmatter if missing. |
| Compression | Move tables and reference lists to `resources/`. Replace inline API docs with a 1-line pointer. Cut examples to 1 representative case. |
