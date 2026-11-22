# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/packages/zconf/common.sh"

_pkg_upgrade_manager() {
  local manager="$1" outdated name current latest names=() lines=()
  outdated="$(_pkg_outdated_listed "$manager")"
  while read -r name current latest; do
    if [ -n "$name" ]; then
      names+=("$name")
      lines+=("$name $current -> $latest ($manager)")
    fi
  done <<<"$outdated"
  if [ "${#names[@]}" -eq 0 ]; then
    zc_ok "$manager packages up to date"
    return 0
  fi
  if ! pkg_upgrade "${names[@]}"; then
    zc_error "$manager upgrade failed" "zconf upgrade"
    return 1
  fi
  for name in "${lines[@]}"; do
    zc_changed "upgraded $name"
  done
}

mod_upgrade() {
  _pkg_for_each_manager _pkg_upgrade_manager
}
