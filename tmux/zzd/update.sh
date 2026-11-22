# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/tmux/zzd/common.sh"

mod_update() {
  local name commit url master
  while IFS=$'\t' read -r name commit || [ -n "$name" ]; do
    zzd_is_data_line "$name" || continue
    url="$(_tmux_url "$name")"
    if ! master="$(zzd_git_remote_head "$url")"; then
      zzd_warn "$name master unknown (git ls-remote failed)"
    elif [ "$master" = "$commit" ]; then
      zzd_ok "$name at master"
    else
      zzd_info "$name $commit -> $master"
    fi
  done <"$ZZD_ROOT/tmux/zzd/pins"
}
