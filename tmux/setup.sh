#¡/usr/bin/env bash

current_dir=$(dirname "$0")

if [ -d "$HOME/.tmux" ]; then
    rm -rf "$HOME/.tmux"
fi

if [ -f "$HOME/.tmux.conf" ]; then
    rm "$HOME/.tmux.conf"
fi

git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

ln -s "$current_dir/.tmux.conf" "$HOME/.tmux.conf"

