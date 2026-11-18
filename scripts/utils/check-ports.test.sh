#!/bin/bash
# Functional tests for check-ports.py. Builds a throwaway harness tree.
#   bash scripts/utils/check-ports.test.sh
set -u
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GUARD="$SCRIPT_DIR/check-ports.py"
ROOT="$(mktemp -d)"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi }
check_contains(){ case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac }

REG="$ROOT/scripts/utils/ports.txt"
run(){ (cd "$ROOT" && python3 "$GUARD" >/dev/null 2>&1; echo $?); }
out(){ (cd "$ROOT" && python3 "$GUARD" 2>&1); }
listed(){ (cd "$ROOT" && python3 "$GUARD" --list 2>&1); }
reset(){
  rm -rf "$ROOT/scripts" "$ROOT/hooks" "$ROOT/templates" "$ROOT"/*.sh
  mkdir -p "$ROOT/scripts/utils" "$ROOT/scripts/svc" "$ROOT/hooks/git" "$ROOT/templates"
  printf 'ALPHA_PORT = 8101\n' > "$ROOT/scripts/svc/alpha.py"
  printf '# registry\n8101 alpha scripts/svc/alpha.py\n' > "$REG"
}

reset
check "clean tree passes"                              "0" "$(run)"

# ── rule 2: unregistered use ────────────────────────────────────────────────
printf 'BETA_PORT = 8102\n' > "$ROOT/scripts/svc/beta.py"
check "new unregistered port fails"                    "1" "$(run)"
check_contains "new port message names the fix"        "$(out)" "8102 <service> scripts/svc/beta.py"
printf '8102 beta scripts/svc/beta.py\n' >> "$REG"
check "registering the new port passes"                "0" "$(run)"; reset

printf 'BETA_PORT = 8101\n' > "$ROOT/scripts/svc/beta.py"
check "second file reusing an owned port fails"        "1" "$(run)"
check_contains "reuse message names the owner"         "$(out)" "belongs to 'alpha'"
printf '8101 alpha scripts/svc/beta.py\n' >> "$REG"
check "same service, second file registered passes"    "0" "$(run)"; reset

# ── rule 1: registry conflicts ──────────────────────────────────────────────
printf 'BETA_PORT = 8101\n' > "$ROOT/scripts/svc/beta.py"
printf '8101 beta scripts/svc/beta.py\n' >> "$REG"
check "one port, two services fails"                   "1" "$(run)"
check_contains "conflict message names both services"  "$(out)" "port 8101 is claimed by 2 services: alpha, beta"
reset

printf 'ALPHA_PORT = 8101\nALPHA_ALT_PORT = 8105\n' > "$ROOT/scripts/svc/alpha.py"
printf '8105 alpha scripts/svc/alpha.py\n' >> "$REG"
check "one service, two ports fails"                   "1" "$(run)"; reset

# ── rule 3: stale entries ───────────────────────────────────────────────────
printf '8109 gone scripts/svc/gone.py\n' >> "$REG"
check "entry for a missing file fails"                 "1" "$(run)"; reset

printf 'ALPHA_PORT = 8111\n' > "$ROOT/scripts/svc/alpha.py"
printf '8101 alpha scripts/svc/alpha.py\n8111 alpha2 scripts/svc/alpha.py\n' > "$REG"
check "entry whose file dropped the port fails"        "1" "$(run)"; reset

# ── detection forms ─────────────────────────────────────────────────────────
detects(){ # $1=label $2=relative file $3=line $4=expected port
  printf '%s\n' "$3" > "$ROOT/$2"
  check_contains "detects: $1" "$(listed)" "$4 $2"
  reset
}
detects "127.0.0.1:N"            "scripts/svc/a.sh"   'curl http://127.0.0.1:8201/readyz'          "8201"
detects "localhost:N"            "scripts/svc/a.py"   'URL = "http://localhost:8202/v1/"'          "8202"
detects "0.0.0.0:N"              "scripts/svc/a.sh"   'serve --bind 0.0.0.0:8203'                  "8203"
detects 'shell ${X_PORT:-N}'     "scripts/svc/a.sh"   'P="${SVC_PORT:-8204}"'                      "8204"
detects "X_PORT_DEFAULT quoted"  "scripts/svc/a.sh"   'SVC_PORT_DEFAULT="8205"'                    "8205"
detects "aligned assignment"     "scripts/svc/a.py"   'GN_PORT          = 8206'                    "8206"
detects "toml port key"          "templates/a.toml.template" 'port = 8207'                         "8207"
detects 'dict .get("port", N)'   "scripts/svc/a.py"   'p = cfg.get("port", 8208)'                  "8208"
detects '"--port", "N" argv'     "scripts/svc/a.py"   'cmd = ["svc", "--port", "8209"]'            "8209"
detects "top-level *.sh"         "install.sh"         'curl http://127.0.0.1:8210/'                "8210"
detects "extensionless git hook" "hooks/git/pre-push" 'curl http://127.0.0.1:8211/'                "8211"

ignores(){ # $1=label $2=relative file $3=line
  mkdir -p "$(dirname "$ROOT/$2")"
  printf '%s\n' "$3" > "$ROOT/$2"
  check "ignores: $1" "0" "$(run)"
  reset
}
ignores "shell comment line"          "scripts/svc/a.sh"      '# e.g. SVC_PORT=8301 ./setup.sh'
ignores "date after a port-ish name"  "scripts/svc/a.py"      'x = {"port": "2026-11-12"}'
ignores "name merely containing port" "scripts/svc/a.py"      'report = 8302'
ignores "non-port \${VAR:-N} default" "scripts/svc/a.sh"      'T="${TIMEOUT_S:-7200}"'
ignores "privileged/short number"     "scripts/svc/a.py"      'SVC_PORT = 443'
ignores "six-digit number"            "scripts/svc/a.py"      'SVC_PORT = 123456'
ignores "*.test.sh file"              "scripts/svc/a.test.sh" 'SVC_PORT=8303'
ignores "test_*.py file"              "scripts/svc/test_a.py" 'SVC_PORT = 8304'
ignores "docs/ tree"                  "docs/a.sh"             'SVC_PORT=8305'
ignores "skills/ tree"                "skills/x/a.py"         'SVC_PORT = 8306'

# ── registry file problems ──────────────────────────────────────────────────
rm "$REG"
check "missing registry exits 2"                       "2" "$(run)"
check "--list works without a registry"                "8101 scripts/svc/alpha.py" "$(listed)"
printf 'not-a-port alpha scripts/svc/alpha.py\n' > "$REG"
check "malformed registry line exits 2"                "2" "$(run)"
printf '8101 alpha\n' > "$REG"
check "registry line with 2 fields exits 2"            "2" "$(run)"

# ── the real repo's registry is in sync with the real repo ──────────────────
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
check "real repo passes its own registry"              "0" "$(cd "$REPO" && python3 "$GUARD" >/dev/null 2>&1; echo $?)"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
