return {
  'nvim-tree/nvim-tree.lua',
  tag = 'nvim-tree-v1.18.0',
  lazy = false,
  dependencies = {
    'nvim-tree/nvim-web-devicons'
  },
  keys = {
    {
      '<leader>e',
      '<cmd>NvimTreeToggle<CR>',
      desc = 'Nvim Tree',
    },
  },
  config = function()
    require('nvim-tree').setup({
      disable_netrw = true,
      update_focused_file = {
        enable = true,
        update_root = {
          enable = true,
        },
      },
      view = {
        number = true,
        width = 60,
      },
      filters = {
        git_ignored = false,
      },
      actions = {
        open_file = {
          quit_on_open = true,
        },
      },
      renderer = {
        highlight_opened_files = 'icon',
        root_folder_label = false,
        indent_markers = {
          enable = true,
        },
        icons = {
          glyphs = {
            default = '\u{e612}',
            git = {
              unstaged = '\u{f458}',
              deleted = '\u{2717}',
            },
            folder = {
              symlink_open = '\u{e5fe}',
            },
          },
        },
      },
    })

    local api = require('nvim-tree.api')
    api.events.subscribe(api.events.Event.TreeClose, function()
      if package.loaded['dap'] and require('dap').session() then
        require('dapui').open({ reset = true })
      end
    end)
  end,
}
