return {
    name = 'clangd',
    cmd = { 'clangd', '--background-index' },
    filetypes = {
        'c',
        'cpp',
        'cuda',
        'proto'
    },
}
