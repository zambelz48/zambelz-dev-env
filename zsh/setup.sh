#!/usr/bin/env bash

current_dir=$(pwd)

if [ -L "$HOME/.zshrc" ]; then
    rm "$HOME/.zshrc"
fi

ln -s "$current_dir/.zshrc" "$HOME/.zshrc"

