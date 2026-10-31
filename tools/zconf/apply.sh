# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/tools/zconf/common.sh"

_tools_write() {
  if ! printf '%s\n' "$2" >"$1" || ! chmod +x "$1"; then
    zc_error "cannot write $1"
    return 1
  fi
}

_tools_link() {
  local bin entries cmd kind content file wanted=$'\n' status=0
  local written=() removed=()
  bin="$(_tools_bin_dir)"
  entries="$(_tools_entries)"
  if ! _zc_dry_run; then
    mkdir -p "$bin"
  fi
  while IFS=$'\t' read -r cmd kind; do
    if [ -z "$cmd" ]; then
      continue
    fi
    wanted="$wanted$cmd"$'\n'
    if ! content="$(_tools_wrapper "$cmd" "$kind")"; then
      zc_error "cannot write $cmd: node is not installed by mise" \
        "zconf apply mise"
      status=1
      continue
    fi
    if [ -f "$bin/$cmd" ] && _tools_same "$bin/$cmd" "$content"; then
      continue
    fi
    if _zc_dry_run; then
      printf 'DRY-RUN: write %s/%s\n' "$bin" "$cmd"
      continue
    fi
    if _tools_write "$bin/$cmd" "$content"; then
      written+=("$cmd")
    else
      status=1
    fi
  done <<<"$entries"
  for file in "$bin"/*; do
    if [ ! -e "$file" ]; then
      continue
    fi
    case "$wanted" in
      *$'\n'"${file##*/}"$'\n'*) continue ;;
      *) ;;
    esac
    zc_do rm -f "$file" || status=1
    removed+=("${file##*/}")
  done
  if [ "${#written[@]}" -gt 0 ]; then
    zc_changed "wrote commands: ${written[*]}"
  fi
  if [ "${#removed[@]}" -gt 0 ]; then
    zc_changed "removed commands: ${removed[*]}"
  fi
  if [ "$status" -eq 0 ] && [ "${#written[@]}" -eq 0 ] &&
    [ "${#removed[@]}" -eq 0 ]; then
    zc_ok "commands in $bin"
  fi
  return "$status"
}

mod_apply() {
  local status=0 line
  line="$(_tools_path_line)"
  zc_ensure_line "${ZC_HOME:?}/.zshenv" "$line" || status=1
  _tools_install_npm || status=1
  _tools_install_python || status=1
  _tools_link || status=1
  return "$status"
}
