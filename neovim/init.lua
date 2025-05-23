local vim = vim

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none',
        '--branch=stable', lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
            { out,                            'WarningMsg' },
            { '\nPress any key to exit...' },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

require('options')
require('keymaps')

-- Setup lazy.nvim
require('lazy').setup({
    spec = {
        require('plugins.plenary'),
        require('plugins.dracula_theme'),
        require('plugins.treesitter'),
        require('plugins.treesitter_textobjects'),
        require('plugins.nvim_web_devicons'),
        require('plugins.nvim_lsp'),
        require('plugins.nvim_cmp'),
        require('plugins.nvim_cmp_luasnip'),
        require('plugins.luasnip'),
        require('plugins.fzf'),
        require('plugins.telescope'),
        require('plugins.telescope_fzf_native'),
        require('plugins.telescope_ui_select'),
        require('plugins.nvim_dap'),
        require('plugins.nvim_dap_ui'),
        require('plugins.nvim_dap_virtual_text'),
        require('plugins.vim_fugitive'),
        require('plugins.gitsigns'),
        require('plugins.nvim_tree'),
        require('plugins.fidget'),
        require('plugins.trouble'),
        require('plugins.comment_ts_context'),
        require('plugins.comment'),
        require('plugins.todo_comments'),
        require('plugins.lualine'),
        require('plugins.tmuxline'),
        require('plugins.toggleterm'),
        require('plugins.copilot'),
        require('plugins.copilot_lualine'),
        require('plugins.copilot_chat'),
        require('plugins.windsurf'),
        require('plugins.neotest'),
        require('plugins.nvim_jdtls'),
        require('plugins.nvim_colorizer'),
        require('plugins.markdown_preview'),
    },

    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { 'dracula' } },

    -- automatically check for plugin updates
    checker = { enabled = true },
})
