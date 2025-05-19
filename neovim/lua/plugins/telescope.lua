local vim = vim

return {
    'nvim-telescope/telescope.nvim',
    commit = 'b4da76b',
    dependencies = {
        'nvim-lua/plenary.nvim',
    },
    opts = {
        defaults = {
            mappings = {
                i = {
                    ['<C-u>'] = false,
                    ['<C-d>'] = false,
                },
            },
        },
        extensions = {
            fzf = {},
            ['ui-select'] = {},
        },
    },
    config = function()
        local telescope = require('telescope')
        local telescope_builtin = require('telescope.builtin')
        local telescope_themes = require('telescope.themes')

        -- Enable telescope fzf native, if installed
        telescope.load_extension('fzf')
        telescope.load_extension('ui-select')

        -- Get current working directory
        local cwd = vim.uv.cwd()

        -- Keymaps
        vim.keymap.set('n', '<leader><space>',
            [[<cmd>lua require('telescope.builtin').buffers()<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>sf',
            [[<cmd>lua require('telescope.builtin').find_files({previewer = true})<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>sfc',
            ':Telescope find_files search_dirs=' .. cwd,
            { noremap = true })

        vim.keymap.set('n', '<leader>sh',
            [[<cmd>lua require('telescope.builtin').help_tags()<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>st',
            [[<cmd>lua require('telescope.builtin').tags()<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>sd',
            [[<cmd>lua require('telescope.builtin').grep_string()<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>sdi', function()
            telescope_builtin.grep_string({
                search = vim.fn.input('Find word: '),
                only_sort_text = true,
            })
        end, { noremap = true })

        vim.keymap.set('n', '<leader>sp',
            [[<cmd>lua require('telescope.builtin').live_grep()<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>so',
            [[<cmd>lua require('telescope.builtin').tags{ only_current_buffer = true }<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>?',
            [[<cmd>lua require('telescope.builtin').oldfiles()<CR>]],
            { noremap = true, silent = true })

        vim.keymap.set('n', '<leader>/', function()
            -- You can pass additional configuration to telescope to change theme, layout, etc.
            telescope_builtin.current_buffer_fuzzy_find(
                telescope_themes.get_dropdown {
                    winblend = 10,
                    previewer = false,
                }
            )
        end, {
            desc = '[/] Fuzzily search in current buffer'
        })
    end
}
