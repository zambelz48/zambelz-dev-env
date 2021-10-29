
local install_path = vim.fn.stdpath 'data' .. '/site/pack/packer/start/packer.nvim'

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.execute('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
end

vim.api.nvim_exec(
    [[
        augroup Packer
            autocmd!
            autocmd BufWritePost init.lua PackerCompile
        augroup end
    ]],
    false
)

local use = require('packer').use
require('packer').startup(function()
    use 'wbthomason/packer.nvim'
    use {
        'kyazdani42/nvim-tree.lua',
        requires = 'kyazdani42/nvim-web-devicons',
        config = function() require'nvim-tree'.setup {} end
    }
    use 'tpope/vim-fugitive'
    use 'tpope/vim-commentary'
    use { 
        'nvim-telescope/telescope.nvim', 
        requires = { 'nvim-lua/plenary.nvim' } 
    }
    use 'nvim-treesitter/nvim-treesitter'
    use 'neovim/nvim-lspconfig'
    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'saadparwaiz1/cmp_luasnip'
    use 'L3MON4D3/LuaSnip'
    use { 
        'dracula/vim', 
        as = 'dracula' 
    }
    use 'itchyny/lightline.vim'
    use 'edkolev/tmuxline.vim'
end)

require('options')
require('mappings')
require('treesitter_conf')
require('lsp_conf')
require('cmp_conf')
require('nvim_tree_conf')
require('telescope_conf')
require('lightline_conf')

