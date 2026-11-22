# shellcheck shell=bash

zzd_git_head() {
  git -C "$1" rev-parse HEAD 2>/dev/null
}

zzd_git_remote_head() {
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
  if zzd_do git clone -q "$url" "$dir" &&
    zzd_do git -C "$dir" checkout -q "$commit"; then
    zzd_changed "$label cloned at $commit"
    return 0
  fi
  zzd_error "$label clone failed" "zzd apply ${ZZD_MODULE:-}"
  return 1
}

zzd_git_pin() {
  local dir="$1" url="$2" commit="$3" label="$4" head changes
  local fix="zzd apply ${ZZD_MODULE:-}"
  if [ ! -e "$dir" ]; then
    _zc_git_clone "$dir" "$url" "$commit" "$label"
    return
  fi
  if [ ! -d "$dir/.git" ]; then
    zzd_error "$dir exists but is not a git checkout" \
      "move $dir aside, then $fix"
    return 1
  fi
  head="$(zzd_git_head "$dir")" || head=""
  if [ "$head" = "$commit" ]; then
    zzd_ok "$label at $commit"
    return 0
  fi
  changes="$(git -C "$dir" status --porcelain 2>/dev/null)" || changes=""
  if [ -n "$changes" ]; then
    zzd_error "$dir has local changes" "git -C $dir stash, then $fix"
    return 1
  fi
  if zzd_do git -C "$dir" fetch -q origin &&
    zzd_do git -C "$dir" checkout -q "$commit"; then
    zzd_changed "$label ${head:-unknown} -> $commit"
    return 0
  fi
  zzd_error "$label checkout of $commit failed" "$fix"
  return 1
}
