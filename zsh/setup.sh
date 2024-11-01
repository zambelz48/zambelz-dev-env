#!/usr/bin/env bash

current_dir=$(dirname "$0")
omz_dir="$HOME/.oh-my-zsh"

if [ ! -d "$omz_dir" ]; then
  echo "oh-my-zsh not found. please install it first (https://github.com/ohmyzsh/ohmyzsh/#basic-installation)"
  exit 1
fi

function install_theme {
  local themes_dir="$current_dir/.themes"
  local omz_themes_dir="$omz_dir/themes"

  if [ ! -d "$current_dir/.themes" ]; then
    echo ".themes dir's not found. please clone the theme first"
    return
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
}

function install_plugins {
  local plugins_dir="$current_dir/.plugins"
  local omz_plugins_dir="$omz_dir/custom/plugins"

  if [ ! -d "$current_dir/.plugins" ]; then
    echo ".plugins dir's not found. please clone the plugins first"
    return
  fi

  local target_plugins=("evalcache")

  for plugin in "${target_plugins[@]}"; do
    plugin_source="$plugins_dir/$plugin"
    plugin_destination="$omz_plugins_dir/$plugin"

    if [ -d "$plugin_destination" ]; then
      rm -rf "$plugin_destination"
    fi

    ln -s "$plugin_source" "$plugin_destination"
  done
}

install_theme
install_plugins

if [ -L "$HOME/.zshrc" ]; then
  rm "$HOME/.zshrc"
fi

ln -s "$current_dir/.zshrc" "$HOME/.zshrc"

