#!/bin/bash
# =============================================================================
# check-no-hardcoded-paths.sh — regression guard for dynamic, portable paths.
# =============================================================================
# Fails (exit 1) if any committed harness SCRIPT contains a hardcoded absolute
# path literal. Every path in the harness must be self-located at runtime (see
# scripts/lib/resolve-harness-dir.sh) or computed from that self-location — so
# the harness runs unchanged on any machine, OS, or clone location.
#
# Run manually:        bash scripts/check-no-hardcoded-paths.sh
# Wired into:          /kiro:harness-validate  and  .git/hooks/pre-commit
#
# Scope: *.sh and *.py under the harness root, EXCLUDING:
#   - .claude/**           installed copies (generated from this source)
#   - docs/**              prose + frozen historical plan/spec records
#   - scripts/lib/resolve-harness-dir.sh  (the one allowed depth marker)
#   - this script itself   (it names the very patterns it bans)
# =============================================================================
set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/../lib/resolve-harness-dir.sh"
cd "$HARNESS_DIR" || exit 1

# Banned patterns — machine/user-specific absolutes and the hardcoded harness
# root used in EXECUTABLE context. Each entry: "regex<TAB>human explanation".
#
# Deliberately NOT banned (legitimate, would be false positives):
#   - bare mount prefixes (/mnt/c/, C:\) in path-CONVERSION utilities
#   - the conventional "~/.claude/sdd-harness/..." string in help/usage text
#     (it documents where the harness is meant to live; it does not execute)
# The patterns below require a concrete USER segment or the executable $HOME
# assignment, which is exactly the anti-pattern that breaks on other machines.
PATTERNS=(
  '/home/[A-Za-z]	hardcoded Linux home dir w/ user (use self-location or $HOME)'
  '/Users/[A-Za-z]	hardcoded macOS home dir w/ user (use self-location or $HOME)'
  '/c/Users/[A-Za-z]	hardcoded Git Bash user path (use self-location or $HOME)'
  '/mnt/c/Users/[A-Za-z]	hardcoded WSL user path (use self-location or $HOME)'
  'C:\\\\Users\\\\[A-Za-z]	hardcoded Windows user path (use self-location or $HOME)'
  '\$HOME/\.claude/sdd-harness	hardcoded harness root (source lib/resolve-harness-dir.sh instead)'
  'cd "\$\(dirname	logical-cd self-location resolves symlinks/junctions to the wrong path — use "cd -P" and/or source lib/resolve-harness-dir.sh'
)

# Collect candidate files: tracked + newly-added (not-yet-committed, not
# gitignored) *.sh and *.py, minus the exclusions.
mapfile -t FILES < <(
  { git ls-files '*.sh' '*.py' 2>/dev/null
    git ls-files --others --exclude-standard '*.sh' '*.py' 2>/dev/null
  } | sort -u \
    | grep -Ev '^\.claude/' \
    | grep -Ev '^docs/' \
    | grep -Ev '^scripts/lib/resolve-harness-dir\.sh$' \
    | grep -Ev '^scripts/utils/check-no-hardcoded-paths\.sh$'
)

# Fallback when not in a git repo (e.g. tarball): walk the filesystem instead.
if [ "${#FILES[@]}" -eq 0 ]; then
  mapfile -t FILES < <(
    find . \( -name '*.sh' -o -name '*.py' \) \
      -not -path './.claude/*' \
      -not -path './docs/*' \
      -not -path './scripts/lib/resolve-harness-dir.sh' \
      -not -path './scripts/check-no-hardcoded-paths.sh' \
      -not -path './.git/*' | sed 's|^\./||'
  )
fi

violations=0
for entry in "${PATTERNS[@]}"; do
  regex="${entry%%	*}"
  why="${entry#*	}"
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    # Skip comment-only matches? No — a hardcoded path in a comment still rots.
    matches="$(grep -nE "$regex" "$f" 2>/dev/null)" || continue
    if [ -n "$matches" ]; then
      while IFS= read -r line; do
        echo "HARDCODED PATH: $f:$line"
        echo "   reason: $why"
        violations=$((violations + 1))
      done <<< "$matches"
    fi
  done
done

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "✗ $violations hardcoded-path violation(s). Paths must be dynamic:"
  echo "  - source scripts/lib/resolve-harness-dir.sh to get \$HARNESS_DIR"
  echo "  - derive everything else from \$HARNESS_DIR or \$HOME"
  exit 1
fi

echo "✓ No hardcoded paths — all paths are self-located or computed."
