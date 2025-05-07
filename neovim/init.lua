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
        'nvim-treesitter/nvim-treesitter',
        commit = '94ea4f4',
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
        tag = 'v2.1.0'
    }
    use {
        'hrsh7th/cmp-nvim-lsp',
        commit = 'a8912b8'
    }
    use {
        'hrsh7th/cmp-buffer',
        commit = 'b74fab3'
    }
    use {
        'hrsh7th/nvim-cmp',
        commit = 'b5311ab'
    }
    use {
        'L3MON4D3/LuaSnip',
        tag = 'v2.3.0',
        run = "make install_jsregexp"
    }
    use {
        'saadparwaiz1/cmp_luasnip',
        commit = '98d9cb5'
    }
    use {
        'mfussenegger/nvim-dap',
        tag = '0.10.0'
    }
    use {
        'rcarriga/nvim-dap-ui',
        commit = '73a26ab'
    }
    use {
        'theHamsta/nvim-dap-virtual-text',
        commit = 'df66808'
    }
    use {
        -- NOTE: required for 'CopilotC-Nvim/CopilotChat.nvim'
        -- TODO: Find out customization options to maximize potential usage of
        -- the plugins, particularly in combining with 'telescope' and
        -- 'telescope-fzf-native'
        'ibhagwan/fzf-lua',
        commit = '18ac8df'
    }
    use {
        'nvim-telescope/telescope.nvim',
        commit = 'a4ed825',
        requires = {
            'nvim-lua/plenary.nvim'
        }
    }
    use {
        'nvim-telescope/telescope-fzf-native.nvim',
        commit = '1f08ed6',
        run = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release'
    }
    use {
        'tpope/vim-fugitive',
        commit = '4a745ea'
    }
    use {
        'lewis6991/gitsigns.nvim',
        tag = 'v1.0.2'
    }
    use {
        'folke/trouble.nvim',
        tag = 'v3.7.1',
        requires = {
            'nvim-tree/nvim-web-devicons'
        }
    }
    use {
        'j-hui/fidget.nvim',
        commit = 'v1.6.1'
    }
    use {
        'numToStr/Comment.nvim',
        commit = 'e30b7f2'
    }
    use {
        'JoosepAlviste/nvim-ts-context-commentstring',
        commit = '1b212c2'
    }
    use {
        'folke/todo-comments.nvim',
        tag = 'v1.4.0'
    }
    use {
        'mfussenegger/nvim-jdtls',
        commit = 'c23f200'
    }
    use {
        'pmizio/typescript-tools.nvim',
        commit = '3c501d7'
    }
    use {
        'nvim-neotest/nvim-nio',
        tag = 'v1.10.1'
    }
    use {
        'tpope/vim-dadbod',
        commit = '9f0ca8b'
    }
    use {
        'kristijanhusak/vim-dadbod-ui',
        commit = '4604323'
    }
    use {
        'kristijanhusak/vim-dadbod-completion',
        commit = 'a8dac0b'
    }
    use {
        'zbirenbaum/copilot.lua',
        commit = '2f50ec4'
    }
    use {
        'CopilotC-Nvim/CopilotChat.nvim',
        tag = 'v3.11.1',
    }
    use {
        'Exafunction/codeium.nvim',
        requires = {
            'nvim-lua/plenary.nvim',
            'hrsh7th/nvim-cmp',
        },
        commit = '821b570'
    }
    use {
        'Mofiqul/dracula.nvim',
        commit = '96c9d19'
    }
    use {
        'nvim-lualine/lualine.nvim',
        -- stick to '640260d' for now, since the newest one is noticeable slow
        commit = '640260d',
        requires = {
            'nvim-tree/nvim-web-devicons',
            opt = true
        }
    }
    use {
        'edkolev/tmuxline.vim',
        commit = '4119c55'
    }
    use {
        'AndreM222/copilot-lualine',
        commit = '6bc29ba'
    }
    use {
        'nvim-tree/nvim-tree.lua',
        tag = 'nvim-tree-v1.12.0',
        requires = 'nvim-tree/nvim-web-devicons'
    }
    use {
        'akinsho/toggleterm.nvim',
        tag = 'v2.13.1'
    }
    use {
        'nvim-tree/nvim-web-devicons',
        commit = '50b5b06'
    }
    use {
        'norcalli/nvim-colorizer.lua',
        commit = 'a065833'
    }
    use {
        'iamcco/markdown-preview.nvim',
        commit = 'a923f5f',
        run = function()
            vim.fn["mkdp#util#install"]()
        end
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
require('typescript_tools_conf')
require('codeium_conf')
