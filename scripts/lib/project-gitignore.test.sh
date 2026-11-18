#!/usr/bin/env bash
# project-gitignore.test.sh — prove the harness entries land in a project's
# .gitignore exactly once, and that a re-run is a safe no-op.
#
# Run: bash scripts/lib/project-gitignore.test.sh
#
# The re-run case is the real test: update.sh runs under `set -e` and calls
# ensure_gitignore on every sync, so a non-zero "nothing to add" return would
# abort every update of an already-configured project.

set -eu

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/project-gitignore.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ok    %-46s %s\n' "$label" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %-46s got [%s] want [%s]\n' "$label" "$actual" "$expected"
    FAIL=$((FAIL + 1))
  fi
}

# --- Case 1: pre-existing .gitignore, entries appended, re-run is a no-op ----
proj="$TMP/with-gitignore"
mkdir -p "$proj"
printf 'node_modules/\n' > "$proj/.gitignore"

ensure_gitignore "$proj" > /dev/null
before="$(cat "$proj/.gitignore")"
ensure_gitignore "$proj" > /dev/null   # must not abort under set -e
after="$(cat "$proj/.gitignore")"

check "re-run leaves the file unchanged" "$([ "$before" = "$after" ] && echo same || echo changed)" "same"
check "pre-existing content preserved" "$(grep -cxF 'node_modules/' "$proj/.gitignore")" "1"

for entry in "${SDD_GITIGNORE_ENTRIES[@]}"; do
  check "entry present exactly once: $entry" "$(grep -cxF "$entry" "$proj/.gitignore")" "1"
done

# --- Case 2: no .gitignore at all — one is created, no leading blank line ----
proj2="$TMP/no-gitignore"
mkdir -p "$proj2"
ensure_gitignore "$proj2" > /dev/null

check "creates a missing .gitignore" "$([ -f "$proj2/.gitignore" ] && echo yes || echo no)" "yes"
check "first line is the header" "$(head -n 1 "$proj2/.gitignore")" "# SDD harness — local-only, never committed"

# --- Case 3: partial .gitignore — only the missing entries are added ---------
proj3="$TMP/partial"
mkdir -p "$proj3"
printf '.claude/\nspecs/\nCLAUDE.md\n' > "$proj3/.gitignore"
ensure_gitignore "$proj3" > /dev/null

check "existing entry not duplicated" "$(grep -cxF '.claude/' "$proj3/.gitignore")" "1"
check "AGENTS.md added to a legacy install" "$(grep -cxF 'AGENTS.md' "$proj3/.gitignore")" "1"
check "ERRORS.md added to a legacy install" "$(grep -cxF 'ERRORS.md' "$proj3/.gitignore")" "1"

# --- Case 4: a commented-out entry is not an opt-out — it is enforced --------
# No project may track harness files; commenting an entry out must not let
# .claude/ or specs/ back into a project's history.
proj4="$TMP/commented"
mkdir -p "$proj4"
printf '# .claude/\n#specs/\n' > "$proj4/.gitignore"
ensure_gitignore "$proj4" > /dev/null
ensure_gitignore "$proj4" > /dev/null

check "commented '# .claude/' enforced as active" "$(grep -cxF '.claude/' "$proj4/.gitignore")" "1"
check "commented '#specs/' enforced as active" "$(grep -cxF 'specs/' "$proj4/.gitignore")" "1"
check "header written once" "$(grep -cxF '# SDD harness — local-only, never committed' "$proj4/.gitignore")" "1"

# --- Case 5: harness files already tracked are untracked, kept on disk --------
# An ignore rule never untracks a file git already has, so ignoring alone
# leaves every committed harness file showing up — and pushed — on each change.
proj5="$TMP/tracked"
mkdir -p "$proj5/.claude/memory" "$proj5/specs/feat" "$proj5/src"
printf 'app\n' > "$proj5/src/app.py"
printf 'note\n' > "$proj5/.claude/memory/hot-memory.md"
printf 'spec\n' > "$proj5/specs/feat/tasks.md"
printf '{}\n' > "$proj5/.mcp.json"
printf 'x\n' > "$proj5/CLAUDE.md"
git -C "$proj5" init -q
git -C "$proj5" add -A
git -C "$proj5" -c user.name=t -c user.email=t@t commit -qm init
ensure_gitignore "$proj5" > /dev/null

check "tracked .claude/ untracked" "$(git -C "$proj5" ls-files -- .claude/ | wc -l | tr -d ' ')" "0"
check "tracked specs/ untracked" "$(git -C "$proj5" ls-files -- specs/ | wc -l | tr -d ' ')" "0"
check "tracked .mcp.json untracked" "$(git -C "$proj5" ls-files -- .mcp.json | wc -l | tr -d ' ')" "0"
check "tracked CLAUDE.md untracked" "$(git -C "$proj5" ls-files -- CLAUDE.md | wc -l | tr -d ' ')" "0"
check "app code still tracked" "$(git -C "$proj5" ls-files -- src/app.py)" "src/app.py"
check "untracked harness files kept on disk" "$([ -f "$proj5/.claude/memory/hot-memory.md" ] && [ -f "$proj5/specs/feat/tasks.md" ] && echo yes || echo no)" "yes"
check "nothing harness left in status" "$(git -C "$proj5" status --porcelain --untracked-files=all | grep -vE '^(D  |M  \.gitignore| M \.gitignore|\?\? \.gitignore)' | wc -l | tr -d ' ')" "0"
ensure_gitignore "$proj5" > /dev/null   # re-run on an already-clean index must not abort
check "re-run on untracked index is a no-op" "$(git -C "$proj5" diff --cached --name-only | wc -l | tr -d ' ')" "4"

# --- Case 6: every harness tree the harness writes is in the list -------------
for e in .claude/ specs/ CLAUDE.md AGENTS.md ERRORS.md .cursor/ .serena/ .gitnexus/ .worktrees/ .mcp.json; do
  check "entry declared: $e" "$(printf '%s\n' "${SDD_GITIGNORE_ENTRIES[@]}" | grep -cxF -- "$e")" "1"
done

echo ""
if [ $FAIL -eq 0 ]; then
  echo "PASS — $PASS check(s)"
  exit 0
fi
echo "FAIL — $FAIL failure(s), $PASS passed"
exit 1
