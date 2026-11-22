#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZZD_ROOT/zzd/lib/log.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZZD_ROOT/zzd/lib/paths.sh"
}

@test "an entry is a data line" {
  zzd_is_data_line "alpha"
  zzd_is_data_line "  # indented is data"
}

@test "blank lines and comments are not data lines" {
  run zzd_is_data_line ""
  [ "$status" -eq 1 ]
  run zzd_is_data_line "# comment"
  [ "$status" -eq 1 ]
}
