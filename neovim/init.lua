local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
local lockfile = require('utils').neovim_dir() .. '/lazy-lock.json'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  -- Clone at the locked commit: the first plugin install rewrites the lock
  -- from this checkout before Lazy restore can correct it.
  local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), '\n'))
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    lazyrepo, lazypath })
  if vim.v.shell_error == 0 then
    out = vim.fn.system({ 'git', '-C', lazypath, 'checkout', '--quiet',
      lock['lazy.nvim'].commit })
  end
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to install lazy.nvim:\n', 'ErrorMsg' },
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
  lockfile = lockfile,
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
