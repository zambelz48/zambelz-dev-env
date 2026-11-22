#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
}

@test "stub records its arguments and prints its output" {
  zc_stub brew 0 "x"
  run brew install a b
  [ "$status" -eq 0 ]
  [ "$output" = "x" ]
  [ "$(zc_calls brew)" = "install a b" ]
}

@test "stub records one line per call" {
  zc_stub git 0
  git status
  git log -1
  [ "$(zc_calls git | wc -l | tr -d ' ')" -eq 2 ]
  [ "$(zc_calls git | tail -1)" = "log -1" ]
}

@test "stub returns its configured exit status" {
  zc_stub dnf 3
  run dnf check-update
  [ "$status" -eq 3 ]
}

@test "zc_calls is empty for a stub that was never called" {
  zc_stub apt-get 0
  [ -z "$(zc_calls apt-get)" ]
}

@test "test home is isolated per test" {
  [ "$HOME" = "$BATS_TEST_TMPDIR/home" ]
  [ "$ZC_HOME" = "$HOME" ]
  [ -d "$HOME" ]
}

@test "contains passes when every piece appears in order" {
  zc_contains "ERROR: x failed
  fix: run y" "ERROR: x" "fix: run y"
}

@test "contains fails on a missing piece and names it" {
  run zc_contains "OK: fine" "ERROR:"
  [ "$status" -eq 1 ]
  [ "$output" = "not found: ERROR:" ]
}

@test "contains fails when pieces are out of order" {
  run zc_contains "fix: y
ERROR: x" "ERROR: x" "fix: y"
  [ "$status" -eq 1 ]
}

@test "contains matches glob characters literally" {
  run zc_contains "a.b" "a*b"
  [ "$status" -eq 1 ]
  zc_contains "[x] *y*" "[x] *y*"
}

@test "a failing contains fails the test even when not last" {
  run bash -c "set -e; $(declare -f zc_contains); zc_contains a b; echo ran"
  [ "$status" -eq 1 ]
  [ "$output" = "not found: b" ]
}

@test "the mise passthrough stub answers which from this test's stubs" {
  zc_stub osv-scanner 0
  zc_stub_mise_passthrough
  [ "$(mise -C "$HOME" which osv-scanner)" = \
    "$BATS_TEST_TMPDIR/stubs/osv-scanner" ]
}

@test "the mise passthrough stub asks the real mise for everything else" {
  zc_stub_mise_passthrough
  run mise -C "$HOME" which python3
  [ "$status" -eq 0 ]
  [[ "$output" == "$MISE_DATA_DIR/installs/python/"* ]] || false
}

@test "suites run under bash 3 on macOS" {
  if [ "$(uname -s)" != "Darwin" ]; then
    skip "macOS only"
  fi
  [ "${BASH_VERSINFO[0]}" -eq 3 ]
}
