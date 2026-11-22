#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  LINT="$ZZD_ROOT/zzd/bin/lint"
  FIXTURE="$BATS_TEST_TMPDIR/repo with space"
  mkdir -p "$FIXTURE/tools" "$FIXTURE/neovim/lua" "$FIXTURE/zsh"
  cp "$ZZD_ROOT/.shellcheckrc" "$FIXTURE/.shellcheckrc"
  cp "$ZZD_ROOT/neovim/.luarc.json" "$FIXTURE/neovim/.luarc.json"
  cat >"$FIXTURE/tools/clean.sh" <<'EOF'
#!/usr/bin/env bash
set -u
name="${1:-x}"
printf '%s\n' "$name"
EOF
  printf 'local M = {}\nM.opt = vim.o.number\nreturn M\n' \
    >"$FIXTURE/neovim/lua/clean.lua"
  printf 'export EDITOR=nvim\n' >"$FIXTURE/zsh/.zshrc"
  git -C "$FIXTURE" init -q
}

@test "clean repository passes every linter" {
  ZZD_ROOT="$FIXTURE" run "$LINT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: shellcheck"* ]] || false
  [[ "$output" == *"OK: zsh -n"* ]] || false
  [[ "$output" == *"OK: lua-language-server"* ]] || false
}

@test "tracked files deleted from the worktree are skipped" {
  printf 'echo gone\n' >"$FIXTURE/tools/gone.sh"
  printf 'echo gone\n' >"$FIXTURE/zsh/.zshrc"
  git -C "$FIXTURE" add tools/gone.sh zsh/.zshrc
  rm "$FIXTURE/tools/gone.sh" "$FIXTURE/zsh/.zshrc"
  ZZD_ROOT="$FIXTURE" run "$LINT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"gone.sh"* ]] || false
}

@test "unquoted variable in a shell script fails and names the file" {
  cat >"$FIXTURE/tools/bad.sh" <<'EOF'
#!/usr/bin/env bash
target=$1
rm $target
EOF
  ZZD_ROOT="$FIXTURE" run "$LINT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tools/bad.sh:3:"*"[SC2086]"* ]] || false
  [[ "$output" == *"ERROR: shellcheck"* ]] || false
}

@test "undefined global in lua fails" {
  printf 'undefined_global_fn()\n' >"$FIXTURE/neovim/lua/bad.lua"
  ZZD_ROOT="$FIXTURE" run "$LINT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: lua-language-server"* ]] || false
}

@test "lua lint uses the global nvim when PATH has no nvim" {
  ZZD_ROOT="$FIXTURE" run env \
    PATH="$(dirname "$ZZD_REAL_MISE"):/usr/bin:/bin" "$LINT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: lua-language-server"* ]] || false
}

@test "lua lint names a missing nvim instead of failing on vim globals" {
  ZZD_ROOT="$FIXTURE" run env PATH=/usr/bin:/bin "$LINT"
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: nvim is not installed by mise" \
    "fix: zzd apply mise"
  [[ "$output" != *"undefined-global"* ]] || false
}

@test "zsh syntax error fails" {
  printf 'if true; then\n' >"$FIXTURE/zsh/.zshrc"
  ZZD_ROOT="$FIXTURE" run "$LINT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: zsh -n"* ]] || false
}
