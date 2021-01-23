#!/usr/bin/env bash

current_dir=$(dirname "$0")
vim_rtp="$HOME/.vim"

trap cleanup EXIT

function cleanup {

    local exitCode=$?

    if [ "$exitCode" -gt 0 ]; then
        reset
    fi
}

function reset {

   if [ -d "$vim_rtp" ]; then
      rm -rf "$vim_rtp"
   fi

   if [ -L "$HOME/.vimrc" ]; then
      rm "$HOME/.vimrc"
   fi

   if [ -f "$HOME/.viminfo" ]; then
      rm "$HOME/.viminfo"
   fi

   if [ -d "$HOME/.config/coc" ]; then
       rm -rf "$HOME/.config/coc"
   fi
}

reset

mkdir "$vim_rtp"

vim_dirs=(
    "autoload"
    "plugged"
    "plugin"
    "undodir"
)

for vim_dir in "${vim_dirs[@]}"; do
    mkdir "$vim_rtp/$vim_dir"
done


curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

ln -s "$current_dir/.vimrc" "$HOME/.vimrc"
ln -s "$current_dir/plugins/sets.vim" "$vim_rtp/plugin/sets.vim"
ln -s "$current_dir/plugins/coc.vim" "$vim_rtp/plugin/coc.vim"
ln -s "$current_dir/plugins/airline.vim" "$vim_rtp/plugin/airline.vim"
ln -s "$current_dir/coc/coc-settings.json" "$HOME/.vim/coc-settings.json"

mkdir "$HOME/.config/coc/extensions"
ln -s "$current_dir/coc/extensions/package.json" "$HOME/.config/coc/extensions/package.json"
cd "$HOME/.config/coc/extensions"
npm install --global-style --ignore-scripts --no-bin-links --no-package-lock --only=prod

