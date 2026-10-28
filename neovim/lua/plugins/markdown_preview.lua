return {
  'iamcco/markdown-preview.nvim',
  commit = 'a923f5f',
  cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
  ft = { 'markdown' },
  build = ':call mkdp#util#install()',
  init = function()
    vim.g.mkdp_theme = 'light'
  end,
}
