local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
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

-- Leaders must be set before lazy.nvim loads so plugin mappings use them.
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

require('options')
require('filetypes')
require('keymaps')

require('lazy').setup({
  spec = {
    { import = 'plugins' },
  },
  lockfile = require('utils').neovim_dir() .. '/lazy-lock.json',
  install = { colorscheme = { 'dracula' } },
  checker = { enabled = false },
  rocks = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'netrwPlugin',
        'tarPlugin',
        'tutor',
        'zipPlugin',
      },
    },
  },
})
