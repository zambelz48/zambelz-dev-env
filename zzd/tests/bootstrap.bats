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
  # The fake installer writes MISE_INSTALL_PATH like the real one.
  zc_stub_script curl <<'EOF'
cat <<'SCRIPT'
echo "installer MISE_VERSION=$MISE_VERSION" >>"$TRACE"
echo "installer MISE_INSTALL_PATH=$MISE_INSTALL_PATH" >>"$TRACE"
printf '#!/usr/bin/env bash\necho "%s macos-arm64"\n' "${MISE_VERSION#v}" \
  >"$MISE_INSTALL_PATH"
chmod +x "$MISE_INSTALL_PATH"
SCRIPT
EOF
  zc_stub git 0
  zc_hide_command mise
  mise_at "$PINNED"
  unset ZC_ROOT
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
  grep -qx "installer MISE_INSTALL_PATH=$HOME/.local/bin/mise" "$TRACE"
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

@test "an older mise ahead of ~/.local/bin on PATH is an error, not replaced" {
  mise_at "2026.4.24"
  mkdir -p "$BATS_TEST_TMPDIR/other"
  printf '#!/usr/bin/env bash\necho "2026.4.24 macos-arm64"\n' \
    >"$BATS_TEST_TMPDIR/other/mise"
  chmod +x "$BATS_TEST_TMPDIR/other/mise"
  PATH="$BATS_TEST_TMPDIR/other:$HOME/.local/bin:$PATH" \
    run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: mise 2026.4.24 at $BATS_TEST_TMPDIR/other/mise is older" \
    "fix: remove $BATS_TEST_TMPDIR/other/mise"
  [ "$(zc_calls curl | grep -c 'mise.run')" -eq 0 ]
  [ ! -e "$TRACE" ]
}

@test "bootstrap leaves submodules to zconf apply" {
  run bash "$FIX/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ "$(zc_calls git | grep -c 'submodule')" -eq 0 ]
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

on_linux() {
  zc_stub uname 0 "Linux"
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZC_OS_RELEASE
  printf 'ID=%s\n' "$1" >"$ZC_OS_RELEASE"
  zc_stub id 0 "501"
  zc_stub sudo 0
  zc_stub getent 0 "dev:x:501:501::/home/dev:/usr/bin/zsh"
}

@test "linux prerequisites that are present are only reported" {
  on_linux fedora
  run bash "$FIX/bootstrap.sh" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: zsh, git, curl and chsh"* ]] || false
  [ -z "$(zc_calls sudo)" ]
}

@test "a missing chsh on fedora is installed from util-linux" {
  on_linux fedora
  zc_hide_command chsh
  run bash "$FIX/bootstrap.sh" </dev/null
  [ "$status" -eq 0 ]
  [ "$(zc_calls sudo | tail -1)" = "-n dnf install -y util-linux" ]
  [[ "$output" == *"CHANGED: installed util-linux"* ]] || false
}

@test "a missing chsh on ubuntu is installed from passwd" {
  on_linux ubuntu
  zc_hide_command chsh
  run bash "$FIX/bootstrap.sh" </dev/null
  [ "$status" -eq 0 ]
  [ "$(zc_calls sudo | tail -1)" = "-n apt-get install -y passwd" ]
  [[ "$output" == *"CHANGED: installed passwd"* ]] || false
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
