# shellcheck shell=bash

mod_doctor() {
  local current
  current="$(git -C "${ZC_ROOT:?}" config --get core.hooksPath)" ||
    current=""
  if [ "$current" = ".githooks" ]; then
    zc_ok "core.hooksPath = .githooks"
    return 0
  fi
  zc_error "core.hooksPath is not .githooks (${current:-unset})" \
    "zconf apply git"
  return 1
}
