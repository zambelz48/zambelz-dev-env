local nvim_tree = require 'nvim-tree'
-- keymap
vim.api.nvim_set_keymap('n', '<leader>e', '<cmd>:NvimTreeToggle<CR>',
    { noremap = true, silent = true })

nvim_tree.setup({
    -- disables netrw completely
    disable_netrw       = true,
    -- hijack netrw window on startup
    hijack_netrw        = true,
    -- opens the tree when changing/opening a new tab if the tree wasn't previously opened
    open_on_tab         = false,
    -- hijack the cursor in the tree to put it at the start of the filename
    hijack_cursor       = false,
    -- updates the root directory of the tree on `DirChanged` (when you run `:cd` usually)
    update_cwd          = false,
    -- show lsp diagnostics in the signcolumn
    diagnostics         = {
        enable = false,
        icons = {
            hint = "",
            info = "",
            warning = "",
            error = "",
        }
    },
    -- update the focused file on `BufEnter`, un-collapses the folders recursively until it finds the file
    update_focused_file = {
        -- enables the feature
        enable      = true,
        -- update the root directory of the tree to the one of the folder containing the file if the file is not under the current root directory
        -- only relevant when `update_focused_file.enable` is true
        update_cwd  = true,
        -- list of buffer names / filetypes that will not update the cwd if the file isn't found under the current root directory
        -- only relevant when `update_focused_file.update_cwd` is true and `update_focused_file.enable` is true
        ignore_list = {}
    },
    -- configuration options for the system open command (`s` in the tree by default)
    system_open         = {
        -- the command to run this, leaving nil should work in most cases
        cmd  = nil,
        -- the command arguments as a list
        args = {}
    },

    view                = {
        -- show current line number
        number = true,
        -- show relative number
        relativenumber = false,
        -- width of the window, can be either a number (columns) or a string in `%`, for left or right side placement
        width = 60,
        -- side of the tree, can be one of 'left' | 'right' | 'top' | 'bottom'
        side = 'left'
    },

    git                 = {
        ignore = false
    },

    filters             = {
        dotfiles = false,
        custom = {}
    },

    actions             = {
        open_file = {
            quit_on_open = true
        }
    },

    -- fix for slow quit: https://github.com/nvim-tree/nvim-tree.lua/issues/2438#issuecomment-1848866750
    filesystem_watchers = {
        enable = true,
        debounce_delay = 50,
        ignore_dirs = {
            'node_modules',
        },
    },

    renderer            = {
        highlight_opened_files = "icon",
        icons = {
            padding = ' ',
            glyphs = {
                default = '',
                symlink = '',
                git = {
                    unstaged = "",
                    staged = "✓",
                    unmerged = "",
                    renamed = "➜",
                    untracked = "★",
                    deleted = "✗",
                    ignored = "◌"
                },
                folder = {
                    arrow_open = "",
                    arrow_closed = "",
                    default = "",
                    open = "",
                    empty = "",
                    empty_open = "",
                    symlink = "",
                    symlink_open = "",
                }
            }
        },
        indent_markers = {
            enable = true
        },
        root_folder_label = false
    }
})

local nvim_tree_api = require 'nvim-tree.api'
local Event = nvim_tree_api.events.Event
nvim_tree_api.events.subscribe(Event.TreeClose, function()
    if require('dap').session() then
        require('dapui').open({ reset = true })
    end
end)
