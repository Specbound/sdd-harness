---
name: cc-skill-strategic-compact
description: Use when a response would otherwise run long but the user needs only the actionable core — status updates, command output summaries, or narrow factual answers. Skip for open-ended design discussion or when the user asked for detail.
author: affaan-m
version: "1.0"
risk: safe
source: community
---

# Strategic Compact

## When to Use
Trigger when the natural response length exceeds what the question needs: a yes/no with one supporting fact, a status check, a short factual lookup. Do not apply to design discussions, multi-step plans, or anything the user explicitly asked to see in detail.

## Format Rules
- Maximum 5 bullet points, or 100 words of running text — whichever is shorter.
- Lead with the answer or result, not the setup.
- Do not restate information already visible in the conversation (file contents just read, command output just shown).
- Skip the format entirely when a single sentence answers the question — compact formatting is still overhead when one line suffices.

## Anti-patterns
- Padding a short answer with hedges ("I think", "it seems") to reach a paragraph.
- Repeating the user's question back before answering.
- Applying this to a request that explicitly asked for a walkthrough or comparison.
