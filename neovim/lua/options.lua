
vim.g.python3_host_prog = '/opt/homebrew/bin/python3'
vim.g.loaded_perl_provider = 0

vim.o.inccommand = 'nosplit'
vim.o.hlsearch = true
vim.o.hidden = true
vim.o.mouse = 'a'
vim.o.breakindent = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.relativenumber = true
vim.o.colorcolumn = '80'
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.guifont = 'Hack Nerd Font 12'
vim.o.guicursor = ''
vim.o.swapfile = false
vim.o.backup = false
vim.o.showmode = false
vim.o.scrolloff = 8
vim.o.cmdheight = 2
vim.o.smartindent = true
vim.o.errorbells = false
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.completeopt = 'menuone,noselect'

vim.wo.number = true
vim.wo.signcolumn = 'yes'
vim.wo.wrap = false

vim.bo.expandtab = true

--Set colorscheme (order is important here)
vim.o.termguicolors = true
vim.g.onedark_terminal_italics = 2
vim.cmd [[colorscheme dracula]]


