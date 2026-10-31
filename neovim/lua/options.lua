vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
-- The node host comes from the repo's tools/npm, not a global npm install.
vim.g.node_host_prog = vim.fs.dirname(require('utils').neovim_dir())
  .. '/tools/npm/node_modules/neovim/bin/cli.js'

vim.opt.hlsearch = false

vim.opt.mouse = ''

vim.opt.breakindent = true

vim.opt.ignorecase = true

vim.opt.smartcase = true

vim.opt.colorcolumn = '80'

vim.opt.signcolumn = 'yes'

vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

vim.opt.guicursor = ''

vim.opt.swapfile = false

vim.opt.showmode = false

vim.opt.scrolloff = 8

vim.opt.cmdheight = 2

vim.opt.smartindent = true

vim.opt.tabstop = 4

vim.opt.softtabstop = 4

vim.opt.shiftwidth = 4

vim.opt.completeopt = 'menuone,noselect'

vim.opt.number = true

vim.opt.wrap = false

vim.opt.expandtab = true

vim.opt.winborder = 'rounded'

vim.keymap.set('n', 'k', function()
  if vim.v.count == 0 then
    return 'gk'
  end
  return 'k'
end, { expr = true, silent = true })
vim.keymap.set('n', 'j', function()
  if vim.v.count == 0 then
    return 'gj'
  end
  return 'j'
end, { expr = true, silent = true })

vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('YankHighlight', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
