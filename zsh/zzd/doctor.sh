# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/zsh/zzd/common.sh"

mod_doctor() {
  local status=0 head shell
  head="$(zzd_git_head "${ZZD_HOME:?}/.oh-my-zsh")" || head=""
  if [ "$head" = "$OHMYZSH_COMMIT" ]; then
    zzd_ok "oh-my-zsh at $OHMYZSH_COMMIT"
  else
    zzd_error "oh-my-zsh at ${head:-missing}, pinned $OHMYZSH_COMMIT" \
      "zzd apply zsh"
    status=1
  fi
  shell="$(zzd_login_shell)"
  case "$shell" in
    */zsh)
      zzd_ok "login shell is $shell"
      ;;
    *)
      zzd_error "login shell is ${shell:-unknown}" \
        "chsh -s \"\$(command -v zsh)\""
      status=1
      ;;
  esac
  return "$status"
}
