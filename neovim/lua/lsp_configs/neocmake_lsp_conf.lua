local nvim_lsp = require 'lspconfig'

return {
    name = 'neocmake',
    cmd = { 'neocmakelsp', '--stdio' },
    filetypes = { 'cmake' },
    single_file_support = true,
    root_dir = nvim_lsp.util.root_pattern('.git', 'cmake')
}
