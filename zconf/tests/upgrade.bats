#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/mise/zconf" "$ZC_ROOT/packages/zconf"
  cp -R "$REAL/zconf" "$ZC_ROOT/zconf"
  cp "$REAL/mise/zconf/platforms" "$ZC_ROOT/mise/zconf/platforms"
  printf 'packages\n' >"$ZC_ROOT/zconf/modules"
  CONFIG="$(printf '[tools]\nnode = ["24.11.0", "22.12.0"]\ngo = "1.26.4"')"
  printf '%s\n' "$CONFIG" >"$ZC_ROOT/mise/mise.toml"
  write_lock lock-v1 "node 24.11.0" "node 22.12.0" "go 1.26.4" \
    >"$ZC_ROOT/mise/mise.lock"
  write_lock lock-v2 "node 24.12.0" "node 24.11.0" "node 22.12.0" \
    "node 20.11.0" "go 1.26.10" "go 1.26.4" >"$BATS_TEST_TMPDIR/lock-v2"
  write_lock lock-v2 "node 24.12.0" "node 22.12.0" "go 1.26.10 none" \
    >"$BATS_TEST_TMPDIR/lock-v2-bare"
  for lib in log paths os exec links modules audit upgrade; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  zc_stub git 0
  zc_stub osv-scanner 0
  fake_mise
}

# Each argument is "<tool> <version> [none]"; none leaves out the platforms.
write_lock() {
  local tag="$1" spec tool version bare platform
  shift
  printf '# %s\nlockfile_version = 3\n' "$tag"
  for spec in "$@"; do
    read -r tool version bare <<<"$spec"
    printf '\n[[tools.%s]]\nversion = "%s"\nbackend = "core:%s"\n' \
      "$tool" "$version" "$tool"
    if [ "$bare" = "none" ]; then
      continue
    fi
    for platform in macos-arm64 macos-x64 linux-x64 linux-arm64; do
      printf '[tools.%s."platforms.%s"]\nurl = "https://example.com/%s"\n' \
        "$tool" "$platform" "$platform"
    done
  done
}

# Records calls; `config set` marks mise.toml so restore is observable, and
# `lock` copies $LOCK_FILE unless the locked tool is listed in $FAIL_LOCK.
fake_mise() {
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  "latest node@24") echo 24.12.0 ;;
  "latest node@22") echo 22.12.0 ;;
  "latest go@1") echo 1.26.10 ;;
  "config set "*) printf '# changed %s\n' "\$5" >>"$ZC_ROOT/mise/mise.toml" ;;
  *" lock --global "*)
    case " \${FAIL_LOCK:-} " in
      *" \${@: -1} "*) exit 1 ;;
      *) ;;
    esac
    cp "\${LOCK_FILE:-$BATS_TEST_TMPDIR/lock-v2}" "$ZC_ROOT/mise/mise.lock"
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "upgrade --yes sets each version, locks that tool, then installs" {
  run zc_upgrade --yes
  [ "$status" -eq 0 ]
  calls="$(zc_calls mise)"
  set_line="$(grep -n '^config set .*tools.node' <<<"$calls" | cut -d: -f1)"
  lock_line="$(grep -n 'lock --global .* node$' <<<"$calls" | cut -d: -f1)"
  install_line="$(grep -n 'install --locked' <<<"$calls" | cut -d: -f1)"
  [ "$set_line" -lt "$lock_line" ]
  [ "$lock_line" -lt "$install_line" ]
  [ "$(grep -c 'install --locked' <<<"$calls")" -eq 1 ]
  platforms="macos-arm64,macos-x64,linux-x64,linux-arm64"
  zc_contains "$calls" \
    "-C $ZC_ROOT/mise lock --global --platform $platforms node"
  zc_contains "$output" "CHANGED: node 24.11.0 -> 24.12.0" \
    "CHANGED: go 1.26.4 -> 1.26.10"
}

@test "a tool that cannot be locked is put back and the others upgrade" {
  FAIL_LOCK=go run zc_upgrade --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: could not lock go 1.26.10; go was left as it was"* \
    ]] || false
  [[ "$output" == *"CHANGED: node 24.11.0 -> 24.12.0"* ]] || false
  grep -qx '# changed tools.node' "$ZC_ROOT/mise/mise.toml"
  [ "$(grep -c 'tools.go' "$ZC_ROOT/mise/mise.toml")" -eq 0 ]
  [ "$(zc_calls mise | grep -c 'install --locked')" -eq 1 ]
}

@test "a version locked without downloads is put back" {
  LOCK_FILE="$BATS_TEST_TMPDIR/lock-v2-bare" run zc_upgrade --yes go
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: go 1.26.10 has no download for any platform" \
    "ERROR: could not lock go 1.26.10"
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" = "$CONFIG" ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(zc_calls mise | grep -c 'install --locked')" -eq 0 ]
}

@test "when no tool can be locked, config and lock are unchanged" {
  FAIL_LOCK="node go" run zc_upgrade --yes
  [ "$status" -eq 1 ]
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" = "$CONFIG" ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(zc_calls mise | grep -c 'install --locked')" -eq 0 ]
  [ -z "$(find "$TMPDIR" -mindepth 1 -type d)" ]
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
  "latest go@1") echo 1.26.4 ;;
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
  "latest go@1") echo 1.26.10 ;;
  "config set "*) printf '# changed %s\n' "\$5" >>"$ZC_ROOT/mise/mise.toml" ;;
  *" lock --global "*)
    cp "$BATS_TEST_TMPDIR/lock-v2" "$ZC_ROOT/mise/mise.lock"
    kill -INT "\$PPID"
    sleep 1
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "an interrupt during a lock restores config and lock" {
  interrupt_during_lock
  run zc_upgrade --yes
  [ "$status" -eq 130 ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" = "$CONFIG" ]
  [ "$(zc_calls mise | grep -c 'install --locked')" -eq 0 ]
  [ -z "$(find "$TMPDIR" -mindepth 1 -type d)" ]
}

@test "an interrupt during use's lock restores everything too" {
  interrupt_during_lock
  run zc_use node 22.12.0
  [ "$status" -eq 130 ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" = "$CONFIG" ]
}

@test "use puts the version first, locks that tool and installs" {
  run zc_use node 22.12.0
  [ "$status" -eq 0 ]
  calls="$(zc_calls mise)"
  grep -q "^config set .* tools.node 22.12.0,24.11.0 --type list" <<<"$calls"
  grep -q "lock --global .* node$" <<<"$calls"
  grep -q "install --locked" <<<"$calls"
}

@test "use restores everything when the lock fails" {
  FAIL_LOCK=node run zc_use node 20.11.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: could not lock node 20.11.0"* ]] || false
  [ "$(cat "$ZC_ROOT/mise/mise.toml")" = "$CONFIG" ]
  [ "$(head -1 "$ZC_ROOT/mise/mise.lock")" = "# lock-v1" ]
  [ "$(zc_calls mise | grep -c 'install --locked')" -eq 0 ]
  [ -z "$(find "$TMPDIR" -mindepth 1 -type d)" ]
}
