local float_size = {
  max_width = 120,
  max_height = 80,
}

local function configure_diagnostics()
  local severity = vim.diagnostic.severity
  vim.diagnostic.config({
    virtual_text = {
      prefix = '●',
    },
    severity_sort = true,
    signs = {
      text = {
        [severity.ERROR] = '\u{ea87}',
        [severity.WARN] = '\u{ea6c}',
        [severity.HINT] = '\u{f0eb}',
        [severity.INFO] = '\u{f02fd}',
      },
      numhl = {
        [severity.ERROR] = 'DiagnosticSignError',
        [severity.WARN] = 'DiagnosticSignWarn',
        [severity.HINT] = 'DiagnosticSignHint',
        [severity.INFO] = 'DiagnosticSignInfo',
      },
    },
    float = {
      source = 'if_many',
      max_width = float_size.max_width,
      max_height = float_size.max_height,
    },
  })
end

local function set_keymaps(bufnr)
  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buf = bufnr, silent = true })
  end

  map('n', 'gD', vim.lsp.buf.declaration)
  map('n', 'gd', vim.lsp.buf.definition)
  map('n', 'H', function()
    vim.lsp.buf.hover(float_size)
  end)
  map('n', '<C-k>', function()
    vim.lsp.buf.signature_help(float_size)
  end)
  map('n', '<leader>wa', vim.lsp.buf.add_workspace_folder)
  map('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder)
  map('n', '<leader>wl', function()
    vim.print(vim.lsp.buf.list_workspace_folders())
  end)
  map('n', '<leader>f', function()
    vim.lsp.buf.format({ async = true })
  end)
  map('n', 'gl', vim.diagnostic.open_float)
  map('n', '<leader>q', vim.diagnostic.setloclist)
  map('n', '<leader>so', function()
    require('telescope.builtin').lsp_document_symbols()
  end)
end

-- Every file in after/lsp/ is an enabled server; its contents (often empty)
-- override nvim-lspconfig's lsp/<name>.lua.
local function discover_servers()
  local servers = {}
  local dir = vim.fn.stdpath('config') .. '/after/lsp'
  for name, kind in vim.fs.dir(dir) do
    if kind == 'file' and name:sub(-4) == '.lua' then
      table.insert(servers, name:sub(1, -5))
    end
  end
  return servers
end

return {
  'neovim/nvim-lspconfig',
  tag = 'v2.12.0',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    configure_diagnostics()

    vim.lsp.config('*', {
      capabilities = require('cmp_nvim_lsp').default_capabilities(),
    })

    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('UserLspKeymaps', { clear = true }),
      callback = function(args)
        set_keymaps(args.buf)
      end,
    })

    vim.lsp.enable(discover_servers())
  end,
}
