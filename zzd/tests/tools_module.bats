#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  REAL="$ZZD_ROOT"
  ZZD_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZZD_ROOT
  mkdir -p "$ZZD_ROOT/tools/npm" "$ZZD_ROOT/tools/python"
  cp -R "$REAL/zzd" "$ZZD_ROOT/zzd"
  cp -R "$REAL/tools/zzd" "$ZZD_ROOT/tools/zzd"
  cp "$REAL/tools/python/pyproject.toml" "$ZZD_ROOT/tools/python/"
  printf 'lock-v1\n' >"$ZZD_ROOT/tools/npm/pnpm-lock.yaml"
  printf 'lock-v1\n' >"$ZZD_ROOT/tools/python/uv.lock"
  for lib in log paths os exec modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
  stub_mise
  zzd_stub node 0
  BIN="$HOME/.local/share/zzd/bin"
  stub_pnpm 0
  stub_uv 0
}

# `which --plugin <cmd>` answers from TEST_PLUGINS ("cmd=tool ..."), as mise
# does for the tool that provides cmd in the current directory.
stub_mise() {
  zzd_stub_script mise <<EOF
case "\$*" in
  *"which --plugin "*)
    cmd="\${@: -1}"
    for pair in \${TEST_PLUGINS:-}; do
      if [ "\${pair%%=*}" = "\$cmd" ]; then
        echo "\${pair#*=}"
        exit 0
      fi
    done
    exit 1
    ;;
$(zzd_mise_which_branch)
  *) exec "$ZZD_REAL_MISE" "\$@" ;;
esac
EOF
}

use_temp_shims() {
  MISE_DATA_DIR="$BATS_TEST_TMPDIR/mise-data"
  export MISE_DATA_DIR
  zzd_stub python3 0
  mkdir -p "$MISE_DATA_DIR/shims"
  printf '#!/bin/sh\necho "project %s"\n' "$1" >"$MISE_DATA_DIR/shims/$1"
  chmod +x "$MISE_DATA_DIR/shims/$1"
}

stub_pnpm() {
  zzd_stub_script pnpm <<EOF
case "\$*" in
  "install --frozen-lockfile")
    [ "$1" -eq 0 ] || exit $1
    mkdir -p node_modules/.bin
    while IFS=\$'\t' read -r cmd kind; do
      if [ "\$kind" = npm ]; then
        printf '#!/bin/sh\necho "\$PATH"\n' >"node_modules/.bin/\$cmd"
        chmod +x "node_modules/.bin/\$cmd"
      fi
    done <"\$ZZD_ROOT/tools/zzd/bins"
    ;;
  "update --lockfile-only --no-save")
    [ "$1" -eq 0 ] || { printf 'broken\n' >pnpm-lock.yaml; exit $1; }
    printf 'lock-v2\n' >pnpm-lock.yaml
    ;;
  "outdated --format json")
    if [ -n "\${PNPM_OUTDATED:-}" ]; then
      printf '%s\n' "\$PNPM_OUTDATED"
    else
      printf '{}\n'
    fi
    exit "\${PNPM_OUTDATED_RC:-0}"
    ;;
esac
EOF
}

stub_uv() {
  zzd_stub_script uv <<EOF
case "\$*" in
  "sync --locked")
    [ "$1" -eq 0 ] || exit $1
    mkdir -p .venv/bin
    printf '#!/bin/sh\n' >.venv/bin/python
    chmod +x .venv/bin/python
    while IFS=\$'\t' read -r cmd kind; do
      if [ "\$kind" = python ]; then
        printf '#!/bin/sh\necho "\$PATH"\n' >".venv/bin/\$cmd"
        chmod +x ".venv/bin/\$cmd"
      fi
    done <"\$ZZD_ROOT/tools/zzd/bins"
    ;;
  "lock --upgrade") printf 'lock-v1\n' >uv.lock ;;
  "pip list --outdated"*) printf '%s\n' "\${UV_OUTDATED:-[]}" ;;
esac
EOF
}

npm_commands() {
  grep -c $'\tnpm$' "$ZZD_ROOT/tools/zzd/bins"
}

all_commands() {
  grep -c -E $'\t(npm|python)$' "$ZZD_ROOT/tools/zzd/bins"
}

@test "apply installs both workspaces from their locks and links commands" {
  run zzd_module_run tools apply
  [ "$status" -eq 0 ]
  zzd_contains "$output" "CHANGED: installed npm tools from pnpm-lock.yaml" \
    "CHANGED: installed python tools from uv.lock" "CHANGED: wrote commands:"
  [ "$(zzd_calls pnpm)" = "install --frozen-lockfile" ]
  [ "$(zzd_calls uv)" = "sync --locked" ]
  [ "$(find "$BIN" -type f | wc -l | tr -d ' ')" -eq "$(all_commands)" ]
  # shellcheck disable=SC2016 # the literal .zshenv line
  grep -Fxq 'export PATH="$HOME/.local/share/zzd/bin:$PATH"' \
    "$HOME/.zshenv"
}

@test "a second apply changes nothing" {
  zzd_module_run tools apply
  run zzd_module_run tools apply
  [ "$status" -eq 0 ]
  [[ "$output" != *"CHANGED"* ]] || false
  [ "$(zzd_calls pnpm | wc -l | tr -d ' ')" -eq 1 ]
  [ "$(zzd_calls uv | wc -l | tr -d ' ')" -eq 1 ]
}

@test "a changed lock is installed again" {
  zzd_module_run tools apply
  printf 'lock-v2\n' >"$ZZD_ROOT/tools/npm/pnpm-lock.yaml"
  run zzd_module_run tools apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHANGED: installed npm tools from pnpm-lock.yaml"* ]] ||
    false
  [ "$(zzd_calls pnpm | wc -l | tr -d ' ')" -eq 2 ]
  [ "$(zzd_calls uv | wc -l | tr -d ' ')" -eq 1 ]
}

@test "npm commands run with the global node first on PATH" {
  zzd_module_run tools apply
  run "$BIN/bash-language-server"
  [ "$status" -eq 0 ]
  [ "${output%%:*}" = "$BATS_TEST_TMPDIR/stubs" ]
}

@test "python commands run with their venv first on PATH" {
  zzd_module_run tools apply
  run "$BIN/ansible-lint"
  [ "$status" -eq 0 ]
  [ "${output%%:*}" = "$ZZD_ROOT/tools/python/.venv/bin" ]
}

@test "a command the current project pins runs the project's version" {
  use_temp_shims ansible-lint
  zzd_module_run tools apply
  TEST_PLUGINS="ansible-lint=pipx:ansible-lint"
  export TEST_PLUGINS
  run "$BIN/ansible-lint"
  [ "$status" -eq 0 ]
  [ "$output" = "project ansible-lint" ]
}

@test "a copy installed into the python runtime is not used" {
  use_temp_shims ansible-lint
  zzd_module_run tools apply
  TEST_PLUGINS="ansible-lint=python"
  export TEST_PLUGINS
  run "$BIN/ansible-lint"
  [ "$status" -eq 0 ]
  [ "${output%%:*}" = "$ZZD_ROOT/tools/python/.venv/bin" ]
}

@test "a copy installed into the node runtime is not used" {
  use_temp_shims tsc
  zzd_module_run tools apply
  TEST_PLUGINS="tsc=node"
  export TEST_PLUGINS
  run "$BIN/tsc"
  [ "$status" -eq 0 ]
  [ "${output%%:*}" = "$BATS_TEST_TMPDIR/stubs" ]
}

@test "a command no longer listed is removed" {
  zzd_module_run tools apply
  printf '#!/bin/sh\n' >"$BIN/old-tool"
  run zzd_module_run tools apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHANGED: removed commands: old-tool"* ]] || false
  [ ! -e "$BIN/old-tool" ]
}

@test "dry-run installs and writes nothing" {
  ZZD_DRY_RUN=1
  export ZZD_DRY_RUN
  run zzd_module_run tools apply
  [ "$status" -eq 0 ]
  [ -z "$(zzd_calls pnpm)" ]
  [ -z "$(zzd_calls uv)" ]
  [ ! -e "$BIN" ]
  [ ! -e "$HOME/.zshenv" ]
}

@test "a failed install is an error and is retried next time" {
  stub_pnpm 1
  run zzd_module_run tools apply
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: pnpm install --frozen-lockfile failed" \
    "fix: cd $ZZD_ROOT/tools/npm && pnpm install --lockfile-only"
  stub_pnpm 0
  run zzd_module_run tools apply
  [[ "$output" == *"CHANGED: installed npm tools from pnpm-lock.yaml"* ]] ||
    false
}

@test "missing pnpm is an error with the mise fix" {
  rm "$BATS_TEST_TMPDIR/stubs/pnpm"
  zzd_stub_script mise <<EOF
case "\$*" in
  *" which pnpm") exit 1 ;;
$(zzd_mise_which_branch)
  *) exec "$ZZD_REAL_MISE" "\$@" ;;
esac
EOF
  run zzd_module_run tools apply
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: pnpm or node is not installed by mise" \
    "fix: zzd apply mise"
}

@test "doctor passes after apply" {
  zzd_module_run tools apply
  run zzd_module_run tools doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"ERROR"* ]] || false
  [[ "$output" == *"OK: $(all_commands) commands in $BIN"* ]] || false
}

@test "doctor flags a lock that changed since the last install" {
  zzd_module_run tools apply
  printf 'lock-v2\n' >"$ZZD_ROOT/tools/python/uv.lock"
  run zzd_module_run tools doctor
  [ "$status" -eq 1 ]
  zzd_contains "$output" \
    "ERROR: python tools are not installed from the current uv.lock" \
    "fix: zzd apply tools"
}

@test "doctor flags missing, edited and unlisted commands" {
  zzd_module_run tools apply
  rm "$BIN/tsc"
  printf '#!/bin/sh\n' >"$BIN/yamllint"
  printf '#!/bin/sh\n' >"$BIN/old-tool"
  run zzd_module_run tools doctor
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: tsc is missing from $BIN" \
    "ERROR: $BIN/yamllint is out of date" \
    "ERROR: $BIN/old-tool is not in tools/zzd/bins"
}

@test "doctor flags a command whose install is gone" {
  zzd_module_run tools apply
  rm -rf "$ZZD_ROOT/tools/npm/node_modules/.bin"
  run zzd_module_run tools doctor
  [ "$status" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c 'which is missing')" -eq \
    "$(npm_commands)" ]
}

@test "doctor warns about a copy installed into a global runtime" {
  use_temp_shims ansible-lint
  zzd_module_run tools apply
  TEST_PLUGINS="ansible-lint=python"
  export TEST_PLUGINS
  run zzd_module_run tools doctor
  [ "$status" -eq 0 ]
  zzd_contains "$output" \
    "WARN: unpinned copies in the global node or python: ansible-lint" \
    "fix: npm uninstall -g <package> or python3 -m pip uninstall <package>"
}

@test "doctor does not warn about a tool a project pins" {
  use_temp_shims ansible-lint
  zzd_module_run tools apply
  TEST_PLUGINS="ansible-lint=pipx:ansible-lint"
  export TEST_PLUGINS
  run zzd_module_run tools doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]] || false
}

@test "doctor flags the commands directory missing from PATH" {
  zzd_module_run tools apply
  : >"$HOME/.zshenv"
  run zzd_module_run tools doctor
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: $BIN is not on PATH" "fix: zzd apply tools"
}

@test "upgrade re-resolves the locks and installs the result" {
  zzd_module_run tools apply
  run zzd_module_run tools upgrade
  [ "$status" -eq 0 ]
  zzd_contains "$output" "CHANGED: re-resolved pnpm-lock.yaml" \
    "CHANGED: installed npm tools from pnpm-lock.yaml" \
    "OK: uv.lock dependencies are current"
}

@test "a failed re-resolve restores the lock" {
  zzd_module_run tools apply
  stub_pnpm 1
  run zzd_module_run tools upgrade
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: re-resolving pnpm-lock.yaml failed"* ]] || false
  [ "$(cat "$ZZD_ROOT/tools/npm/pnpm-lock.yaml")" = "lock-v1" ]
}

@test "update reports newer versions of the declared tools only" {
  zzd_module_run tools apply
  export PNPM_OUTDATED='{"typescript": {"current": "7.0.2",
    "latest": "7.1.0"}}'
  export PNPM_OUTDATED_RC=1
  export UV_OUTDATED='[{"name": "pyrefly", "version": "1.4.0",
    "latest_version": "1.5.0"}, {"name": "filelock", "version": "4.2.5",
    "latest_version": "4.3.0"}]'
  run zzd_module_run tools update
  [ "$status" -eq 0 ]
  zzd_contains "$output" "INFO: npm typescript 7.0.2 -> 7.1.0" \
    "INFO: python pyrefly 1.4.0 -> 1.5.0"
  [[ "$output" != *"filelock"* ]] || false
}

@test "update says when everything is current" {
  zzd_module_run tools apply
  run zzd_module_run tools update
  [ "$status" -eq 0 ]
  zzd_contains "$output" "OK: npm tools are current" \
    "OK: python tools are current"
}
