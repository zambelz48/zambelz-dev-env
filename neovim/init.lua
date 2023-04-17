
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
        requires = 'kyazdani42/nvim-web-devicons'
    }
	use {
		'nvim-lualine/lualine.nvim',
		requires = {
			'kyazdani42/nvim-web-devicons', 
			opt = true 
		}
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
    use 'edkolev/tmuxline.vim'
	use 'norcalli/nvim-colorizer.lua'
	use { 
		'iamcco/markdown-preview.nvim', 
		run = 'cd app && yarn install'
	}
	use { 'puremourning/vimspector' }
	use {
		'akinsho/toggleterm.nvim',
		tag = '*'
	}
	use {
		'lewis6991/gitsigns.nvim',
		tag = 'release'
	}
end)

require('options')
require('mappings')
require('treesitter_conf')
require('lsp_conf')
require('cmp_conf')
require('nvim_tree_conf')
require('telescope_conf')
require('lualine_conf')
require('nvim_colorizer_conf')
require('markdown_preview_conf')
require('vimspector_conf')
require('toggleterm_conf')
require('gitsigns_conf')

