# shellcheck shell=bash
# shellcheck source=../../zzd/lib/gitpin.sh
. "${ZZD_ROOT:?}/zzd/lib/gitpin.sh"

_tmux_url() {
  printf 'https://github.com/%s.git' "$1"
}

_tmux_dir() {
  printf '%s/.tmux/plugins/%s' "${ZZD_HOME:?}" "${1##*/}"
}

_tmux_plugins() {
  local line cmd flag key value
  while IFS= read -r line || [ -n "$line" ]; do
    read -r cmd flag key value _ <<<"$line"
    case "$cmd $flag $key" in
      "set -g @plugin" | "set-option -g @plugin") ;;
      *) continue ;;
    esac
    value="${value//\'/}"
    value="${value//\"/}"
    printf '%s\n' "${value%%#*}"
  done <"$ZZD_ROOT/tmux/.tmux.conf"
}

_tmux_pin() {
  local want="$1" name commit
  while IFS=$'\t' read -r name commit || [ -n "$name" ]; do
    if [ "$name" = "$want" ]; then
      printf '%s' "$commit"
      return 0
    fi
  done <"$ZZD_ROOT/tmux/zzd/pins"
  return 1
}

_tmux_unpinned() {
  zzd_error "$1 is not pinned" \
    "add $1 and its commit to $ZZD_ROOT/tmux/zzd/pins"
}
