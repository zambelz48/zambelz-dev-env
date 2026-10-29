# shellcheck shell=bash

pkg_available() {
  command -v apt-get >/dev/null 2>&1
}

pkg_is_installed() {
  local status
  status="$(dpkg-query -W -f="\${Status}" "$1" 2>/dev/null)" || return 1
  [ "$status" = "install ok installed" ]
}

pkg_version() {
  dpkg-query -W -f="\${Version}\n" "$1"
}

pkg_install() {
  zc_sudo apt-get install -y "$@"
}

pkg_outdated() {
  local pkg policy key value installed candidate
  for pkg in "$@"; do
    policy="$(apt-cache policy "$pkg" 2>/dev/null)" || continue
    installed=""
    candidate=""
    while read -r key value; do
      case "$key" in
        Installed:) installed="$value" ;;
        Candidate:) candidate="$value" ;;
        *) ;;
      esac
    done <<<"$policy"
    if [ -n "$installed" ] && [ "$installed" != "(none)" ] &&
      [ -n "$candidate" ] && [ "$installed" != "$candidate" ]; then
      printf '%s %s %s\n' "$pkg" "$installed" "$candidate"
    fi
  done
}

pkg_upgrade() {
  zc_sudo apt-get install -y --only-upgrade "$@"
}
