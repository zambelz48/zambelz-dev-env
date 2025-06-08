local vim = vim

-- Load all plugins from $HOME/.config/nvim/lua/plugins/*.lua
local loaded_plugins = {}
local plugins_dir = os.getenv('HOME') .. '/.config/nvim/lua/plugins'
for _, plugin_path in pairs(vim.fn.glob(plugins_dir .. '/*.lua', true, true)) do
    local plugin_spec = dofile(plugin_path)
    if type(plugin_spec[1]) == 'table' then
        vim.list_extend(loaded_plugins, plugin_spec)
    else
        table.insert(loaded_plugins, plugin_spec)
    end
end

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
    spec = loaded_plugins,

    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { 'dracula' } },

    -- automatically check for plugin updates
    checker = { enabled = true },
})
