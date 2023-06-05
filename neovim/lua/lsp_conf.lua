-- list of available lsp: https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md

local nvim_lsp = require 'lspconfig'

-- Enable the following language servers
local servers = {
	{
		name = 'vimls',
		cmd = { 'vim-language-server', '--stdio' },
		filetypes = {
			'vim'
		},
		root_dir = nvim_lsp.util.root_pattern('Package.swift', '.git')
	},
	{
		name = 'bashls',
		cmd = { 'bash-language-server', 'start' },
		filetypes = {
			'sh'
		},
	},
	{
		name = 'clangd',
		cmd = { 'clangd', '--background-index' },
		filetypes = {
			'c',
			'cpp',
			'objc',
			'objcpp',
			'cuda',
			'proto'
		},
	},
	{
		name = 'cmake',
		cmd = { 'cmake-language-server' },
		filetypes = {
			'cmake'
		},
		single_file_support = true,
		init_options = {
			buildDirectory = "build"
		},
		root_dir = nvim_lsp.util.root_pattern('CMakePresets.json', 'CTestConfig.cmake', '.git', 'build', 'cmake')
	},
	{
		name = 'jsonls',
		cmd = { 'vscode-json-language-server', '--stdio' },
		filetypes = {
			'json',
			'jsonc'
		},
	},
	{
		name = 'cssls',
		cmd = { 'vscode-css-language-server', '--stdio' },
		filetypes = {
			'css',
			'scss',
			'less'
		},
	},
	{
		name = 'eslint',
		cmd = { 'vscode-eslint-language-server', '--stdio' },
		filetypes = {
			'javascript',
			'javascriptreact',
			'javascript.jsx',
			'typescript',
			'typescriptreact',
			'typescript.tsx',
			'vue',
			'svelte'
		},
	},
	{
		name = 'html',
		cmd = { 'vscode-html-language-server', '--stdio' },
		filetypes = {
			'html'
		},
	},
	{
		name = 'lua_ls',
		cmd = { 'lua-language-server' },
		filetypes = {
			'lua'
		},
	},
	{
		name = 'pyright',
		cmd = { 'pyright-langserver', '--stdio' },
		filetypes = {
			'python'
		},
	},
	{
		name = 'rust_analyzer',
		cmd = { 'rust-analyzer' },
		filetypes = {
			'rust'
		},
	},
	{
		name = 'solargraph',
		cmd = { 'solargraph', 'stdio' },
		filetypes = {
			'ruby'
		},
	},
	{
		name = 'sourcekit',
		cmd = { 'sourcekit-lsp' },
		filetypes = {
			'swift',
			'objective-c',
			'objective-cpp'
		},
	},
	{
		name = 'tsserver',
		cmd = { 'typescript-language-server', '--stdio' },
		filetypes = {
			'javascript',
			'javascriptreact',
			'javascript.jsx',
			'typescript',
			'typescriptreact',
			'typescript.tsx'
		},
	},
	{
		name = 'yamlls',
		cmd = { 'yaml-language-server', '--stdio' },
		filetypes = {
			'yaml',
			'yaml.docker-compose'
		},
	},
	{
		name = 'kotlin_language_server',
		cmd = { 'kotlin-language-server' },
		filetypes = { 'kotlin' },
		root_dir = nvim_lsp.util.root_pattern('settings.gradle', 'settings.gradle.kts')
	},
	{
		name = 'gradle_ls',
		cmd = { 'gradle-language-server' },
		filetypes = { 'groovy' },
		init_options = {
			settings = {
				graldeWrapperEnabled = true
			}
		},
		root_dir = nvim_lsp.util.root_pattern('settings.gradle', 'settings.gradle.kts')
	},
	{
		name = 'dockerls',
		cmd = { 'docker-langserver', '--stdio' },
		filetypes = { 'dockerfile' },
		single_file_support = true,
		root_dir = nvim_lsp.util.root_pattern('Dockerfile')
	},
	{
		name = 'docker_compose_language_service',
		cmd = { 'docker-compose-langserver', '--stdio' },
		filetypes = { 'yaml' },
		single_file_support = true,
		root_dir = nvim_lsp.util.root_pattern('docker-compose.yaml')
	},
	{
		name = 'marksman',
		cmd = { 'marksman', 'server' },
		filetypes = { 'markdown' },
		single_file_support = true,
		root_dir = nvim_lsp.util.root_pattern('.git', '.marksman.toml')
	}
}

local on_attach = function(_, bufnr)
	local function buf_set_option(...)
		vim.api.nvim_buf_set_option(bufnr, ...)
	end

	local function buf_set_keymap(...)
		vim.api.nvim_buf_set_keymap(bufnr, ...)
	end

	buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

	local opts = { noremap = true, silent = true }

	buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
	buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
	buf_set_keymap('n', 'H', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
	buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
	buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
	buf_set_keymap('n', '<leader>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
	buf_set_keymap('n', '<leader>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
	buf_set_keymap('n', '<leader>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
	buf_set_keymap('n', '<leader>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
	buf_set_keymap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
	buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
	buf_set_keymap('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
	buf_set_keymap('n', '<leader>f', '<cmd>lua vim.lsp.buf.format { async = true }<CR>', opts)
	buf_set_keymap('v', '<leader>ca', '<cmd>lua vim.lsp.buf.range_code_action()<CR>', opts)
	buf_set_keymap('n', '<leader>d', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
	buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
	buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
	buf_set_keymap('n', '<leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
	buf_set_keymap('n', '<leader>so', [[<cmd>lua require('telescope.builtin').lsp_document_symbols()<CR>]], opts)
end

local signs = {
	Error = "",
	Warn = "",
	Hint = "",
	Info = "󰋽"
}
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl,
		{
			text = icon,
			texthl = hl,
			numhl = hl
		}
	)
end

vim.diagnostic.config({
  virtual_text = {
    prefix = '●',
  },
  severity_sort = true,
  float = {
    source = "always",
  },
})

-- nvim-cmp supports additional completion capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

for _, lsp in ipairs(servers) do

	local server_conf = {
		cmd = lsp.cmd,
		filetypes = lsp.filetypes,
		on_attach = on_attach,
		capabilities = capabilities,
	}

	if lsp.single_file_support then
		server_conf = vim.tbl_extend('force', server_conf, { single_file_support = lsp.single_file_support })
	end

	if lsp.root_dir then
		server_conf = vim.tbl_extend('force', server_conf, { root_dir = lsp.root_dir })
	end

	if lsp.init_options then
		server_conf = vim.tbl_extend('force', server_conf, { init_options = lsp.init_options })
	end

	nvim_lsp[lsp.name].setup(server_conf)
end

