# shellcheck shell=bash

_zc_has_tty() {
  [ -t 0 ] || { : </dev/tty; } 2>/dev/null
}

zzd_do() {
  if _zc_dry_run; then
    printf 'DRY-RUN: %s\n' "$*"
    return 0
  fi
  "$@"
}

zzd_sudo() {
  local uid
  uid="$(id -u)"
  if [ "$uid" = "0" ]; then
    zzd_do "$@"
    return
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: sudo %s\n' "$*"
    return 0
  fi
  if _zc_has_tty; then
    sudo "$@"
    return
  fi
  if sudo -n true 2>/dev/null; then
    sudo -n "$@"
    return
  fi
  zzd_error "root required, no terminal" "sudo $*"
  return 1
}

# mise downloads hit GitHub's anonymous API rate limit without a token.
zzd_github_token() {
  local gh
  if [ -z "${GITHUB_TOKEN:-}" ] && gh="$(zzd_tool gh)"; then
    GITHUB_TOKEN="$("$gh" auth token 2>/dev/null)" || GITHUB_TOKEN=""
    export GITHUB_TOKEN
  fi
}

zzd_ensure_line() {
  local file="$1" line="$2" dir last
  if [ -f "$file" ] && grep -Fxq -- "$line" "$file"; then
    zzd_ok "$file has: $line"
    return 0
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: append to %s: %s\n' "$file" "$line"
    return 0
  fi
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  if [ -s "$file" ]; then
    last="$(tail -c 1 "$file")"
    if [ -n "$last" ]; then
      printf '\n' >>"$file"
    fi
  fi
  printf '%s\n' "$line" >>"$file"
  zzd_changed "added to $file: $line"
}
