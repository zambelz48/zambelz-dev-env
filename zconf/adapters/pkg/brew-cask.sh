# shellcheck shell=bash
# shellcheck source=brew.sh
. "$(dirname "${BASH_SOURCE[0]}")/brew.sh"

pkg_is_installed() {
  brew list --cask --versions "$1" >/dev/null 2>&1
}

pkg_version() {
  local line version
  line="$(brew list --cask --versions "$1")" || return 1
  read -r _ version _ <<<"$line"
  printf '%s\n' "$version"
}

pkg_install() {
  zc_do brew install --cask "$@"
}

pkg_outdated() {
  local out
  out="$(brew outdated --cask --verbose "$@" 2>/dev/null)" || true
  _brew_parse_outdated <<<"$out"
}

pkg_upgrade() {
  zc_do brew upgrade --cask "$@"
}
