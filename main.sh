#!/usr/bin/env bash

current_dir=$(pwd)
options=$(echo "$@" | xargs)
option=$(echo "$options" | head -n1 | awk '{print $1;}')

case $option in
    zsh)
        cd zsh
        bash setup.sh
        cd "$current_dir"
    ;;
    vim)
        cd vim
        bash setup.sh
        cd "$current_dir" 
    ;;
    alacritty)
        cd alacritty
        bash setup.sh
        cd "$current_dir" 
    ;;
esac

