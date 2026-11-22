#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
  zzd_test_setup
  REPO="$ZZD_ROOT"
  FIX="$BATS_TEST_TMPDIR/repo dir"
  mkdir -p "$FIX"
  cp -R "$ZZD_ROOT/zzd" "$FIX/zzd"
  mkdir -p "$FIX/alpha/zzd" "$FIX/beta/zzd" "$FIX/mise"
  printf 'alpha\nbeta\n' >"$FIX/zzd/modules"
  printf 'min_version = "2026.1.1"\n' >"$FIX/mise/mise.toml"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  for m in alpha beta; do
    printf "mod_apply() { echo %s >>\"\$TRACE\"; zzd_ok %s; }\n" "$m" "$m" \
      >"$FIX/$m/zzd/apply.sh"
  done
  ZZD="$FIX/zzd/bin/zzd"
  unset ZZD_ROOT
}

@test "help exits 0 and lists the commands" {
  run "$ZZD" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"apply"*"doctor"*"update"*"lint"* ]] || false
}

@test "an unknown command exits 2 with usage on stderr" {
  run --separate-stderr "$ZZD" frobnicate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage: zzd"* ]] || false
}

@test "an unknown module exits 2" {
  run "$ZZD" apply ghost
  [ "$status" -eq 2 ]
}

@test "apply runs every module in registry order and summarizes" {
  run "$ZZD" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "$(printf 'alpha\nbeta')" ]
  [[ "$output" == *"Summary: 0 changed, 2 ok, 0 warnings, 0 errors"* ]] || false
}

@test "apply with module names runs only those" {
  run "$ZZD" apply beta
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "beta" ]
}

@test "apply exits 1 when a module fails and still runs the others" {
  printf 'mod_apply() { return 1; }\n' >"$FIX/alpha/zzd/apply.sh"
  run "$ZZD" apply
  [ "$status" -eq 1 ]
  [ "$(cat "$TRACE")" = "beta" ]
}

@test "apply --dry-run writes nothing" {
  printf 'x\n' >"$FIX/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$FIX/alpha/zzd/links"
  run "$ZZD" apply --dry-run alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN: link .alpha"* ]] || false
  [ ! -L "$HOME/.alpha" ]
}

@test "legacy form 'zzd <module>' applies that module" {
  run "$ZZD" beta
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "beta" ]
}

pin_files() {
  mkdir -p "$FIX/mise/zzd" "$FIX/zsh/zzd" "$FIX/tmux/zzd" \
    "$FIX/tools/npm" "$FIX/tools/python"
  for f in mise/mise.toml mise/mise.lock mise/zzd/platforms \
    zsh/zzd/pins tmux/.tmux.conf tmux/zzd/pins \
    tools/npm/package.json tools/npm/pnpm-lock.yaml \
    tools/python/pyproject.toml tools/python/uv.lock; do
    cp "$REPO/$f" "$FIX/$f"
  done
}

@test "check-pins passes on the repository's pin files" {
  pin_files
  run "$ZZD" check-pins
  [ "$status" -eq 0 ]
  [[ "$output" == "OK: pins exact and locked"* ]] || false
}

@test "check-pins fails on a floating pin" {
  pin_files
  printf 'OHMYZSH_COMMIT=master\n' >"$FIX/zsh/zzd/pins"
  run "$ZZD" check-pins
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: OHMYZSH_COMMIT is not a full commit sha"* ]] ||
    false
}

@test "audit runs every scope by default" {
  zzd_stub_mise_passthrough
  printf 'import sys\nopen(%s, "w").write(" ".join(sys.argv[1:]))\n' "'$BATS_TEST_TMPDIR/engine-args'" \
    >"$FIX/zzd/lib/audit/__main__.py"

  run "$ZZD" audit

  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/engine-args")" = "audit --all" ]
}

@test "audit with an unknown mode exits 2" {
  run "$ZZD" audit --everything
  [ "$status" -eq 2 ]
}

auto_install_probe() {
  local phase
  for phase in apply doctor update; do
    # shellcheck disable=SC2016 # script text, expanded when the phase runs
    printf 'mod_%s() { echo "%s auto=${MISE_AUTO_INSTALL:-unset}"; }\n' \
      "$phase" "$phase" >"$FIX/alpha/zzd/$phase.sh"
  done
}

@test "read-only commands turn off mise auto-install for their process" {
  auto_install_probe
  run "$ZZD" doctor alpha
  zzd_contains "$output" "doctor auto=0"
  run "$ZZD" update alpha
  zzd_contains "$output" "update auto=0"
}

@test "apply leaves mise auto-install alone" {
  auto_install_probe
  run "$ZZD" apply alpha
  zzd_contains "$output" "apply auto=unset"
}

@test "zzd removes its run log when it exits" {
  run "$ZZD" apply alpha
  [ "$status" -eq 0 ]
  run "$ZZD" doctor alpha
  [ "$(find "$TMPDIR" -maxdepth 1 -name 'zzd-run.*' | wc -l)" -eq 0 ]
}

@test "use without a tool and version exits 2" {
  run "$ZZD" use node
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: zzd use <tool> <version>"* ]] || false
}

@test "upgrade rejects an unknown option" {
  run "$ZZD" upgrade --everything
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR: unknown option: --everything"* ]] || false
}

@test "zzd finds the bootstrap mise when PATH lacks it" {
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho "OK: fake python"\n' >"$BATS_TEST_TMPDIR/py"
  # shellcheck disable=SC2016 # script text, expanded when the stub runs
  printf '#!/bin/sh\n[ "$1" = --version ] && echo 2099.1.1 && exit\n' \
    >"$HOME/.local/bin/mise"
  printf 'echo %s\n' "$BATS_TEST_TMPDIR/py" >>"$HOME/.local/bin/mise"
  chmod +x "$BATS_TEST_TMPDIR/py" "$HOME/.local/bin/mise"
  run env PATH=/usr/bin:/bin "$ZZD" check-pins
  [ "$status" -eq 0 ]
  [ "$output" = "OK: fake python" ]
}

old_mise() {
  zzd_stub_script mise 'echo "2026.1.0 macos-arm64"'
}

@test "commands that need mise stop on an old mise with the apply fix" {
  old_mise
  for args in "doctor alpha" "update alpha" check-pins audit lint \
    "upgrade --yes" "use node 24" "apply alpha"; do
    # shellcheck disable=SC2086 # split into command and arguments
    run "$ZZD" $args
    [ "$status" -eq 1 ]
    zzd_contains "$output" "ERROR: mise 2026.1.0 is older than 2026.1.1" \
      "fix: zzd apply mise"
  done
  [ ! -e "$TRACE" ]
}

@test "apply that includes mise is not stopped by an old mise" {
  old_mise
  run "$ZZD" apply
  [ "$(cat "$TRACE")" = "$(printf 'alpha\nbeta')" ]
}

@test "a missing mise is reported with the apply fix" {
  zzd_hide_command mise
  run "$ZZD" doctor alpha
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: mise is not installed (min_version 2026.1.1)" \
    "fix: zzd apply mise"
}

@test "zzd works when called through a symlink" {
  mkdir -p "$HOME/bin"
  ln -s "$ZZD" "$HOME/bin/zzd"
  run "$HOME/bin/zzd" apply beta
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "beta" ]
}
