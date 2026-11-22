#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZC_ROOT/zconf/lib/log.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZC_ROOT/zconf/lib/paths.sh"
  # shellcheck source=../lib/exec.sh
  . "$ZC_ROOT/zconf/lib/exec.sh"
  # shellcheck source=../lib/links.sh
  . "$ZC_ROOT/zconf/lib/links.sh"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo dir"
  ZC_HOME="$BATS_TEST_TMPDIR/home dir"
  ZC_STATE_DIR="$ZC_HOME/.local/state/zconf"
  ZC_MODULE="tmux"
  export ZC_ROOT ZC_HOME ZC_STATE_DIR ZC_MODULE
  mkdir -p "$ZC_ROOT/tmux" "$ZC_HOME"
  printf 'set -g mouse on\n' >"$ZC_ROOT/tmux/.tmux.conf"
  LINKS="$BATS_TEST_TMPDIR/links"
  printf '# tmux config\n\ntmux/.tmux.conf\t.tmux.conf\n' >"$LINKS"
}

@test "apply creates a missing link" {
  run zc_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [[ "$output" == "CHANGED:"* ]] || false
  [ "$(readlink "$ZC_HOME/.tmux.conf")" = "$ZC_ROOT/tmux/.tmux.conf" ]
}

@test "second apply changes nothing" {
  zc_links_apply "$LINKS"
  run zc_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [[ "$output" != *"CHANGED:"* ]] || false
  [[ "$output" == "OK:"* ]] || false
}

@test "apply replaces a symlink that points elsewhere" {
  ln -s /nonexistent "$ZC_HOME/.tmux.conf"
  run zc_links_apply "$LINKS"
  [[ "$output" == "CHANGED:"* ]] || false
  [ "$(readlink "$ZC_HOME/.tmux.conf")" = "$ZC_ROOT/tmux/.tmux.conf" ]
}

@test "apply backs up a real file instead of deleting it" {
  printf 'my local tmux\n' >"$ZC_HOME/.tmux.conf"
  run zc_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"backup:"* ]] || false
  backup="$(find "$ZC_STATE_DIR/backup" -name .tmux.conf -type f)"
  [ "$(cat "$backup")" = "my local tmux" ]
  [ -L "$ZC_HOME/.tmux.conf" ]
}

@test "two backups in the same second use different directories" {
  printf 'one\n' >"$ZC_HOME/.tmux.conf"
  zc_links_apply "$LINKS"
  rm "$ZC_HOME/.tmux.conf"
  printf 'two\n' >"$ZC_HOME/.tmux.conf"
  zc_links_apply "$LINKS"
  count="$(find "$ZC_STATE_DIR/backup" -name .tmux.conf | wc -l)"
  [ "$count" -eq 2 ]
}

@test "apply creates a missing parent directory" {
  mkdir -p "$ZC_ROOT/kitty"
  printf 'font_size 12\n' >"$ZC_ROOT/kitty/kitty.conf"
  printf 'kitty/kitty.conf\t.config/kitty/kitty.conf\n' >"$LINKS"
  run zc_links_apply "$LINKS"
  [ "$status" -eq 0 ]
  [ -L "$ZC_HOME/.config/kitty/kitty.conf" ]
}

@test "missing source is an error and nothing is linked" {
  printf 'tmux/absent.conf\t.absent.conf\n' >"$LINKS"
  run zc_links_apply "$LINKS"
  [ "$status" -eq 1 ]
  [[ "$output" == "ERROR:"* ]] || false
  [ ! -e "$ZC_HOME/.absent.conf" ]
  [ ! -L "$ZC_HOME/.absent.conf" ]
}

@test "dry-run apply changes nothing" {
  printf 'mine\n' >"$ZC_HOME/.tmux.conf"
  ZC_DRY_RUN=1 run zc_links_apply "$LINKS"
  [[ "$output" == *"DRY-RUN:"* ]] || false
  [ ! -L "$ZC_HOME/.tmux.conf" ]
  [ "$(cat "$ZC_HOME/.tmux.conf")" = "mine" ]
  [ ! -d "$ZC_STATE_DIR/backup" ]
}

@test "check reports a missing link with the module fix and changes nothing" {
  run zc_links_check "$LINKS"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "ERROR: not linked: .tmux.conf" ]
  [ "${lines[1]}" = "  fix: zconf apply tmux" ]
  [ ! -e "$ZC_HOME/.tmux.conf" ]
}

@test "check reports a wrong symlink" {
  ln -s /nonexistent "$ZC_HOME/.tmux.conf"
  run zc_links_check "$LINKS"
  [ "$status" -eq 1 ]
  [ "$(readlink "$ZC_HOME/.tmux.conf")" = "/nonexistent" ]
}

@test "check passes for a correct link" {
  zc_links_apply "$LINKS"
  run zc_links_check "$LINKS"
  [ "$status" -eq 0 ]
  [ "$output" = "OK: linked .tmux.conf" ]
}
