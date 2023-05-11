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
		name = 'java_language_server',
		cmd = { '/Users/nanda/Dev/Projects/java-language-server/scripts/link_mac.sh' },
		filetypes = {
			'java'
		},
	},
	{
		name = 'kotlin_language_server',
		cmd = { 'kotlin-language-server' },
		filetypes = {
			'kotlin'
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
	nvim_lsp[lsp.name].setup {
		cmd = lsp.cmd,
		filetypes = lsp.filetypes,
		on_attach = on_attach,
		capabilities = capabilities,
	}
end
