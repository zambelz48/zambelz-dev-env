local nvim_lsp = require 'lspconfig'

return {
    name = 'graphql',
    cmd = { 'graphql-lsp', 'server', '-m', 'stream' },
    filtypes = { 'graphql', 'typescriptreact', 'javascriptreact' },
    root_dir = nvim_lsp.util.root_pattern('.git', '.graphqlrc*',
        '.graphql.config.*', 'graphql.config.*')
}
