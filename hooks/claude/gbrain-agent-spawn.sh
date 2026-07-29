#!/bin/bash
# Fires PreToolUse (Agent) — injects model-tier and background-routing guidance
# before every subagent spawn so the right model and run mode are chosen.

# Deterministic handoff snapshot of the MAIN session's state, taken before the
# subagent spawns. Hooks can't inject content into the Agent tool's own prompt
# param, so this is the honest mechanism: snapshot to disk + nudge below.
python3 .claude/scripts/session/write_handoff.py --trigger agent-spawn 2>/dev/null || true

cat << 'RULES'
╔══ GBrain Agent Protocols ══════════════════════════════════════════╗
║  You are about to spawn an agent. Apply these protocols first.    ║
╚═══════════════════════════════════════════════════════════════════╝

MODEL TIERS — match model to task:
  haiku   (claude-haiku-4-5-20251001) — classification, validation, expansion, dedup
  sonnet  (claude-sonnet-4-6)         — generation, synthesis, tool loops [DEFAULT]
  opus    (claude-opus-4-7)           — deep reasoning, high-stakes judgment only
  ↳ Subagents: use SONNET not opus — latency compounds in loops; opus buys little here.
  ↳ When in doubt: sonnet. Upgrade to opus only after sonnet demonstrably fails.

BACKGROUND ROUTING — inline unless a pain signal fires:
  ✗ Gateway restarted mid-task  → switch to background
  ✗ Agent dropped state         → switch to background
  ✗ Parallel agents > 3         → switch to background
  ✗ Expected runtime > 5 min    → switch to background
  ✗ User expresses frustration  → offer the switch explicitly
  ↳ Zero signals = stay inline.  Offer background; don't switch silently.

MEMORY FIRST — brief the agent with what's already known:
  Run mcp__plugin_claude-mem_mcp-search__search before writing the prompt.
  Include relevant memory findings in the agent brief.
  An agent that re-discovers known context wastes tokens and may contradict decisions.

SESSION HANDOFF — a fresh snapshot of this session's state was just written to
  .claude/memory/handoff/latest.md. For a background, long-running, or parallel
  agent, pull the relevant parts into its prompt instead of re-deriving them.
RULES
