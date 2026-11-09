#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  for lib in log paths exec version misebin; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/mise" "$HOME/.local/bin"
  printf 'min_version = "2026.5.1"\n\n[tools]\n' >"$ZC_ROOT/mise/mise.toml"
  zc_hide_command mise
  BIN="$HOME/.local/bin/mise"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  zc_stub_script curl <<'EOF'
cat <<'SCRIPT'
echo "MISE_VERSION=$MISE_VERSION MISE_INSTALL_PATH=$MISE_INSTALL_PATH" \
  "MISE_INSTALL_HELP=$MISE_INSTALL_HELP" >>"$TRACE"
printf '#!/usr/bin/env bash\necho "%s macos-arm64"\n' "${MISE_VERSION#v}" \
  >"$MISE_INSTALL_PATH"
chmod +x "$MISE_INSTALL_PATH"
SCRIPT
EOF
}

mise_in() {
  printf '#!/usr/bin/env bash\necho "%s macos-arm64 (2026-10-27)"\n' "$2" \
    >"$1/mise"
  chmod +x "$1/mise"
}

@test "version reads the calendar version from mise --version" {
  mise_in "$HOME/.local/bin" "2026.11.4-DEBUG"
  run zc_mise_version "$BIN"
  [ "$output" = "2026.11.4" ]
}

@test "version is empty for a binary that does not print a version" {
  printf '#!/bin/sh\necho /some/path\n' >"$BIN"
  chmod +x "$BIN"
  run zc_mise_version "$BIN"
  [ -z "$output" ]
}

@test "ensure keeps a mise at or above min_version" {
  mise_in "$HOME/.local/bin" "2026.5.1"
  run zc_mise_ensure
  [ "$status" -eq 0 ]
  [ "$output" = "OK: mise 2026.5.1 (>= 2026.5.1)" ]
  [ -z "$(zc_calls curl)" ]
}

@test "ensure installs min_version over an older mise in ~/.local/bin" {
  mise_in "$HOME/.local/bin" "2026.4.24"
  run zc_mise_ensure
  [ "$status" -eq 0 ]
  zc_calls curl | grep -qx -- "-fsSL https://mise.run"
  grep -qx \
    "MISE_VERSION=v2026.5.1 MISE_INSTALL_PATH=$BIN MISE_INSTALL_HELP=0" \
    "$TRACE"
  [[ "$output" == *"CHANGED: mise 2026.4.24 -> 2026.5.1"* ]] || false
  [ "$(zc_mise_version "$BIN")" = "2026.5.1" ]
}

@test "ensure installs a missing mise" {
  run zc_mise_ensure
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHANGED: mise missing -> 2026.5.1"* ]] || false
}

@test "ensure refuses an older mise that comes before ~/.local/bin" {
  mkdir -p "$BATS_TEST_TMPDIR/other"
  mise_in "$BATS_TEST_TMPDIR/other" "2026.4.24"
  PATH="$BATS_TEST_TMPDIR/other:$PATH"
  run zc_mise_ensure
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: mise 2026.4.24 at $BATS_TEST_TMPDIR/other/mise is older" \
    "fix: remove $BATS_TEST_TMPDIR/other/mise, or put $HOME/.local/bin" \
    "before $BATS_TEST_TMPDIR/other on PATH"
  [ -z "$(zc_calls curl)" ]
}

@test "ensure reports a failed installer download" {
  zc_stub curl 22
  run zc_mise_ensure
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: cannot download the mise installer"
}

@test "ensure reports an installer that leaves the wrong version" {
  mise_in "$HOME/.local/bin" "2026.4.24"
  zc_stub_script curl 'echo true'
  run zc_mise_ensure
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: mise is 2026.4.24 after the install, expected 2026.5.1"
}

@test "ensure in dry-run installs nothing" {
  ZC_DRY_RUN=1 run zc_mise_ensure
  [ "$status" -eq 0 ]
  zc_contains "$output" "DRY-RUN: install mise 2026.5.1 from https://mise.run"
  [ -z "$(zc_calls curl)" ]
  [ ! -e "$BIN" ]
}

@test "ensure fails when min_version cannot be read" {
  printf '[tools]\n' >"$ZC_ROOT/mise/mise.toml"
  run zc_mise_ensure
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: cannot read min_version"
}

@test "ready and check agree on an old mise" {
  mise_in "$HOME/.local/bin" "2026.4.24"
  run zc_mise_ready
  [ "$status" -eq 1 ]
  run zc_mise_check
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: mise 2026.4.24 is older than 2026.5.1" \
    "fix: zconf apply mise"
}

@test "ready and check accept a newer mise" {
  mise_in "$HOME/.local/bin" "2099.1.1"
  run zc_mise_ready
  [ "$status" -eq 0 ]
  run zc_mise_check
  [ "$output" = "OK: mise 2099.1.1 (>= 2026.5.1)" ]
}
