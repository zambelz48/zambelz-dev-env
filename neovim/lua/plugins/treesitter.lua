return {
  'nvim-treesitter/nvim-treesitter',
  commit = '19bdfc0',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').install(require('treesitter_parsers'))

    -- nvim-treesitter's main branch enables nothing by itself.
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('UserTreesitter', { clear = true }),
      callback = function(details)
        local bufnr = details.buf
        if not pcall(vim.treesitter.start, bufnr) then
          return
        end

        vim.wo[0][0].foldlevel = 99
        vim.wo[0][0].foldmethod = 'expr'
        vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.bo[bufnr].indentexpr =
        "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end
}
