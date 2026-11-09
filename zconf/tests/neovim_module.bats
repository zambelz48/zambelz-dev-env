#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  N="$ZC_ROOT/neovim"
  mkdir -p "$N/lua" "$N/after/lsp" "$N/ftplugin"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  cp -R "$REAL/neovim/zconf" "$N/zconf"
  printf -- '-- init\n' >"$N/init.lua"
  printf '{}\n' >"$N/.luarc.json"
  printf '{\n  "a.nvim": { "branch": "main", "commit": "%s" }\n}\n' \
    "aaa111" >"$N/lazy-lock.json"
  GRADLE="$N/.lsp_vendors/vscode-gradle"
  OUT="$GRADLE/gradle-language-server/build/install/gradle-language-server"
  OUT="$OUT/bin/gradle-language-server"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  mkdir -p "$GRADLE"
  cat >"$GRADLE/gradlew" <<'EOF'
#!/usr/bin/env bash
echo "gradlew $* JAVA_HOME=$JAVA_HOME" >>"$TRACE"
out="gradle-language-server/build/install/gradle-language-server/bin"
mkdir -p "$out"
printf '#!/bin/sh\n' >"$out/gradle-language-server"
chmod +x "$out/gradle-language-server"
EOF
  chmod +x "$GRADLE/gradlew"
  for lib in log paths exec links modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  TS="$BATS_TEST_TMPDIR/treesitter"
  mkdir -p "$TS"
  fake_nvim 0 ""
  zc_stub tree-sitter 0
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  *"where java@temurin-17"*) echo "/fake/jdk17" ;;
  *) exit 0 ;;
esac
EOF
  # Checkouts keep their fake HEAD in .git/stub_head.
  zc_stub_script git <<'EOF'
case "$*" in
  *"rev-parse HEAD"*)
    [ -d "$2/.git" ] || exit 128
    cat "$2/.git/stub_head"
    ;;
  *) exit 0 ;;
esac
EOF
  submodule_at 3171aaa
  unset XDG_DATA_HOME
  LAZY="$HOME/.local/share/nvim/lazy"
  mkdir -p "$LAZY/nvim-treesitter"
}

fake_nvim() {
  zc_stub_script nvim <<EOF
case "\$*" in
  "-l $N/scripts/treesitter_parsers.lua "*)
    printf '%s\n' "\${PATH%%:*}" >"$TS/path"
    if [ -f "$TS/err" ]; then cat "$TS/err" >&2; fi
    if [ -f "$TS/out" ]; then cat "$TS/out"; else printf 'checked\t2\n'; fi
    if [ -f "$TS/status" ]; then exit "\$(cat "$TS/status")"; fi
    ;;
  *)
    if [ -n "$2" ]; then echo "$2"; fi
    exit $1
    ;;
esac
EOF
}

parsers_say() {
  printf '%b' "$1" >"$TS/out"
}

submodule_at() {
  mkdir -p "$GRADLE/.git"
  echo "$1" >"$GRADLE/.git/stub_head"
}

lazy_at() {
  mkdir -p "$LAZY/a.nvim/.git"
  echo "$1" >"$LAZY/a.nvim/.git/stub_head"
}

@test "apply links the neovim entries into ~/.config/nvim" {
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  for entry in init.lua lua after ftplugin .luarc.json; do
    [ "$(readlink "$HOME/.config/nvim/$entry")" = "$N/$entry" ]
  done
}

@test "apply restores lazy.nvim plugins headless from the lock" {
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  zc_calls nvim | grep -qx -- "--headless +Lazy! restore +qa"
}

@test "apply runs the global nvim, found through mise, not PATH" {
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  zc_calls mise | grep -qx -- "-C $HOME which nvim"
}

@test "apply without neovim installed is an error with the mise fix" {
  zc_stub_script mise <<EOF
case "\$*" in
  *" which nvim") exit 1 ;;
  *"where java@temurin-17"*) echo "/fake/jdk17" ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: neovim is not installed by mise" \
    "fix: zconf apply mise"
  [ -z "$(zc_calls nvim)" ]
}

@test "apply keeps lazy.nvim restore output out of the report" {
  fake_nvim 0 "[LuaSnip] checkout | Finished task checkout"
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  [[ "$output" != *"LuaSnip"* ]] || false
}

@test "apply shows lazy.nvim output when the restore fails" {
  fake_nvim 1 "[LuaSnip] checkout failed"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "[LuaSnip] checkout failed" \
    "ERROR: lazy.nvim restore failed"
}

@test "apply builds a missing gradle server with Java 17" {
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  expected="gradlew --no-daemon -q :gradle-language-server:installDist"
  grep -qx "$expected JAVA_HOME=/fake/jdk17" "$TRACE"
  [ -x "$OUT" ]
  [[ "$output" == *"CHANGED: built gradle-language-server at 3171aaa"* ]] ||
    false
}

@test "apply skips the gradle build when built at the submodule's commit" {
  zc_module_run neovim apply
  rm "$TRACE"
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  [ ! -e "$TRACE" ]
  [[ "$output" == *"OK: gradle-language-server built at 3171aaa"* ]] ||
    false
}

@test "apply rebuilds when the submodule moved, even to an older commit" {
  zc_module_run neovim apply
  rm "$TRACE"
  submodule_at 3150bbb
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  [ -s "$TRACE" ]
  [[ "$output" == *"CHANGED: built gradle-language-server at 3150bbb"* ]] ||
    false
}

@test "apply rebuilds a build that has no commit stamp" {
  mkdir -p "$(dirname "$OUT")"
  printf '#!/bin/sh\n' >"$OUT"
  chmod +x "$OUT"
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  [ -s "$TRACE" ]
}

@test "apply reports an uninitialized gradle submodule" {
  rm "$GRADLE/gradlew"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  fix="fix: git -C $ZC_ROOT submodule update --init"
  fix+=" neovim/.lsp_vendors/vscode-gradle"
  zc_contains "$output" "ERROR: vscode-gradle submodule is not checked out" \
    "$fix"
}

@test "apply fails when the gradle build fails" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$GRADLE/gradlew"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: gradle-language-server build failed"* ]] || false
}

@test "doctor passes when links, plugins and the gradle build are in place" {
  zc_module_run neovim apply
  lazy_at aaa111
  run zc_module_run neovim doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: lazy.nvim plugins match lazy-lock.json (1)"* ]] ||
    false
}

@test "doctor flags a lazy plugin off its lock commit" {
  zc_module_run neovim apply
  lazy_at bbb222
  run zc_module_run neovim doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: a.nvim at bbb222, locked aaa111" \
    "fix: zconf apply neovim"
}

@test "dry-run apply neither restores nor builds" {
  ZC_DRY_RUN=1 run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  [ -z "$(zc_calls nvim)" ]
  [ ! -e "$TRACE" ]
  [[ "$output" != *"OK: lazy.nvim plugins restored"* ]] || false
}

@test "update runs the existing plugin update check" {
  run zc_module_run neovim update
  [ "$status" -eq 0 ]
  zc_calls nvim | grep -qx -- "-l $N/scripts/check_plugin_updates.lua"
}

@test "doctor flags a gradle server built from another commit" {
  zc_module_run neovim apply
  lazy_at aaa111
  submodule_at 3150bbb
  run zc_module_run neovim doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: gradle-language-server built at 3171aaa, submodule at 3150bbb" \
    "fix: zconf apply neovim"
}

@test "doctor flags a missing gradle server build" {
  zc_module_run neovim apply
  lazy_at aaa111
  rm "$OUT"
  run zc_module_run neovim doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: gradle-language-server is not built" \
    "fix: zconf apply neovim"
}

@test "apply syncs treesitter parsers after the restore, tree-sitter first" {
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  restore="$(zc_calls nvim | grep -n 'Lazy! restore' | cut -d: -f1)"
  sync="$(zc_calls nvim | grep -n 'treesitter_parsers.lua sync' | cut -d: -f1)"
  [ "$restore" -lt "$sync" ]
  zc_calls nvim | grep -qx -- \
    "-l $N/scripts/treesitter_parsers.lua sync $LAZY/nvim-treesitter"
  [ "$(cat "$TS/path")" = "$BATS_TEST_TMPDIR/stubs" ]
  zc_contains "$output" "OK: treesitter parsers match nvim-treesitter (2)"
}

@test "apply reports installed and updated parsers as changes" {
  parsers_say 'installed\tvim\ninstalled\tlua\nupdated\tbash\nchecked\t3\n'
  run zc_module_run neovim apply
  [ "$status" -eq 0 ]
  zc_contains "$output" "CHANGED: treesitter parsers installed: vim, lua" \
    "CHANGED: treesitter parsers updated: bash"
  [[ "$output" != *"OK: treesitter"* ]] || false
}

@test "apply fails on parsers still missing or outdated, with the logs" {
  parsers_say 'missing\tvim\noutdated\tlua\tdeadbeef0000aa\t10fe0054734e99\n'
  printf 'checked\t1\n' >>"$TS/out"
  printf 'Error during "tree-sitter build"\n' >"$TS/err"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: treesitter parser vim is not installed" "fix: zconf apply neovim"
  zc_contains "$output" \
    "ERROR: treesitter parser lua at deadbeef0000, nvim-treesitter wants" \
    "10fe0054734e"
  zc_contains "$output" 'Error during "tree-sitter build"'
}

@test "apply fails when a parser task did not finish" {
  parsers_say 'failed\tupdate\ttimeout\nchecked\t2\n'
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: treesitter update did not finish: timeout"
}

@test "apply fails with the logs when the parser script fails" {
  printf '1\n' >"$TS/status"
  printf 'E5113: Lua chunk: boom\n' >"$TS/err"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "E5113: Lua chunk: boom" \
    "ERROR: treesitter parser sync failed"
}

@test "apply fails when the parser script prints no result" {
  : >"$TS/out"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: treesitter parser sync failed"
}

@test "apply reports a missing nvim-treesitter checkout" {
  rmdir "$LAZY/nvim-treesitter"
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: nvim-treesitter is not installed" \
    "fix: zconf apply neovim"
  [ "$(zc_calls nvim | grep -c treesitter_parsers)" -eq 0 ]
}

@test "apply needs the pinned tree-sitter to build parsers" {
  rm "$BATS_TEST_TMPDIR/stubs/tree-sitter"
  zc_stub_script mise <<EOF
case "\$*" in
  *" which tree-sitter") exit 1 ;;
$(zc_mise_which_branch)
  *"where java@temurin-17"*) echo "/fake/jdk17" ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run neovim apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: tree-sitter is not installed by mise" \
    "fix: zconf apply mise"
  [ "$(zc_calls nvim | grep -c treesitter_parsers)" -eq 0 ]
}

@test "doctor checks parsers read-only and reports problems" {
  zc_module_run neovim apply
  lazy_at aaa111
  parsers_say 'outdated\tjsx\tstale-queries\tqueries\nchecked\t2\n'
  run zc_module_run neovim doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: treesitter queries for jsx are out of date" \
    "fix: zconf apply neovim"
  zc_calls nvim | grep -qx -- \
    "-l $N/scripts/treesitter_parsers.lua check $LAZY/nvim-treesitter"
  [ "$(zc_calls nvim | grep -c 'treesitter_parsers.lua sync')" -eq 1 ]
}

@test "doctor passes parsers that match nvim-treesitter" {
  zc_module_run neovim apply
  lazy_at aaa111
  run zc_module_run neovim doctor
  [ "$status" -eq 0 ]
  zc_contains "$output" "OK: treesitter parsers match nvim-treesitter (2)"
}
