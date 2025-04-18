local nvim_lsp = require 'lspconfig'

return {
    name = 'dockerls',
    cmd = { 'docker-langserver', '--stdio' },
    filetypes = { 'dockerfile' },
    settings = {
        docker = {
            languageserver = {
                formatter = {
                    ignoreMultilineInstructions = true,
                },
            },
        },
    },
    single_file_support = true,
    root_dir = nvim_lsp.util.root_pattern('Dockerfile')
}
