# shellcheck shell=bash

mod_apply() {
  local current
  current="$(git -C "${ZZD_ROOT:?}" config --get core.hooksPath)" ||
    current=""
  if [ "$current" = ".githooks" ]; then
    zzd_ok "core.hooksPath = .githooks"
    return 0
  fi
  zzd_do git -C "$ZZD_ROOT" config core.hooksPath .githooks || return 1
  zzd_changed "core.hooksPath = .githooks"
}
