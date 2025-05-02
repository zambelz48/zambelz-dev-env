local utils = require 'utils'

local function reload_workspace(bufnr)
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'rust_analyzer' }
  for _, client in ipairs(clients) do
    vim.notify 'Reloading Cargo Workspace'
    client.request('rust-analyzer/reloadWorkspace', nil, function(err)
      if err then
        error(tostring(err))
      end
      vim.notify 'Cargo workspace reloaded'
    end, 0)
  end
end

return {
    name = 'rust_analyzer',
    cmd = { 'rust-analyzer' },
    filetypes = { 'rust' },
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_create_user_command(0, 'LspCargoReload', function()
            reload_workspace(0)
        end, { desc = 'Reload current cargo workspace' })

        utils.lsp_shared_keymaps(bufnr)
    end,
}
