return {
  'folke/todo-comments.nvim',
  tag = 'v1.5.0',
  event = { 'BufReadPost', 'BufNewFile' },
  cmd = { 'TodoQuickFix', 'TodoLocList', 'TodoTelescope' },
  opts = {},
}
