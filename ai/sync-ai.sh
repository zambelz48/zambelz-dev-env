#!/usr/bin/env bash
set -u

ai_dir="$(cd "$(dirname "$0")" && pwd -P)"
PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
export PATH

if ! python="$(command -v python3)"; then
  printf 'ERROR: python3 is not installed by mise\n  fix: zzd apply mise\n' >&2
  exit 1
fi

exec "$python" -E -s "$ai_dir/lib/sync.py" "$@"
