#!/usr/bin/env bash
# Runs check_plugin_updates.lua, then (if anything is actually updatable)
# lets you pick which plugins to bump via an interactive fzf multi-select
# (SPACE to toggle, ENTER to apply, ESC/Ctrl-C to cancel with no changes).
#
# Usage: neovim/scripts/apply_plugin_updates.sh [repo-slug-filter ...]
# Wired up as: zconf neovim check-updates [filter ...]

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is required for this command (see README prerequisites)." >&2
  exit 1
fi

candidates_file=$(mktemp)
trap 'rm -f "$candidates_file"' EXIT

nvim -l "$script_dir/check_plugin_updates.lua" --candidates-file "$candidates_file" "$@"

if [ ! -s "$candidates_file" ]; then
  echo
  echo "Nothing to update."
  exit 0
fi

echo
selected=$(fzf \
  --multi \
  --bind 'space:toggle+down' \
  --header 'SPACE select, ENTER apply, ESC/Ctrl-C cancel' \
  --delimiter '\t' \
  --with-nth '2,3,4,5' \
  < "$candidates_file" || true)

if [ -z "$selected" ]; then
  echo "Nothing selected, no changes made."
  exit 0
fi

echo "$selected" | nvim -l "$script_dir/check_plugin_updates.lua" --apply
