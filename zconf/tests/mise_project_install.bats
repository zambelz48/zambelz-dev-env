#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Installs a fake Go from a local mirror, laid out like a real machine:
# ~/.config/mise holds symlinks into a copy of this repository's mise dir.
setup() {
  load helpers
  zc_test_setup
  PY="$MISE_DATA_DIR/shims/python3"
  REPO="$BATS_TEST_TMPDIR/repo"
  PROJECT="$HOME/Dev/project"
  MIRROR="$BATS_TEST_TMPDIR/mirror"
  mkdir -p "$REPO" "$HOME/.config/mise" "$PROJECT" "$MIRROR" \
    "$BATS_TEST_TMPDIR/fake/go/bin" "$BATS_TEST_TMPDIR/shims"
  cp "$ZC_ROOT/mise/mise.toml" "$ZC_ROOT/mise/mise.lock" "$REPO/"
  ln -s "$REPO/mise.toml" "$HOME/.config/mise/config.toml"
  ln -s "$REPO/mise.lock" "$HOME/.config/mise/mise.lock"
  printf 'module example\n\ngo 1.25.99\n' >"$PROJECT/go.mod"
  ln -s "$ZC_REAL_MISE" "$BATS_TEST_TMPDIR/shims/go"

  printf '#!/bin/sh\necho "go version go1.25.99"\n' \
    >"$BATS_TEST_TMPDIR/fake/go/bin/go"
  chmod +x "$BATS_TEST_TMPDIR/fake/go/bin/go"
  local platform archive
  for platform in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64; do
    archive="go1.25.99.$platform.tar.gz"
    tar -C "$BATS_TEST_TMPDIR/fake" -czf "$MIRROR/$archive" go
    # Go's .sha256 files have no trailing newline; mise compares it verbatim.
    "$PY" -c 'import hashlib, sys; sys.stdout.write(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' \
      "$MIRROR/$archive" >"$MIRROR/$archive.sha256"
  done

  "$PY" -c '
import functools, http.server, sys
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
server = http.server.HTTPServer(("127.0.0.1", 0), handler)
with open(sys.argv[2] + ".tmp", "w") as f:
    f.write(str(server.server_port))
__import__("os").rename(sys.argv[2] + ".tmp", sys.argv[2])
server.serve_forever()
' "$MIRROR" "$BATS_TEST_TMPDIR/port" 2>/dev/null &
  SERVER_PID=$!
  local tries=0
  while [ ! -s "$BATS_TEST_TMPDIR/port" ]; do
    tries=$((tries + 1))
    if [ "$tries" -gt 50 ]; then
      echo "ERROR: mirror server did not start" >&2
      return 1
    fi
    "$PY" -c 'import time; time.sleep(0.1)'
  done
  PORT="$(cat "$BATS_TEST_TMPDIR/port")"
}

teardown() {
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}

@test "a shim auto-installing a go.mod version leaves the global lock untouched" {
  # shellcheck source=../../mise/zconf/common.sh
  . "$ZC_ROOT/mise/zconf/common.sh"
  eval "$(_mise_global_root_line)"
  before="$(cksum <"$REPO/mise.lock")"
  cd "$PROJECT"
  run --separate-stderr env -u MISE_GLOBAL_CONFIG_FILE \
    MISE_GLOBAL_CONFIG_ROOT="$MISE_GLOBAL_CONFIG_ROOT" \
    MISE_CONFIG_DIR="$HOME/.config/mise" \
    MISE_DATA_DIR="$BATS_TEST_TMPDIR/mise-data" \
    MISE_CACHE_DIR="$BATS_TEST_TMPDIR/mise-cache" \
    MISE_STATE_DIR="$BATS_TEST_TMPDIR/mise-state" \
    MISE_TRUSTED_CONFIG_PATHS="$BATS_TEST_TMPDIR" \
    MISE_GO_DOWNLOAD_MIRROR="http://127.0.0.1:$PORT" \
    "$BATS_TEST_TMPDIR/shims/go" version
  [ "$status" -eq 0 ]
  [ "$output" = "go version go1.25.99" ]
  [ "$(cksum <"$REPO/mise.lock")" = "$before" ]
  [ ! -e "$PROJECT/mise.lock" ]
}
