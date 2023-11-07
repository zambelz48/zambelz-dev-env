local treesitter_config = require 'nvim-treesitter.configs'
-- Parsers must be installed manually via :TSInstall (https://github.com/nvim-treesitter/nvim-treesitter#language-parsers)
-- list of execite this => :TSInstall bash c cmake cpp css dockerfile html java javascript jsdoc json json5 jsonc kotlin llvm lua python ruby rust scss swift toml tsx typescript vim yaml

treesitter_config.setup ({
	-- Add languages to be installed here that you want installed for treesitter
	ensure_installed = {
		'bash',
		'c',
		'cmake',
		'cpp',
		'css',
		'dockerfile',
		'git_config',
		'git_rebase',
		'gitattributes',
		'gitcommit',
		'gitignore',
		'go',
		'gomod',
		'gowork',
		'graphql',
		'html',
		'java',
		'javascript',
		'jsdoc',
		'json',
		'json5',
		'jsonc',
		'kotlin',
		'llvm',
		'lua',
		'luadoc',
		'make',
		'markdown',
		'mermaid',
		'prisma',
		'proto',
		'python',
		'query',
		'regex',
		'ruby',
		'rust',
		'scss',
		'sql',
		'swift',
		'toml',
		'tsx',
		'typescript',
		'vim',
		'vimdoc',
		'yaml'
	},

	-- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)
	auto_install = false,

	highlight = { enable = true },
	indent = { enable = true, disable = { 'python' } },
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = '<c-space>',
			node_incremental = '<c-space>',
			scope_incremental = '<c-s>',
			node_decremental = '<M-space>',
		},
	},
	textobjects = {
		select = {
			enable = true,
			lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
			keymaps = {
				-- You can use the capture groups defined in textobjects.scm
				['aa'] = '@parameter.outer',
				['ia'] = '@parameter.inner',
				['af'] = '@function.outer',
				['if'] = '@function.inner',
				['ac'] = '@class.outer',
				['ic'] = '@class.inner',
			},
		},
		move = {
			enable = true,
			set_jumps = true, -- whether to set jumps in the jumplist
			goto_next_start = {
				[']m'] = '@function.outer',
				[']]'] = '@class.outer',
			},
			goto_next_end = {
				[']M'] = '@function.outer',
				[']['] = '@class.outer',
			},
			goto_previous_start = {
				['[m'] = '@function.outer',
				['[['] = '@class.outer',
			},
			goto_previous_end = {
				['[M'] = '@function.outer',
				['[]'] = '@class.outer',
			},
		},
		swap = {
			enable = true,
			swap_next = {
				['<leader>a'] = '@parameter.inner',
			},
			swap_previous = {
				['<leader>A'] = '@parameter.inner',
			},
		},
	},
	playground = {
		enable = true,
		disable = {},
		updatetime = 25,   -- Debounced time for highlighting nodes in the playground from source code
		persist_queries = false, -- Whether the query persists across vim sessions
		keybindings = {
			toggle_query_editor = 'o',
			toggle_hl_groups = 'i',
			toggle_injected_languages = 't',
			toggle_anonymous_nodes = 'a',
			toggle_language_display = 'I',
			focus_language = 'f',
			unfocus_language = 'F',
			update = 'R',
			goto_node = '<cr>',
			show_help = '?',
		},
	}
})
