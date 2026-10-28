return {
  'lukas-reineke/indent-blankline.nvim',
  main = 'ibl',
  tag = 'v3.10.1',
  event = { 'BufReadPost', 'BufNewFile' },
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
        'NvimTree',
        'lazy',
      },
    },
  },
}
