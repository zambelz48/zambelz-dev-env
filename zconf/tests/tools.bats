#!/usr/bin/env bats

# Real mise, global config, no installs: a project directory that pins
# other versions must not change which binary zconf runs.
setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZC_ROOT/zconf/lib/log.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZC_ROOT/zconf/lib/paths.sh"
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT"
  MISE_TRUSTED_CONFIG_PATHS="$PROJECT"
  export MISE_TRUSTED_CONFIG_PATHS
}

@test "zc_tool returns the global binary inside a project pinning another" {
  echo 3.10.19 >"$PROJECT/.python-version"
  global="$("$ZC_REAL_MISE" -C "$HOME" which python3)"
  cd "$PROJECT"
  run zc_tool python3
  [ "$status" -eq 0 ]
  [ "$output" = "$global" ]
}

@test "zc_python runs the global interpreter, so tomllib is there" {
  echo 3.10.19 >"$PROJECT/.python-version"
  cd "$PROJECT"
  run zc_python -c 'import tomllib'
  [ "$status" -eq 0 ]
}

@test "zc_python in a project asking for a missing version installs nothing" {
  echo 3.99.99 >"$PROJECT/.python-version"
  cd "$PROJECT"
  run zc_python -c 'import sys; print(sys.version_info[0])'
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
  [ ! -e "$MISE_DATA_DIR/installs/python/3.99.99" ]
}

@test "zc_tool fails for a binary no global tool provides" {
  run zc_tool zconf-no-such-binary
  [ "$status" -eq 1 ]
}
