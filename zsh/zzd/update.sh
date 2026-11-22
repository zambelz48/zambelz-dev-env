# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/zsh/zzd/common.sh"

mod_update() {
  local master
  if ! master="$(zzd_git_remote_head "$OHMYZSH_URL")"; then
    zzd_warn "oh-my-zsh master unknown (git ls-remote failed)"
    return 0
  fi
  if [ "$master" = "$OHMYZSH_COMMIT" ]; then
    zzd_ok "oh-my-zsh at master"
  else
    zzd_info "oh-my-zsh $OHMYZSH_COMMIT -> $master"
  fi
}
