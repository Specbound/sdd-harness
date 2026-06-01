#!/usr/bin/env bash
# Context Priming Hook — reads hot-memory summary before each prompt
# Runs on UserPromptSubmit to ensure the agent always has current context
# Must be fast (<1s) since it fires on every prompt

HOT_MEMORY=".claude/memory/hot-memory.md"

if [ -f "$HOT_MEMORY" ]; then
  LINE_COUNT=$(wc -l < "$HOT_MEMORY")
  if [ "$LINE_COUNT" -gt 0 ]; then
    echo "--- Active Context (hot-memory) ---"
    cat "$HOT_MEMORY"
    echo "--- End Active Context ---"
  fi
fi
