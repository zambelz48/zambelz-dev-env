#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  for lib in log paths os exec doctor; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
  zzd_stub_mise_passthrough
  zzd_stub uname 0 "Darwin"
  zzd_stub gh 0 "token"
  SHIMS="$HOME/.local/share/mise/shims"
  shell_path "$SHIMS:$HOME/.local/bin:/usr/bin:/bin"
}

shell_path() {
  zzd_stub_script zsh <<EOF
case "\$*" in
  *PATH*) echo "$1" ;;
  *) exit 0 ;;
esac
EOF
}

@test "clean setup passes the core checks" {
  run zzd_doctor_core
  [ "$status" -eq 0 ]
  [[ "$output" != *"ERROR:"* ]] || false
  [[ "$output" != *"WARN:"* ]] || false
}

@test "hook-mode mise activate is flagged with file and line" {
  cat >"$HOME/.profile.zsh" <<'EOF'
export A=1
eval "$(~/.local/bin/mise activate zsh)"
EOF
  run zzd_doctor_core
  zzd_contains "$output" \
    "WARN: $HOME/.profile.zsh:2 runs mise activate in hook mode" \
    "fix: remove line 2 from $HOME/.profile.zsh"
}

@test "mise activate with --shims is not flagged" {
  cat >"$HOME/.zprofile" <<'EOF'
eval "$(mise activate zsh --shims)"
EOF
  run zzd_doctor_core
  [[ "$output" != *"hook mode"* ]] || false
}

@test "retired version manager lines are flagged" {
  cat >"$HOME/.zshrc" <<'EOF'
eval "$(fnm env --use-on-cd --shell zsh)"
eval "$(pyenv init - zsh)"
EOF
  run zzd_doctor_core
  zzd_contains "$output" \
    "WARN: $HOME/.zshrc:1 loads a retired version manager" \
    "WARN: $HOME/.zshrc:2 loads a retired version manager"
}

@test "shims after a retired manager on PATH is an error" {
  shell_path "$HOME/.pyenv/shims:$SHIMS:/usr/bin"
  run zzd_doctor_core
  [ "$status" -eq 1 ]
  zzd_contains "$output" \
    "ERROR: $HOME/.pyenv/shims comes before the mise shims on PATH"
}

@test "a directory ahead of the shims that shadows a pinned tool is an error" {
  brew="$BATS_TEST_TMPDIR/brew"
  mkdir -p "$SHIMS" "$brew"
  touch "$SHIMS/python3" "$SHIMS/node" "$brew/python3" "$brew/wget"
  chmod +x "$SHIMS"/* "$brew"/*
  shell_path "$brew:$SHIMS:/usr/bin"
  run zzd_doctor_core
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: $brew shadows mise shims: python3" \
    "fix: zzd apply zsh"
}

@test "a directory ahead of the shims with no overlap is fine" {
  brew="$BATS_TEST_TMPDIR/brew"
  mkdir -p "$SHIMS" "$brew"
  touch "$SHIMS/python3" "$brew/wget"
  chmod +x "$SHIMS"/* "$brew"/*
  shell_path "$brew:$SHIMS:$HOME/.local/bin:/usr/bin"
  run zzd_doctor_core
  [ "$status" -eq 0 ]
}

@test "the tools commands directory may come before the shims" {
  tools="$HOME/.local/share/zzd/bin"
  mkdir -p "$SHIMS" "$tools"
  touch "$SHIMS/ansible-lint" "$tools/ansible-lint"
  chmod +x "$SHIMS"/* "$tools"/*
  shell_path "$tools:$SHIMS:$HOME/.local/bin:/usr/bin"
  run zzd_doctor_core
  [ "$status" -eq 0 ]
  [[ "$output" != *"shadows"* ]] || false
}

@test "missing shims on PATH is an error with the apply fix" {
  shell_path "/usr/bin:/bin"
  run zzd_doctor_core
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: mise shims are not on the interactive PATH" \
    "fix: zzd apply mise"
}

@test "a PATH without the mise command directory is an error" {
  shell_path "$SHIMS:/usr/bin:/bin"
  run zzd_doctor_core
  [ "$status" -eq 1 ]
  zzd_contains "$output" \
    "ERROR: the mise command ($HOME/.local/bin) is not on PATH" \
    "fix: zzd apply mise"
}

@test "the token check runs the global gh, not a project's" {
  unset GITHUB_TOKEN
  run zzd_doctor_core
  zzd_calls mise | grep -qx -- "-C $HOME which gh"
}

@test "missing GitHub token is a warning with the login fix" {
  zzd_stub gh 1
  unset GITHUB_TOKEN
  run zzd_doctor_core
  [[ "$output" == *"WARN: no GitHub token"*"fix: gh auth login"* ]] || false
  [[ "$output" != *"ERROR: no GitHub token"* ]] || false
}

@test "retired manager installs are reported as info only" {
  mkdir -p "$HOME/.pyenv"
  run zzd_doctor_core
  [ "$status" -eq 0 ]
  zzd_contains "$output" \
    "INFO: $HOME/.pyenv is present (retired; remove it manually when ready)"
}

@test "unsupported OS is an error" {
  zzd_stub uname 0 "FreeBSD"
  run zzd_doctor_core
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: unsupported OS"* ]] || false
}

@test "perf flags mise prompt hooks" {
  zzd_stub_script zsh <<'EOF'
case "$*" in
  *functions*) echo "_omz_async_request _mise_hook_precmd" ;;
  *) exit 0 ;;
esac
EOF
  run zzd_doctor_perf
  [[ "$output" == *"WARN: mise prompt hooks are active"* ]] || false
  [[ "$output" == *"INFO: zsh startup median"*" ms"* ]] || false
}

@test "perf passes without mise prompt hooks" {
  zzd_stub_script zsh <<'EOF'
case "$*" in
  *functions*) echo "_omz_async_request mcfly_prompt_command" ;;
  *) exit 0 ;;
esac
EOF
  run zzd_doctor_perf
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: no mise prompt hooks"* ]] || false
}
