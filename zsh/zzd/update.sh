# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/zsh/zconf/common.sh"

mod_update() {
  local master
  if ! master="$(zc_git_remote_head "$OHMYZSH_URL")"; then
    zc_warn "oh-my-zsh master unknown (git ls-remote failed)"
    return 0
  fi
  if [ "$master" = "$OHMYZSH_COMMIT" ]; then
    zc_ok "oh-my-zsh at master"
  else
    zc_info "oh-my-zsh $OHMYZSH_COMMIT -> $master"
  fi
}
