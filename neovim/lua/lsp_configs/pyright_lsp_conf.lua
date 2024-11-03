return {
    name = 'pyright',
    cmd = { 'pyright-langserver', '--stdio' },
    filetypes = { 'python' },
    single_file_support = true,
    settings = {
        python = {
            analysis = {
                autoSearchPaths = true,
                diagnosticMode = "openFilesOnly",
                useLibraryCodeForTypes = true
            }
        }
    }
}
