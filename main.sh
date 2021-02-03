#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")

options=$(echo "$@" | xargs)
option=$(echo "$options" | head -n1 | awk '{print $1;}')

case $option in
    zsh)
        bash "$SCRIPT_DIR/zsh/setup.sh"
    ;;
    vim)
        bash "$SCRIPT_DIR/vim/setup.sh"
    ;;
    neovim)
        bash "$SCRIPT_DIR/neovim/setup.sh"
    ;;
    alacritty)
        bash "$SCRIPT_DIR/alacritty/setup.sh"
    ;;
    tmux)
        bash "$SCRIPT_DIR/tmux/setup.sh"
    ;;
esac

