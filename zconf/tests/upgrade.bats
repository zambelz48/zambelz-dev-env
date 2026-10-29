#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/mise/.mise/locks" "$ZC_ROOT/mise/zconf" \
    "$ZC_ROOT/packages/zconf"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  cp "$REAL/mise/zconf/platforms" "$ZC_ROOT/mise/zconf/platforms"
  printf 'packages\n' >"$ZC_ROOT/zconf/modules"
  printf '[tools]\nnode = ["24.11.0", "22.12.0"]\n' >"$ZC_ROOT/mise/mise.toml"
  printf '# lock-v1\nlockfile_version = 3\n' >"$ZC_ROOT/mise/mise.lock"
  printf 'sidecar-v1\n' >"$ZC_ROOT/mise/.mise/locks/x"
  for lib in log paths os exec links modules audit upgrade; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  zc_stub git 0
  zc_stub osv-scanner 0
  fake_mise 0
}

# Records calls; `config set` rewrites mise.toml so restore is observable.
fake_mise() {
  local lock_status="$1"
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  "latest node@24") echo 24.12.0 ;;
  "latest node@22") echo 22.12.0 ;;
  "config set "*) printf 'changed\n' >"$ZC_ROOT/mise/mise.toml" ;;
  *" lock --global "*)
    printf '# lock-v2\nlockfile_version = 3\n' >"$ZC_ROOT/mise/mise.lock"
    exit $lock_status
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "upgrade --yes sets the version, re-locks, then installs locked" {
  run zc_upgrade --yes
  [ "$status" -eq 0 ]
  calls="$(zc_calls mise)"
  set_line="$(grep -n '^config set' <<<"$calls" | cut -d: -f1)"
  lock_line="$(grep -n 'lock --global' <<<"$calls" | cut -d: -f1)"
  install_line="$(grep -n 'install --locked' <<<"$calls" | cut -d: -f1)"
  [ "$set_line" -lt "$lock_line" ]
  [ "$lock_line" -lt "$install_line" ]
  platforms="macos-arm64,macos-x64,linux-x64,linux-arm64"
  zc_contains "$calls" "-C $ZC_ROOT/mise lock --global --platform $platforms"
}

@test "upgrade restores mise.toml, the lock and sidecars when re-lock fails" {
  fake_mise 1
  run zc_upgrade --yes
  [ "$status" -eq 1 ]
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" = \
    "$(printf '[tools]\nnode = ["24.11.0", "22.12.0"]')" ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(cat "$ZC_ROOT/mise/.mise/locks/x")" = "sidecar-v1" ]
  zc_contains "$output" \
    "ERROR: re-lock failed; mise.toml and the lock were restored"
  run zc_calls mise
  [[ "$output" != *"install --locked"* ]] || false
}

@test "upgrade --dry-run prints the plan and changes nothing" {
  run zc_upgrade --yes --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN: node 24.11.0 -> 24.12.0"* ]] || false
  [ "$(zc_calls mise | grep -c -E '^config set|lock --global|install')" -eq 0 ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
}

@test "upgrade without a terminal and without --yes refuses" {
  _zc_has_tty() { return 1; }
  run zc_upgrade </dev/null
  [ "$status" -eq 2 ]
  zc_contains "$output" "ERROR: no terminal for the selection" \
    "fix: zconf upgrade --yes"
}

@test "upgrade reports when everything is current" {
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  "latest node@24") echo 24.11.0 ;;
  "latest node@22") echo 22.12.0 ;;
  *) exit 0 ;;
esac
EOF
  run zc_upgrade --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: mise tools are current"* ]] || false
}

@test "upgrade runs each module's upgrade phase and the audit" {
  printf 'mod_upgrade() { echo "packages upgraded"; }\n' \
    >"$ZC_ROOT/packages/zconf/upgrade.sh"
  run zc_upgrade --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"packages upgraded"* ]] || false
  zc_calls osv-scanner | grep -q "scan"
}

@test "a cancelled selection changes nothing at all" {
  _zc_has_tty() { return 0; }
  zc_stub fzf 130
  printf 'mod_upgrade() { echo "packages upgraded"; }\n' \
    >"$ZC_ROOT/packages/zconf/upgrade.sh"
  run zc_upgrade
  [ "$status" -eq 0 ]
  zc_contains "$output" "OK: nothing selected"
  [[ "$output" != *"packages upgraded"* ]] || false
  [ "$(zc_calls mise | grep -c -E '^config set|lock --global')" -eq 0 ]
  [ -z "$(zc_calls osv-scanner)" ]
}

@test "naming tools upgrades only those tools, not OS packages" {
  printf 'mod_upgrade() { echo "packages upgraded"; }\n' \
    >"$ZC_ROOT/packages/zconf/upgrade.sh"
  run zc_upgrade --yes node
  [ "$status" -eq 0 ]
  [[ "$output" != *"packages upgraded"* ]] || false
  [ "$(zc_calls mise | grep -c '^config set')" -eq 1 ]
}

interrupt_during_lock() {
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  "latest node@24") echo 24.12.0 ;;
  "latest node@22") echo 22.12.0 ;;
  "config set "*) printf 'changed\n' >"$ZC_ROOT/mise/mise.toml" ;;
  *" lock --global "*)
    printf '# lock-v2\nlockfile_version = 3\n' >"$ZC_ROOT/mise/mise.lock"
    kill -INT "\$PPID"
    sleep 1
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "an interrupt during re-lock restores config, lock and sidecars" {
  interrupt_during_lock
  run zc_upgrade --yes
  [ "$status" -eq 130 ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" != "changed" ]
  [ "$(cat "$ZC_ROOT/mise/.mise/locks/x")" = "sidecar-v1" ]
  [ "$(zc_calls mise | grep -c 'install --locked')" -eq 0 ]
}

@test "an interrupt during use's re-lock restores everything too" {
  interrupt_during_lock
  run zc_use node 22.12.0
  [ "$status" -eq 130 ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" != "changed" ]
}

@test "use puts the version first, re-locks and installs" {
  run zc_use node 22.12.0
  [ "$status" -eq 0 ]
  calls="$(zc_calls mise)"
  grep -q "^config set .* tools.node 22.12.0,24.11.0 --type list" <<<"$calls"
  grep -q "lock --global" <<<"$calls"
  grep -q "install --locked" <<<"$calls"
}

@test "use restores everything when re-lock fails" {
  fake_mise 1
  run zc_use node 20.11.0
  [ "$status" -eq 1 ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
}
