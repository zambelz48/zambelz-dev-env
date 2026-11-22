# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/packages/zconf/common.sh"

_pkg_doctor_manager() {
  local manager="$1" entries name command version status=0 present=()
  local unrequested
  entries="$(_pkg_entries "$manager")"
  while IFS=$'\t' read -r name command; do
    if [ -z "$name" ]; then
      continue
    fi
    if _pkg_provided "$command"; then
      zc_ok "$name (provided by $command)"
    elif pkg_is_installed "$name"; then
      version="$(pkg_version "$name")"
      zc_ok "$name $version (system-managed)"
      present+=("$name")
    else
      zc_error "$name is not installed" "zconf apply packages"
      status=1
    fi
  done <<<"$entries"
  unrequested="$(_pkg_unrequested ${present[@]+"${present[@]}"})"
  while IFS= read -r name; do
    if [ -n "$name" ]; then
      zc_warn "$name is installed only as a dependency; cleanup may remove it" \
        "zconf apply packages"
    fi
  done <<<"$unrequested"
  return "$status"
}

mod_doctor() {
  _pkg_for_each_manager _pkg_doctor_manager
}
