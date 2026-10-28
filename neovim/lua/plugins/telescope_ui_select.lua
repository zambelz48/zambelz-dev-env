return {
  'nvim-telescope/telescope-ui-select.nvim',
  commit = '6e51d7d',
  lazy = true,
  init = function()
    -- Telescope is lazy; load it on the first vim.ui.select() so the
    -- extension can take over (e.g. LSP code actions).
    local default_select = vim.ui.select
    local function lazy_select(...)
      require('lazy').load({ plugins = { 'telescope.nvim' } })
      if vim.ui.select == lazy_select then
        vim.ui.select = default_select
      end
      return vim.ui.select(...)
    end
    vim.ui.select = lazy_select
  end,
}
