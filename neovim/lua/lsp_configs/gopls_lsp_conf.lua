return {
    name = 'gopls',
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    settings = {
        gopls = {
            analyses = {
                unusedparams = true,
                ST1000 = false,
            },
            staticcheck = true,
            gofumpt = true
        }
    }
}
