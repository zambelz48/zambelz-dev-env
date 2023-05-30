#!/usr/bin/env bash

current_dir=$(dirname "$0")
themes_dir="$current_dir/.themes"
omz_dir="$HOME/.oh-my-zsh"
omz_themes_dir="$omz_dir/themes"

if [ ! -d "$omz_dir" ]; then
	echo "oh-my-zsh not found. please install it first (https://github.com/ohmyzsh/ohmyzsh/#basic-installation)"
	exit 1
fi

if [ ! -d "$current_dir/.themes" ]; then
	echo ".themes dir's not found. please clone the theme first"
	exit 1
fi


dracula_theme_name="dracula.zsh-theme"
dracula_theme_source="$themes_dir/dracula/$dracula_theme_name"
dracula_theme_destination="$omz_themes_dir/$dracula_theme_name"

dracula_theme_lib="lib"
dracula_theme_lib_source="$themes_dir/dracula/$dracula_theme_lib"
dracula_theme_lib_destination="$omz_themes_dir/$dracula_theme_lib"

if [ -f "$dracula_theme_destination" ]; then
	rm -rf "$dracula_theme_destination"
fi

if [ -d "$dracula_theme_lib_destination" ]; then
	rm -rf "$dracula_theme_lib_destination"
fi

ln -s "$dracula_theme_source" "$dracula_theme_destination"
ln -s "$dracula_theme_lib_source" "$dracula_theme_lib_destination"

if [ -L "$HOME/.zshrc" ]; then
    rm "$HOME/.zshrc"
fi

ln -s "$current_dir/.zshrc" "$HOME/.zshrc"

