#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
  zc_test_setup
  PY="$MISE_DATA_DIR/shims/python3"
  V="$ZC_ROOT/zconf/lib/versions.py"
  CFG="$BATS_TEST_TMPDIR/mise.toml"
  cat >"$CFG" <<'EOF'
[tool_config]
locked = true

[tools]
node = ["24.11.0", "22.12.0"]
go = ["1.26.4", "1.24.3"]
java = "temurin-17.0.12+7"
marksman = "2025-11-30"
"github:cantino/mcfly" = { version = "0.9.4", os = ["linux"] }

[tools."http:jdtls"]
version = "1.63.0"
EOF
  zc_stub_script mise <<'EOF'
case "$*" in
  "latest node@24") echo 24.12.0 ;;
  "latest node@22") echo 22.12.0 ;;
  "latest node") echo 25.1.0 ;;
  "latest go@1.26") echo 1.26.10 ;;
  "latest go@1.24") echo 1.24.13 ;;
  "latest go") echo 1.27.0 ;;
  "latest java@temurin-17") echo temurin-17.0.13+11 ;;
  "latest java@temurin") echo temurin-27.0.1+0 ;;
  "latest marksman") echo 2026-02-08 ;;
  "latest github:cantino/mcfly@0.9") echo 0.9.4 ;;
  "latest github:cantino/mcfly") echo 0.10.0 ;;
  "config set "*) exit 0 ;;
  *) exit 1 ;;
esac
EOF
}

outdated() {
  run --separate-stderr "$PY" "$V" outdated "$CFG" "$@"
}

@test "outdated keeps each pin within its major" {
  outdated
  [ "$status" -eq 0 ]
  [[ "$output" == *"node 24.11.0 24.12.0"* ]] || false
  [[ "$output" != *"25.1.0"* ]] || false
  [[ "$output" != *"node 22.12.0"* ]] || false
}

@test "outdated --major crosses the major" {
  outdated --major
  [[ "$output" == *"node 24.11.0 25.1.0"* ]] || false
}

@test "outdated --major moves only the default pin of each tool" {
  outdated --major
  [[ "$output" == *"node 24.11.0 25.1.0"* ]] || false
  [[ "$output" != *"node 22.12.0"* ]] || false
  [[ "$output" == *"go 1.26.4 1.27.0"* ]] || false
  [[ "$output" != *"go 1.24.3"* ]] || false
}

@test "set refuses a new version that is already pinned" {
  run --separate-stderr "$PY" "$V" set "$CFG" node 22.12.0 24.11.0
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"ERROR: node 24.11.0 is already pinned"* ]] || false
  [ "$(zc_calls mise | grep -c '^config set')" -eq 0 ]
}

@test "pins of one tool sharing a major keep their own minor line" {
  outdated
  [[ "$output" == *"go 1.26.4 1.26.10"* ]] || false
  [[ "$output" == *"go 1.24.3 1.24.13"* ]] || false
}

@test "a vendor-prefixed version stays on its vendor and major" {
  outdated
  [[ "$output" == *"java temurin-17.0.12+7 temurin-17.0.13+11"* ]] || false
  outdated --major
  [[ "$output" == *"java temurin-17.0.12+7 temurin-27.0.1+0"* ]] || false
}

@test "a date version moves to the newest" {
  outdated
  [[ "$output" == *"marksman 2025-11-30 2026-02-08"* ]] || false
}

@test "a 0.x version keeps its minor as the line" {
  outdated
  [[ "$output" != *"mcfly"* ]] || false
  outdated --major
  [[ "$output" == *"github:cantino/mcfly 0.9.4 0.10.0"* ]] || false
}

@test "an http tool is reported as unchecked, not guessed" {
  outdated
  [[ "$stderr" == *"WARN: http:jdtls is not checked"* ]] || false
  [[ "$output" != *"jdtls"* ]] || false
}

@test "outdated can be limited to named tools" {
  outdated node
  [[ "$output" == *"node 24.11.0 24.12.0"* ]] || false
  [[ "$output" != *"go "* ]] || false
}

@test "set changes only the targeted list element" {
  run "$PY" "$V" set "$CFG" node 24.11.0 24.12.0
  [ "$status" -eq 0 ]
  [ "$(zc_calls mise | grep '^config set')" = \
    "config set -f $CFG tools.node 24.12.0,22.12.0 --type list" ]
}

@test "set on a scalar writes a string" {
  run "$PY" "$V" set "$CFG" java temurin-17.0.12+7 temurin-17.0.13+11
  [ "$(zc_calls mise | grep '^config set')" = \
    "config set -f $CFG tools.java temurin-17.0.13+11 --type string" ]
}

@test "set on a table-form tool writes its version key, quoted" {
  run "$PY" "$V" set "$CFG" github:cantino/mcfly 0.9.4 0.10.0
  expected="config set -f $CFG tools.\"github:cantino/mcfly\".version"
  [ "$(zc_calls mise | grep '^config set')" = \
    "$expected 0.10.0 --type string" ]
}

@test "set refuses a version that is not pinned" {
  run "$PY" "$V" set "$CFG" node 20.0.0 20.1.0
  [ "$status" -eq 1 ]
  [ "$(zc_calls mise | grep -c '^config set')" -eq 0 ]
}

@test "use moves an existing version to the front and keeps the other" {
  run "$PY" "$V" use "$CFG" node 22.12.0
  [ "$status" -eq 0 ]
  [ "$(zc_calls mise | grep '^config set')" = \
    "config set -f $CFG tools.node 22.12.0,24.11.0 --type list" ]
}

@test "use adds a new version in front of a scalar pin" {
  run "$PY" "$V" use "$CFG" java temurin-21.0.5+11
  expected="config set -f $CFG tools.java"
  [ "$(zc_calls mise | grep '^config set')" = \
    "$expected temurin-21.0.5+11,temurin-17.0.12+7 --type list" ]
}

@test "use refuses a version that is not exact and changes nothing" {
  for version in 24 24.11 latest "^24.11.0" lts; do
    run "$PY" "$V" use "$CFG" node "$version"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: node $version is not an exact version"* ]] ||
      false
  done
  [ "$(zc_calls mise | grep -c '^config set')" -eq 0 ]
}

@test "use refuses a table-form tool" {
  run "$PY" "$V" use "$CFG" github:cantino/mcfly 0.9.5
  [ "$status" -eq 1 ]
  [ "$(zc_calls mise | grep -c '^config set')" -eq 0 ]
}

# Writes a lock entry; the third word lists platforms, or none for no
# platforms at all.
lock_entry() {
  local tool version platforms platform
  read -r tool version platforms <<<"$1"
  printf '\n[[tools."%s"]]\nversion = "%s"\n' "$tool" "$version"
  if [ "$platforms" = "none" ]; then
    return 0
  fi
  for platform in ${platforms//,/ }; do
    printf '[tools."%s"."platforms.%s"]\nurl = "u"\n' "$tool" "$platform"
  done
}

locked() {
  local entry
  mkdir -p "$BATS_TEST_TMPDIR/zconf"
  printf 'macos-arm64,linux-x64\n' >"$BATS_TEST_TMPDIR/zconf/platforms"
  printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/before.lock"
  shift
  for entry in "${@:3}"; do
    lock_entry "$entry"
  done >"$BATS_TEST_TMPDIR/after.lock"
  run --separate-stderr "$PY" "$V" locked "$CFG" \
    "$BATS_TEST_TMPDIR/after.lock" "$BATS_TEST_TMPDIR/before.lock" "$1" "$2"
}

@test "locked passes a version locked for every platform" {
  locked "$(lock_entry "node 24.11.0 macos-arm64,linux-x64")" node 24.12.0 \
    "node 24.12.0 macos-arm64,linux-x64"
  [ "$status" -eq 0 ]
}

@test "locked names the platforms a version is missing" {
  locked "$(lock_entry "node 24.11.0 macos-arm64,linux-x64")" node 24.12.0 \
    "node 24.12.0 macos-arm64"
  [ "$status" -eq 1 ]
  [ "$stderr" = "ERROR: node 24.12.0 is not locked for linux-x64" ]
}

@test "locked fails a version with no downloads when the old one had them" {
  locked "$(lock_entry "node 24.11.0 macos-arm64,linux-x64")" node 9.9.9 \
    "node 9.9.9 none"
  [ "$status" -eq 1 ]
  [ "$stderr" = "ERROR: node 9.9.9 has no download for any platform" ]
}

@test "locked passes a source-built tool that never had platforms" {
  locked "$(lock_entry "go:example.com/tool 1.0.0 none")" \
    go:example.com/tool 1.1.0 "go:example.com/tool 1.1.0 none"
  [ "$status" -eq 0 ]
}

@test "locked skips platforms the tool's os list excludes" {
  locked "$(lock_entry "github:cantino/mcfly 0.9.4 linux-x64")" \
    github:cantino/mcfly 0.9.4 "github:cantino/mcfly 0.9.4 linux-x64"
  [ "$status" -eq 0 ]
}

@test "locked fails a version missing from the lock" {
  locked "" node 24.12.0 "node 24.11.0 macos-arm64,linux-x64"
  [ "$status" -eq 1 ]
  [ "$stderr" = "ERROR: node 24.12.0 is not in the lock" ]
}
