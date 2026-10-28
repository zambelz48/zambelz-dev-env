local function builtin()
  return require('telescope.builtin')
end

return {
  'nvim-telescope/telescope.nvim',
  commit = '40aedd8',
  cmd = 'Telescope',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-fzf-native.nvim',
    'nvim-telescope/telescope-ui-select.nvim',
  },
  keys = {
    { '<leader><space>', function() builtin().buffers() end },
    {
      '<leader>sf',
      function() builtin().find_files({ previewer = true }) end,
    },
    {
      '<leader>sF',
      function()
        return ':Telescope find_files search_dirs=' .. vim.uv.cwd()
      end,
      expr = true,
    },
    { '<leader>sh', function() builtin().help_tags() end },
    { '<leader>st', function() builtin().tags() end },
    { '<leader>sd', function() builtin().grep_string() end },
    {
      '<leader>sD',
      function()
        builtin().grep_string({
          search = vim.fn.input('Find word: '),
          only_sort_text = true,
        })
      end,
    },
    { '<leader>sp', function() builtin().live_grep() end },
    {
      '<leader>so',
      function() builtin().tags({ only_current_buffer = true }) end,
    },
    { '<leader>?', function() builtin().oldfiles() end },
    {
      '<leader>/',
      function()
        builtin().current_buffer_fuzzy_find(
          require('telescope.themes').get_dropdown({
            winblend = 10,
            previewer = false,
          })
        )
      end,
      desc = '[/] Fuzzily search in current buffer',
    },
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
  config = function(_, opts)
    local telescope = require('telescope')
    telescope.setup(opts)
    telescope.load_extension('fzf')
    telescope.load_extension('ui-select')
  end,
}
