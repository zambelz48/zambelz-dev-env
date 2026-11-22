# shellcheck shell=bash
# shellcheck source=submodules.sh
. "${ZZD_ROOT:?}/zzd/lib/submodules.sh"

zzd_modules_list() {
  local name status=0
  while IFS= read -r name || [ -n "$name" ]; do
    zzd_is_data_line "$name" || continue
    if [ -d "$ZZD_ROOT/$name/zzd" ]; then
      printf '%s\n' "$name"
    else
      zzd_error "module $name has no $name/zzd"
      status=1
    fi
  done <"${ZZD_ROOT:?}/zzd/modules"
  return "$status"
}

zzd_module_known() {
  local name list
  list="$(zzd_modules_list)" || return 1
  while IFS= read -r name; do
    if [ "$name" = "$1" ]; then
      return 0
    fi
  done <<<"$list"
  return 1
}

_zc_has_function() {
  declare -F "$1" >/dev/null
}

zzd_module_run() {
  local module="$1" phase="$2"
  (
    local dir="${ZZD_ROOT:?}/$module/zzd" status=0
    ZZD_MODULE="$module"
    export ZZD_MODULE
    if [ -f "$dir/$phase.sh" ]; then
      # shellcheck source=/dev/null
      . "$dir/$phase.sh"
    fi
    if [ "$phase" = "apply" ] && _zc_has_function mod_pre_apply; then
      mod_pre_apply || exit 1
    fi
    case "$phase" in
      apply) zzd_submodules_apply "$module" || status=1 ;;
      doctor) zzd_submodules_check "$module" || status=1 ;;
      *) ;;
    esac
    if [ -f "$dir/links" ]; then
      case "$phase" in
        apply) zzd_links_apply "$dir/links" || status=1 ;;
        doctor) zzd_links_check "$dir/links" || status=1 ;;
        *) ;;
      esac
    fi
    if [ -f "$dir/fonts" ]; then
      case "$phase" in
        apply) zzd_fonts_apply "$dir/fonts" || status=1 ;;
        doctor) zzd_fonts_check "$dir/fonts" || status=1 ;;
        *) ;;
      esac
    fi
    if _zc_has_function "mod_$phase"; then
      "mod_$phase" || status=1
    fi
    exit "$status"
  )
}

zzd_modules_run() {
  local phase="$1" module list status=0
  shift
  if [ "$#" -eq 0 ]; then
    list="$(zzd_modules_list)" || status=1
    while IFS= read -r module; do
      if [ -n "$module" ]; then
        set -- "$@" "$module"
      fi
    done <<<"$list"
  fi
  for module in "$@"; do
    zzd_info "$module: $phase"
    zzd_module_run "$module" "$phase" || status=1
  done
  return "$status"
}
