# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/zsh/zzd/common.sh"

# Runs before the links: they create ~/.oh-my-zsh/custom, and git cannot
# clone into a non-empty directory.
mod_pre_apply() {
  zzd_git_pin "${ZZD_HOME:?}/.oh-my-zsh" "$OHMYZSH_URL" "$OHMYZSH_COMMIT" \
    "oh-my-zsh"
}

mod_apply() {
  zzd_ensure_line "$ZZD_HOME/.profile.zsh" \
    "export ZAMBELZ_DEV_ENV_PATH=\"$ZZD_ROOT\""
}
