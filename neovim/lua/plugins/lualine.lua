local utils = require('utils')

local lualine_x_content = function()
  local content = {}
  local coding_assistant = utils.coding_assistant()
  if coding_assistant == 'copilot' then
    local copilot_status_line = function()
      return {
        'copilot',
        symbols = {
          status = {
            icons = {
              enabled = '\u{f4b8} ',
              sleep = '\u{f4b8} ', -- auto-trigger disabled
              disabled = '\u{f4b9} ',
              warning = '\u{f4ba} ',
              unknown = '\u{f05e} '
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
        show_loading = true,
        -- Rendering requires copilot modules; don't force-load lazy copilot.
        cond = function()
          return package.loaded['copilot'] ~= nil
        end,
      }
    end
    table.insert(content, copilot_status_line())
  end

  table.insert(content, 'encoding')
  table.insert(content, 'filetype')
  return content
end

local function theme()
  local dracula_theme = vim.deepcopy(require('lualine.themes.dracula-nvim'))
  local colors = require('dracula').colors()
  local modes = { 'normal', 'insert', 'visual', 'replace', 'command' }
  for _, mode in ipairs(modes) do
    dracula_theme[mode].b.bg = colors.comment
    dracula_theme[mode].b.fg = colors.fg
  end
  return dracula_theme
end

return {
  'nvim-lualine/lualine.nvim',
  commit = '221ce6b',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    local lualine = require('lualine')
    lualine.setup({
      options = {
        icons_enabled = true,
        theme = theme(),

        -- Flat blocks, matching the dracula/tmux status bar.
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },

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
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = lualine_x_content(),
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {}
      },
      tabline = {},
      winbar = {},
      inactive_winbar = {},
      extensions = {}
    })
  end
}
