# shellcheck shell=bash

ZC_HOME="${ZC_HOME:-$HOME}"
ZC_STATE_DIR="${ZC_STATE_DIR:-$ZC_HOME/.local/state/zconf}"
export ZC_HOME ZC_STATE_DIR

# Hooks and GUI clients run without the login PATH; bootstrap puts mise here.
case ":$PATH:" in
  *":$ZC_HOME/.local/bin:"*) ;;
  *) PATH="$ZC_HOME/.local/bin:$PATH" ;;
esac
export PATH

# Path of a binary from the global mise tools. Shims pick versions by the
# current directory and may install; `mise which` does neither.
zc_tool() {
  mise -C "${ZC_HOME:?}" which "$1" 2>/dev/null
}

# The helpers need tomllib (3.11+), so always the global python.
zc_python() {
  local python
  if ! python="$(zc_tool python3)"; then
    zc_error "python3 is not installed by mise" "zconf apply mise"
    return 1
  fi
  "$python" "$@"
}

zc_lock_platforms() {
  cat "${ZC_ROOT:?}/mise/zconf/platforms"
}

# Data files (modules, links, fonts, pins, package lists) skip these lines.
zc_is_data_line() {
  case "$1" in
    '' | '#'*) return 1 ;;
    *) return 0 ;;
  esac
}
