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
    use 'nvim-tree/nvim-web-devicons'
    use {
        'nvim-tree/nvim-tree.lua',
        requires = 'nvim-tree/nvim-web-devicons'
    }
    use {
        'nvim-lualine/lualine.nvim',
        requires = {
            'nvim-tree/nvim-web-devicons',
            opt = true
        }
    }
    use 'tpope/vim-fugitive'
    use 'nvim-lua/plenary.nvim'
    use 'ibhagwan/fzf-lua'
    use {
        'nvim-telescope/telescope.nvim',
        requires = { 'nvim-lua/plenary.nvim' }
    }
    use {
        'nvim-telescope/telescope-fzf-native.nvim',
        run =
        'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
    }
    use {
        'nvim-treesitter/nvim-treesitter',
        requires = { 'nvim-treesitter/nvim-treesitter-textobjects' }
    }
    use 'nvim-treesitter/playground'
    use 'neovim/nvim-lspconfig'
    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'saadparwaiz1/cmp_luasnip'
    use {
        'L3MON4D3/LuaSnip',
        run = "make install_jsregexp"
    }
    use 'Mofiqul/dracula.nvim'
    use 'edkolev/tmuxline.vim'
    use 'norcalli/nvim-colorizer.lua'
    use {
        'iamcco/markdown-preview.nvim',
        run = function() vim.fn["mkdp#util#install"]() end
    }
    use {
        'akinsho/toggleterm.nvim',
        tag = '*'
    }
    use 'lewis6991/gitsigns.nvim'
    use {
        'folke/trouble.nvim',
        requires = 'nvim-tree/nvim-web-devicons'
    }
    use {
        'j-hui/fidget.nvim'
    }
    use 'numToStr/Comment.nvim'
    use 'JoosepAlviste/nvim-ts-context-commentstring'
    use 'mfussenegger/nvim-jdtls'
    use 'mfussenegger/nvim-dap'
    use 'nvim-neotest/nvim-nio'
    use 'rcarriga/nvim-dap-ui'
    use 'theHamsta/nvim-dap-virtual-text'
    use 'tpope/vim-dadbod'
    use 'kristijanhusak/vim-dadbod-ui'
    use 'kristijanhusak/vim-dadbod-completion'
    use 'zbirenbaum/copilot.lua'
    use 'AndreM222/copilot-lualine'
    use {
        'CopilotC-Nvim/CopilotChat.nvim',
        branch = 'canary',
    }
    use 'pmizio/typescript-tools.nvim'
    use 'folke/todo-comments.nvim'
    use 'Hoffs/omnisharp-extended-lsp.nvim'
end)

require('options')
require('dracula_theme_conf')
require('mappings')
require('treesitter_conf')
require('lsp_conf')
require('omnisharp_conf')
require('cmp_conf')
require('typescript_tools_conf')
require('nvim_tree_conf')
require('telescope_conf')
require('lualine_conf')
require('nvim_colorizer_conf')
require('markdown_preview_conf')
require('toggleterm_conf')
require('gitsigns_conf')
require('trouble_conf')
require('nvim_web_devicons_conf')
require('fidget_conf')
require('comment_conf')
require('nvim_dap_conf')
require('keymaps')
require('todo_comments_conf')
require('copilot_conf')
require('copilot_chat_conf')
