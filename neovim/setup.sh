#!/usr/bin/env bash

current_dir=$(dirname "$0")
nvim_config="$HOME/.config/nvim"
nvim_lua="$nvim_config/lua"

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
}

reset

mkdir "$nvim_config"
mkdir "$nvim_lua"

ln -s "$current_dir/init.lua" "$nvim_config/init.lua"

ln -s "$current_dir/lua/mappings.lua" "$nvim_lua/mappings.lua"
ln -s "$current_dir/lua/options.lua" "$nvim_lua/options.lua"
ln -s "$current_dir/lua/lsp_conf.lua" "$nvim_lua/lsp_conf.lua"
ln -s "$current_dir/lua/telescope_conf.lua" "$nvim_lua/telescope_conf.lua"
ln -s "$current_dir/lua/treesitter_conf.lua" "$nvim_lua/treesitter_conf.lua"
ln -s "$current_dir/lua/nvim_tree_conf.lua" "$nvim_lua/nvim_tree_conf.lua"
ln -s "$current_dir/lua/cmp_conf.lua" "$nvim_lua/cmp_conf.lua"
ln -s "$current_dir/lua/lualine_conf.lua" "$nvim_lua/lualine_conf.lua"
ln -s "$current_dir/lua/nvim_colorizer_conf.lua" "$nvim_lua/nvim_colorizer_conf.lua"

