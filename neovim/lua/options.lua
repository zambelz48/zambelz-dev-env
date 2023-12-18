local utils = require 'utils'

local python3_path = utils.shell_cmd('which python3')
vim.g.python3_host_prog = python3_path

vim.g.loaded_perl_provider = 0

vim.o.inccommand = 'nosplit'

-- disable netrw (nvim-tree suggestion: https://github.com/nvim-tree/nvim-tree.lua/blob/00741206c2df9c4b538055def19b99790f0c95c8/doc/nvim-tree-lua.txt#L85)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set highlight on search
vim.o.hlsearch = false

vim.o.hidden = true

-- Enable mouse mode
vim.o.mouse = ''

vim.o.breakindent = true

vim.o.ignorecase = true

vim.o.smartcase = true

vim.o.colorcolumn = '80'

vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

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

-- Make line numbers default
vim.wo.number = true

vim.wo.signcolumn = 'yes'

vim.wo.wrap = false

vim.bo.expandtab = true

vim.g.skip_ts_context_commentstring_module = true

--Set colorscheme (order is important here)
vim.o.termguicolors = true
vim.g.onedark_terminal_italics = 2
vim.cmd [[colorscheme dracula]]


