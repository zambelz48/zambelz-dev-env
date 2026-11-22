#!/usr/bin/env bash
set -u

ai_dir="$(cd "$(dirname "$0")" && pwd -P)"
mise_data="${MISE_DATA_DIR:-$HOME/.local/share/mise}"

usable_python() {
  "$1" -E -s -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null
}

find_python() {
  local candidate

  for candidate in "$mise_data"/installs/python/3.*/bin/python3; do
    if [ -x "$candidate" ] && usable_python "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  candidate="$(PATH="$mise_data/shims:$PATH" command -v python3)" || return 1

  if usable_python "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

if ! python="$(find_python)"; then
  printf 'ERROR: zambelz-dev-env hook: no python 3.11 or newer is installed by mise; run zzd apply mise\n' >&2
  exit 2
fi

PATH="$mise_data/shims:$PATH"
export PATH

"$python" -E -s "$ai_dir/lib/hook.py" "$@"
status=$?

case "$status" in
  0)
    exit 0
    ;;
  *)
    printf 'ERROR: zambelz-dev-env hook failed (exit %s)\n' "$status" >&2
    exit 2
    ;;
esac
