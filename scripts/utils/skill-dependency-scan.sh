#!/bin/bash
# Deterministic cross-reference scan for skill-curator.
#
# For every skill in ~/.claude/skills/*/, greps for its name (word-boundary) across
# other skills' SKILL.md bodies, hooks, agents, commands, CLAUDE.md, kiro rules, and
# routine scripts — so the curator never proposes deleting/merging something that
# other skills, hooks, or agents still depend on.
#
# Output is file:line locations only (never the full matched line text) and capped
# to MAX_REFS per skill — a common English-word skill name (e.g. "questions") can
# otherwise match hundreds of lines and produce a single multi-KB entry that buries
# the signal for every other skill in the map.
#
# Usage: bash scripts/utils/skill-dependency-scan.sh   (run from the harness repo root)
# Output: markdown lines, one per skill with >=1 referrer. Silent (no output) if none.

set -u

REPO_DIR="$(pwd)"
SKILLS_DIR="$HOME/.claude/skills"
MAX_REFS=8

[ -d "$SKILLS_DIR" ] || exit 0

TARGETS=()
for d in "$REPO_DIR/hooks" "$REPO_DIR/agents" "$REPO_DIR/commands" \
         "$REPO_DIR/kiro/settings/rules" "$REPO_DIR/scripts/routines"; do
  [ -d "$d" ] && TARGETS+=("$d")
done
[ -f "$REPO_DIR/CLAUDE.md" ] && TARGETS+=("$REPO_DIR/CLAUDE.md")

for skill_dir in "$SKILLS_DIR"/*/; do
  name="$(basename "${skill_dir%/}")"
  [ -z "$name" ] && continue

  hits=()

  # Other skills' SKILL.md bodies (exclude the skill's own file).
  # cut -d: -f1,2 keeps only "path:line" — never the matched line's own text,
  # which is what caused unbounded per-hit bloat before this fix.
  while IFS= read -r line; do
    [ -n "$line" ] && hits+=("$line")
  done < <(
    grep -rn -w -- "$name" "$SKILLS_DIR"/*/SKILL.md 2>/dev/null \
      | grep -v -- "^$SKILLS_DIR/$name/SKILL.md:" \
      | cut -d: -f1,2 \
      | sed "s|^$SKILLS_DIR/||" \
      | sed 's|/SKILL.md:| skill:|'
  )

  # Repo source tree: hooks, agents, commands, kiro rules, routine scripts, CLAUDE.md
  if [ "${#TARGETS[@]}" -gt 0 ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && hits+=("$line")
    done < <(
      grep -rn -w -- "$name" "${TARGETS[@]}" 2>/dev/null \
        | cut -d: -f1,2 \
        | sed "s|^$REPO_DIR/||"
    )
  fi

  [ "${#hits[@]}" -eq 0 ] && continue

  # Dedupe (same file:line can repeat across the two passes) and cap.
  mapfile -t hits < <(printf '%s\n' "${hits[@]}" | sort -u)
  total="${#hits[@]}"
  shown=("${hits[@]:0:$MAX_REFS}")

  refs="$(printf '%s, ' "${shown[@]}")"
  refs="${refs%, }"
  if [ "$total" -gt "$MAX_REFS" ]; then
    refs="$refs (+$((total - MAX_REFS)) more)"
  fi
  echo "- \`$name\` — referenced by: $refs"
done
