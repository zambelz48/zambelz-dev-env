# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/packages/zzd/common.sh"

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
    zzd_ok "$manager packages up to date"
    return 0
  fi
  if ! pkg_upgrade "${names[@]}"; then
    zzd_error "$manager upgrade failed" "zzd upgrade"
    return 1
  fi
  for name in "${lines[@]}"; do
    zzd_changed "upgraded $name"
  done
}

mod_upgrade() {
  _pkg_for_each_manager _pkg_upgrade_manager
}
