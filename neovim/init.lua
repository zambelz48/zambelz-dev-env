local install_path = vim.fn.stdpath 'data' ..
    '/site/pack/packer/start/packer.nvim'

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.execute('!git clone https://github.com/wbthomason/packer.nvim ' ..
        install_path)
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
    use 'nvim-lua/plenary.nvim'
    use {
        'nvim-tree/nvim-web-devicons',
        commit = '19d257c'
    }
    use {
        'nvim-tree/nvim-tree.lua',
        tag = 'nvim-tree-v1.7.1',
        requires = 'nvim-tree/nvim-web-devicons'
    }
    use {
        'nvim-lualine/lualine.nvim',
        commit = '640260d',
        requires = {
            'nvim-tree/nvim-web-devicons',
            opt = true
        }
    }
    use {
        'tpope/vim-fugitive',
        commit = 'd4877e5'
    }
    use {
        'ibhagwan/fzf-lua',
        commit = 'ce1e24f'
    }
    use {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        requires = {
            'nvim-lua/plenary.nvim'
        }
    }
    use {
        'nvim-telescope/telescope-fzf-native.nvim',
        commit = 'cf48d4d',
        run = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
    }
    use {
        'nvim-treesitter/nvim-treesitter',
        tag = 'v0.9.3',
        requires = {
            'nvim-treesitter/nvim-treesitter-textobjects'
        }
    }
    use {
        'nvim-treesitter/playground',
        commit = 'ba48c6a'
    }
    use {
        'neovim/nvim-lspconfig',
        tag = 'v1.0.0'
    }
    use {
        'hrsh7th/cmp-nvim-lsp',
        commit = '39e2eda'
    }
    use {
        'hrsh7th/cmp-buffer',
        commit = '3022dbc'
    }
    use {
        'hrsh7th/nvim-cmp',
        commit = 'f17d9b4'
    }
    use {
        'L3MON4D3/LuaSnip',
        tag = 'v2.3.0',
        run = "make install_jsregexp"
    }
    use {
        'saadparwaiz1/cmp_luasnip',
        commit = '05a9ab2'
    }
    use {
        'Mofiqul/dracula.nvim',
        commit = '94fa788'
    }
    use {
        'edkolev/tmuxline.vim',
        commit = '4119c55'
    }
    use {
        'norcalli/nvim-colorizer.lua',
        commit = 'a065833'
    }
    use {
        'iamcco/markdown-preview.nvim',
        commit = 'a923f5f',
        run = function() vim.fn["mkdp#util#install"]() end
    }
    use {
        'akinsho/toggleterm.nvim',
        tag = 'v2.12.0'
    }
    use {
        'lewis6991/gitsigns.nvim',
        commit = '7c27a30'
    }
    use {
        'folke/trouble.nvim',
        commit = '2f3b537',
        requires = {
            'nvim-tree/nvim-web-devicons'
        }
    }
    use {
        'j-hui/fidget.nvim',
        commit = 'e2a175c'
    }
    use {
        'numToStr/Comment.nvim',
        commit = 'e30b7f2'
    }
    use {
        'JoosepAlviste/nvim-ts-context-commentstring',
        commit = '9c74db6'
    }
    use {
        'mfussenegger/nvim-jdtls',
        commit = 'a9b5fc8'
    }
    use {
        'mfussenegger/nvim-dap',
        commit = '7ff6936'
    }
    use {
        'nvim-neotest/nvim-nio',
        tag = 'v1.10.0'
    }
    use {
        'rcarriga/nvim-dap-ui',
        commit = 'ffa8983'
    }
    use {
        'theHamsta/nvim-dap-virtual-text',
        commit = '76d80c3'
    }
    use {
        'tpope/vim-dadbod',
        commit = 'fe5a55e'
    }
    use {
        'kristijanhusak/vim-dadbod-ui',
        commit = 'f29c85a'
    }
    use {
        'kristijanhusak/vim-dadbod-completion',
        commit = '880f7e9'
    }
    use {
        'zbirenbaum/copilot.lua',
        commit = 'f8d8d87'
    }
    use {
        'AndreM222/copilot-lualine',
        commit = 'f40450c'
    }
    use {
        'CopilotC-Nvim/CopilotChat.nvim',
        tag = 'v2.15.0',
    }
    use {
        'pmizio/typescript-tools.nvim',
        commit = 'f8c2e0b'
    }
    use {
        'folke/todo-comments.nvim',
        tag = 'v1.4.0'
    }
end)

require('options')
require('dracula_theme_conf')
require('mappings')
require('treesitter_conf')
require('cmp_conf')
require('lsp_conf')
require('nvim_tree_conf')
require('telescope_conf')
require('lualine_conf')
require('nvim_colorizer_conf')
require('toggleterm_conf')
require('gitsigns_conf')
require('trouble_conf')
require('nvim_web_devicons_conf')
require('fidget_conf')
require('comment_conf')
require('nvim_dap_conf')
require('keymaps')
require('todo_comments_conf')
require('markdown_preview_conf')
require('copilot_conf')
require('copilot_chat_conf')
require('omnisharp_conf')
require('typescript_tools_conf')
