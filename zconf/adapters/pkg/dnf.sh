# shellcheck shell=bash

pkg_available() {
  command -v dnf >/dev/null 2>&1
}

pkg_is_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

pkg_version() {
  rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$1"
}

pkg_install() {
  zc_sudo dnf install -y "$@"
}

pkg_outdated() {
  local out name latest current
  out="$(dnf repoquery --upgrades --qf '%{name} %{evr}\n' "$@" 2>/dev/null)" ||
    true
  while read -r name latest; do
    if [ -n "$name" ]; then
      current="$(pkg_version "$name")"
      printf '%s %s %s\n' "$name" "$current" "$latest"
    fi
  done <<<"$out"
}

pkg_upgrade() {
  zc_sudo dnf upgrade -y "$@"
}
