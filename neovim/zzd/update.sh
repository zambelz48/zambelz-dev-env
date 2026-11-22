# shellcheck shell=bash

mod_update() {
  local nvim
  if ! nvim="$(zc_tool nvim)"; then
    zc_warn "neovim is not installed by mise" "zconf apply mise"
    return 0
  fi
  if ! "$nvim" -l "${ZC_ROOT:?}/neovim/scripts/check_plugin_updates.lua"; then
    zc_warn "neovim plugin update check failed"
  fi
}
