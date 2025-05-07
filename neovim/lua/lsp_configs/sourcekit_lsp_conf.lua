return {
    name = 'sourcekit',
    cmd = { 'sourcekit-lsp' },
    filetypes = {
        'swift',
        'objc',
        'objcpp'
    },
    capabilities = {
        textDocument = {
            diagnostic = {
                dynamicRegistration = true,
                relatedDocumentSupport = true
            }
        },
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true
            }
        }
    },
}
