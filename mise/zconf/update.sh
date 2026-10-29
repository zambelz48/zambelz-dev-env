# shellcheck shell=bash

_mise_update_warnings() {
  local line message fix
  while IFS= read -r line; do
    case "$line" in
      'WARN: '*) message="${line#WARN: }" ;;
      *) continue ;;
    esac
    case "$message" in
      *"(http backend)")
        fix="update its url and checksum in ${ZC_ROOT:?}/mise/mise.toml"
        ;;
      *) fix="retry; check the network and GITHUB_TOKEN" ;;
    esac
    zc_warn "$message" "$fix"
  done <"$1"
}

mod_update() {
  local outdated errors tool current latest found=0
  zc_github_token
  errors="$(mktemp)"
  if ! outdated="$(zc_python "${ZC_ROOT:?}/zconf/lib/versions.py" outdated \
    "$ZC_ROOT/mise/mise.toml" 2>"$errors")"; then
    if [ -n "$outdated" ]; then
      printf '%s\n' "$outdated"
    fi
    cat "$errors"
    rm -f "$errors"
    zc_error "cannot check mise versions" "zconf check-pins"
    return 1
  fi
  _mise_update_warnings "$errors"
  rm -f "$errors"
  while read -r tool current latest; do
    if [ -n "$tool" ]; then
      zc_info "$tool $current -> $latest (mise)"
      found=1
    fi
  done <<<"$outdated"
  if [ "$found" -eq 0 ]; then
    zc_ok "mise tools are current"
  fi
}
