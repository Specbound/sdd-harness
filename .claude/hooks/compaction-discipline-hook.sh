#!/bin/bash
# Fires PreCompact — injects boundary-timing and state-preservation principles
# before every compaction so Claude applies them during summarization.

cat << 'RULES'
╔══ Compaction Discipline ═══════════════════════════════════════════╗
║  Compaction is about to occur. Apply these principles:            ║
╚═══════════════════════════════════════════════════════════════════╝

TIMING — compact at WORKFLOW BOUNDARIES, not arbitrary turn counts:
  ✓ Good triggers: end of phase, task completion, before context switch
  ✗ Poor triggers: fixed message count, reactive to size alone

PRESERVE in the compaction summary:
  ✓ Current working state and active batch context
  ✓ Cited facts and open questions
  ✓ Artifact paths (files created or modified)
  ✓ Unresolved concerns and phase-completion status
  ✓ Decisions made and their rationale

DO NOT over-compress:
  ✗ Never strip file paths, function names, or error messages
  ✗ Never collapse multi-step decisions into vague summaries
  ✗ Never lose specific values (numbers, identifiers) that will be needed

METHOD — use anchored iterative summarization:
  Merge new content into existing summary sections rather than regenerating from scratch.
  Structure forces preservation: dedicated sections act as checklists.
RULES
