# shellcheck shell=bash

# Per-user font directories: Homebrew's --fontdir default on macOS, the
# fontconfig `<dir prefix="xdg">fonts</dir>` elsewhere.
zzd_fonts_dir() {
  case "$(zzd_os)" in
    darwin) printf '%s/Library/Fonts\n' "${ZZD_HOME:?}" ;;
    *) printf '%s/fonts\n' "${XDG_DATA_HOME:-${ZZD_HOME:?}/.local/share}" ;;
  esac
}

_zzd_fonts_files() {
  local dir files
  dir="$(mise -C "${ZZD_HOME:?}" where "$1" 2>/dev/null)" || return 1
  if [ ! -d "$dir" ]; then
    return 1
  fi
  files="$(find "$dir" -type f \
    \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' \))" || return 1
  if [ -z "$files" ]; then
    return 2
  fi
  sort <<<"$files"
}

_zzd_fonts_unavailable() {
  case "$2" in
    1) zzd_error "$1 is not installed by mise" "zzd apply mise" ;;
    *) zzd_error "$1 has no font files" ;;
  esac
}

_zzd_fonts_state() {
  printf '%s/fonts/%s\n' "${ZZD_STATE_DIR:?}" "${1//[\/:]/-}"
}

_zzd_fonts_refresh() {
  local os
  os="$(zzd_os)"
  if [ "$os" = "darwin" ] || ! command -v fc-cache >/dev/null 2>&1; then
    return 0
  fi
  if ! fc-cache "$1" >/dev/null 2>&1; then
    zzd_warn "fc-cache failed for $1" "fc-cache -f $1"
  fi
}

_zzd_fonts_apply_tool() {
  local tool="$1" fontdir="$2" files="$3" file name state old
  local shipped=$'\n' installed=() removed=()
  state="$(_zzd_fonts_state "$tool")"
  if ! _zzd_dry_run; then
    mkdir -p "$fontdir"
  fi
  while IFS= read -r file; do
    name="${file##*/}"
    shipped="$shipped$name"$'\n'
    if cmp -s "$file" "$fontdir/$name"; then
      continue
    fi
    zzd_do cp "$file" "$fontdir/$name" || return 1
    installed+=("$name")
  done <<<"$files"
  if [ -f "$state" ]; then
    while IFS= read -r old; do
      case "$shipped" in
        *$'\n'"$old"$'\n'*) continue ;;
        *) ;;
      esac
      if [ -n "$old" ] && [ -f "$fontdir/$old" ]; then
        zzd_do rm "$fontdir/$old" || return 1
        removed+=("$old")
      fi
    done <"$state"
  fi
  if _zzd_dry_run; then
    return 0
  fi
  mkdir -p "$(dirname "$state")"
  printf '%s' "${shipped#$'\n'}" >"$state"
  if [ "${#installed[@]}" -gt 0 ]; then
    zzd_changed "installed fonts from $tool: ${installed[*]}"
  fi
  if [ "${#removed[@]}" -gt 0 ]; then
    zzd_changed "removed fonts no longer in $tool: ${removed[*]}"
  fi
  if [ "${#installed[@]}" -eq 0 ] && [ "${#removed[@]}" -eq 0 ]; then
    zzd_ok "$tool fonts in $fontdir"
    return 0
  fi
  _zzd_fonts_refresh "$fontdir"
}

_zzd_fonts_check_tool() {
  local tool="$1" fontdir="$2" files="$3" file name status=0
  while IFS= read -r file; do
    name="${file##*/}"
    if ! cmp -s "$file" "$fontdir/$name"; then
      zzd_error "$name from $tool is missing or outdated in $fontdir" \
        "zzd apply ${ZZD_MODULE:-}"
      status=1
    fi
  done <<<"$files"
  if [ "$status" -eq 0 ]; then
    zzd_ok "$tool fonts in $fontdir"
  fi
  return "$status"
}

_zzd_fonts_each() {
  local action="$1" tool fontdir files rc status=0
  fontdir="$(zzd_fonts_dir)"
  while IFS= read -r tool || [ -n "$tool" ]; do
    zzd_is_data_line "$tool" || continue
    files="$(_zzd_fonts_files "$tool")"
    rc=$?
    if [ "$rc" -ne 0 ]; then
      _zzd_fonts_unavailable "$tool" "$rc"
      status=1
      continue
    fi
    "$action" "$tool" "$fontdir" "$files" || status=1
  done <"$2"
  return "$status"
}

zzd_fonts_apply() {
  _zzd_fonts_each _zzd_fonts_apply_tool "$1"
}

zzd_fonts_check() {
  _zzd_fonts_each _zzd_fonts_check_tool "$1"
}
