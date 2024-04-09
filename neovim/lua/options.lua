local utils = require 'utils'

local python3_path = utils.shell_cmd('which python3')
vim.g.python3_host_prog = python3_path

vim.g.loaded_perl_provider = 0

vim.opt.inccommand = 'nosplit'

-- disable netrw (nvim-tree suggestion: https://github.com/nvim-tree/nvim-tree.lua/blob/00741206c2df9c4b538055def19b99790f0c95c8/doc/nvim-tree-lua.txt#L85)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set highlight on search
vim.opt.hlsearch = false

vim.opt.hidden = true

-- Enable mouse mode
vim.opt.mouse = ''

vim.opt.breakindent = true

vim.opt.ignorecase = true

vim.opt.smartcase = true

vim.opt.colorcolumn = '80'

vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250
vim.opt.timeout = true
vim.opt.timeoutlen = 300

vim.opt.guifont = 'Hack Nerd Font 12'

vim.opt.guicursor = ''

vim.opt.swapfile = false

vim.opt.backup = false

vim.opt.showmode = false

vim.opt.scrolloff = 8

vim.opt.cmdheight = 2

vim.opt.smartindent = true

vim.opt.errorbells = false

vim.opt.tabstop = 4

vim.opt.softtabstop = 4

vim.opt.shiftwidth = 4

vim.opt.completeopt = 'menuone,noselect'

-- Make line numbers default
vim.opt.number = true

vim.opt.signcolumn = 'yes'

vim.opt.wrap = false

vim.opt.expandtab = true

vim.g.skip_ts_context_commentstring_module = true

--Set colorscheme (order is important here)
vim.opt.termguicolors = true
vim.g.onedark_terminal_italics = 2
vim.cmd [[colorscheme dracula]]


