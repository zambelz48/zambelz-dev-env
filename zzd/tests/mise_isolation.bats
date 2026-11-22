#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Runs the real mise against this repository's global config and a separate
# project config; no network and no installs.
setup() {
  load helpers
  zzd_test_setup
  MISE_GLOBAL_CONFIG_FILE="$ZZD_ROOT/mise/mise.toml"
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT"
  printf '[tools]\nshellcheck = "0.10.0"\n' >"$PROJECT/mise.toml"
  MISE_TRUSTED_CONFIG_PATHS="$PROJECT:$ZZD_ROOT/mise"
  export MISE_GLOBAL_CONFIG_FILE MISE_TRUSTED_CONFIG_PATHS
}

@test "a project pin that is not in the global lock still resolves" {
  run --separate-stderr "$ZZD_REAL_MISE" -C "$PROJECT" current shellcheck
  [ "$status" -eq 0 ]
  [ "$output" = "0.10.0" ]
  [[ "$stderr" != *"lockfile"* ]] || false
}

@test "working in a project leaves the global lock untouched" {
  before="$(cksum "$ZZD_ROOT/mise/mise.lock")"
  "$ZZD_REAL_MISE" -C "$PROJECT" current >/dev/null 2>&1 || true
  "$ZZD_REAL_MISE" -C "$PROJECT" ls >/dev/null 2>&1 || true
  [ "$(cksum "$ZZD_ROOT/mise/mise.lock")" = "$before" ]
  [ ! -e "$PROJECT/mise.lock" ]
}

@test "the global tools stay locked outside projects" {
  run --separate-stderr "$ZZD_REAL_MISE" -C "$HOME" settings get locked
  [ "$output" = "false" ]
  grep -qx '\[tool_config\]' "$ZZD_ROOT/mise/mise.toml"
}
