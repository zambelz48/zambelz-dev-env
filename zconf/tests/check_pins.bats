#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  PY="$MISE_DATA_DIR/shims/python3"
  SCRIPT="$ZC_ROOT/zconf/lib/check_pins.py"
  F="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$F/zconf"
  printf 'macos-arm64,macos-x64,linux-x64,linux-arm64\n' \
    >"$F/zconf/platforms"
  SHA_A="e261deb1b47614eed3400089ce7197dc68acc4eb"
  SHA_B="50b5fdfcbece52124c1ecfd5687469d163e05bf3"
  cat >"$F/mise.toml" <<'EOF'
[settings]
idiomatic_version_file_enable_tools = ["node"]

[tool_config]
locked = true

[tools]
node = ["24.11.0", "22.12.0"]
java = "temurin-25.0.1+8"
marksman = "2026-02-08"
"github:cantino/mcfly" = { version = "0.9.4", os = ["linux"] }

[tools."http:jdtls"]
version = "1.63.0"
EOF
  cat >"$F/mise.lock" <<'EOF'
lockfile_version = 3

[[tools.node]]
version = "24.11.0"

[[tools.node]]
version = "22.12.0"

[[tools.java]]
version = "temurin-25.0.1+8"

[[tools.marksman]]
version = "2026-02-08"

[[tools."github:cantino/mcfly"]]
version = "0.9.4"

[[tools."http:jdtls"]]
version = "1.63.0"
EOF
  printf 'OHMYZSH_URL=https://example.invalid\nOHMYZSH_COMMIT=%s\n' \
    "$SHA_A" >"$F/zsh-pins"
  printf "set -g @plugin 'tmux-plugins/tpm'\nset -g @plugin 'dracula/tmux'\n" \
    >"$F/tmux.conf"
  printf 'tmux-plugins/tpm\t%s\ndracula/tmux\t%s\n' "$SHA_A" "$SHA_B" \
    >"$F/tmux-pins"
}

check() {
  run "$PY" "$SCRIPT" "$F/mise.toml" "$F/mise.lock" "$F/zsh-pins" \
    "$F/tmux.conf" "$F/tmux-pins"
}

set_tool() {
  local line="$1"
  "$PY" - "$F/mise.toml" "$line" <<'EOF'
import sys
path, line = sys.argv[1], sys.argv[2]
text = open(path).read().replace("[tools]\n", "[tools]\n" + line + "\n", 1)
open(path, "w").write(text)
EOF
}

@test "exact pins present in the lock pass" {
  check
  [ "$status" -eq 0 ]
  [[ "$output" == "OK: "* ]] || false
}

replace_in_config() {
  "$PY" - "$F/mise.toml" "$1" "$2" <<'EOF'
import sys
path, old, new = sys.argv[1:]
text = open(path).read()
assert old in text, old
open(path, "w").write(text.replace(old, new, 1))
EOF
}

@test "a global setting that changes every project is rejected" {
  replace_in_config '[settings]' \
    $'[settings]\nlocked = true\ndotnet.isolated = true'
  check
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: global setting locked applies to every project" \
    "ERROR: global setting dotnet.isolated applies to every project"
}

@test "a global table that applies to every project is rejected" {
  printf '\n[env]\nNODE_ENV = "dev"\n\n[hooks]\nenter = "echo hi"\n' \
    >>"$F/mise.toml"
  check
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: global [env] applies to every project" \
    "ERROR: global [hooks] applies to every project"
}

@test "global tools must be locked through tool_config" {
  replace_in_config $'[tool_config]\nlocked = true\n' ''
  check
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: [tool_config] locked = true is missing"* ]] || false
}

lock_fd() {
  local platform
  for platform in "$@"; do
    printf '\n[[tools.fd]]\nversion = "10.5.0"\n' >>"$F/mise.lock"
    printf '\n[tools.fd."platforms.%s"]\nurl = "u"\n' "$platform" \
      >>"$F/mise.lock"
  done
}

@test "a locked tool missing a platform is rejected" {
  set_tool 'fd = "10.5.0"'
  lock_fd macos-arm64
  check
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: fd 10.5.0 is not locked for macos-x64, linux-x64, linux-arm64"
}

@test "a tool's os option limits the platforms it must be locked for" {
  set_tool 'fd = { version = "10.5.0", os = ["macos/arm64"] }'
  lock_fd macos-arm64
  check
  [ "$status" -eq 0 ]
}

@test "per-platform lock entries of one version are combined" {
  set_tool 'fd = { version = "10.5.0", os = ["macos", "linux/x64"] }'
  lock_fd macos-arm64 macos-x64 linux-x64
  check
  [ "$status" -eq 0 ]
}

@test "--mise checks only the mise pins" {
  printf 'OHMYZSH_COMMIT=master\n' >"$F/zsh-pins"
  run "$PY" "$SCRIPT" --mise "$F/mise.toml" "$F/mise.lock"
  [ "$status" -eq 0 ]
  [[ "$output" == "OK: "* ]] || false
}

@test "a major-only version is rejected" {
  set_tool 'go = "24"'
  check
  [ "$status" -eq 1 ]
  [[ "$output" == *'ERROR: go = "24" is not an exact version'* ]] || false
}

@test "latest, ranges, prefixes and x wildcards are rejected" {
  set_tool 'a = "latest"'
  set_tool 'b = "^1.2.3"'
  set_tool 'c = "prefix:1.2"'
  set_tool 'd = "1.x"'
  set_tool 'e = "lts"'
  set_tool 'f = "3.13"'
  check
  [ "$status" -eq 1 ]
  for t in a b c d e f; do
    [[ "$output" == *"ERROR: $t = "*"is not an exact version"* ]] || false
  done
}

@test "a pinned version missing from the lock is rejected" {
  set_tool 'ruby = "3.4.1"'
  check
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: ruby 3.4.1 is not in the lock"* ]] || false
}

@test "a missing oh-my-zsh commit is rejected" {
  printf 'OHMYZSH_COMMIT=master\n' >"$F/zsh-pins"
  check
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: OHMYZSH_COMMIT is not a full commit sha"* ]] ||
    false
}

@test "a tmux plugin without a pin is rejected" {
  printf "set -g @plugin 'tmux-plugins/tmux-yank'\n" >>"$F/tmux.conf"
  check
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: tmux plugin tmux-plugins/tmux-yank is not pinned"
}

@test "a tmux pin that is not a full commit sha is rejected" {
  printf 'tmux-plugins/tpm\tv3.1.0\ndracula/tmux\t%s\n' "$SHA_B" \
    >"$F/tmux-pins"
  check
  [ "$status" -eq 1 ]
  zc_contains "$output" \
    "ERROR: tmux plugin tmux-plugins/tpm pin v3.1.0 is not a full commit sha"
}
