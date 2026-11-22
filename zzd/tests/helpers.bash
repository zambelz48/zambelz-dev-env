ZC_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

zc_test_setup() {
  ZC_ROOT="$(cd "$ZC_TESTS_DIR/../.." && pwd -P)"
  MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
  ZC_REAL_MISE="$(readlink "$MISE_DATA_DIR/shims/node")"
  export ZC_REAL_MISE
  local mise_config="$HOME/.config/mise/config.toml"
  MISE_GLOBAL_CONFIG_FILE="${MISE_GLOBAL_CONFIG_FILE:-$mise_config}"
  if [ "$(uname -s)" = "Darwin" ]; then
    MISE_CACHE_DIR="${MISE_CACHE_DIR:-$HOME/Library/Caches/mise}"
  else
    MISE_CACHE_DIR="${MISE_CACHE_DIR:-$HOME/.cache/mise}"
  fi
  MISE_STATE_DIR="${MISE_STATE_DIR:-$HOME/.local/state/mise}"
  export MISE_DATA_DIR MISE_CACHE_DIR MISE_STATE_DIR MISE_GLOBAL_CONFIG_FILE
  HOME="$BATS_TEST_TMPDIR/home"
  ZC_HOME="$HOME"
  ZC_STATE_DIR="$HOME/.local/state/zconf"
  export ZC_ROOT HOME ZC_HOME ZC_STATE_DIR
  TMPDIR="$BATS_TEST_TMPDIR/tmp"
  export TMPDIR
  mkdir -p "$HOME" "$TMPDIR" "$BATS_TEST_TMPDIR/stubs" \
    "$BATS_TEST_TMPDIR/calls"
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  unset ZC_RUN_LOG ZC_DRY_RUN
}

zc_stub() {
  local cmd="$1" code="$2" out="${3:-}"
  local stub="$BATS_TEST_TMPDIR/stubs/$cmd"
  local calls="$BATS_TEST_TMPDIR/calls/$cmd"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" "$*" >> %q\n' "$calls"
    if [ -n "$out" ]; then
      printf 'printf "%%s\\n" %q\n' "$out"
    fi
    printf 'exit %d\n' "$code"
  } >"$stub"
  chmod +x "$stub"
}

# Rebuilds PATH so every directory holding the command is replaced by a
# mirror of it without that command.
zc_hide_command() {
  local name="$1" dir file mirror n=0 path="" dirs
  IFS=: read -r -a dirs <<<"$PATH"
  for dir in "${dirs[@]}"; do
    if [ -e "$dir/$name" ]; then
      n=$((n + 1))
      mirror="$BATS_TEST_TMPDIR/hidden/$n"
      mkdir -p "$mirror"
      for file in "$dir"/*; do
        if [ "${file##*/}" != "$name" ]; then
          ln -s "$file" "$mirror/${file##*/}"
        fi
      done
      dir="$mirror"
    fi
    path="${path:+$path:}$dir"
  done
  export PATH="$path"
}

zc_stub_script() {
  local cmd="$1" body
  if [ "$#" -ge 2 ]; then
    body="$2"
  else
    body="$(cat)"
  fi
  local stub="$BATS_TEST_TMPDIR/stubs/$cmd"
  local calls="$BATS_TEST_TMPDIR/calls/$cmd"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" "$*" >> %q\n' "$calls"
    printf '%s\n' "$body"
  } >"$stub"
  chmod +x "$stub"
}

# Passes when $1 contains every later argument, in order, as literal text.
# A failing function call fails the test on bash 3.2, unlike `[[ ]]`.
zc_contains() {
  local rest="$1" piece
  shift
  for piece in "$@"; do
    case "$rest" in
      *"$piece"*) rest="${rest#*"$piece"}" ;;
      *)
        printf 'not found: %s\n' "$piece"
        return 1
        ;;
    esac
  done
}

# Case branch for a mise stub: `mise ... which <bin>` answers with this test's
# stub of <bin> when there is one, otherwise asks the real mise.
zc_mise_which_branch() {
  cat <<EOF
  *" which "*)
    bin="\${@: -1}"
    if [ "\$bin" != mise ] && [ -x "$BATS_TEST_TMPDIR/stubs/\$bin" ]; then
      echo "$BATS_TEST_TMPDIR/stubs/\$bin"
    else
      exec "$ZC_REAL_MISE" "\$@"
    fi
    ;;
EOF
}

# A mise stub that only points `which` at this test's stubs.
zc_stub_mise_passthrough() {
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  *) exec "$ZC_REAL_MISE" "\$@" ;;
esac
EOF
}

zc_calls() {
  local calls="$BATS_TEST_TMPDIR/calls/$1"
  if [ -f "$calls" ]; then
    cat "$calls"
  fi
}
