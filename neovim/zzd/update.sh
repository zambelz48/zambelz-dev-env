# shellcheck shell=bash

mod_update() {
  local nvim
  if ! nvim="$(zzd_tool nvim)"; then
    zzd_warn "neovim is not installed by mise" "zzd apply mise"
    return 0
  fi
  if ! "$nvim" -l "${ZZD_ROOT:?}/neovim/scripts/check_plugin_updates.lua"; then
    zzd_warn "neovim plugin update check failed"
  fi
}
