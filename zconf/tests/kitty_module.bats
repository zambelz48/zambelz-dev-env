#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/kitty"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  cp -R "$REAL/kitty/zconf" "$ZC_ROOT/kitty/zconf"
  printf 'font_family Fira Code\n' >"$ZC_ROOT/kitty/kitty.base.conf"
  for lib in log paths os exec links fonts modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  CONF="$ZC_ROOT/kitty/kitty.conf"
  FONTSRC="$BATS_TEST_TMPDIR/nerd-fonts"
  mkdir -p "$FONTSRC"
  printf 'hack\n' >"$FONTSRC/HackNerdFont-Regular.ttf"
  zc_stub_script mise <<EOF
case "\$*" in
  *" where github:ryanoasis/nerd-fonts") echo "$FONTSRC" ;;
  *) exit 1 ;;
esac
EOF
  zc_stub uname 0 "Darwin"
}

@test "apply installs Hack Nerd Font from the mise nerd-fonts pin" {
  run zc_module_run kitty apply
  [ "$status" -eq 0 ]
  cmp "$FONTSRC/HackNerdFont-Regular.ttf" \
    "$HOME/Library/Fonts/HackNerdFont-Regular.ttf"
}

@test "apply generates a missing kitty.conf with the include and font size" {
  run zc_module_run kitty apply
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$CONF")" = "include kitty.base.conf" ]
  grep -qx 'font_size 12.0' "$CONF"
  [[ "$output" == *"CHANGED: generated kitty/kitty.conf"* ]] || false
}

@test "apply leaves an existing kitty.conf untouched" {
  printf 'include kitty.base.conf\nfont_size 15.0\n' >"$CONF"
  run zc_module_run kitty apply
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "$(printf 'include kitty.base.conf\nfont_size 15.0')" ]
  [[ "$output" != *"generated"* ]] || false
}

@test "apply links both files into a missing ~/.config/kitty" {
  run zc_module_run kitty apply
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/kitty/kitty.conf")" = "$CONF" ]
  [ "$(readlink "$HOME/.config/kitty/kitty.base.conf")" = \
    "$ZC_ROOT/kitty/kitty.base.conf" ]
}

@test "dry-run apply does not generate kitty.conf" {
  ZC_DRY_RUN=1 run zc_module_run kitty apply
  [ ! -e "$CONF" ]
  [[ "$output" == *"DRY-RUN: generate kitty/kitty.conf"* ]] || false
}
