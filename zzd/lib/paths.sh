# shellcheck shell=bash

ZZD_HOME="${ZZD_HOME:-$HOME}"
ZZD_STATE_DIR="${ZZD_STATE_DIR:-$ZZD_HOME/.local/state/zzd}"
export ZZD_HOME ZZD_STATE_DIR

# Hooks and GUI clients run without the login PATH; bootstrap puts mise here.
case ":$PATH:" in
  *":$ZZD_HOME/.local/bin:"*) ;;
  *) PATH="$ZZD_HOME/.local/bin:$PATH" ;;
esac
export PATH

# Path of a binary from the global mise tools. Shims pick versions by the
# current directory and may install; `mise which` does neither.
zzd_tool() {
  mise -C "${ZZD_HOME:?}" which "$1" 2>/dev/null
}

# The helpers need tomllib (3.11+), so always the global python.
zzd_python() {
  local python
  if ! python="$(zzd_tool python3)"; then
    zzd_error "python3 is not installed by mise" "zzd apply mise"
    return 1
  fi
  "$python" "$@"
}

zzd_lock_platforms() {
  cat "${ZZD_ROOT:?}/mise/zzd/platforms"
}

# Data files (modules, links, fonts, pins, package lists) skip these lines.
zzd_is_data_line() {
  case "$1" in
    '' | '#'*) return 1 ;;
    *) return 0 ;;
  esac
}
