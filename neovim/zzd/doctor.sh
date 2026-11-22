# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/neovim/zzd/common.sh"

_nvim_lock_entries() {
  zzd_python - "$ZZD_ROOT/neovim/lazy-lock.json" <<'EOF'
import json
import sys

with open(sys.argv[1]) as f:
    for name, entry in json.load(f).items():
        print(f"{name}\t{entry['commit']}")
EOF
}

_nvim_check_lazy() {
  local dir entries name commit head count=0 status=0
  dir="$(_nvim_lazy_dir)"
  if ! entries="$(_nvim_lock_entries)"; then
    zzd_error "cannot read neovim/lazy-lock.json"
    return 1
  fi
  while IFS=$'\t' read -r name commit; do
    if [ -z "$name" ]; then
      continue
    fi
    count=$((count + 1))
    head="$(zzd_git_head "$dir/$name")" || head=""
    if [ "$head" != "$commit" ]; then
      zzd_error "$name at ${head:-missing}, locked $commit" \
        "zzd apply neovim"
      status=1
    fi
  done <<<"$entries"
  if [ "$status" -eq 0 ]; then
    zzd_ok "lazy.nvim plugins match lazy-lock.json ($count)"
  fi
  return "$status"
}

_nvim_check_parsers() {
  local out err count status=0
  _nvim_parsers_prepare check || return 1
  out="$(mktemp)"
  err="$(mktemp)"
  if ! _nvim_parsers_run check "$out" "$err"; then
    cat "$err"
    zzd_error "treesitter parser check failed" "zzd apply neovim"
    status=1
  elif _nvim_parsers_problems "$out"; then
    count="$(_nvim_parsers_count "$out")"
    zzd_ok "treesitter parsers match nvim-treesitter ($count)"
  else
    status=1
  fi
  rm -f "$out" "$err"
  return "$status"
}

mod_doctor() {
  local status=0 dir out head built
  _nvim_check_lazy || status=1
  _nvim_check_parsers || status=1
  dir="$(_nvim_gradle_dir)"
  out="$(_nvim_gradle_out)"
  head="$(zzd_git_head "$dir")" || head=""
  built="$(_nvim_gradle_built_commit)"
  if [ ! -x "$out" ]; then
    zzd_error "gradle-language-server is not built" "zzd apply neovim"
    status=1
  elif [ "$built" != "$head" ]; then
    built="built at ${built:-unknown}, submodule at ${head:-unknown}"
    zzd_error "gradle-language-server $built" "zzd apply neovim"
    status=1
  else
    zzd_ok "gradle-language-server built at $head"
  fi
  return "$status"
}
