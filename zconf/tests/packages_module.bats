#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/packages/zconf"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  cp "$REAL"/packages/zconf/*.sh "$ZC_ROOT/packages/zconf/"
  printf 'darwin\tbrew\nfedora\tdnf\n' >"$ZC_ROOT/packages/zconf/managers"
  printf '# libs\ngmp\nchafa\nzsh\tzsh\n' >"$ZC_ROOT/packages/brew.txt"
  printf 'gmp-devel\nchafa\n' >"$ZC_ROOT/packages/dnf.txt"
  for lib in log paths os exec links modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  zc_stub id 0 "501"
  zc_stub zsh 0
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZC_OS_RELEASE
}

on_darwin() {
  zc_stub uname 0 "Darwin"
}

on_fedora() {
  zc_stub uname 0 "Linux"
  printf 'ID=fedora\n' >"$ZC_OS_RELEASE"
}

brew_with_only_gmp() {
  zc_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") [ "$4" = "gmp" ] && { echo "gmp 6.3.0"; exit 0; }; exit 1 ;;
  *) exit 0 ;;
esac
EOF
}

@test "apply installs only missing packages in one call" {
  on_darwin
  brew_with_only_gmp
  run zc_module_run packages apply
  [ "$status" -eq 0 ]
  [ "$(zc_calls brew | grep '^install')" = "install --formula chafa" ]
  [[ "$output" == *"OK: zsh (provided by zsh)"* ]] || false
  [[ "$output" == *"CHANGED: installed chafa"* ]] || false
}

@test "apply on fedora installs through sudo dnf" {
  on_fedora
  zc_stub rpm 1
  zc_stub sudo 0
  zc_stub dnf 0
  run zc_module_run packages apply </dev/null
  [ "$status" -eq 0 ]
  [ "$(zc_calls sudo | tail -1)" = "-n dnf install -y gmp-devel chafa" ]
}

@test "apply fails on an unsupported OS" {
  zc_stub uname 0 "FreeBSD"
  run zc_module_run packages apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: unsupported OS"* ]] || false
}

@test "apply fails with a fix when the package manager is missing" {
  on_fedora
  zc_hide_command dnf
  run zc_module_run packages apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: dnf is not available"* ]] || false
}

@test "doctor reports missing packages and versions of installed ones" {
  on_darwin
  brew_with_only_gmp
  run zc_module_run packages doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"OK: gmp 6.3.0 (system-managed)"* ]] || false
  zc_contains "$output" "ERROR: chafa is not installed" \
    "fix: zconf apply packages"
  [ "$(zc_calls brew | grep -c -E '^(install|tab)')" -eq 0 ]
}

brew_with_gmp_as_dependency() {
  zc_stub_script brew <<'EOF'
case "$*" in
  "list --formula --no-installed-on-request") printf 'gmp\nopenssl@3\n' ;;
  "list --formula --versions gmp") echo "gmp 6.3.0" ;;
  "list --formula --versions chafa") echo "chafa 1.18.2" ;;
  "list --formula --versions "*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
}

@test "apply marks a declared dependency-only package so cleanup keeps it" {
  on_darwin
  brew_with_gmp_as_dependency
  run zc_module_run packages apply
  [ "$status" -eq 0 ]
  [ "$(zc_calls brew | grep '^tab')" = "tab --installed-on-request gmp" ]
  [[ "$output" == *"CHANGED: marked gmp as explicitly installed"* ]] ||
    false
}

@test "apply marks nothing when declared packages are already requested" {
  on_darwin
  brew_with_only_gmp
  run zc_module_run packages apply
  [ "$status" -eq 0 ]
  [ "$(zc_calls brew | grep -c '^tab')" -eq 0 ]
}

@test "doctor warns about a declared dependency-only package" {
  on_darwin
  brew_with_gmp_as_dependency
  run zc_module_run packages doctor
  [ "$status" -eq 0 ]
  zc_contains "$output" \
    "WARN: gmp is installed only as a dependency; cleanup may remove it" \
    "fix: zconf apply packages"
  [ "$(zc_calls brew | grep -c '^tab')" -eq 0 ]
}

@test "upgrade upgrades only the outdated listed packages" {
  on_darwin
  zc_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") echo "$4 1.0"; exit 0 ;;
  "outdated --formula") echo "chafa (1.18.3) < 1.18.4"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run packages upgrade
  [ "$status" -eq 0 ]
  [ "$(zc_calls brew | grep '^upgrade')" = "upgrade --formula chafa" ]
  [[ "$output" == *"CHANGED: upgraded chafa 1.18.3 -> 1.18.4 (brew)"* ]] ||
    false
}

@test "upgrade with nothing outdated upgrades nothing" {
  on_darwin
  zc_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") echo "$4 1.0"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run packages upgrade
  [ "$status" -eq 0 ]
  [ "$(zc_calls brew | grep -c '^upgrade')" -eq 0 ]
}

@test "update reports outdated packages" {
  on_darwin
  zc_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") echo "$4 1.0"; exit 0 ;;
  "outdated --formula") echo "chafa (1.18.3) < 1.18.4"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run packages update
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: chafa 1.18.3 -> 1.18.4 (brew)"* ]] || false
}
