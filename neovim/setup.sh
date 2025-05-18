#!/usr/bin/env bash

current_dir=$(dirname "$0")
nvim_config="$HOME/.config/nvim"
nvim_lua="$nvim_config/lua"
nvim_lua_plugins="$nvim_lua/plugins"
nvim_lsp_configs="$nvim_lua/lsp_configs"

trap cleanup EXIT

function cleanup {

  local exitCode=$?

  if [ "$exitCode" -gt 0 ]; then
    reset
  fi
}

function reset {

  if [ -d "$nvim_config" ]; then
    rm -rf "$nvim_config"
  fi

  if [ -d "$nvim_lua" ]; then
    rm -rf "$nvim_lua"
  fi

  if [ -d "$nvim_lua_plugins" ]; then
    rm -rf "$nvim_lua_plugins"
  fi

  if [ -d "$nvim_lsp_configs" ]; then
    rm -rf "$nvim_lsp_configs"
  fi
}

reset

mkdir "$nvim_config"
mkdir "$nvim_lua"
mkdir "$nvim_lua_plugins"
mkdir "$nvim_lsp_configs"

ln -s "$current_dir/init.lua" "$nvim_config/init.lua"

# lua config files
source_config_dir="$current_dir/lua"
destination_config_dir="$nvim_lua"

shopt -s nullglob
conf_files=("$source_config_dir"/*.lua)

for conf_file in "${conf_files[@]}"; do
  conf_file_name="${conf_file[@]##*/}"
  ln -s "$source_config_dir/$conf_file_name" "$nvim_lua/$conf_file_name"
done

# lua plugin files
source_lua_plugins_dir="$current_dir/lua/plugins"
destination_lua_plugins_dir="$nvim_lua_plugins"

shopt -s nullglob
lua_plugin_files=("$source_lua_plugins_dir"/*.lua)

for lua_plugin_file in "${lua_plugin_files[@]}"; do
  lua_plugin_file_name="${lua_plugin_file[@]##*/}"
  ln -s "$source_lua_plugins_dir/$lua_plugin_file_name" "$nvim_lua_plugins/$lua_plugin_file_name"
done

# lsp config files
source_lsp_configs_dir="$current_dir/lua/lsp_configs"
destination_lsp_configs_dir="$nvim_lsp_configs"

shopt -s nullglob
lsp_conf_files=("$source_lsp_configs_dir"/*.lua)

for lsp_conf_file in "${lsp_conf_files[@]}"; do
  lsp_conf_file_name="${lsp_conf_file[@]##*/}"
  ln -s "$source_lsp_configs_dir/$lsp_conf_file_name" "$nvim_lsp_configs/$lsp_conf_file_name"
done
