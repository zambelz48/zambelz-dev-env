# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/zsh/zconf/common.sh"

mod_doctor() {
  local status=0 head shell
  head="$(zc_git_head "${ZC_HOME:?}/.oh-my-zsh")" || head=""
  if [ "$head" = "$OHMYZSH_COMMIT" ]; then
    zc_ok "oh-my-zsh at $OHMYZSH_COMMIT"
  else
    zc_error "oh-my-zsh at ${head:-missing}, pinned $OHMYZSH_COMMIT" \
      "zconf apply zsh"
    status=1
  fi
  shell="$(zc_login_shell)"
  case "$shell" in
    */zsh)
      zc_ok "login shell is $shell"
      ;;
    *)
      zc_error "login shell is ${shell:-unknown}" \
        "chsh -s \"\$(command -v zsh)\""
      status=1
      ;;
  esac
  return "$status"
}
