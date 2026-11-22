#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZZD_ROOT/zzd/lib/log.sh"
  zzd_log_init
}

@test "warn prints the message and the fix on its own line" {
  run zzd_warn "shims not first on PATH" "zzd apply mise"
  [ "${lines[0]}" = "WARN: shims not first on PATH" ]
  [ "${lines[1]}" = "  fix: zzd apply mise" ]
}

@test "changed is silent and uncounted during a dry run" {
  ZZD_DRY_RUN=1 run zzd_changed "linked .zshrc"
  [ -z "$output" ]
  run zzd_summary
  [ "$output" = "Summary: 0 changed, 0 ok, 0 warnings, 0 errors" ]
}

@test "error without a fix prints a single line" {
  run zzd_error "unsupported OS"
  [ "$output" = "ERROR: unsupported OS" ]
}

@test "summary counts markers emitted from subshells and fails on errors" {
  (zzd_changed "linked .zshrc")
  (zzd_ok "tmux at pin")
  zzd_ok "kitty linked"
  zzd_error "mise missing"
  run zzd_summary
  [ "$status" -eq 1 ]
  [ "$output" = "Summary: 1 changed, 2 ok, 0 warnings, 1 errors" ]
}

@test "summary succeeds when there are only warnings" {
  zzd_warn "old pyenv install present"
  zzd_changed "linked .tmux.conf"
  run zzd_summary
  [ "$status" -eq 0 ]
  [ "$output" = "Summary: 1 changed, 0 ok, 1 warnings, 0 errors" ]
}

@test "log init keeps an already exported run log" {
  first="$ZZD_RUN_LOG"
  zzd_log_init
  [ "$ZZD_RUN_LOG" = "$first" ]
}
