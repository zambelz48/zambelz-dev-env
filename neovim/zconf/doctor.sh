# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/neovim/zconf/common.sh"

_nvim_lock_entries() {
  zc_python - "$ZC_ROOT/neovim/lazy-lock.json" <<'EOF'
import json
import sys

with open(sys.argv[1]) as f:
    for name, entry in json.load(f).items():
        print(f"{name}\t{entry['commit']}")
EOF
}

_nvim_check_lazy() {
  local dir entries name commit head count=0 status=0
  dir="${XDG_DATA_HOME:-$ZC_HOME/.local/share}/nvim/lazy"
  if ! entries="$(_nvim_lock_entries)"; then
    zc_error "cannot read neovim/lazy-lock.json"
    return 1
  fi
  while IFS=$'\t' read -r name commit; do
    if [ -z "$name" ]; then
      continue
    fi
    count=$((count + 1))
    head="$(zc_git_head "$dir/$name")" || head=""
    if [ "$head" != "$commit" ]; then
      zc_error "$name at ${head:-missing}, locked $commit" \
        "zconf apply neovim"
      status=1
    fi
  done <<<"$entries"
  if [ "$status" -eq 0 ]; then
    zc_ok "lazy.nvim plugins match lazy-lock.json ($count)"
  fi
  return "$status"
}

mod_doctor() {
  local status=0 dir out head built
  _nvim_check_lazy || status=1
  dir="$(_nvim_gradle_dir)"
  out="$(_nvim_gradle_out)"
  head="$(zc_git_head "$dir")" || head=""
  built="$(_nvim_gradle_built_commit)"
  if [ ! -x "$out" ]; then
    zc_error "gradle-language-server is not built" "zconf apply neovim"
    status=1
  elif [ "$built" != "$head" ]; then
    built="built at ${built:-unknown}, submodule at ${head:-unknown}"
    zc_error "gradle-language-server $built" "zconf apply neovim"
    status=1
  else
    zc_ok "gradle-language-server built at $head"
  fi
  return "$status"
}
