#!/usr/bin/env bash

set -euo pipefail

current_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
nvim_config="$HOME/.config/nvim"

# Linked as whole entries so new files need no re-run. lazy-lock.json lives
# in the repo (see init.lua), so nothing else in $nvim_config is touched.
entries=(init.lua lua after ftplugin .luarc.json)

mkdir -p "$nvim_config"

for entry in "${entries[@]}"; do
  target="$nvim_config/$entry"
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
  fi
  ln -s "$current_dir/$entry" "$target"
done
