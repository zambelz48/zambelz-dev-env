#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZZD_ROOT/zzd/lib/log.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZZD_ROOT/zzd/lib/paths.sh"
  # shellcheck source=../lib/exec.sh
  . "$ZZD_ROOT/zzd/lib/exec.sh"
  # shellcheck source=../lib/links.sh
  . "$ZZD_ROOT/zzd/lib/links.sh"
  ZZD_ROOT="$BATS_TEST_TMPDIR/repo dir"
  ZZD_HOME="$BATS_TEST_TMPDIR/home dir"
  ZZD_STATE_DIR="$ZZD_HOME/.local/state/zzd"
  ZZD_MODULE="tmux"
  export ZZD_ROOT ZZD_HOME ZZD_STATE_DIR ZZD_MODULE
  mkdir -p "$ZZD_ROOT/tmux" "$ZZD_HOME"
  printf 'set -g mouse on\n' >"$ZZD_ROOT/tmux/.tmux.conf"
  LINKS="$BATS_TEST_TMPDIR/links"
  printf '# tmux config\n\ntmux/.tmux.conf\t.tmux.conf\n' >"$LINKS"
}

@test "apply creates a missing link" {
  run zzd_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [[ "$output" == "CHANGED:"* ]] || false
  [ "$(readlink "$ZZD_HOME/.tmux.conf")" = "$ZZD_ROOT/tmux/.tmux.conf" ]
}

@test "second apply changes nothing" {
  zzd_links_apply "$LINKS"
  run zzd_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [[ "$output" != *"CHANGED:"* ]] || false
  [[ "$output" == "OK:"* ]] || false
}

@test "apply replaces a symlink that points elsewhere" {
  ln -s /nonexistent "$ZZD_HOME/.tmux.conf"
  run zzd_links_apply "$LINKS"
  [[ "$output" == "CHANGED:"* ]] || false
  [ "$(readlink "$ZZD_HOME/.tmux.conf")" = "$ZZD_ROOT/tmux/.tmux.conf" ]
}

@test "apply backs up a real file instead of deleting it" {
  printf 'my local tmux\n' >"$ZZD_HOME/.tmux.conf"
  run zzd_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"backup:"* ]] || false
  backup="$(find "$ZZD_STATE_DIR/backup" -name .tmux.conf -type f)"
  [ "$(cat "$backup")" = "my local tmux" ]
  [ -L "$ZZD_HOME/.tmux.conf" ]
}

@test "two backups in the same second use different directories" {
  printf 'one\n' >"$ZZD_HOME/.tmux.conf"
  zzd_links_apply "$LINKS"
  rm "$ZZD_HOME/.tmux.conf"
  printf 'two\n' >"$ZZD_HOME/.tmux.conf"
  zzd_links_apply "$LINKS"
  count="$(find "$ZZD_STATE_DIR/backup" -name .tmux.conf | wc -l)"
  [ "$count" -eq 2 ]
}

@test "apply creates a missing parent directory" {
  mkdir -p "$ZZD_ROOT/kitty"
  printf 'font_size 12\n' >"$ZZD_ROOT/kitty/kitty.conf"
  printf 'kitty/kitty.conf\t.config/kitty/kitty.conf\n' >"$LINKS"
  run zzd_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [ -L "$ZZD_HOME/.config/kitty/kitty.conf" ]
}

@test "missing source is an error and nothing is linked" {
  printf 'tmux/absent.conf\t.absent.conf\n' >"$LINKS"
  run zzd_links_apply "$LINKS"
  [ "$status" -eq 1 ]
  [[ "$output" == "ERROR:"* ]] || false
  [ ! -e "$ZZD_HOME/.absent.conf" ]
  [ ! -L "$ZZD_HOME/.absent.conf" ]
}

@test "dry-run apply changes nothing" {
  printf 'mine\n' >"$ZZD_HOME/.tmux.conf"
  ZZD_DRY_RUN=1 run zzd_links_apply "$LINKS"
  [[ "$output" == *"DRY-RUN:"* ]] || false
  [ ! -L "$ZZD_HOME/.tmux.conf" ]
  [ "$(cat "$ZZD_HOME/.tmux.conf")" = "mine" ]
  [ ! -d "$ZZD_STATE_DIR/backup" ]
}

@test "check reports a missing link with the module fix and changes nothing" {
  run zzd_links_check "$LINKS"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "ERROR: not linked: .tmux.conf" ]
  [ "${lines[1]}" = "  fix: zzd apply tmux" ]
  [ ! -e "$ZZD_HOME/.tmux.conf" ]
}

@test "check reports a wrong symlink" {
  ln -s /nonexistent "$ZZD_HOME/.tmux.conf"
  run zzd_links_check "$LINKS"
  [ "$status" -eq 1 ]
  [ "$(readlink "$ZZD_HOME/.tmux.conf")" = "/nonexistent" ]
}

@test "check passes for a correct link" {
  zzd_links_apply "$LINKS"
  run zzd_links_check "$LINKS"
  [ "$status" -eq 0 ]
  [ "$output" = "OK: linked .tmux.conf" ]
}
