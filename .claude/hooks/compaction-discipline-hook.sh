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

DOMAIN-AWARE STRATEGY — match compression style to content type:

  CODE (functions, classes, tests, configs):
    ✓ Chunk-level: keep function signatures, class names, return types, error lines
    ✓ Drop: implementation bodies that have already been acted on
    ✗ Never token-strip across a code boundary — broken syntax is worse than verbosity
    ✗ Never drop import lists or type annotations (callers depend on them)

  DOCUMENTATION / PROSE:
    ✓ Sentence-level: keep topic sentences and conclusions of each section
    ✓ Drop: supporting evidence, examples, and elaboration already incorporated
    ✗ Never drop section headers — they anchor the structure for future turns

  RETRIEVED DOCUMENTS (RAG results, search hits, fetched pages):
    ✓ Query-aware: filter to passages relevant to the LAST stated user intent
    ✓ Drop: passages that didn't contribute to the answer given
    ✗ Never drop source citations or URLs — needed for traceability

  CONVERSATION HISTORY (user/assistant turns):
    ✓ Keep: decisions, commitments, user corrections, unresolved questions
    ✓ Drop: affirmations, pleasantries, superseded plans, back-and-forth that resolved
    ✗ Never drop the user's exact wording when they corrected Claude's output

  TOOL OUTPUT (shell, file reads, API responses):
    ✓ Keep: error messages, key metrics, file paths, identifiers
    ✓ Drop: passing test output, verbose headers, repeated boilerplate
    ✗ Never drop non-zero exit codes or stack trace roots

METHOD — use anchored iterative summarization:
  Merge new content into existing summary sections rather than regenerating from scratch.
  Structure forces preservation: dedicated sections act as checklists.
  Rationale: full regeneration compounds LLM sampling drift — each pass moves content
  toward the model's prior, not ground truth (faulty memory / consolidation loop pattern).
RULES
