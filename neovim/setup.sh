#!/usr/bin/env bash

current_dir=$(dirname "$0")
nvim_dir="$HOME/.local/share/nvim"
nvim_site_dir="$nvim_dir/site"
nvim_config="$HOME/.config/nvim"
coc_config="$HOME/.config/coc"

trap cleanup EXIT

function cleanup {

    local exitCode=$?

    if [ "$exitCode" -gt 0 ]; then
        reset
    fi
}

function reset {

   if [ -d "$nvim_dir" ]; then
      rm -rf "$nvim_dir"
   fi

   if [ -d "$nvim_config" ]; then
      rm -rf "$nvim_config"
   fi

   if [ -d "$coc_config" ]; then
       rm -rf "$coc_config"
   fi
}

reset

mkdir "$nvim_dir"
mkdir "$nvim_config"
mkdir "$nvim_site_dir"

nvim_config_dirs=(
    "autoload"
    "plugin"
)

for config_dir in "${nvim_config_dirs[@]}"; do
    mkdir "$nvim_site_dir/$config_dir"
done


curl -fLo "$nvim_site_dir/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

ln -s "$current_dir/init.vim" "$nvim_config/init.vim"

ln -s "$current_dir/plugin/sets.vim" "$nvim_site_dir/plugin/sets.vim"
ln -s "$current_dir/plugin/airline.vim" "$nvim_site_dir/plugin/airline.vim"

# coc
mkdir "$coc_config"
mkdir "$coc_config/extensions"

ln -s "$current_dir/coc/extensions/package.json" "$coc_config/extensions/package.json"
cd "$coc_config/extensions" && npm install --global-style --ignore-scripts --no-bin-links --no-package-lock --only=prod

ln -s "$current_dir/coc/coc-settings.json" "$nvim_config/coc-settings.json"
ln -s "$current_dir/plugin/coc.vim" "$nvim_site_dir/plugin/coc.vim"
ln -s "$current_dir/plugin/coc-explorer.vim" "$nvim_site_dir/plugin/coc-explorer.vim"

