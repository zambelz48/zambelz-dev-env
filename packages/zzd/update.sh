# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/packages/zconf/common.sh"

_pkg_update_manager() {
  local manager="$1" outdated name current latest found=0
  outdated="$(_pkg_outdated_listed "$manager")"
  while read -r name current latest; do
    if [ -n "$name" ]; then
      zc_info "$name $current -> $latest ($manager)"
      found=1
    fi
  done <<<"$outdated"
  if [ "$found" -eq 0 ]; then
    zc_ok "$manager packages up to date"
  fi
}

mod_update() {
  _pkg_for_each_manager _pkg_update_manager
}
