#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  PY="$MISE_DATA_DIR/shims/python3"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/mise"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  printf '' >"$ZC_ROOT/osv-scanner.toml"
  cat >"$ZC_ROOT/mise/mise.lock" <<'EOF'
lockfile_version = 3

[[tools."npm:lodash"]]
version = "4.17.20"
backend = "npm:lodash"

[[tools."pipx:black"]]
version = "24.1.0"

[[tools."cargo:neocmakelsp"]]
version = "0.11.2"

[[tools."go:golang.org/x/tools/gopls"]]
version = "0.24.0"

[[tools."gem:solargraph"]]
version = "0.61.0"

[[tools."aqua:bats-core/bats-core"]]
version = "1.14.0"

[[tools.node]]
version = "24.22.1"
EOF
  for lib in log paths os exec audit; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  zc_stub_mise_passthrough
  zc_stub uname 0 "Darwin"
}

convert() {
  "$PY" "$ZC_ROOT/zconf/lib/audit_lock_to_osv.py" "$ZC_ROOT/mise/mise.lock" \
    "$BATS_TEST_TMPDIR/out.json"
}

packages() {
  "$PY" - "$BATS_TEST_TMPDIR/out.json" <<'EOF'
import json
import sys

data = json.load(open(sys.argv[1]))
for result in data["results"]:
    for entry in result["packages"]:
        p = entry["package"]
        print(f'{p["ecosystem"]} {p["name"]} {p["version"]}')
EOF
}

@test "converter maps each language backend and skips the others" {
  convert
  run packages
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' \
    'npm lodash 4.17.20' \
    'PyPI black 24.1.0' \
    'crates.io neocmakelsp 0.11.2' \
    'Go golang.org/x/tools/gopls 0.24.0' \
    'RubyGems solargraph 0.61.0')" ]
}

@test "audit runs the global osv-scanner, not a project's" {
  zc_stub osv-scanner 0
  run zc_audit --declared
  [ "$status" -eq 0 ]
  zc_calls mise | grep -qx -- "-C $HOME which osv-scanner"
}

@test "audit without the pinned osv-scanner exits 3 with the apply fix" {
  zc_stub_script mise <<EOF
case "\$*" in
  *" which osv-scanner") exit 1 ;;
  *) exec "$ZC_REAL_MISE" "\$@" ;;
esac
EOF
  run zc_audit --declared
  [ "$status" -eq 3 ]
  zc_contains "$output" "ERROR: osv-scanner is not installed by mise" \
    "fix: zconf apply mise"
}

@test "audit exits 3 when the scanner cannot run" {
  zc_stub osv-scanner 127
  run zc_audit --declared
  [ "$status" -eq 3 ]
  [[ "$output" == *"ERROR: scan could not run"* ]] || false
}

@test "audit exits 1 on findings and 0 when clean" {
  zc_stub osv-scanner 1
  run zc_audit --declared
  [ "$status" -eq 1 ]
  zc_stub osv-scanner 0
  run zc_audit --declared
  [ "$status" -eq 0 ]
}

@test "declared audit scans the converted lock and the sidecar locks" {
  mkdir -p "$ZC_ROOT/mise/.mise/locks/npm-x/1.0.0" \
    "$ZC_ROOT/mise/.mise/locks/pipx-y/2.0.0"
  touch "$ZC_ROOT/mise/.mise/locks/npm-x/1.0.0/aube-lock.yaml" \
    "$ZC_ROOT/mise/.mise/locks/pipx-y/2.0.0/uv.lock"
  zc_stub osv-scanner 0
  run zc_audit --declared
  [ "$status" -eq 0 ]
  call="$(zc_calls osv-scanner)"
  [[ "$call" == "scan --config $ZC_ROOT/osv-scanner.toml "* ]] || false
  [[ "$call" == *"-L osv-scanner:"*".json"* ]] || false
  lock="$ZC_ROOT/mise/.mise/locks/npm-x/1.0.0/aube-lock.yaml"
  zc_contains "$call" "-L pnpm-lock.yaml:$lock"
  [[ "$call" == *"-L $ZC_ROOT/mise/.mise/locks/pipx-y/2.0.0/uv.lock"* ]] ||
    false
}

@test "installed audit reports OS advisories as info only" {
  zc_stub osv-scanner 0
  run zc_audit --installed
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: no native OS advisory source"* ]] || false
  zc_calls osv-scanner | grep -q -- "-r $MISE_DATA_DIR/installs"
}

@test "installed audit on fedora lists security updates without failing" {
  zc_stub uname 0 "Linux"
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZC_OS_RELEASE
  printf 'ID=fedora\n' >"$ZC_OS_RELEASE"
  zc_stub dnf 1 "FEDORA-2026-1 Important/Sec. openssl-3.5.1"
  zc_stub osv-scanner 0
  run zc_audit --installed
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: FEDORA-2026-1 Important/Sec. openssl-3.5.1"* ]] ||
    false
}

lodash_lock() {
  printf '%s\n' 'lockfile_version = 3' '' '[[tools."npm:lodash"]]' \
    'version = "4.17.20"' >"$ZC_ROOT/mise/mise.lock"
}

# bats test_tags=network
@test "a known vulnerable npm pin fails the real scan" {
  lodash_lock
  run zc_audit --declared
  [ "$status" -eq 1 ]
  [[ "$output" == *"lodash"*"ERROR: vulnerabilities found"* ]] || false
}

ids_for_lodash() {
  "$MISE_DATA_DIR/shims/osv-scanner" scan --format json \
    -L "osv-scanner:$1" 2>/dev/null |
    "$PY" -c 'import json,sys
d = json.load(sys.stdin)
for r in d["results"]:
    for p in r["packages"]:
        for v in p["vulnerabilities"]:
            print(v["id"])'
}

accept_lodash_until() {
  local until="$1" id
  lodash_lock
  convert
  : >"$ZC_ROOT/osv-scanner.toml"
  for id in $(ids_for_lodash "$BATS_TEST_TMPDIR/out.json"); do
    printf '[[IgnoredVulns]]\nid = "%s"\nignoreUntil = %s\nreason = "t"\n\n' \
      "$id" "$until" >>"$ZC_ROOT/osv-scanner.toml"
  done
}

# bats test_tags=network
@test "an acceptance with a future ignoreUntil passes" {
  accept_lodash_until 2099-01-01
  run zc_audit --declared
  [ "$status" -eq 0 ]
}

# bats test_tags=network
@test "an expired acceptance fails again" {
  accept_lodash_until 2020-01-01
  run zc_audit --declared
  [ "$status" -eq 1 ]
}
