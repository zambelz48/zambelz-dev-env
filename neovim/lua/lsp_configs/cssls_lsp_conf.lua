local nvim_lsp = require 'lspconfig'

return {
    name = 'cssls',
    cmd = { 'vscode-css-language-server', '--stdio' },
    filetypes = {
        'css',
        'scss',
        'less'
    },
    single_file_support = true,
    settings = {
        css = {
            validate = true
        },
        less = {
            validate = true
        },
        scss = {
            validate = true
        }
    },
    root_dir = nvim_lsp.util.root_pattern('package.json', '.git')
}
