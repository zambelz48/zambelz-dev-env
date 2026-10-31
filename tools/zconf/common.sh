# shellcheck shell=bash

_tools_bin_dir() {
  printf '%s/.local/share/zconf/bin' "${ZC_HOME:?}"
}

_tools_path_line() {
  # shellcheck disable=SC2016 # written to .zshenv, expanded by zsh
  printf 'export PATH="$HOME/.local/share/zconf/bin:$PATH"'
}

_tools_lock() {
  case "$1" in
    npm) printf '%s/tools/npm/pnpm-lock.yaml' "${ZC_ROOT:?}" ;;
    *) printf '%s/tools/python/uv.lock' "${ZC_ROOT:?}" ;;
  esac
}

_tools_stamp() {
  printf '%s/tools/%s.lock' "${ZC_STATE_DIR:?}" "$1"
}

_tools_installed() {
  local lock stamp
  lock="$(_tools_lock "$1")"
  stamp="$(_tools_stamp "$1")"
  [ -d "$2" ] && cmp -s "$lock" "$stamp"
}

_tools_record() {
  local stamp
  stamp="$(_tools_stamp "$1")"
  mkdir -p "${stamp%/*}"
  cp "$(_tools_lock "$1")" "$stamp"
}

_tools_entries() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    if zc_is_data_line "$line"; then
      printf '%s\n' "$line"
    fi
  done <"${ZC_ROOT:?}/tools/zconf/bins"
}

_tools_target() {
  case "$2" in
    npm) printf '%s/tools/npm/node_modules/.bin/%s' "${ZC_ROOT:?}" "$1" ;;
    *) printf '%s/tools/python/.venv/bin/%s' "${ZC_ROOT:?}" "$1" ;;
  esac
}

_tools_path_dir() {
  local node
  case "$1" in
    npm)
      node="$(zc_tool node)" || return 1
      printf '%s' "${node%/*}"
      ;;
    *) printf '%s/tools/python/.venv/bin' "${ZC_ROOT:?}" ;;
  esac
}

_tools_runtime() {
  case "$1" in
    npm) printf 'node' ;;
    *) printf 'python' ;;
  esac
}

_tools_shims() {
  printf '%s/shims' "${MISE_DATA_DIR:-${ZC_HOME:?}/.local/share/mise}"
}

_tools_wrapper() {
  local cmd="$1" kind="$2" dir target mise
  dir="$(_tools_path_dir "$kind")" || return 1
  mise="$(command -v mise)" || return 1
  target="$(_tools_target "$cmd" "$kind")"
  # shellcheck disable=SC2016 # $PATH and $@ expand when the wrapper runs
  printf '%s\n' '#!/bin/sh' \
    "case \"\$(\"$mise\" which --plugin $cmd </dev/null 2>/dev/null)\" in" \
    "  '' | $(_tools_runtime "$kind")) ;;" \
    "  *) exec \"$(_tools_shims)/$cmd\" \"\$@\" ;;" \
    'esac' \
    "PATH=\"$dir:\$PATH\" exec \"$target\" \"\$@\""
}

_tools_npm_run() {
  local pnpm node
  if ! pnpm="$(zc_tool pnpm)" || ! node="$(zc_tool node)"; then
    zc_error "pnpm or node is not installed by mise" "zconf apply mise"
    return 1
  fi
  (cd "${ZC_ROOT:?}/tools/npm" && PATH="${node%/*}:$PATH" "$pnpm" "$@")
}

_tools_uv_run() {
  local uv python
  if ! uv="$(zc_tool uv)" || ! python="$(zc_tool python3)"; then
    zc_error "uv or python is not installed by mise" "zconf apply mise"
    return 1
  fi
  (cd "${ZC_ROOT:?}/tools/python" &&
    UV_PYTHON="$python" UV_PYTHON_DOWNLOADS=never "$uv" "$@")
}

_tools_install_npm() {
  local dir="${ZC_ROOT:?}/tools/npm" output
  if _tools_installed npm "$dir/node_modules"; then
    zc_ok "npm tools installed from pnpm-lock.yaml"
    return 0
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: pnpm install --frozen-lockfile in %s\n' "$dir"
    return 0
  fi
  if ! output="$(_tools_npm_run install --frozen-lockfile 2>&1)"; then
    printf '%s\n' "$output"
    zc_error "pnpm install --frozen-lockfile failed" \
      "cd $dir && pnpm install --lockfile-only"
    return 1
  fi
  _tools_record npm
  zc_changed "installed npm tools from pnpm-lock.yaml"
}

_tools_install_python() {
  local dir="${ZC_ROOT:?}/tools/python" output
  if [ -x "$dir/.venv/bin/python" ] &&
    _tools_installed python "$dir/.venv"; then
    zc_ok "python tools installed from uv.lock"
    return 0
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: uv sync --locked in %s\n' "$dir"
    return 0
  fi
  if ! output="$(_tools_uv_run sync --locked 2>&1)"; then
    printf '%s\n' "$output"
    zc_error "uv sync --locked failed" "cd $dir && uv lock"
    return 1
  fi
  _tools_record python
  zc_changed "installed python tools from uv.lock"
}
