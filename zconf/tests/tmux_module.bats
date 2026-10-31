#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/tmux"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  cp -R "$REAL/tmux/zconf" "$ZC_ROOT/tmux/zconf"
  cat >"$ZC_ROOT/tmux/.tmux.conf" <<'EOF'
set -g @plugin 'tmux-plugins/tpm'
  set -g @plugin "tmux-plugins/tmux-sensible"
set -g @plugin 'dracula/tmux#v3.3.1'
run '~/.tmux/plugins/tpm/tpm'
EOF
  printf '%s\t%s\n' \
    tmux-plugins/tpm aaa111 \
    tmux-plugins/tmux-sensible bbb222 \
    dracula/tmux ccc333 >"$ZC_ROOT/tmux/zconf/pins"
  for lib in log paths exec links modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  PLUGINS="$HOME/.tmux/plugins"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  fake_git
}

# Each checkout keeps its fake HEAD in .git/stub_head.
fake_git() {
  local remote="${1:-}"
  zc_stub_script git <<EOF
case "\$*" in
  "clone -q "*)
    dest="\${@: -1}"
    mkdir -p "\$dest/.git"
    if [ "\${dest##*/}" = "tpm" ]; then
      mkdir -p "\$dest/bin"
      {
        echo '#!/usr/bin/env bash'
        echo 'state=unlinked'
        echo '[ -L "\$HOME/.tmux.conf" ] && state=linked'
        echo 'echo "\$state" >>"\$TRACE"'
      } >"\$dest/bin/install_plugins"
      chmod +x "\$dest/bin/install_plugins"
    fi
    ;;
  "-C "*" rev-parse HEAD")
    [ -d "\$2/.git" ] || exit 128
    cat "\$2/.git/stub_head" 2>/dev/null || echo "old999"
    ;;
  "-C "*" checkout -q "*) echo "\${@: -1}" >"\$2/.git/stub_head" ;;
  "ls-remote "*) printf '%s\tHEAD\n' "${remote:-same}" ;;
  *) exit 0 ;;
esac
EOF
}

at_pins() {
  local name commit
  while read -r name commit; do
    mkdir -p "$PLUGINS/${name##*/}/.git"
    echo "$commit" >"$PLUGINS/${name##*/}/.git/stub_head"
  done <"$ZC_ROOT/tmux/zconf/pins"
  mkdir -p "$PLUGINS/tpm/bin"
  printf '#!/usr/bin/env bash\n' >"$PLUGINS/tpm/bin/install_plugins"
  chmod +x "$PLUGINS/tpm/bin/install_plugins"
}

@test "apply clones TPM at its pinned commit when it is absent" {
  run zc_module_run tmux apply
  [ "$status" -eq 0 ]
  zc_calls git |
    grep -qx "clone -q https://github.com/tmux-plugins/tpm.git $PLUGINS/tpm"
  zc_calls git | grep -qx -- "-C $PLUGINS/tpm checkout -q aaa111"
}

@test "apply runs TPM's install_plugins after linking .tmux.conf" {
  run zc_module_run tmux apply
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "linked" ]
  [ "$(readlink "$HOME/.tmux.conf")" = "$ZC_ROOT/tmux/.tmux.conf" ]
}

@test "apply moves each plugin to its pinned commit" {
  run zc_module_run tmux apply
  [ "$status" -eq 0 ]
  [ "$(cat "$PLUGINS/tmux-sensible/.git/stub_head")" = "bbb222" ]
  [ "$(cat "$PLUGINS/tmux/.git/stub_head")" = "ccc333" ]
}

@test "apply at the pins changes nothing" {
  at_pins
  zc_module_run tmux apply
  run zc_module_run tmux apply
  [ "$status" -eq 0 ]
  [[ "$output" != *"CHANGED:"* ]] || false
  run zc_calls git
  [[ "$output" != *"fetch"* ]] || false
}

@test "apply fails for a plugin without a pin" {
  at_pins
  printf "set -g @plugin 'tmux-plugins/tmux-yank'\n" \
    >>"$ZC_ROOT/tmux/.tmux.conf"
  run zc_module_run tmux apply
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: tmux-plugins/tmux-yank is not pinned" \
    "fix: add tmux-plugins/tmux-yank" "tmux/zconf/pins"
}

@test "doctor passes when every plugin is at its pin" {
  at_pins
  zc_module_run tmux apply
  run zc_module_run tmux doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: dracula/tmux at ccc333"* ]] || false
}

@test "doctor flags a plugin at another commit" {
  at_pins
  zc_module_run tmux apply
  echo "old999" >"$PLUGINS/tmux/.git/stub_head"
  run zc_module_run tmux doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: dracula/tmux at old999, pinned ccc333" \
    "fix: zconf apply tmux"
}

@test "doctor flags a missing plugin" {
  at_pins
  zc_module_run tmux apply
  rm -rf "$PLUGINS/tmux-sensible"
  run zc_module_run tmux doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: tmux-plugins/tmux-sensible at missing, pinned bbb222"
}

@test "doctor flags a plugin without a pin" {
  at_pins
  zc_module_run tmux apply
  printf "set -g @plugin 'tmux-plugins/tmux-yank'\n" \
    >>"$ZC_ROOT/tmux/.tmux.conf"
  run zc_module_run tmux doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: tmux-plugins/tmux-yank is not pinned"* ]] || false
}

@test "update reports plugins whose master moved" {
  fake_git "ddd444"
  run zc_module_run tmux update
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: dracula/tmux ccc333 -> ddd444"* ]] || false
  zc_calls git | grep -qx "ls-remote https://github.com/dracula/tmux.git HEAD"
}

@test "update reports plugins at master" {
  printf '%s\t%s\n' dracula/tmux same >"$ZC_ROOT/tmux/zconf/pins"
  run zc_module_run tmux update
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: dracula/tmux at master"* ]] || false
}
