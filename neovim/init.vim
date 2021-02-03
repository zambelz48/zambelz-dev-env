
call plug#begin(stdpath('data') . '/plugged')

Plug 'junegunn/vim-plug'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'gruvbox-community/gruvbox'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-commentary'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'edkolev/tmuxline.vim'
Plug 'udalov/kotlin-vim'

" Don't forget to clone: https://github.com/apple/swift
Plug '/Users/nanda/Dev/Projects/swift/utils/vim'

call plug#end()

colorscheme gruvbox
set background=dark

highlight Normal guibg=none

