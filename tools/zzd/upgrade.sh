# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/tools/zconf/common.sh"

_tools_relock() {
  local kind="$1" lock backup
  shift
  lock="$(_tools_lock "$kind")"
  if _zc_dry_run; then
    printf 'DRY-RUN: re-resolve %s\n' "$lock"
    return 0
  fi
  backup="$(mktemp)"
  cp "$lock" "$backup"
  if ! "$@" >/dev/null 2>&1; then
    cp "$backup" "$lock"
    rm -f "$backup"
    zc_error "re-resolving ${lock##*/} failed; it was restored"
    return 1
  fi
  if cmp -s "$backup" "$lock"; then
    zc_ok "${lock##*/} dependencies are current"
  else
    zc_changed "re-resolved ${lock##*/}"
  fi
  rm -f "$backup"
}

mod_upgrade() {
  local status=0
  if _tools_relock npm _tools_npm_run update --lockfile-only --no-save; then
    _tools_install_npm || status=1
  else
    status=1
  fi
  if _tools_relock python _tools_uv_run lock --upgrade; then
    _tools_install_python || status=1
  else
    status=1
  fi
  return "$status"
}
