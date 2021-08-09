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

if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    rm "$HOME/.config/kitty/kitty.conf"
fi

ln -s "$current_dir/kitty.conf" "$HOME/.config/kitty/kitty.conf"

