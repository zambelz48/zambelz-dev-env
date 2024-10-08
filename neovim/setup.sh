#!/usr/bin/env bash

current_dir=$(dirname "$0")
nvim_config="$HOME/.config/nvim"
nvim_lua="$nvim_config/lua"
nvim_ftplugin="$nvim_config/ftplugin"

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

  if [ -d "$nvim_ftplugin" ]; then
    rm -rf "$nvim_ftplugin"
  fi
}

reset

mkdir "$nvim_config"
mkdir "$nvim_lua"
mkdir "$nvim_ftplugin"

ln -s "$current_dir/init.lua" "$nvim_config/init.lua"

source_config_dir="$current_dir/lua"
destination_config_dir="$nvim_lua"

shopt -s nullglob
conf_files=("$source_config_dir"/*.lua)

for conf_file in "${conf_files[@]}"; do
  conf_file_name="${conf_file[@]##*/}"
  ln -s "$source_config_dir/$conf_file_name" "$nvim_lua/$conf_file_name"
done

source_ftplugin_dir="$current_dir/ftplugin"
destination_ftplugin_dir="$nvim_ftplugin"

shopt -s nullglob
ftplugin_files=("$source_ftplugin_dir"/*.lua)

for ftplugin_file in "${ftplugin_files[@]}"; do
  ftplugin_file_name="${ftplugin_file[@]##*/}"
  ln -s "$source_ftplugin_dir/$ftplugin_file_name" "$nvim_ftplugin/$ftplugin_file_name"
done

