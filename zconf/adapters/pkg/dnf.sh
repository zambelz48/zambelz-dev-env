# shellcheck shell=bash

pkg_available() {
  command -v dnf >/dev/null 2>&1
}

# By capability: zlib-devel is provided by zlib-ng-compat-devel since
# Fedora 40, and every package provides its own name.
pkg_is_installed() {
  rpm -q --whatprovides "$1" >/dev/null 2>&1
}

pkg_version() {
  local out
  out="$(rpm -q --whatprovides --qf '%{VERSION}-%{RELEASE}\n' "$1")" ||
    return 1
  printf '%s\n' "${out%%$'\n'*}"
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
