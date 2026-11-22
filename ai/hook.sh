#!/usr/bin/env bash
set -u

ai_dir="$(cd "$(dirname "$0")" && pwd -P)"
PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
export PATH

if ! python="$(command -v python3)"; then
  printf 'ERROR: zambelz-dev-env hook: python3 is not installed by mise; run zconf apply mise\n' >&2
  exit 2
fi

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
