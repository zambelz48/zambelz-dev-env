# shellcheck shell=bash

zc_mise_bin() {
  printf '%s/.local/bin/mise' "${ZC_HOME:?}"
}

zc_mise_version() {
  local line version=""
  line="$("$1" --version 2>/dev/null)" || line=""
  read -r version _ <<<"$line"
  version="${version%%-*}"
  case "$version" in
    [0-9]*.[0-9]*.[0-9]*) printf '%s' "$version" ;;
    *) ;;
  esac
}

_zc_mise_unreadable() {
  zc_error "cannot read min_version from ${ZC_ROOT:?}/mise/mise.toml" \
    "edit $ZC_ROOT/mise/mise.toml"
  return 1
}

_zc_mise_path() {
  command -v mise 2>/dev/null || true
}

_zc_mise_current() {
  if [ -n "$1" ]; then
    zc_mise_version "$1"
  fi
}

zc_mise_ready() {
  local pinned path current
  pinned="$(zc_mise_min_version)" || return 1
  path="$(_zc_mise_path)"
  current="$(_zc_mise_current "$path")"
  [ -n "$current" ] && zc_version_ge "$current" "$pinned"
}

zc_mise_check() {
  local pinned path current
  pinned="$(zc_mise_min_version)" || _zc_mise_unreadable || return 1
  path="$(_zc_mise_path)"
  current="$(_zc_mise_current "$path")"
  if [ -n "$current" ] && zc_version_ge "$current" "$pinned"; then
    zc_ok "mise $current (>= $pinned)"
    return 0
  fi
  if [ -z "$current" ]; then
    zc_error "mise is not installed (min_version $pinned)" "zconf apply mise"
  else
    zc_error "mise $current is older than $pinned" "zconf apply mise"
  fi
  return 1
}

# Runs no mise command but --version: a min_version above the running mise
# breaks all of them, `mise self-update` included. A newer mise is kept.
zc_mise_ensure() {
  local pinned bin path current installer after
  pinned="$(zc_mise_min_version)" || _zc_mise_unreadable || return 1
  bin="$(zc_mise_bin)"
  path="$(_zc_mise_path)"
  current="$(_zc_mise_current "$path")"
  if [ -n "$current" ] && zc_version_ge "$current" "$pinned"; then
    zc_ok "mise $current (>= $pinned)"
    return 0
  fi
  if [ -n "$path" ] && [ "$path" != "$bin" ]; then
    zc_error "mise ${current:-unknown} at $path is older than $pinned" \
      "remove $path, or put ${bin%/*} before ${path%/*} on PATH"
    return 1
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: install mise %s from https://mise.run into %s\n' \
      "$pinned" "$bin"
    return 0
  fi
  installer="$(curl -fsSL https://mise.run)" || {
    zc_error "cannot download the mise installer" "https://mise.run"
    return 1
  }
  if ! printf '%s\n' "$installer" | MISE_VERSION="v$pinned" \
    MISE_INSTALL_PATH="$bin" MISE_INSTALL_HELP=0 sh; then
    zc_error "mise installer failed" "https://mise.jdx.dev/installing-mise.html"
    return 1
  fi
  hash -r
  after="$(zc_mise_version "$bin")"
  if [ "$after" != "$pinned" ]; then
    zc_error "mise is ${after:-missing} after the install, expected $pinned" \
      "https://mise.jdx.dev/installing-mise.html"
    return 1
  fi
  zc_changed "mise ${current:-missing} -> $pinned"
}
