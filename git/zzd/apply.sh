# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/git/zzd/common.sh"

mod_apply() {
  local key wanted current settings
  settings="$(_git_module_settings)"

  while IFS=$'\t' read -r key wanted; do
    current="$(_git_module_current "$key")"
    if [ "$current" = "$wanted" ]; then
      zzd_ok "$key = $wanted"
      continue
    fi

    zzd_do git -C "$ZZD_ROOT" config "$key" "$wanted" || return 1
    zzd_changed "$key = $wanted"
  done <<<"$settings"
}
