#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
}

@test "stub records its arguments and prints its output" {
  zzd_stub brew 0 "x"
  run brew install a b
  [ "$status" -eq 0 ]
  [ "$output" = "x" ]
  [ "$(zzd_calls brew)" = "install a b" ]
}

@test "stub records one line per call" {
  zzd_stub git 0
  git status
  git log -1
  [ "$(zzd_calls git | wc -l | tr -d ' ')" -eq 2 ]
  [ "$(zzd_calls git | tail -1)" = "log -1" ]
}

@test "stub returns its configured exit status" {
  zzd_stub dnf 3
  run dnf check-update
  [ "$status" -eq 3 ]
}

@test "zzd_calls is empty for a stub that was never called" {
  zzd_stub apt-get 0
  [ -z "$(zzd_calls apt-get)" ]
}

@test "test home is isolated per test" {
  [ "$HOME" = "$BATS_TEST_TMPDIR/home" ]
  [ "$ZZD_HOME" = "$HOME" ]
  [ -d "$HOME" ]
}

@test "contains passes when every piece appears in order" {
  zzd_contains "ERROR: x failed
  fix: run y" "ERROR: x" "fix: run y"
}

@test "contains fails on a missing piece and names it" {
  run zzd_contains "OK: fine" "ERROR:"
  [ "$status" -eq 1 ]
  [ "$output" = "not found: ERROR:" ]
}

@test "contains fails when pieces are out of order" {
  run zzd_contains "fix: y
ERROR: x" "ERROR: x" "fix: y"
  [ "$status" -eq 1 ]
}

@test "contains matches glob characters literally" {
  run zzd_contains "a.b" "a*b"
  [ "$status" -eq 1 ]
  zzd_contains "[x] *y*" "[x] *y*"
}

@test "a failing contains fails the test even when not last" {
  run bash -c "set -e; $(declare -f zzd_contains); zzd_contains a b; echo ran"
  [ "$status" -eq 1 ]
  [ "$output" = "not found: b" ]
}

@test "the mise passthrough stub answers which from this test's stubs" {
  zzd_stub osv-scanner 0
  zzd_stub_mise_passthrough
  [ "$(mise -C "$HOME" which osv-scanner)" = \
    "$BATS_TEST_TMPDIR/stubs/osv-scanner" ]
}

@test "the mise passthrough stub asks the real mise for everything else" {
  zzd_stub_mise_passthrough
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
