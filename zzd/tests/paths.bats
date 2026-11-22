#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZC_ROOT/zconf/lib/log.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZC_ROOT/zconf/lib/paths.sh"
}

@test "an entry is a data line" {
  zc_is_data_line "alpha"
  zc_is_data_line "  # indented is data"
}

@test "blank lines and comments are not data lines" {
  run zc_is_data_line ""
  [ "$status" -eq 1 ]
  run zc_is_data_line "# comment"
  [ "$status" -eq 1 ]
}
