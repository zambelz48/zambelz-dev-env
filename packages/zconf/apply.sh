# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/packages/zconf/common.sh"

_pkg_keep_present() {
  local names name keep=()
  names="$(_pkg_unrequested "$@")"
  while IFS= read -r name; do
    if [ -n "$name" ]; then
      keep+=("$name")
    fi
  done <<<"$names"
  if [ "${#keep[@]}" -eq 0 ]; then
    return 0
  fi
  if ! pkg_keep "${keep[@]}"; then
    zc_error "marking ${keep[*]} as explicitly installed failed" \
      "zconf apply packages"
    return 1
  fi
  zc_changed "marked ${keep[*]} as explicitly installed"
}

_pkg_apply_manager() {
  local manager="$1" entries name command missing=() present=()
  entries="$(_pkg_entries "$manager")"
  while IFS=$'\t' read -r name command; do
    if [ -z "$name" ]; then
      continue
    fi
    if _pkg_provided "$command"; then
      zc_ok "$name (provided by $command)"
    elif pkg_is_installed "$name"; then
      zc_ok "$name"
      present+=("$name")
    else
      missing+=("$name")
    fi
  done <<<"$entries"
  if [ "${#missing[@]}" -gt 0 ]; then
    if ! pkg_install "${missing[@]}"; then
      zc_error "installing ${missing[*]} failed" "zconf apply packages"
      return 1
    fi
    zc_changed "installed ${missing[*]}"
  fi
  _pkg_keep_present ${present[@]+"${present[@]}"}
}

mod_apply() {
  _pkg_for_each_manager _pkg_apply_manager
}
