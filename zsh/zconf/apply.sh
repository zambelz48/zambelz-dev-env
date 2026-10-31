# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/zsh/zconf/common.sh"

# Runs before the links: they create ~/.oh-my-zsh/custom, and git cannot
# clone into a non-empty directory.
mod_pre_apply() {
  zc_git_pin "${ZC_HOME:?}/.oh-my-zsh" "$OHMYZSH_URL" "$OHMYZSH_COMMIT" \
    "oh-my-zsh"
}

mod_apply() {
  zc_ensure_line "$ZC_HOME/.profile.zsh" \
    "export ZAMBELZ_DEV_ENV_PATH=\"$ZC_ROOT\""
}
