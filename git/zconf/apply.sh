# shellcheck shell=bash

mod_apply() {
  local current
  current="$(git -C "${ZC_ROOT:?}" config --get core.hooksPath)" ||
    current=""
  if [ "$current" = ".githooks" ]; then
    zc_ok "core.hooksPath = .githooks"
    return 0
  fi
  zc_do git -C "$ZC_ROOT" config core.hooksPath .githooks || return 1
  zc_changed "core.hooksPath = .githooks"
}
