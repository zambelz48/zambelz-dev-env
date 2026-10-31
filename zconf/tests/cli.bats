#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
  zc_test_setup
  REPO="$ZC_ROOT"
  FIX="$BATS_TEST_TMPDIR/repo dir"
  mkdir -p "$FIX"
  cp -R "$ZC_ROOT/zconf" "$FIX/zconf"
  mkdir -p "$FIX/alpha/zconf" "$FIX/beta/zconf"
  printf 'alpha\nbeta\n' >"$FIX/zconf/modules"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  for m in alpha beta; do
    printf "mod_apply() { echo %s >>\"\$TRACE\"; zc_ok %s; }\n" "$m" "$m" \
      >"$FIX/$m/zconf/apply.sh"
  done
  ZCONF="$FIX/zconf/bin/zconf"
  unset ZC_ROOT
}

@test "help exits 0 and lists the commands" {
  run "$ZCONF" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"apply"*"doctor"*"update"*"lint"* ]] || false
}

@test "an unknown command exits 2 with usage on stderr" {
  run --separate-stderr "$ZCONF" frobnicate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage: zconf"* ]] || false
}

@test "an unknown module exits 2" {
  run "$ZCONF" apply ghost
  [ "$status" -eq 2 ]
}

@test "apply runs every module in registry order and summarizes" {
  run "$ZCONF" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "$(printf 'alpha\nbeta')" ]
  [[ "$output" == *"Summary: 0 changed, 2 ok, 0 warnings, 0 errors"* ]] || false
}

@test "apply with module names runs only those" {
  run "$ZCONF" apply beta
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "beta" ]
}

@test "apply exits 1 when a module fails and still runs the others" {
  printf 'mod_apply() { return 1; }\n' >"$FIX/alpha/zconf/apply.sh"
  run "$ZCONF" apply
  [ "$status" -eq 1 ]
  [ "$(cat "$TRACE")" = "beta" ]
}

@test "apply --dry-run writes nothing" {
  printf 'x\n' >"$FIX/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$FIX/alpha/zconf/links"
  run "$ZCONF" apply --dry-run alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN: link .alpha"* ]] || false
  [ ! -L "$HOME/.alpha" ]
}

@test "legacy form 'zconf <module>' applies that module" {
  run "$ZCONF" beta
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "beta" ]
}

pin_files() {
  mkdir -p "$FIX/mise/zconf" "$FIX/zsh/zconf" "$FIX/tmux/zconf" \
    "$FIX/tools/npm" "$FIX/tools/python"
  for f in mise/mise.toml mise/mise.lock mise/zconf/platforms \
    zsh/zconf/pins tmux/.tmux.conf tmux/zconf/pins \
    tools/npm/package.json tools/npm/pnpm-lock.yaml \
    tools/python/pyproject.toml tools/python/uv.lock; do
    cp "$REPO/$f" "$FIX/$f"
  done
}

@test "check-pins passes on the repository's pin files" {
  pin_files
  run "$ZCONF" check-pins
  [ "$status" -eq 0 ]
  [[ "$output" == "OK: pins exact and locked"* ]] || false
}

@test "check-pins fails on a floating pin" {
  pin_files
  printf 'OHMYZSH_COMMIT=master\n' >"$FIX/zsh/zconf/pins"
  run "$ZCONF" check-pins
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: OHMYZSH_COMMIT is not a full commit sha"* ]] ||
    false
}

@test "audit runs the declared scan by default" {
  zc_stub_mise_passthrough
  zc_stub osv-scanner 0
  mkdir -p "$FIX/mise"
  printf 'lockfile_version = 3\n' >"$FIX/mise/mise.lock"
  run "$ZCONF" audit
  [ "$status" -eq 0 ]
  zc_calls osv-scanner | grep -q -- "-L osv-scanner:"
}

@test "audit with an unknown mode exits 2" {
  run "$ZCONF" audit --everything
  [ "$status" -eq 2 ]
}

auto_install_probe() {
  local phase
  for phase in apply doctor update; do
    # shellcheck disable=SC2016 # script text, expanded when the phase runs
    printf 'mod_%s() { echo "%s auto=${MISE_AUTO_INSTALL:-unset}"; }\n' \
      "$phase" "$phase" >"$FIX/alpha/zconf/$phase.sh"
  done
}

@test "read-only commands turn off mise auto-install for their process" {
  auto_install_probe
  run "$ZCONF" doctor alpha
  zc_contains "$output" "doctor auto=0"
  run "$ZCONF" update alpha
  zc_contains "$output" "update auto=0"
}

@test "apply leaves mise auto-install alone" {
  auto_install_probe
  run "$ZCONF" apply alpha
  zc_contains "$output" "apply auto=unset"
}

@test "zconf removes its run log when it exits" {
  run "$ZCONF" apply alpha
  [ "$status" -eq 0 ]
  run "$ZCONF" doctor alpha
  [ "$(find "$TMPDIR" -maxdepth 1 -name 'zconf-run.*' | wc -l)" -eq 0 ]
}

@test "use without a tool and version exits 2" {
  run "$ZCONF" use node
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: zconf use <tool> <version>"* ]] || false
}

@test "upgrade rejects an unknown option" {
  run "$ZCONF" upgrade --everything
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR: unknown option: --everything"* ]] || false
}

@test "zconf finds the bootstrap mise when PATH lacks it" {
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho "OK: fake python"\n' >"$BATS_TEST_TMPDIR/py"
  printf '#!/bin/sh\necho %s\n' "$BATS_TEST_TMPDIR/py" \
    >"$HOME/.local/bin/mise"
  chmod +x "$BATS_TEST_TMPDIR/py" "$HOME/.local/bin/mise"
  run env PATH=/usr/bin:/bin "$ZCONF" check-pins
  [ "$status" -eq 0 ]
  [ "$output" = "OK: fake python" ]
}

@test "zconf works when called through a symlink" {
  mkdir -p "$HOME/bin"
  ln -s "$ZCONF" "$HOME/bin/zconf"
  run "$HOME/bin/zconf" apply beta
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "beta" ]
}
