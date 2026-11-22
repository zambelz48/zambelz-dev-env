#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  REAL="$ZZD_ROOT"
  ZZD_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZZD_ROOT
  mkdir -p "$ZZD_ROOT/packages/zzd"
  cp -R "$REAL/zzd" "$ZZD_ROOT/zzd"
  cp "$REAL"/packages/zzd/*.sh "$ZZD_ROOT/packages/zzd/"
  printf 'darwin\tbrew\nfedora\tdnf\n' >"$ZZD_ROOT/packages/zzd/managers"
  printf '# libs\ngmp\nchafa\nzsh\tzsh\n' >"$ZZD_ROOT/packages/brew.txt"
  printf 'gmp-devel\nchafa\n' >"$ZZD_ROOT/packages/dnf.txt"
  for lib in log paths os exec links modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
  zzd_stub id 0 "501"
  zzd_stub zsh 0
  ZZD_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZZD_OS_RELEASE
}

on_darwin() {
  zzd_stub uname 0 "Darwin"
}

on_fedora() {
  zzd_stub uname 0 "Linux"
  printf 'ID=fedora\n' >"$ZZD_OS_RELEASE"
}

brew_with_only_gmp() {
  zzd_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") [ "$4" = "gmp" ] && { echo "gmp 6.3.0"; exit 0; }; exit 1 ;;
  *) exit 0 ;;
esac
EOF
}

@test "apply installs only missing packages in one call" {
  on_darwin
  brew_with_only_gmp
  run zzd_module_run packages apply
  [ "$status" -eq 0 ]
  [ "$(zzd_calls brew | grep '^install')" = "install --formula chafa" ]
  [[ "$output" == *"OK: zsh (provided by zsh)"* ]] || false
  [[ "$output" == *"CHANGED: installed chafa"* ]] || false
}

@test "apply on fedora installs through sudo dnf" {
  on_fedora
  zzd_stub rpm 1
  zzd_stub sudo 0
  zzd_stub dnf 0
  run zzd_module_run packages apply </dev/null
  [ "$status" -eq 0 ]
  [ "$(zzd_calls sudo | tail -1)" = "-n dnf install -y gmp-devel chafa" ]
}

@test "apply fails on an unsupported OS" {
  zzd_stub uname 0 "FreeBSD"
  run zzd_module_run packages apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: unsupported OS"* ]] || false
}

@test "apply fails with a fix when the package manager is missing" {
  on_fedora
  zzd_hide_command dnf
  run zzd_module_run packages apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: dnf is not available"* ]] || false
}

@test "doctor reports missing packages and versions of installed ones" {
  on_darwin
  brew_with_only_gmp
  run zzd_module_run packages doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"OK: gmp 6.3.0 (system-managed)"* ]] || false
  zzd_contains "$output" "ERROR: chafa is not installed" \
    "fix: zzd apply packages"
  [ "$(zzd_calls brew | grep -c -E '^(install|tab)')" -eq 0 ]
}

brew_with_gmp_as_dependency() {
  zzd_stub_script brew <<'EOF'
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
  run zzd_module_run packages apply
  [ "$status" -eq 0 ]
  [ "$(zzd_calls brew | grep '^tab')" = "tab --installed-on-request gmp" ]
  [[ "$output" == *"CHANGED: marked gmp as explicitly installed"* ]] ||
    false
}

@test "apply marks nothing when declared packages are already requested" {
  on_darwin
  brew_with_only_gmp
  run zzd_module_run packages apply
  [ "$status" -eq 0 ]
  [ "$(zzd_calls brew | grep -c '^tab')" -eq 0 ]
}

@test "doctor warns about a declared dependency-only package" {
  on_darwin
  brew_with_gmp_as_dependency
  run zzd_module_run packages doctor
  [ "$status" -eq 0 ]
  zzd_contains "$output" \
    "WARN: gmp is installed only as a dependency; cleanup may remove it" \
    "fix: zzd apply packages"
  [ "$(zzd_calls brew | grep -c '^tab')" -eq 0 ]
}

@test "upgrade upgrades only the outdated listed packages" {
  on_darwin
  zzd_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") echo "$4 1.0"; exit 0 ;;
  "outdated --formula") echo "chafa (1.18.3) < 1.18.4"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  run zzd_module_run packages upgrade
  [ "$status" -eq 0 ]
  [ "$(zzd_calls brew | grep '^upgrade')" = "upgrade --formula chafa" ]
  [[ "$output" == *"CHANGED: upgraded chafa 1.18.3 -> 1.18.4 (brew)"* ]] ||
    false
}

@test "upgrade with nothing outdated upgrades nothing" {
  on_darwin
  zzd_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") echo "$4 1.0"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  run zzd_module_run packages upgrade
  [ "$status" -eq 0 ]
  [ "$(zzd_calls brew | grep -c '^upgrade')" -eq 0 ]
}

@test "update reports outdated packages" {
  on_darwin
  zzd_stub_script brew <<'EOF'
case "$1 $2" in
  "list --formula") echo "$4 1.0"; exit 0 ;;
  "outdated --formula") echo "chafa (1.18.3) < 1.18.4"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  run zzd_module_run packages update
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: chafa 1.18.3 -> 1.18.4 (brew)"* ]] || false
}
