# shellcheck shell=bash

zc_modules_list() {
  local name status=0
  while IFS= read -r name || [ -n "$name" ]; do
    zc_is_data_line "$name" || continue
    if [ -d "$ZC_ROOT/$name/zconf" ]; then
      printf '%s\n' "$name"
    else
      zc_error "module $name has no $name/zconf"
      status=1
    fi
  done <"${ZC_ROOT:?}/zconf/modules"
  return "$status"
}

zc_module_known() {
  local name list
  list="$(zc_modules_list)" || return 1
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

zc_module_run() {
  local module="$1" phase="$2"
  (
    local dir="${ZC_ROOT:?}/$module/zconf" status=0
    ZC_MODULE="$module"
    export ZC_MODULE
    if [ -f "$dir/$phase.sh" ]; then
      # shellcheck source=/dev/null
      . "$dir/$phase.sh"
    fi
    if [ "$phase" = "apply" ] && _zc_has_function mod_pre_apply; then
      mod_pre_apply || exit 1
    fi
    if [ -f "$dir/links" ]; then
      case "$phase" in
        apply) zc_links_apply "$dir/links" || status=1 ;;
        doctor) zc_links_check "$dir/links" || status=1 ;;
        *) ;;
      esac
    fi
    if [ -f "$dir/fonts" ]; then
      case "$phase" in
        apply) zc_fonts_apply "$dir/fonts" || status=1 ;;
        doctor) zc_fonts_check "$dir/fonts" || status=1 ;;
        *) ;;
      esac
    fi
    if _zc_has_function "mod_$phase"; then
      "mod_$phase" || status=1
    fi
    exit "$status"
  )
}

zc_modules_run() {
  local phase="$1" module list status=0
  shift
  if [ "$#" -eq 0 ]; then
    list="$(zc_modules_list)" || status=1
    while IFS= read -r module; do
      if [ -n "$module" ]; then
        set -- "$@" "$module"
      fi
    done <<<"$list"
  fi
  for module in "$@"; do
    zc_info "$module: $phase"
    zc_module_run "$module" "$phase" || status=1
  done
  return "$status"
}
