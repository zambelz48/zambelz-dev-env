local nvim_lsp = require 'lspconfig'
local utils = require 'utils'

-- list of available lsp: https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md
local servers = {
    require 'lsp_configs/ansiblels_lsp_conf',
    require 'lsp_configs/bashls_lsp_conf',
    require 'lsp_configs/clangd_lsp_conf',
    require 'lsp_configs/cssls_lsp_conf',
    require 'lsp_configs/dartls_lsp_conf',
    require 'lsp_configs/docker_compose_lsp_conf',
    require 'lsp_configs/dockerls_lsp_conf',
    require 'lsp_configs/eslint_lsp_conf',
    require 'lsp_configs/gopls_lsp_conf',
    require 'lsp_configs/gradlels_lsp_conf',
    require 'lsp_configs/graphql_lsp_conf',
    require 'lsp_configs/html_lsp_conf',
    require 'lsp_configs/jsonls_lsp_conf',
    require 'lsp_configs/kotlin_lsp_conf',
    require 'lsp_configs/lemminx_lsp_conf',
    require 'lsp_configs/lua_lsp_conf',
    require 'lsp_configs/marksman_lsp_conf',
    require 'lsp_configs/neocmake_lsp_conf',
    require 'lsp_configs/prismals_lsp_conf',
    require 'lsp_configs/pyright_lsp_conf',
    require 'lsp_configs/rust_lsp_conf',
    require 'lsp_configs/solargraph_lsp_conf',
    require 'lsp_configs/sourcekit_lsp_conf',
    require 'lsp_configs/tailwind_lsp_conf',
    require 'lsp_configs/terraformls_lsp_conf',
    require 'lsp_configs/vimls_lsp_conf',
    require 'lsp_configs/vls_lsp_conf',
    require 'lsp_configs/yamlls_lsp_conf',
}

local on_attach = function(_, bufnr)
    utils.lsp_shared_keymaps(bufnr)
end

local signs = {
    Error = '',
    Warn = '',
    Hint = '',
    Info = '󰋽'
}
for type, icon in pairs(signs) do
    local hl = 'DiagnosticSign' .. type
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
        source = 'always',
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
        server_conf = vim.tbl_extend('force', server_conf,
            { single_file_support = lsp.single_file_support })
    end

    if lsp.root_dir then
        server_conf = vim.tbl_extend('force', server_conf,
            { root_dir = lsp.root_dir })
    end

    if lsp.init_options then
        server_conf = vim.tbl_extend('force', server_conf,
            { init_options = lsp.init_options })
    end

    if lsp.settings then
        server_conf = vim.tbl_extend('force', server_conf,
            { settings = lsp.settings })
    end

    nvim_lsp[lsp.name].setup(server_conf)
end

local lsp_border_style = 'rounded'
local lsp_hover_style = {
    border = lsp_border_style,
    max_width = 120,
    max_height = 80
}

vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
    vim.lsp.handlers.hover, lsp_hover_style
)

vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
    vim.lsp.handlers.signature_help, lsp_hover_style
)

vim.diagnostic.config {
    float = lsp_hover_style
}

require('lspconfig.ui.windows').default_options = {
    border = lsp_border_style
}
