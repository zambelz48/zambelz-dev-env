vim.g.lspTimeoutConfig = {
    stopTimeout = 60000, -- ms, timeout before stopping all LSPs
    startTimeout = 2000, -- ms, timeout before restart
    silent = false,
    filetypes = {
        ignore = {
            -- filetypes to ignore; empty by default
            -- lsp-timeout is disabld completely for these filetypes
            'java',
            'kotlin'
        }
    }
}
