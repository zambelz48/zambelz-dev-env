#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  REAL="$ZZD_ROOT"
  ZZD_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZZD_ROOT
  mkdir -p "$ZZD_ROOT/kitty"
  cp -R "$REAL/zzd" "$ZZD_ROOT/zzd"
  cp -R "$REAL/kitty/zzd" "$ZZD_ROOT/kitty/zzd"
  printf 'font_family Fira Code\n' >"$ZZD_ROOT/kitty/kitty.base.conf"
  for lib in log paths os exec links fonts modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
  CONF="$ZZD_ROOT/kitty/kitty.conf"
  FONTSRC="$BATS_TEST_TMPDIR/nerd-fonts"
  mkdir -p "$FONTSRC"
  printf 'hack\n' >"$FONTSRC/HackNerdFont-Regular.ttf"
  zzd_stub_script mise <<EOF
case "\$*" in
  *" where github:ryanoasis/nerd-fonts") echo "$FONTSRC" ;;
  *) exit 1 ;;
esac
EOF
  zzd_stub uname 0 "Darwin"
}

@test "apply installs Hack Nerd Font from the mise nerd-fonts pin" {
  run zzd_module_run kitty apply
  [ "$status" -eq 0 ]
  cmp "$FONTSRC/HackNerdFont-Regular.ttf" \
    "$HOME/Library/Fonts/HackNerdFont-Regular.ttf"
}

@test "apply generates a missing kitty.conf with the include and font size" {
  run zzd_module_run kitty apply
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$CONF")" = "include kitty.base.conf" ]
  grep -qx 'font_size 12.0' "$CONF"
  [[ "$output" == *"CHANGED: generated kitty/kitty.conf"* ]] || false
}

@test "apply leaves an existing kitty.conf untouched" {
  printf 'include kitty.base.conf\nfont_size 15.0\n' >"$CONF"
  run zzd_module_run kitty apply
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "$(printf 'include kitty.base.conf\nfont_size 15.0')" ]
  [[ "$output" != *"generated"* ]] || false
}

@test "apply links both files into a missing ~/.config/kitty" {
  run zzd_module_run kitty apply
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/kitty/kitty.conf")" = "$CONF" ]
  [ "$(readlink "$HOME/.config/kitty/kitty.base.conf")" = \
    "$ZZD_ROOT/kitty/kitty.base.conf" ]
}

@test "dry-run apply does not generate kitty.conf" {
  ZZD_DRY_RUN=1 run zzd_module_run kitty apply
  [ ! -e "$CONF" ]
  [[ "$output" == *"DRY-RUN: generate kitty/kitty.conf"* ]] || false
}
