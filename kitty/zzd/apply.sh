# shellcheck shell=bash

# kitty.conf holds per-machine overrides and is git-ignored: generate it
# once, before the links need it, and never overwrite it.
mod_pre_apply() {
  local conf="${ZZD_ROOT:?}/kitty/kitty.conf"
  if [ -e "$conf" ]; then
    zzd_ok "kitty/kitty.conf present"
    return 0
  fi
  if _zzd_dry_run; then
    printf 'DRY-RUN: generate kitty/kitty.conf\n'
    return 0
  fi
  printf 'include kitty.base.conf\n\nfont_size 12.0\n' >"$conf"
  zzd_changed "generated kitty/kitty.conf"
}
