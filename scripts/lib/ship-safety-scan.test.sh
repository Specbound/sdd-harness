#!/usr/bin/env bash
# ship-safety-scan.test.sh — prove the pre-ship gate scans the same files from
# any working directory, and fails closed when it found nothing to scan.
#
# Run: bash scripts/lib/ship-safety-scan.test.sh
#
# update.sh runs the scan from whatever directory the caller is in. The prune
# patterns used to be expanded unquoted, so `*/__pycache__` globbed against the
# caller's cwd: from a project with two such dirs `find` got malformed args,
# the file list came back empty, and the update aborted on an unbound array.
# Secret fixtures are assembled at runtime so this file never matches itself.

set -eu

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SCAN="$__here/ship-safety-scan.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ok    %-50s %s\n' "$label" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %-50s got [%s] want [%s]\n' "$label" "$actual" "$expected"
    FAIL=$((FAIL + 1))
  fi
}

# Exit code of a scan of <root>, run from <cwd> — or "crash" when bash itself
# aborted, so a crash can never pass for a deliberate block.
scan_exit() {
  local root="$1" cwd="$2" out="$TMP/scan.out" rc
  (cd "$cwd" && bash "$SCAN" "$root" > "$out" 2>&1) && rc=0 || rc=$?
  if grep -qF 'unbound variable' "$out"; then echo crash; else echo "$rc"; fi
}

FAKE_KEY="AKIA""ABCDEFGHIJKLMNOP"

# A cwd whose `*/__pycache__` glob expands to two words.
hostile="$TMP/hostile-cwd"
mkdir -p "$hostile/api/__pycache__" "$hostile/services/__pycache__"

# --- Case 1: clean root, no templates/ — passes from any cwd -----------------
clean="$TMP/clean"
mkdir -p "$clean/scripts"
printf 'echo hello\n' > "$clean/scripts/a.sh"
check "clean root passes from a neutral cwd" "$(scan_exit "$clean" "$TMP")" "0"
check "clean root passes from a glob-hostile cwd" "$(scan_exit "$clean" "$hostile")" "0"

# --- Case 2: a real secret blocks from any cwd --------------------------------
leaky="$TMP/leaky"
mkdir -p "$leaky/scripts"
printf 'KEY=%s\n' "$FAKE_KEY" > "$leaky/scripts/config.sh"
check "secret blocks from a neutral cwd" "$(scan_exit "$leaky" "$TMP")" "1"
check "secret blocks from a glob-hostile cwd" "$(scan_exit "$leaky" "$hostile")" "1"

# --- Case 3: prune patterns match literally, at any depth ---------------------
pruned="$TMP/pruned"
mkdir -p "$pruned/scripts/deep/__pycache__"
printf 'ok\n' > "$pruned/scripts/a.sh"
printf '%s\n' "$FAKE_KEY" > "$pruned/scripts/deep/__pycache__/cache.txt"
check "nested __pycache__ pruned from a glob-hostile cwd" "$(scan_exit "$pruned" "$hostile")" "0"

# --- Case 3b: AWS's documented placeholder key is prose, not a secret ---------
# Skill docs quote AWS's own example key (AKIA...EXAMPLE); blocking on it would
# block every ship. A real key in the same file must still block.
docs="$TMP/docs"
mkdir -p "$docs/skills"
printf 'OLD_KEY="%s"\n' "AKIA""IOSFODNN7EXAMPLE" > "$docs/skills/SKILL.md"
check "AWS docs placeholder key does not block" "$(scan_exit "$docs" "$TMP")" "0"
printf 'NEW_KEY="%s"\n' "$FAKE_KEY" >> "$docs/skills/SKILL.md"
check "real key next to a placeholder still blocks" "$(scan_exit "$docs" "$TMP")" "1"

# --- Case 4: nothing to scan is a failure, not a clean pass -------------------
empty="$TMP/empty"
mkdir -p "$empty"
check "empty root fails closed" "$(scan_exit "$empty" "$TMP")" "1"

echo ""
if [ $FAIL -eq 0 ]; then
  echo "PASS — $PASS check(s)"
  exit 0
fi
echo "FAIL — $FAIL failure(s), $PASS passed"
exit 1
