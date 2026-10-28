return {
  'zbirenbaum/copilot.lua',
  tag = 'v3.1.10',
  cond = function()
    return require('utils').coding_assistant() == 'copilot'
  end,
  cmd = 'Copilot',
  event = 'InsertEnter',
  opts = {
    panel = {
      auto_refresh = false,
      keymap = {
        jump_prev = '[[',
        jump_next = ']]',
        accept = '<CR>',
        refresh = 'gr',
        open = '<M-CR>'
      },
      layout = {
        position = 'bottom',
        ratio = 0.4
      },
    },
    suggestion = {
      auto_trigger = true,
      debounce = 75,
      keymap = {
        accept = '<C-J>',
        accept_word = false,
        accept_line = false,
        next = '<M-]>',
        prev = '<M-[>',
        dismiss = '<C-]>',
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
      ['.'] = false,
    },
    copilot_node_command = 'node',
    server_opts_overrides = {},
  },
}
