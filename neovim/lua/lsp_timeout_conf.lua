vim.g.lspTimeoutConfig = {
    stopTimeout = 1000 * 60 * 2, -- ms, timeout before stopping all LSPs
    startTimeout = 1000 * 5,     -- ms, timeout before restart
    silent = false,
    filetypes = {
        ignore = {
            -- filetypes to ignore; empty by default
            -- lsp-timeout is disabld completely for these filetypes
        }
    }
}
