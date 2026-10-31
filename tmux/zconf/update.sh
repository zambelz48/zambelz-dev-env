# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/tmux/zconf/common.sh"

mod_update() {
  local name commit url master
  while IFS=$'\t' read -r name commit || [ -n "$name" ]; do
    zc_is_data_line "$name" || continue
    url="$(_tmux_url "$name")"
    if ! master="$(zc_git_remote_head "$url")"; then
      zc_warn "$name master unknown (git ls-remote failed)"
    elif [ "$master" = "$commit" ]; then
      zc_ok "$name at master"
    else
      zc_info "$name $commit -> $master"
    fi
  done <"$ZC_ROOT/tmux/zconf/pins"
}
