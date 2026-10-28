local Mod = {}

function Mod.nnoremap(lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.api.nvim_set_keymap('n', lhs, rhs, options)
end

function Mod.tnoremap_buf(lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.api.nvim_buf_set_keymap(0, 't', lhs, rhs, options)
end

function Mod.coding_assistant()
  local assistant = os.getenv('CODING_ASSISTANT')
  if assistant == nil then
    return 'copilot'
  end

  return assistant
end

-- Repo's neovim/ dir, resolved through the ~/.config/nvim/init.lua symlink.
function Mod.neovim_dir()
  local init = vim.fn.resolve(vim.fn.stdpath('config') .. '/init.lua')
  return vim.fs.dirname(init)
end

return Mod
