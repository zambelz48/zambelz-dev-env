#!/usr/bin/env bash

current_dir=$(dirname "$0")

if [ -L "$HOME/.zshrc" ]; then
    rm "$HOME/.zshrc"
fi

ln -s "$current_dir/.zshrc" "$HOME/.zshrc"

