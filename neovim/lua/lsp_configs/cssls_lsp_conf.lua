return {
    name = 'cssls',
    cmd = { 'vscode-css-language-server', '--stdio' },
    filetypes = {
        'css',
        'scss',
        'less'
    },
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
    init_options =   {
        provideFormatter = true
    },
}
