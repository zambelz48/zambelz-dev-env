#!/usr/bin/env bats

# Real mise, global config, no installs: a project directory that pins
# other versions must not change which binary zzd runs.
setup() {
  load helpers
  zzd_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZZD_ROOT/zzd/lib/log.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZZD_ROOT/zzd/lib/paths.sh"
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT"
  MISE_TRUSTED_CONFIG_PATHS="$PROJECT"
  export MISE_TRUSTED_CONFIG_PATHS
}

@test "zzd_tool returns the global binary inside a project pinning another" {
  echo 3.10.19 >"$PROJECT/.python-version"
  global="$("$ZZD_REAL_MISE" -C "$HOME" which python3)"
  cd "$PROJECT"
  run zzd_tool python3
  [ "$status" -eq 0 ]
  [ "$output" = "$global" ]
}

@test "zzd_python runs the global interpreter, so tomllib is there" {
  echo 3.10.19 >"$PROJECT/.python-version"
  cd "$PROJECT"
  run zzd_python -c 'import tomllib'
  [ "$status" -eq 0 ]
}

@test "zzd_python in a project asking for a missing version installs nothing" {
  echo 3.99.99 >"$PROJECT/.python-version"
  cd "$PROJECT"
  run zzd_python -c 'import sys; print(sys.version_info[0])'
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
  [ ! -e "$MISE_DATA_DIR/installs/python/3.99.99" ]
}

@test "zzd_tool fails for a binary no global tool provides" {
  run zzd_tool zzd-no-such-binary
  [ "$status" -eq 1 ]
}
