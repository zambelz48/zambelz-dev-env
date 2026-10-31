# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/tmux/zconf/common.sh"

mod_doctor() {
  local status=0 plugins plugin commit head dir
  plugins="$(_tmux_plugins)"
  while IFS= read -r plugin; do
    if [ -z "$plugin" ]; then
      continue
    fi
    if ! commit="$(_tmux_pin "$plugin")"; then
      _tmux_unpinned "$plugin"
      status=1
      continue
    fi
    dir="$(_tmux_dir "$plugin")"
    head="$(zc_git_head "$dir")" || head=""
    if [ "$head" = "$commit" ]; then
      zc_ok "$plugin at $commit"
    else
      zc_error "$plugin at ${head:-missing}, pinned $commit" "zconf apply tmux"
      status=1
    fi
  done <<<"$plugins"
  return "$status"
}
