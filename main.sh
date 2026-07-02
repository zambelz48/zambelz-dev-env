#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")

options=$(echo "$@" | xargs)
option=$(echo "$options" | head -n1 | awk '{print $1;}')

case $option in
    zsh)
        bash "$SCRIPT_DIR/zsh/setup.sh"
    ;;
    kitty)
        bash "$SCRIPT_DIR/kitty/setup.sh"
    ;;
    neovim)
        case $2 in
            check-updates)
                bash "$SCRIPT_DIR/neovim/scripts/apply_plugin_updates.sh" "${@:3}"
            ;;
            *)
                bash "$SCRIPT_DIR/neovim/setup.sh"
            ;;
        esac
    ;;
    tmux)
        bash "$SCRIPT_DIR/tmux/setup.sh"
    ;;
esac

