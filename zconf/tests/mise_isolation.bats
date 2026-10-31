#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Runs the real mise against this repository's global config and a separate
# project config; no network and no installs.
setup() {
  load helpers
  zc_test_setup
  MISE_GLOBAL_CONFIG_FILE="$ZC_ROOT/mise/mise.toml"
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT"
  printf '[tools]\nshellcheck = "0.10.0"\n' >"$PROJECT/mise.toml"
  MISE_TRUSTED_CONFIG_PATHS="$PROJECT:$ZC_ROOT/mise"
  export MISE_GLOBAL_CONFIG_FILE MISE_TRUSTED_CONFIG_PATHS
}

@test "a project pin that is not in the global lock still resolves" {
  run --separate-stderr "$ZC_REAL_MISE" -C "$PROJECT" current shellcheck
  [ "$status" -eq 0 ]
  [ "$output" = "0.10.0" ]
  [[ "$stderr" != *"lockfile"* ]] || false
}

@test "working in a project leaves the global lock untouched" {
  before="$(cksum "$ZC_ROOT/mise/mise.lock")"
  "$ZC_REAL_MISE" -C "$PROJECT" current >/dev/null 2>&1 || true
  "$ZC_REAL_MISE" -C "$PROJECT" ls >/dev/null 2>&1 || true
  [ "$(cksum "$ZC_ROOT/mise/mise.lock")" = "$before" ]
  [ ! -e "$PROJECT/mise.lock" ]
}

@test "the global tools stay locked outside projects" {
  run --separate-stderr "$ZC_REAL_MISE" -C "$HOME" settings get locked
  [ "$output" = "false" ]
  grep -qx '\[tool_config\]' "$ZC_ROOT/mise/mise.toml"
}
