# shellcheck shell=bash

mod_doctor() {
  local current
  current="$(git -C "${ZZD_ROOT:?}" config --get core.hooksPath)" ||
    current=""
  if [ "$current" = ".githooks" ]; then
    zzd_ok "core.hooksPath = .githooks"
    return 0
  fi
  zzd_error "core.hooksPath is not .githooks (${current:-unset})" \
    "zzd apply git"
  return 1
}
