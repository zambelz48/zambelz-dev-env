#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZC_ROOT/zconf/lib/log.sh"
  zc_log_init
}

@test "warn prints the message and the fix on its own line" {
  run zc_warn "shims not first on PATH" "zconf apply mise"
  [ "${lines[0]}" = "WARN: shims not first on PATH" ]
  [ "${lines[1]}" = "  fix: zconf apply mise" ]
}

@test "changed is silent and uncounted during a dry run" {
  ZC_DRY_RUN=1 run zc_changed "linked .zshrc"
  [ -z "$output" ]
  run zc_summary
  [ "$output" = "Summary: 0 changed, 0 ok, 0 warnings, 0 errors" ]
}

@test "error without a fix prints a single line" {
  run zc_error "unsupported OS"
  [ "$output" = "ERROR: unsupported OS" ]
}

@test "summary counts markers emitted from subshells and fails on errors" {
  (zc_changed "linked .zshrc")
  (zc_ok "tmux at pin")
  zc_ok "kitty linked"
  zc_error "mise missing"
  run zc_summary
  [ "$status" -eq 1 ]
  [ "$output" = "Summary: 1 changed, 2 ok, 0 warnings, 1 errors" ]
}

@test "summary succeeds when there are only warnings" {
  zc_warn "old pyenv install present"
  zc_changed "linked .tmux.conf"
  run zc_summary
  [ "$status" -eq 0 ]
  [ "$output" = "Summary: 1 changed, 0 ok, 1 warnings, 0 errors" ]
}

@test "log init keeps an already exported run log" {
  first="$ZC_RUN_LOG"
  zc_log_init
  [ "$ZC_RUN_LOG" = "$first" ]
}
