local utils = require 'utils'

require('toggleterm').setup({
	size = 20,
	open_mapping = [[<c-\>]],
	hide_numbers = true,
	shade_filetypes = {},
	shade_terminals = true,
	shading_factor = 2,
	start_in_insert = true,
	insert_mappings = true,
	persist_size = true,
	direction = "float",
	close_on_exit = true,
	shell = vim.o.shell,
	float_opts = {
		border = "curved",
		winblend = 0,
		highlights = {
			border = "Normal",
			background = "Normal",
		},
	},
})

function _G.set_terminal_keymaps()
	utils.tnoremap_buf('<esc>', [[<C-\><C-n>]])
	utils.tnoremap_buf('jk', [[<C-\><C-n>]])
	utils.tnoremap_buf('<C-h>', [[<C-\><C-n><C-W>h]])
	utils.tnoremap_buf('<C-j>', [[<C-\><C-n><C-W>j]])
	utils.tnoremap_buf('<C-k>', [[<C-\><C-n><C-W>k]])
	utils.tnoremap_buf('<C-l>', [[<C-\><C-n><C-W>l]])
end

vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

local Terminal = require("toggleterm.terminal").Terminal

local repl_node = Terminal:new({ cmd = "node", hidden = true })
function _REPL_NODE()
	repl_node:toggle()
end

local repl_swift = Terminal:new({ cmd = "swift repl", hidden = true })
function _REPL_SWIFT()
	repl_swift:toggle()
end

