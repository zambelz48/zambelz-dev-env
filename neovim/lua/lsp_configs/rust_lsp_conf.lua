local nvim_lsp = require 'lspconfig'

return {
    name = 'rust_analyzer',
    cmd = { 'rust-analyzer' },
    filetypes = { 'rust' },
    root_dir = nvim_lsp.util.root_pattern('Cargo.toml', 'rust-project.json'),
    single_file_support = true,
}
