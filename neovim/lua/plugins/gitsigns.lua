return {
  'lewis6991/gitsigns.nvim',
  tag = 'v2.1.0',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    signs = {
      add = { text = '\u{2502}' },
      change = { text = '\u{2502}' },
      delete = { text = '_' },
      topdelete = { text = '\u{203e}' },
    },
    current_line_blame_formatter =
    '<author>, <author_time:%Y-%m-%d> - <summary>',
    preview_config = {
      border = 'single',
    },
    on_attach = function(bufnr)
      local gitsigns = require('gitsigns')

      local function map(mode, lhs, rhs, opts)
        opts = opts or {}
        opts.buf = bufnr
        vim.keymap.set(mode, lhs, rhs, opts)
      end

      -- Navigation
      map('n', ']c', function()
        if vim.wo.diff then
          return ']c'
        end
        vim.schedule(function() gitsigns.nav_hunk('next') end)
        return '<Ignore>'
      end, { expr = true })

      map('n', '[c', function()
        if vim.wo.diff then
          return '[c'
        end
        vim.schedule(function() gitsigns.nav_hunk('prev') end)
        return '<Ignore>'
      end, { expr = true })

      -- Actions
      map('n', '<leader>hs', gitsigns.stage_hunk)
      map('n', '<leader>hr', gitsigns.reset_hunk)
      map('v', '<leader>hs', function()
        gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
      end)
      map('v', '<leader>hr', function()
        gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
      end)
      map('n', '<leader>hS', gitsigns.stage_buffer)
      map('n', '<leader>hR', gitsigns.reset_buffer)
      map('n', '<leader>hp', gitsigns.preview_hunk)
      map('n', '<leader>hb', function()
        gitsigns.blame_line({ full = true })
      end)
      map('n', '<leader>tb', gitsigns.toggle_current_line_blame)
      map('n', '<leader>hd', gitsigns.diffthis)
      map('n', '<leader>hD', function() gitsigns.diffthis('~') end)
      map('n', '<leader>td', gitsigns.preview_hunk_inline)

      -- Text object
      map({ 'o', 'x' }, 'ih', gitsigns.select_hunk)
    end,
  },
}
