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
        commit = '4023772'
    }
    use {
        'nvim-tree/nvim-tree.lua',
        tag = 'nvim-tree-v1.10.0',
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
        commit = 'b068eaf'
    }
    use {
        'ibhagwan/fzf-lua',
        commit = 'b3e9303'
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
        commit = 'dae2eac',
        run = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release'
    }
    use {
        'nvim-treesitter/nvim-treesitter',
        commit = 'da89532',
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
        tag = 'v1.6.0'
    }
    use {
        'hrsh7th/cmp-nvim-lsp',
        commit = '99290b3'
    }
    use {
        'hrsh7th/cmp-buffer',
        commit = '3022dbc'
    }
    use {
        'hrsh7th/nvim-cmp',
        commit = '1250990'
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
        'Mofiqul/dracula.nvim',
        commit = '515acae'
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
        tag = 'v2.13.1'
    }
    use {
        'lewis6991/gitsigns.nvim',
        tag = 'v1.0.0'
    }
    use {
        'folke/trouble.nvim',
        tag = 'v3.7.0',
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
        'mfussenegger/nvim-jdtls',
        commit = '3cdd09f'
    }
    use {
        'mfussenegger/nvim-dap',
        commit = '52302f0'
    }
    use {
        'rcarriga/nvim-dap-ui',
        commit = 'bc81f8d'
    }
    use {
        'theHamsta/nvim-dap-virtual-text',
        commit = 'df66808'
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
        commit = 'f4d37b7'
    }
    use {
        'kristijanhusak/vim-dadbod-completion',
        commit = 'c7f1be2'
    }
    use {
        'zbirenbaum/copilot.lua',
        commit = '886ee73'
    }
    use {
        'AndreM222/copilot-lualine',
        commit = 'dc4b8ed'
    }
    use {
        'CopilotC-Nvim/CopilotChat.nvim',
        tag = 'v3.5.0',
    }
    use {
        'pmizio/typescript-tools.nvim',
        commit = '35e397c'
    }
    use {
        'folke/todo-comments.nvim',
        tag = 'v1.4.0'
    }
    use {
        'Exafunction/codeium.nvim',
        requires = {
            'nvim-lua/plenary.nvim',
            'hrsh7th/nvim-cmp',
        },
        commit = 'ebed4f7'
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
require('codeium_conf')
