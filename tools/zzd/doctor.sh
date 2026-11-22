# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/tools/zzd/common.sh"

_tools_check_install() {
  local kind="$1" dir="$2" lock
  lock="$(_tools_lock "$kind")"
  if _tools_installed "$kind" "$dir"; then
    zzd_ok "$kind tools installed from ${lock##*/}"
    return 0
  fi
  zzd_error "$kind tools are not installed from the current ${lock##*/}" \
    "zzd apply tools"
  return 1
}

_tools_check_commands() {
  local bin entries cmd kind expected file target wanted=$'\n' status=0 n=0
  local shims runtime plugin duplicates=()
  bin="$(_tools_bin_dir)"
  shims="$(_tools_shims)"
  entries="$(_tools_entries)"
  while IFS=$'\t' read -r cmd kind; do
    if [ -z "$cmd" ]; then
      continue
    fi
    wanted="$wanted$cmd"$'\n'
    runtime="$(_tools_runtime "$kind")"
    if [ -e "$shims/$cmd" ]; then
      plugin="$(mise -C "${ZZD_HOME:?}" which --plugin "$cmd" </dev/null \
        2>/dev/null)" || plugin=""
      if [ "$plugin" = "$runtime" ]; then
        duplicates+=("$cmd")
      fi
    fi
    target="$(_tools_target "$cmd" "$kind")"
    expected="$(_tools_wrapper "$cmd" "$kind")" || expected=""
    if [ ! -f "$bin/$cmd" ]; then
      zzd_error "$cmd is missing from $bin" "zzd apply tools"
      status=1
    elif ! _tools_same "$bin/$cmd" "$expected"; then
      zzd_error "$bin/$cmd is out of date" "zzd apply tools"
      status=1
    elif [ ! -x "$target" ]; then
      zzd_error "$cmd runs $target, which is missing" "zzd apply tools"
      status=1
    else
      n=$((n + 1))
    fi
  done <<<"$entries"
  for file in "$bin"/*; do
    if [ ! -e "$file" ]; then
      continue
    fi
    case "$wanted" in
      *$'\n'"${file##*/}"$'\n'*) ;;
      *)
        zzd_error "$file is not in tools/zzd/bins" "zzd apply tools"
        status=1
        ;;
    esac
  done
  if [ "${#duplicates[@]}" -gt 0 ]; then
    zzd_warn "unpinned copies in the global node or python: ${duplicates[*]}" \
      "npm uninstall -g <package> or python3 -m pip uninstall <package>"
  fi
  if [ "$status" -eq 0 ]; then
    zzd_ok "$n commands in $bin"
  fi
  return "$status"
}

mod_doctor() {
  local status=0 dir="${ZZD_ROOT:?}/tools" bin line
  bin="$(_tools_bin_dir)"
  line="$(_tools_path_line)"
  if [ -f "${ZZD_HOME:?}/.zshenv" ] &&
    grep -Fxq -- "$line" "$ZZD_HOME/.zshenv"; then
    zzd_ok "$bin is on PATH (.zshenv)"
  else
    zzd_error "$bin is not on PATH" "zzd apply tools"
    status=1
  fi
  _tools_check_install npm "$dir/npm/node_modules" || status=1
  if [ -x "$dir/python/.venv/bin/python" ]; then
    _tools_check_install python "$dir/python/.venv" || status=1
  else
    zzd_error "python tools are not installed" "zzd apply tools"
    status=1
  fi
  _tools_check_commands || status=1
  return "$status"
}
