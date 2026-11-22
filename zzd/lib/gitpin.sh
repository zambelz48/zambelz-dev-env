# shellcheck shell=bash

zc_git_head() {
  git -C "$1" rev-parse HEAD 2>/dev/null
}

zc_git_remote_head() {
  local line
  line="$(git ls-remote "$1" HEAD 2>/dev/null)" || return 1
  line="${line%%[[:space:]]*}"
  if [ -z "$line" ]; then
    return 1
  fi
  printf '%s\n' "$line"
}

_zc_git_clone() {
  local dir="$1" url="$2" commit="$3" label="$4"
  if zc_do git clone -q "$url" "$dir" &&
    zc_do git -C "$dir" checkout -q "$commit"; then
    zc_changed "$label cloned at $commit"
    return 0
  fi
  zc_error "$label clone failed" "zconf apply ${ZC_MODULE:-}"
  return 1
}

zc_git_pin() {
  local dir="$1" url="$2" commit="$3" label="$4" head changes
  local fix="zconf apply ${ZC_MODULE:-}"
  if [ ! -e "$dir" ]; then
    _zc_git_clone "$dir" "$url" "$commit" "$label"
    return
  fi
  if [ ! -d "$dir/.git" ]; then
    zc_error "$dir exists but is not a git checkout" \
      "move $dir aside, then $fix"
    return 1
  fi
  head="$(zc_git_head "$dir")" || head=""
  if [ "$head" = "$commit" ]; then
    zc_ok "$label at $commit"
    return 0
  fi
  changes="$(git -C "$dir" status --porcelain 2>/dev/null)" || changes=""
  if [ -n "$changes" ]; then
    zc_error "$dir has local changes" "git -C $dir stash, then $fix"
    return 1
  fi
  if zc_do git -C "$dir" fetch -q origin &&
    zc_do git -C "$dir" checkout -q "$commit"; then
    zc_changed "$label ${head:-unknown} -> $commit"
    return 0
  fi
  zc_error "$label checkout of $commit failed" "$fix"
  return 1
}
