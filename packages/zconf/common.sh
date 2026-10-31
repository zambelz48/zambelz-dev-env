# shellcheck shell=bash

_pkg_managers() {
  local os="$1" line_os manager
  while IFS=$'\t' read -r line_os manager || [ -n "$line_os" ]; do
    if [ "$line_os" = "$os" ]; then
      printf '%s\n' "$manager"
    fi
  done <"${ZC_ROOT:?}/packages/zconf/managers"
}

_pkg_entries() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    if zc_is_data_line "$line"; then
      printf '%s\n' "$line"
    fi
  done <"${ZC_ROOT:?}/packages/$1.txt"
}

_pkg_provided() {
  [ -n "$1" ] && command -v "$1" >/dev/null 2>&1
}

_pkg_unrequested() {
  if [ "$#" -gt 0 ] && declare -F pkg_unrequested >/dev/null; then
    pkg_unrequested "$@"
  fi
}

_pkg_outdated_listed() {
  local manager="$1" entries name installed=()
  entries="$(_pkg_entries "$manager")"
  while IFS=$'\t' read -r name _; do
    if [ -n "$name" ] && pkg_is_installed "$name"; then
      installed+=("$name")
    fi
  done <<<"$entries"
  if [ "${#installed[@]}" -gt 0 ]; then
    pkg_outdated "${installed[@]}"
  fi
}

_pkg_for_each_manager() {
  local action="$1" os managers manager status=0
  os="$(zc_os)"
  if [ "$os" = "unsupported" ]; then
    zc_error "unsupported OS" "use macOS, Fedora or Ubuntu"
    return 1
  fi
  managers="$(_pkg_managers "$os")"
  while IFS= read -r manager; do
    if [ -z "$manager" ]; then
      continue
    fi
    (
      # shellcheck source=/dev/null
      . "$ZC_ROOT/zconf/adapters/pkg/$manager.sh"
      if ! pkg_available; then
        zc_error "$manager is not available" "$ZC_ROOT/bootstrap.sh"
        exit 1
      fi
      "$action" "$manager"
    ) || status=1
  done <<<"$managers"
  return "$status"
}
