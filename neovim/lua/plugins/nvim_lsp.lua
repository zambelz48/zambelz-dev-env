local vim = vim

-- list of available lsp: https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md
-- Load all lsp config from $HOME/.config/nvim/lua/lsp_configs/*.lua
local loaded_lsp_configs = {}
local lsp_configs_dir = os.getenv('HOME') .. '/.config/nvim/lua/lsp_configs'
for _, lsp_config_path in pairs(vim.fn.glob(lsp_configs_dir .. '/*.lua', true, true)) do
    local lsp_spec = dofile(lsp_config_path)
    table.insert(loaded_lsp_configs, lsp_spec)
end

return {
    'neovim/nvim-lspconfig',
    tag = 'v2.2.0',
    config = function()
        local utils = require('utils')

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

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        local has_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
        if has_cmp then
            capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
        end

        for _, config in ipairs(loaded_lsp_configs) do
            vim.lsp.config(config.name, {
                capabilities = capabilities,
                on_attach = function(_, bufnr)
                    utils.lsp_shared_keymaps(bufnr)
                end
            })
            vim.lsp.config(config.name, config)
            vim.lsp.enable(config.name)
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
    end,
}
