# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/git/zzd/common.sh"

mod_doctor() {
  local key wanted current settings status=0
  settings="$(_git_module_settings)"

  while IFS=$'\t' read -r key wanted; do
    current="$(_git_module_current "$key")"
    if [ "$current" = "$wanted" ]; then
      zzd_ok "$key = $wanted"
      continue
    fi

    zzd_error "$key is not $wanted (${current:-unset})" "zzd apply git"
    status=1
  done <<<"$settings"

  return "$status"
}
