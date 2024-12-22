local nvim_lsp = require 'lspconfig'

return {
    name = 'gradle_ls',
    cmd = { 'gradle-language-server' },
    filetypes = { 'groovy' },
    init_options = {
        settings = {
            gradleWrapperEnabled = true
        }
    },
    root_dir = nvim_lsp.util.root_pattern(
        'settings.gradle',
        'settings.gradle.kts',
        'build.gradle',
        'build.gradle.kts'
    )
}
