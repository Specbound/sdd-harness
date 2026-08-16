---
name: rtk-token-reduction
description: RTK advanced usage NOT covered by the always-loaded ~/.claude/RTK.md — when to bypass with rtk proxy, configuring exclusions, tee mode, and --ultra-compact. Use when compressed output hides needed detail or a command needs an exclusion.
risk: safe
source: https://github.com/rtk-ai/rtk
---

# RTK — Advanced Usage

`~/.claude/RTK.md` (always loaded) covers the meta commands (`rtk gain`, `rtk discover`, `rtk proxy`, install checks) and the hook that transparently rewrites Bash calls. This skill covers only what it doesn't: bypass decisions, configuration, and extra compression.

## When to bypass with `rtk proxy <cmd>`

Only when exact raw output is required:
- Piping to another tool that parses stdout: `rtk proxy git log --format="%H" | head -5`
- Debugging a hook/script that reads exact output
- Verbatim before/after output comparison
- Compression is dropping detail you need right now (one-off; return to compressed defaults after)

Never bypass just to avoid RTK — if compression keeps losing needed detail for a command, add an exclusion instead (below).

## Configuration and exclusions

Config: `~/Library/Application Support/rtk/config.toml` (macOS). Show/create with `rtk config`.

```toml
[hooks]
exclude_commands = ["curl", "playwright"]  # exact prefix match, never rewritten

[tee]
enabled = true
mode = "failures"   # save raw outputs: "failures" | "always" | "never"
```

Add an exclusion when RTK misidentifies a command or a script needs exact output every time.

## Extra compression

`--ultra-compact` on any rtk command (ASCII icons, inline format) — for very long test suites or near context limits:

```bash
rtk --ultra-compact pytest tests/
```

## Preview a rewrite

```bash
rtk hook check <cmd>   # shows how the hook would rewrite the command
```

## Structural index before Grep/Glob

For an unfamiliar area of the codebase, prefer a structural/AST-aware index (Serena, Glean, Claude Context, Repomix) as the first navigation step — one-shot map vs. brute-force Grep/Glob (like flipping through a phone book blind). Fall back to Grep/Glob for exact-string search once you already know roughly where to look. (Source: tech.autoscout24.com/blog/posts/3-techniques-to-reduce-token-consumption-claude-code-codex/)

## Subagent token caps

For a bounded, well-scoped subtask, cap the subagent's reply length, right-size the model (e.g. `haiku` for narrow tasks), and restrict its tool allowlist — don't let it run on full default budget. Track cache-hit ratio and cost-per-task, not intuition, to confirm a technique is actually saving tokens.

### Sizing the cap: TALE-EP (estimate, then constrain)

A fixed cap is a guess — too tight and the model blows through it anyway (reverts to long-form reasoning when it can't fit, sometimes producing *more* output than an unconstrained call would have), too loose and it wastes nothing. TALE-EP (Token-Budget-Aware LLM rEasoning, estimation variant) fixes this with a two-phase pattern instead of a hand-picked number:

1. **Estimate:** ask the model, zero-shot, for the minimum tokens it thinks the task needs.
2. **Constrain:** feed that estimate back in as the explicit budget for the actual task.

Reported result across seven benchmark datasets on GPT-4o-mini: ~67% average output-token reduction with under 3% accuracy drop — on one benchmark (GSM8K) accuracy *improved* (81.35% → 84.46%) as output fell from 318 to 77 tokens, likely because a tight budget suppresses overthinking on problems that didn't need it. (Source: [arxiv.org/html/2412.18547v5](https://arxiv.org/html/2412.18547v5), via [Redis: token-budget-aware LLM reasoning](https://redis.io/blog/token-budget-aware-llm-reasoning/).)

**Caveat — task type matters more than the model:** the Chain-of-Draft finding (capping each reasoning step to ≤5 words) shows compression is not uniformly safe. On commonsense/symbolic tasks it lost nothing (Claude 3.5 Sonnet: 190→14 tokens, accuracy 93.2%→97.3%). On arithmetic (GSM8K) both GPT-4o and Claude 3.5 Sonnet traded ~4 accuracy points for an 80% token cut. **Don't apply a tight budget uniformly** — arithmetic/multi-step-math subtasks need more room than commonsense/lookup subtasks of similar apparent size.

Claude's own newer models don't take a raw token-count budget parameter (`budget_tokens` 400s on Opus 4.7+ — thinking is adaptive/model-controlled there); use the `effort` parameter and the advisory task budget instead — see `model-tiers`' "Effort Level" section.
