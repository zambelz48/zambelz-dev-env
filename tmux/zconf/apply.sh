# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/tmux/zconf/common.sh"

_tmux_install_plugins() {
  local tpm="$1" output
  if _zc_dry_run; then
    zc_do "$tpm/bin/install_plugins"
    return 0
  fi
  if output="$("$tpm/bin/install_plugins" 2>&1)"; then
    zc_ok "TPM install_plugins"
    return 0
  fi
  printf '%s\n' "$output"
  zc_error "TPM install_plugins failed" "$tpm/bin/install_plugins"
  return 1
}

mod_apply() {
  local status=0 tpm url plugins plugin commit dir
  tpm="$(_tmux_dir tmux-plugins/tpm)"
  url="$(_tmux_url tmux-plugins/tpm)"
  if commit="$(_tmux_pin tmux-plugins/tpm)"; then
    zc_git_pin "$tpm" "$url" "$commit" "tmux-plugins/tpm" || return 1
  else
    _tmux_unpinned tmux-plugins/tpm
    return 1
  fi
  _tmux_install_plugins "$tpm" || status=1
  plugins="$(_tmux_plugins)"
  while IFS= read -r plugin; do
    case "$plugin" in
      '' | tmux-plugins/tpm) continue ;;
      *) ;;
    esac
    if commit="$(_tmux_pin "$plugin")"; then
      dir="$(_tmux_dir "$plugin")"
      url="$(_tmux_url "$plugin")"
      zc_git_pin "$dir" "$url" "$commit" "$plugin" || status=1
    else
      _tmux_unpinned "$plugin"
      status=1
    fi
  done <<<"$plugins"
  return "$status"
}
