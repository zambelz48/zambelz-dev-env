# shellcheck shell=bash

_zc_sub_paths() {
  local config path
  config="$(git config --file "${ZC_ROOT:?}/.gitmodules" \
    --get-regexp '^submodule\..*\.path$' 2>/dev/null)" || config=""
  while read -r _ path; do
    case "$path" in
      "$1"/*) printf '%s\n' "$path" ;;
      *) ;;
    esac
  done <<<"$config"
}

_zc_sub_entries() {
  local paths path lines line state sha list=()
  paths="$(_zc_sub_paths "$1")"
  while IFS= read -r path; do
    if [ -n "$path" ]; then
      list+=("$path")
    fi
  done <<<"$paths"
  if [ "${#list[@]}" -eq 0 ]; then
    return 0
  fi
  lines="$(git -C "$ZC_ROOT" submodule status -- "${list[@]}" \
    2>/dev/null)" || return 1
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    case "${line:0:1}" in
      ' ') state=ok ;;
      -) state=missing ;;
      +) state=moved ;;
      *) state=conflict ;;
    esac
    read -r sha path _ <<<"${line:1}"
    printf '%s\t%s\t%s\n' "$state" "$path" "$sha"
  done <<<"$lines"
}

_zc_sub_recorded() {
  local line sha=""
  line="$(git -C "${ZC_ROOT:?}" ls-files --stage -- "$1" 2>/dev/null)" ||
    line=""
  read -r _ sha _ <<<"$line"
  printf '%s' "$sha"
}

_zc_sub_was_recorded() {
  local log old new
  log="$(git -C "${ZC_ROOT:?}" log --format= --raw --no-abbrev -- "$1" \
    2>/dev/null)" || return 1
  while read -r _ _ old new _; do
    if [ "$old" = "$2" ] || [ "$new" = "$2" ]; then
      return 0
    fi
  done <<<"$log"
  return 1
}

_zc_sub_update() {
  zc_do git -C "${ZC_ROOT:?}" \
    -c "url.https://github.com/.insteadOf=git@github.com:" \
    submodule update --quiet --init --recursive -- "$1"
}

_zc_sub_left_alone() {
  zc_warn "submodule $1 is at $2, not the recorded $3; left as is" \
    "git -C ${ZC_ROOT:?} submodule update -- $1"
}

_zc_sub_apply_one() {
  local module="$1" state="$2" path="$3" head="$4" dir recorded changes
  dir="${ZC_ROOT:?}/$path"
  case "$state" in
    ok)
      zc_ok "submodule $path at $head"
      return 0
      ;;
    missing)
      if _zc_sub_update "$path"; then
        zc_changed "submodule $path checked out at $head"
        return 0
      fi
      zc_error "submodule $path checkout failed" \
        "git -C $ZC_ROOT submodule update --init --recursive -- $path"
      return 1
      ;;
    moved) ;;
    *)
      zc_error "submodule $path has a merge conflict" "git -C $ZC_ROOT status"
      return 1
      ;;
  esac
  recorded="$(_zc_sub_recorded "$path")"
  if ! _zc_sub_was_recorded "$path" "$head"; then
    _zc_sub_left_alone "$path" "$head" "$recorded"
    return 0
  fi
  changes="$(git -C "$dir" status --porcelain --untracked-files=no \
    2>/dev/null)" || changes=""
  if [ -n "$changes" ]; then
    zc_error "$dir has local changes" \
      "git -C $dir stash, then zconf apply $module"
    return 1
  fi
  if _zc_sub_update "$path"; then
    zc_changed "submodule $path $head -> $recorded"
    return 0
  fi
  zc_error "submodule $path checkout of $recorded failed" \
    "zconf apply $module"
  return 1
}

_zc_sub_check_one() {
  local module="$1" state="$2" path="$3" head="$4" recorded
  case "$state" in
    ok)
      zc_ok "submodule $path at $head"
      return 0
      ;;
    missing)
      zc_error "submodule $path is not checked out" "zconf apply $module"
      return 1
      ;;
    moved) ;;
    *)
      zc_error "submodule $path has a merge conflict" \
        "git -C ${ZC_ROOT:?} status"
      return 1
      ;;
  esac
  recorded="$(_zc_sub_recorded "$path")"
  if ! _zc_sub_was_recorded "$path" "$head"; then
    _zc_sub_left_alone "$path" "$head" "$recorded"
    return 0
  fi
  zc_error "submodule $path at $head, recorded $recorded" \
    "zconf apply $module"
  return 1
}

_zc_submodules_each() {
  local each="$1" module="$2" entries state path head status=0
  if [ ! -f "${ZC_ROOT:?}/.gitmodules" ]; then
    return 0
  fi
  if ! entries="$(_zc_sub_entries "$module")"; then
    zc_error "cannot read the submodules under $module" \
      "git -C $ZC_ROOT submodule status -- $module"
    return 1
  fi
  while IFS=$'\t' read -r state path head; do
    if [ -n "$path" ]; then
      "$each" "$module" "$state" "$path" "$head" || status=1
    fi
  done <<<"$entries"
  return "$status"
}

# Moves a stale checkout (a commit the repository recorded before) to the
# recorded commit; any other commit is the owner's work and is left alone.
zc_submodules_apply() {
  _zc_submodules_each _zc_sub_apply_one "$1"
}

zc_submodules_check() {
  _zc_submodules_each _zc_sub_check_one "$1"
}
