#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
  zc_test_setup
  unset GITHUB_TOKEN
  REPO="$ZC_ROOT"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/mise" "$HOME/.local/bin"
  cp "$REPO/bootstrap.sh" "$FIX/bootstrap.sh"
  cp -R "$REPO/zconf" "$FIX/zconf"
  cp "$REPO/mise/mise.toml" "$FIX/mise/mise.toml"
  # shellcheck source=../lib/version.sh
  . "$REPO/zconf/lib/version.sh"
  PINNED="$(zc_mise_min_version)"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  # shellcheck disable=SC2016 # script text, expanded when the stub runs
  printf '#!/usr/bin/env bash\necho "zconf $*" >>"$TRACE"\n' \
    >"$FIX/zconf/bin/zconf"
  zc_stub uname 0 "Darwin"
  zc_stub xcode-select 0 "/Library/Developer/CommandLineTools"
  zc_stub brew 0
  zc_stub gh 0 "token"
  zc_stub dscl 0 "UserShell: /bin/zsh"
  zc_stub chsh 0
  # The fake installer replaces ~/.local/bin/mise like the real one.
  zc_stub_script curl <<'EOF'
cat <<'SCRIPT'
echo "installer MISE_VERSION=$MISE_VERSION" >>"$TRACE"
printf '#!/usr/bin/env bash\necho "%s macos-arm64"\n' "${MISE_VERSION#v}" \
  >"$HOME/.local/bin/mise"
chmod +x "$HOME/.local/bin/mise"
SCRIPT
EOF
  submodules " 3153dcd zsh/.plugins/evalcache (v1.0.2)"
  mise_at "$PINNED"
  unset ZC_ROOT
}

submodules() {
  local status="$1"
  zc_stub_script git <<EOF
case "\$*" in
  *"submodule status"*) printf '%s\n' "$status" ;;
  *) exit 0 ;;
esac
EOF
}

mise_at() {
  printf '#!/usr/bin/env bash\necho "%s macos-arm64 (2026-10-27)"\n' "$1" \
    >"$HOME/.local/bin/mise"
  chmod +x "$HOME/.local/bin/mise"
}

@test "a converged machine prints only OK and hands off to zconf apply" {
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: os: darwin"* ]] || false
  [[ "$output" == *"OK: Xcode Command Line Tools"* ]] || false
  [[ "$output" == *"OK: Homebrew"* ]] || false
  [[ "$output" == *"OK: login shell is /bin/zsh"* ]] || false
  [[ "$output" == *"OK: submodules checked out"* ]] || false
  [[ "$output" == *"OK: GitHub token available"* ]] || false
  [[ "$output" == *"OK: mise $PINNED (>= $PINNED)"* ]] || false
  [[ "$output" != *"CHANGED:"* ]] || false
  [[ "$output" != *"ERROR:"* ]] || false
  [[ "$output" != *"WARN:"* ]] || false
  [ "$(cat "$TRACE")" = "zconf apply" ]
}

@test "run from a clone does not clone" {
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ "$(zc_calls git | grep -c 'clone')" -eq 0 ]
}

@test "module names are passed to zconf apply" {
  run bash "$FIX/bootstrap.sh" mise zsh
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "zconf apply mise zsh" ]
}

@test "run outside a clone clones into --dir and re-executes the clone" {
  mkdir -p "$BATS_TEST_TMPDIR/raw"
  cp "$REPO/bootstrap.sh" "$BATS_TEST_TMPDIR/raw/bootstrap.sh"
  zc_stub_script git <<'EOF'
case "$*" in
  "clone "*)
    dest="${@: -1}"
    mkdir -p "$dest"
    printf '#!/usr/bin/env bash\necho "reexec $*" >>"$TRACE"\n' \
      >"$dest/bootstrap.sh"
    ;;
  *) exit 0 ;;
esac
EOF
  target="$BATS_TEST_TMPDIR/dev env"
  run bash "$BATS_TEST_TMPDIR/raw/bootstrap.sh" --dir "$target" mise
  [ "$status" -eq 0 ]
  zc_calls git |
    grep -qx "clone -q https://github.com/zambelz48/zambelz-dev-env.git $target"
  [ "$(cat "$TRACE")" = "reexec mise" ]
}

@test "an existing clone at --dir is used instead of cloning again" {
  mkdir -p "$BATS_TEST_TMPDIR/raw" "$BATS_TEST_TMPDIR/existing/.git"
  cp "$REPO/bootstrap.sh" "$BATS_TEST_TMPDIR/raw/bootstrap.sh"
  # shellcheck disable=SC2016 # script text, expanded when the stub runs
  printf '#!/usr/bin/env bash\necho "reexec $*" >>"$TRACE"\n' \
    >"$BATS_TEST_TMPDIR/existing/bootstrap.sh"
  run bash "$BATS_TEST_TMPDIR/raw/bootstrap.sh" \
    --dir "$BATS_TEST_TMPDIR/existing"
  [ "$status" -eq 0 ]
  [ "$(zc_calls git | grep -c 'clone')" -eq 0 ]
  [ "$(cat "$TRACE")" = "reexec " ]
}

@test "an older mise is replaced by the pinned version" {
  mise_at "2026.4.24"
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  grep -qx "installer MISE_VERSION=v$PINNED" "$TRACE"
  zc_calls curl | grep -qx -- "-fsSL https://mise.run"
  [[ "$output" == *"CHANGED: mise 2026.4.24 -> $PINNED"* ]] || false
}

@test "a missing mise is installed at the pinned version" {
  rm "$HOME/.local/bin/mise"
  run bash "$FIX/bootstrap.sh"
  grep -qx "installer MISE_VERSION=v$PINNED" "$TRACE"
  [[ "$output" == *"CHANGED: mise missing -> $PINNED"* ]] || false
}

@test "an installer that leaves the old mise behind is an error" {
  mise_at "2026.4.24"
  zc_stub_script curl 'echo "true"'
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: mise is 2026.4.24 after the install, expected $PINNED"
  [ ! -e "$TRACE" ]
}

@test "a newer mise is kept" {
  mise_at "2099.1.1"
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ "$(zc_calls curl | grep -c 'mise.run')" -eq 0 ]
}

@test "uninitialized submodules are fetched over https" {
  submodules "-3153dcd zsh/.plugins/evalcache"
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  expected="-c url.https://github.com/.insteadOf=git@github.com:"
  expected+=" submodule update --init --recursive -- zsh/.plugins/evalcache"
  zc_contains "$(zc_calls git)" "$expected"
  [[ "$output" == *"CHANGED: submodule zsh/.plugins/evalcache"* ]] || false
}

@test "a submodule at another commit is left alone with a warning" {
  submodules "+9999999 neovim/.lsp_vendors/vscode-gradle (3.15.0)"
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ "$(zc_calls git | grep -c 'submodule update')" -eq 0 ]
  expected="WARN: submodule neovim/.lsp_vendors/vscode-gradle is not at its"
  expected+=" recorded commit; left as is"
  zc_contains "$output" "$expected"
}

@test "missing Command Line Tools starts the installer and stops" {
  zc_stub_script xcode-select <<'EOF'
case "$1" in
  -p) exit 2 ;;
  *) exit 0 ;;
esac
EOF
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 1 ]
  zc_calls xcode-select | grep -qx -- "--install"
  [[ "$output" == *"ERROR: Xcode Command Line Tools are not installed"* ]] ||
    false
  [ ! -e "$TRACE" ]
}

@test "a missing GitHub token is a warning with instructions" {
  zc_stub gh 1
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN: no GitHub token"*"fix: export GITHUB_TOKEN="* ]] ||
    false
}

@test "a login shell other than zsh is changed with chsh" {
  zc_stub dscl 0 "UserShell: /bin/bash"
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  zc_calls chsh | grep -q -- "-s .*zsh"
  [[ "$output" == *"CHANGED: login shell /bin/bash -> "*"zsh"* ]] || false
}

@test "an unsupported OS stops before changing anything" {
  zc_stub uname 0 "FreeBSD"
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: unsupported OS"* ]] || false
  [ ! -e "$TRACE" ]
}

@test "an unknown option exits 2 with usage" {
  run bash "$FIX/bootstrap.sh" --frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: bootstrap.sh"* ]] || false
}
