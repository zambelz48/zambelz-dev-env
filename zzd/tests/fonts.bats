#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  for lib in log paths os exec fonts; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  unset XDG_DATA_HOME
  ZC_MODULE=kitty
  export ZC_MODULE
  SRC="$BATS_TEST_TMPDIR/install"
  mkdir -p "$SRC"
  printf 'regular\n' >"$SRC/Hack-Regular.ttf"
  printf 'bold\n' >"$SRC/Hack-Bold.otf"
  printf 'readme\n' >"$SRC/README.md"
  MANIFEST="$BATS_TEST_TMPDIR/fonts"
  printf '# fonts\ngithub:example/fonts\n' >"$MANIFEST"
  zc_stub_script mise <<EOF
case "\$*" in
  *" where github:example/fonts") echo "$SRC" ;;
  *) exit 1 ;;
esac
EOF
  zc_stub uname 0 "Darwin"
  MAC="$HOME/Library/Fonts"
}

on_fedora() {
  zc_stub uname 0 "Linux"
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZC_OS_RELEASE
  printf 'ID=fedora\n' >"$ZC_OS_RELEASE"
  zc_stub fc-cache 0
}

@test "apply copies the tool's font files into ~/Library/Fonts on macOS" {
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  cmp "$SRC/Hack-Regular.ttf" "$MAC/Hack-Regular.ttf"
  cmp "$SRC/Hack-Bold.otf" "$MAC/Hack-Bold.otf"
  [ ! -e "$MAC/README.md" ]
  zc_contains "$output" \
    "CHANGED: installed fonts from github:example/fonts: Hack-Bold.otf"
}

@test "a second apply changes nothing" {
  zc_fonts_apply "$MANIFEST"
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: github:example/fonts fonts in $MAC"* ]] || false
  [[ "$output" != *"CHANGED"* ]] || false
}

@test "apply replaces a font file whose content differs" {
  zc_fonts_apply "$MANIFEST"
  printf 'regular v2\n' >"$SRC/Hack-Regular.ttf"
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  cmp "$SRC/Hack-Regular.ttf" "$MAC/Hack-Regular.ttf"
  zc_contains "$output" \
    "CHANGED: installed fonts from github:example/fonts: Hack-Regular.ttf"
}

@test "apply removes fonts it installed that the tool no longer ships" {
  zc_fonts_apply "$MANIFEST"
  rm "$SRC/Hack-Bold.otf"
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  [ ! -e "$MAC/Hack-Bold.otf" ]
  [ -e "$MAC/Hack-Regular.ttf" ]
  zc_contains "$output" \
    "CHANGED: removed fonts no longer in github:example/fonts: Hack-Bold.otf"
}

@test "apply never removes fonts it did not install" {
  mkdir -p "$MAC"
  printf 'other\n' >"$MAC/Other.ttf"
  zc_fonts_apply "$MANIFEST"
  rm "$SRC/Hack-Bold.otf"
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  [ "$(cat "$MAC/Other.ttf")" = "other" ]
}

@test "apply on Linux installs into XDG_DATA_HOME/fonts, refreshes fc-cache" {
  on_fedora
  XDG_DATA_HOME="$BATS_TEST_TMPDIR/xdg"
  export XDG_DATA_HOME
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  cmp "$SRC/Hack-Regular.ttf" "$XDG_DATA_HOME/fonts/Hack-Regular.ttf"
  [ "$(zc_calls fc-cache)" = "$XDG_DATA_HOME/fonts" ]
}

@test "apply on Linux without XDG_DATA_HOME uses ~/.local/share/fonts" {
  on_fedora
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  [ -e "$HOME/.local/share/fonts/Hack-Regular.ttf" ]
}

@test "an unchanged apply on Linux does not refresh fc-cache" {
  on_fedora
  zc_fonts_apply "$MANIFEST"
  rm "$BATS_TEST_TMPDIR/calls/fc-cache"
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  [ -z "$(zc_calls fc-cache)" ]
}

@test "dry-run apply copies nothing" {
  ZC_DRY_RUN=1 run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 0 ]
  [ ! -e "$MAC/Hack-Regular.ttf" ]
  [[ "$output" == *"DRY-RUN: cp $SRC/Hack-Regular.ttf"* ]] || false
}

@test "apply fails with a fix when the tool is not installed by mise" {
  printf 'github:example/missing\n' >"$MANIFEST"
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: github:example/missing is not installed by mise" \
    "fix: zconf apply mise"
}

@test "apply fails when the tool ships no font files" {
  rm "$SRC"/*.ttf "$SRC"/*.otf
  run zc_fonts_apply "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: github:example/fonts has no font files"* ]] ||
    false
}

@test "doctor passes when every font is installed and current" {
  zc_fonts_apply "$MANIFEST"
  run zc_fonts_check "$MANIFEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: github:example/fonts fonts in $MAC"* ]] || false
}

@test "doctor reports a missing font with the fix and copies nothing" {
  run zc_fonts_check "$MANIFEST"
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: Hack-Bold.otf from github:example/fonts is missing or outdated" \
    "fix: zconf apply kitty"
  [ ! -e "$MAC/Hack-Bold.otf" ]
}
