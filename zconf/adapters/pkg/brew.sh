# shellcheck shell=bash

pkg_available() {
  command -v brew >/dev/null 2>&1
}

pkg_is_installed() {
  brew list --formula --versions "$1" >/dev/null 2>&1
}

pkg_version() {
  local line version
  line="$(brew list --formula --versions "$1")" || return 1
  read -r _ version _ <<<"$line"
  printf '%s\n' "$version"
}

pkg_install() {
  zc_do brew install --formula "$@"
}

# Optional hook pair: `brew autoremove` removes formulae not installed on
# request, even when they are declared here.
pkg_unrequested() {
  local deps name
  deps="$(brew list --formula --no-installed-on-request 2>/dev/null)" ||
    return 0
  deps=$'\n'"$deps"$'\n'
  for name in "$@"; do
    case "$deps" in
      *$'\n'"$name"$'\n'*) printf '%s\n' "$name" ;;
      *) ;;
    esac
  done
}

pkg_keep() {
  zc_do brew tab --installed-on-request "$@"
}

_brew_parse_outdated() {
  local name current latest
  while read -r name current _ latest; do
    if [ -n "$name" ]; then
      current="${current#(}"
      current="${current%)}"
      printf '%s %s %s\n' "$name" "$current" "$latest"
    fi
  done
}

pkg_outdated() {
  local out
  out="$(brew outdated --formula --verbose "$@" 2>/dev/null)" || true
  _brew_parse_outdated <<<"$out"
}

pkg_upgrade() {
  zc_do brew upgrade --formula "$@"
}
