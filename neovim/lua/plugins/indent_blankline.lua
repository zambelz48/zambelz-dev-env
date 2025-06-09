return {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    tag = 'v3.9.0',
    opts = {
        indent = {
            char = '┊',
            highlight = 'LineNr',
        },
        scope = {
            enabled = true,
            show_start = false,
            show_end = false,
            highlight = 'Keyword',
        },
        exclude = {
            filetypes = {
                'help',
                'dashboard',
                'NvimTree',
                'Trouble',
                'lazy',
                'mason',
                'notify',
            },
        },
    },
}
