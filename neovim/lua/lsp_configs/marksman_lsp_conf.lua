local nvim_lsp = require 'lspconfig'

return {
    name = 'marksman',
    cmd = { 'marksman', 'server' },
    filetypes = { 'markdown' },
    single_file_support = true,
    root_dir = nvim_lsp.util.root_pattern('.git', '.marksman.toml')
}
