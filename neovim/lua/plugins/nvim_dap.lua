local function dap()
  return require('dap')
end

return {
  'mfussenegger/nvim-dap',
  tag = '0.10.0',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'theHamsta/nvim-dap-virtual-text',
  },
  keys = {
    { '<F5>', function() dap().continue() end },
    { '<F10>', function() dap().step_over() end },
    { '<F11>', function() dap().step_into() end },
    { '<F12>', function() dap().step_out() end },
    { '<leader>b', function() dap().toggle_breakpoint() end },
    { '<leader>B', function() dap().set_breakpoint() end },
    {
      '<leader>lp',
      function()
        dap().set_breakpoint(nil, nil, vim.fn.input('Log point message: '))
      end,
    },
    { '<leader>dr', function() dap().repl.open() end },
    { '<leader>dl', function() dap().run_last() end },
    { '<leader><ESC>', function() dap().terminate() end },
  },
  config = function()
    local mise_where = require('utils').mise_where

    vim.fn.sign_define('DapBreakpoint', { text = '\u{f0ec3}' })
    vim.fn.sign_define('DapStopped', { text = '\u{f0734}' })

    -- C/C++/Rust
    local codelldb_executable = (mise_where('github:vadimcn/codelldb') or '')
        .. '/extension/adapter/codelldb'
    if vim.fn.executable(codelldb_executable) == 1 then
      dap().adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = codelldb_executable,
          args = { '--port', '${port}' },
        },
      }
    end

    -- Javascript/Typescript
    -- TODO: Still doesn't work in 'Typescript'
    local js_debug_server_file =
        (mise_where('github:microsoft/vscode-js-debug') or '')
        .. '/src/dapDebugServer.js'
    if vim.fn.filereadable(js_debug_server_file) == 1 then
      dap().adapters['pwa-node'] = {
        type = 'server',
        host = 'localhost',
        port = '${port}',
        executable = {
          command = 'node',
          args = { js_debug_server_file, '${port}' },
        },
      }
    end

    -- Go
    if vim.fn.executable('dlv') == 1 then
      dap().adapters.delve = function(callback, config)
        if config.mode == 'remote' and config.request == 'attach' then
          callback({
            type = 'server',
            host = config.host or '127.0.0.1',
            port = config.port or '38697',
          })
        else
          callback({
            type = 'server',
            port = '${port}',
            executable = {
              command = 'dlv',
              args = { 'dap', '-l', '127.0.0.1:${port}', '--log',
                '--log-output=dap' },
            },
          })
        end
      end
    end

    -- Dart
    if vim.fn.executable('dart') == 1 then
      dap().adapters.dart = {
        type = 'executable',
        command = 'dart',
        args = { 'debug_adapter' },
      }
    end

    -- Flutter
    if vim.fn.executable('flutter') == 1 then
      dap().adapters.flutter = {
        type = 'executable',
        command = 'flutter',
        args = { 'debug_adapter' },
      }
    end
  end,
}
