#!/usr/bin/env bash

current_dir=$(dirname "$0")

if [ ! -d "$HOME/.config" ]; then
  echo -e ".config dir not found"
  exit 1
fi

if [ ! -d "$HOME/.config/kitty" ]; then
  echo -e "Kitty config not found"
  exit 1
fi

if [ -f "$HOME/.config/kitty/kitty.base.conf" ]; then
  rm "$HOME/.config/kitty/kitty.base.conf"
fi

ln -s "$current_dir/kitty.base.conf" "$HOME/.config/kitty/kitty.base.conf"

# kitty.conf holds per-machine overrides (e.g. font_size) and is git-ignored.
# Only generate it once so re-running setup never clobbers local edits.
if [ ! -f "$current_dir/kitty.conf" ]; then
  cat > "$current_dir/kitty.conf" << 'EOF'
include kitty.base.conf

font_size 12.0
EOF
fi

if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
  rm "$HOME/.config/kitty/kitty.conf"
fi

ln -s "$current_dir/kitty.conf" "$HOME/.config/kitty/kitty.conf"

