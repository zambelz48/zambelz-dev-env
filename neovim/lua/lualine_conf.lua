local lualine = require 'lualine'
lualine.setup({
	options = {
		icons_enabled = true,
		theme = 'dracula',

		-- This causing neovim intro message disappear
		component_separators = { left = '', right = '' },
		section_separators = { left = '', right = '' },

		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		globalstatus = false,
		refresh = {
			statusline = 1000,
			tabline = 1000,
			winbar = 1000,
		}
	},
	sections = {
		lualine_a = { 'mode' },
		lualine_b = { 'branch', 'diff', 'diagnostics' },
		lualine_c = { 'filename' },
		lualine_x = {
			{
				'copilot',
				symbols = {
					status = {
						icons = {
							enabled = " ",
							sleep = " ",   -- auto-trigger disabled
							disabled = " ",
							warning = " ",
							unknown = " "
						},
						hl = {
							enabled = "#50FA7B",
							sleep = "#c1f7cf",
							disabled = "#6272A4",
							warning = "#FFB86C",
							unknown = "#FF5555"
						}
					},
					spinners = require("copilot-lualine.spinners").dots,
				spinner_color = "#bd93f9"
				},
				show_colors = true,
				show_loading = true
			},
			'encoding',
			'filetype',
		},
		lualine_y = { 'progress' },
		lualine_z = { 'location' }
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { 'filename' },
		lualine_x = { 'location' },
		lualine_y = {},
		lualine_z = {}
	},
	tabline = {},
	winbar = {},
	inactive_winbar = {},
	extensions = {}
})
