#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  for lib in log paths os exec links modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  # shellcheck source=/dev/null
  . "$ZC_ROOT/zsh/zconf/pins"
  OMZ="$HOME/.oh-my-zsh"
  zc_stub uname 0 "Darwin"
  zc_stub dscl 0 "UserShell: /bin/zsh"
}

fake_git() {
  local head="$1" remote="${2:-$OHMYZSH_COMMIT}"
  zc_stub_script git <<EOF
case "\$*" in
  *"clone"*) mkdir -p "\${@: -1}/.git" ;;
  *"rev-parse HEAD"*) echo "$head" ;;
  *"ls-remote"*) printf '%s\tHEAD\n' "$remote" ;;
  *) exit 0 ;;
esac
EOF
}

@test "apply clones oh-my-zsh at the pin when it is absent" {
  fake_git "$OHMYZSH_COMMIT"
  run zc_module_run zsh apply
  [ "$status" -eq 0 ]
  zc_calls git | grep -q "clone -q https://github.com/ohmyzsh/ohmyzsh.git $OMZ"
  zc_calls git | grep -q "checkout -q $OHMYZSH_COMMIT"
  [[ "$output" == *"CHANGED: oh-my-zsh cloned at $OHMYZSH_COMMIT"* ]] || false
}

@test "apply links .zshrc, the dracula theme and evalcache" {
  fake_git "$OHMYZSH_COMMIT"
  zc_module_run zsh apply
  custom="$OMZ/custom"
  [ "$(readlink "$HOME/.zshrc")" = "$ZC_ROOT/zsh/.zshrc" ]
  [ "$(readlink "$custom/themes/dracula.zsh-theme")" = \
    "$ZC_ROOT/zsh/.themes/dracula/dracula.zsh-theme" ]
  [ "$(readlink "$custom/themes/lib")" = "$ZC_ROOT/zsh/.themes/dracula/lib" ]
  [ "$(readlink "$custom/plugins/evalcache")" = \
    "$ZC_ROOT/zsh/.plugins/evalcache" ]
}

@test "apply adds the dev env path to .profile.zsh once" {
  fake_git "$OHMYZSH_COMMIT"
  zc_module_run zsh apply
  zc_module_run zsh apply
  line="export ZAMBELZ_DEV_ENV_PATH=\"$ZC_ROOT\""
  [ "$(grep -cxF "$line" "$HOME/.profile.zsh")" -eq 1 ]
}

@test "doctor flags oh-my-zsh at another commit" {
  fake_git "$OHMYZSH_COMMIT"
  zc_module_run zsh apply
  fake_git "0000000"
  run zc_module_run zsh doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: oh-my-zsh at 0000000, pinned $OHMYZSH_COMMIT" \
    "fix: zconf apply zsh"
}

@test "doctor flags a login shell that is not zsh" {
  fake_git "$OHMYZSH_COMMIT"
  zc_module_run zsh apply
  zc_stub dscl 0 "UserShell: /bin/bash"
  run zc_module_run zsh doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: login shell is /bin/bash" "fix: chsh -s" "zsh"
}

@test "doctor passes when everything is in place" {
  fake_git "$OHMYZSH_COMMIT"
  zc_module_run zsh apply
  run zc_module_run zsh doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: login shell is /bin/zsh"* ]] || false
}

@test "update reports a newer oh-my-zsh master" {
  fake_git "$OHMYZSH_COMMIT" "1111111"
  run zc_module_run zsh update
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: oh-my-zsh $OHMYZSH_COMMIT -> 1111111"* ]] || false
}

@test "update is quiet about oh-my-zsh at master" {
  fake_git "$OHMYZSH_COMMIT"
  run zc_module_run zsh update
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: oh-my-zsh at master"* ]] || false
}
