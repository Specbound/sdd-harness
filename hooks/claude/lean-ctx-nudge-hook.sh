#!/bin/bash
# lean-ctx nudge hook — PostToolUse(Read)
# Fires after every Read tool call. When the file is large enough to be
# costly, prints a one-line suggestion for the optimal ctx_read mode.
# Threshold: ~16 KB on disk ≈ 4,000 tokens (@ ~4 chars/token).
# Exits silently for small files, non-existent paths, and data formats
# that lean-ctx intentionally skips (JSON, YAML, TOML).

set -euo pipefail

EVENT=$(cat)

FILE_PATH=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    print(e.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# File size in bytes
FILE_BYTES=$(wc -c < "$FILE_PATH" 2>/dev/null || echo 0)
THRESHOLD=16000  # ~4,000 tokens

(( FILE_BYTES < THRESHOLD )) && exit 0

TOKENS=$(( FILE_BYTES / 4 ))
EXT="${FILE_PATH##*.}"

# lean-ctx skips data formats — don't nudge for those
case "$EXT" in
  json|yaml|yml|toml|env|lock|sum) exit 0 ;;
esac

# Pick the best mode and a brief rationale
case "$EXT" in
  py|ts|tsx|js|jsx|go|rs|java|cpp|c|h|rb|swift|kt|scala|cs|sh|bash|zsh)
    MODE="signatures"
    NOTE="exports + types only — typically 3-5% of full-file tokens"
    ;;
  md|txt|rst|mdx|wiki)
    MODE="reference"
    NOTE="quote-ready excerpts — removes boilerplate, keeps key passages"
    ;;
  *)
    MODE="aggressive"
    NOTE="maximum compression for unknown type"
    ;;
esac

BASENAME=$(basename "$FILE_PATH")

cat << EOF
╔══ lean-ctx Opportunity (~${TOKENS} tokens) ═════════════════════════╗
║  ${BASENAME} is large. Consider:
║
║    ctx_read("${FILE_PATH}", "${MODE}")
║    # ${NOTE}
║
║  Other modes:
║    "map"       — dependency list + exports (no implementation)
║    "entropy"   — high-signal fragments, attention-mimicking filter
║    "task"      — filter to active task context (best precision)
║    "diff"      — only changes since last read (re-checks after edits)
║    "lines:N-M" — specific range if you know where to look
║
║  Re-read after edits: ctx_delta("${FILE_PATH}") ≈ 13 tokens
╚═══════════════════════════════════════════════════════════════════╝
EOF
