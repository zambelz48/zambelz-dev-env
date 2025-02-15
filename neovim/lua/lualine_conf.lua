local lualine = require 'lualine'

local copilot_status_line = function()
    local coding_assistant = os.getenv('CODING_ASSISTANT')
    if coding_assistant == 'copilot' then
        return {
            'copilot',
            symbols = {
                status = {
                    icons = {
                        enabled = " ",
                        sleep = " ", -- auto-trigger disabled
                        disabled = " ",
                        warning = " ",
                        unknown = " "
                    },
                    hl = {
                        enabled = "#50FA7B",
                        sleep = "#c1f7cf",
                        disabled = "#6272A4",
                        warning = "#FFB86C",
                        unknown = "#FF5555"
                    }
                },
                spinners = require("copilot-lualine.spinners").dots,
                spinner_color = "#bd93f9"
            },
            show_colors = true,
            show_loading = true
        }
    else
        return {}
    end
end

local lualine_x_content = function()
    local initial_content = {}
    local coding_assistant = os.getenv('CODING_ASSISTANT')
    if coding_assistant == 'copilot' then
        table.insert(initial_content, copilot_status_line())
    end

    table.insert(initial_content, 'encoding')
    table.insert(initial_content, 'filetype')
    return initial_content
end

lualine.setup({
    options = {
        icons_enabled = true,
        theme = 'dracula-nvim',

        -- This causing neovim intro message disappear
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },

        disabled_filetypes = {
            statusline = {},
            winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        globalstatus = false,
        refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
        }
    },
    sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = lualine_x_content(),
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {}
    },
    tabline = {},
    winbar = {},
    inactive_winbar = {},
    extensions = {}
})
