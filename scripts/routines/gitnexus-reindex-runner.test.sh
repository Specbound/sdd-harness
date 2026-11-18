#!/usr/bin/env bash
# gitnexus-reindex-runner.test.sh — prove the weekly reindex runs only when needed.
#
# Run: bash scripts/routines/gitnexus-reindex-runner.test.sh
#
# Uses a throwaway git repo and a fake gitnexus (GITNEXUS_BIN) that records each
# call, so no real index is touched.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
RUNNER="$__here/gitnexus-reindex-runner.sh"
PASS=0
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

check() {
  if [ "$2" = "$3" ]; then
    printf '  ok   %s\n' "$1"; PASS=$((PASS + 1))
  else
    printf '  FAIL %s :: expected %s, got %s\n' "$1" "$3" "$2"; FAIL=$((FAIL + 1))
  fi
}

FAKE="$TMP/fake-gitnexus"
CALLS="$TMP/calls"
cat > "$FAKE" <<EOF
#!/bin/bash
echo "\$*" >> "$CALLS"
[ "\${FAKE_FAIL:-0}" = "1" ] && { echo "boom" >&2; exit 3; }
exit 0
EOF
chmod +x "$FAKE"

REPO="$TMP/repo"
mkdir -p "$REPO/.claude/memory"
git -C "$REPO" init -q
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
STATE="$REPO/.claude/memory/.last-gitnexus-reindex"

run() { (cd "$REPO" && GITNEXUS_BIN="$FAKE" bash "$RUNNER" "$@" 2>/dev/null); }
calls() { [ -f "$CALLS" ] && wc -l < "$CALLS" | tr -d ' ' || echo 0; }

# 1. No .gitnexus/ → nothing happens
run; check "no index: exit 0" "$?" 0
check "no index: gitnexus not called" "$(calls)" 0
check "no index: not stamped" "$([ -f "$STATE" ] && echo y || echo n)" n

# 2. Index already at HEAD → no analyze, stamped
mkdir -p "$REPO/.gitnexus"
printf '{"lastCommit": "%s"}\n' "$HEAD_SHA" > "$REPO/.gitnexus/meta.json"
run; check "fresh: exit 0" "$?" 0
check "fresh: gitnexus not called" "$(calls)" 0
check "fresh: stamped" "$([ -f "$STATE" ] && echo y || echo n)" y

# 3. Within cadence → skipped even when stale
printf '{"lastCommit": "deadbeef"}\n' > "$REPO/.gitnexus/meta.json"
run; check "cadence: exit 0" "$?" 0
check "cadence: gitnexus not called" "$(calls)" 0

# 4. Analyze fails → exit 1, stamp not refreshed
echo "2000-01-01T00:00:00+00:00" > "$STATE"
(cd "$REPO" && FAKE_FAIL=1 GITNEXUS_BIN="$FAKE" bash "$RUNNER" 2>/dev/null)
check "failure: exit 1" "$?" 1
check "failure: stamp unchanged" "$(cut -dT -f1 "$STATE")" 2000-01-01

# 5. Stale and due → index-only analyze (no CLAUDE.md/AGENTS.md rewrite), stamped today
run; check "stale: exit 0" "$?" 0
check "stale: analyze args" "$(tail -1 "$CALLS")" "analyze --index-only"
check "stale: stamped today" "$(cut -dT -f1 "$STATE")" "$(date +%Y-%m-%d)"

# 6. Opt-out
rm -f "$STATE"
before="$(calls)"
(cd "$REPO" && SDD_SKIP_GITNEXUS_REINDEX=1 GITNEXUS_BIN="$FAKE" bash "$RUNNER")
check "opt-out: gitnexus not called" "$(calls)" "$before"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
