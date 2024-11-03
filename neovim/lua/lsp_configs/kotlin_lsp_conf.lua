local nvim_lsp = require 'lspconfig'

return {
    name = 'kotlin_language_server',
    cmd = { 'kotlin-language-server' },
    filetypes = { 'kotlin' },
    root_dir = nvim_lsp.util.root_pattern('settings.gradle',
        'settings.gradle.kts')
}
