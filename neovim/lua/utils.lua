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

local mise_paths = {}

-- Install dir of a globally pinned mise tool, or nil when it is missing.
function Mod.mise_where(tool)
  if mise_paths[tool] == nil then
    mise_paths[tool] = false
    local ok, job = pcall(vim.system, { 'mise', 'where', tool },
      { cwd = vim.uv.os_homedir(), text = true })
    if ok then
      local result = job:wait()
      if result.code == 0 then
        mise_paths[tool] = vim.trim(result.stdout)
      end
    end
  end
  return mise_paths[tool] or nil
end

return Mod
