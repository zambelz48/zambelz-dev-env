local nvim_lsp = require 'lspconfig'

return {
    name = 'gopls',
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    single_file_support = true,
    root_dir = nvim_lsp.util.root_pattern('go.work', 'go.mod', '.git'),
    settings = {
        gopls = {
            analyses = {
                unusedparams = true,
            },
            staticcheck = true,
            gofumpt = true
        }
    }
}
