return {
    name = 'html',
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
    single_file_support = true,
    init_options = {
        configurationSection = { 'html', 'css', 'javascript' },
        embeddedLanguages = {
            css = true,
            javascript = true
        },
        provideFormatter = true
    }
}
