local utils = require('utils')

local is_copilot_enabled = function()
    return utils.coding_assistant() == 'copilot'
end

return {
    'zbirenbaum/copilot.lua',
    commit = '8aebaa3',
    opts = {
        panel = {
            enabled = is_copilot_enabled(),
            auto_refresh = false,
            keymap = {
                jump_prev = "[[",
                jump_next = "]]",
                accept = "<CR>",
                refresh = "gr",
                open = "<M-CR>"
            },
            layout = {
                position = "bottom", -- | top | left | right
                ratio = 0.4
            },
        },
        suggestion = {
            enabled = is_copilot_enabled(),
            auto_trigger = true,
            debounce = 75,
            keymap = {
                accept = "<C-J>",
                accept_word = false,
                accept_line = false,
                next = "<M-]>",
                prev = "<M-[>",
                dismiss = "<C-]>",
            },
        },
        filetypes = {
            yaml = false,
            markdown = false,
            help = false,
            gitcommit = false,
            gitrebase = false,
            hgcommit = false,
            svn = false,
            cvs = false,
            ["."] = false,
        },
        copilot_node_command = 'node', -- Node.js version must be > 18.x
        server_opts_overrides = {},
    },
}
