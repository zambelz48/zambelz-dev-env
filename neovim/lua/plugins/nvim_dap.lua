local vim = vim

return {
    'mfussenegger/nvim-dap',
    tag = '0.10.0',
    config = function()
        local dap = require('dap')
        local z_dev_env_path = os.getenv('ZAMBELZ_DEV_ENV_PATH')

        -- Signs (TODO: 'vim.fn.sign_define' won't changed the text in neovim 0.12)
        vim.fn.sign_define('DapBreakpoint', { text = '󰻃' })
        vim.fn.sign_define('DapStopped', { text = '󰜴' })

        -- Adapter Configurations

        -- C/C++/Rust
        local codelldb_executable = z_dev_env_path ..
        '/neovim/.dap/vscode-codelldb/extension/adapter/codelldb'
        if vim.fn.executable(codelldb_executable) == 1 then
            dap.adapters.codelldb = {
                type = 'server',
                port = "${port}",
                executable = {
                    command = codelldb_executable,
                    args = { '--port', '${port}' }
                }
            }
        end

        -- Javascript/Typescript
        -- TODO: Still doesn't work in 'Typescript'
        local js_debug_server_file = z_dev_env_path ..
        '/neovim/.dap/vscode-js-debug/src/dapDebugServer.js'
        if vim.fn.filereadable(js_debug_server_file) == 1 then
            dap.adapters['pwa-node'] = {
                type = 'server',
                host = 'localhost',
                port = "${port}",
                executable = {
                    command = 'node',
                    args = { js_debug_server_file, '${port}' }
                }
            }
        end

        -- Go
        if vim.fn.executable('dlv') == 1 then
            dap.adapters.delve = function(callback, config)
                if config.mode == 'remote' and config.request == 'attach' then
                    callback({
                        type = 'server',
                        host = config.host or '127.0.0.1',
                        port = config.port or '38697'
                    })
                else
                    callback({
                        type = 'server',
                        port = '${port}',
                        executable = {
                            command = 'dlv',
                            args = { 'dap', '-l', '127.0.0.1:${port}', '--log', '--log-output=dap' },
                        }
                    })
                end
            end
        end

        -- Dart
        if vim.fn.executable('dart') == 1 then
            dap.adapters.dart = {
                type = 'executable',
                command = 'dart',
                args = { 'debug_adapter' },
            }
        end

        -- Flutter
        if vim.fn.executable('flutter') == 1 then
            dap.adapters.flutter = {
                type = 'executable',
                command = 'flutter',
                args = { 'debug_adapter' },
            }
        end

        -- End of Adapter Configurations

        -- dap mappings
        vim.api.nvim_set_keymap('n', '<F5>',
            [[<cmd>lua require('dap').continue()<CR>]],
            { noremap = true })
        vim.api.nvim_set_keymap('n', '<F10>',
            [[<cmd>lua require('dap').step_over()<CR>]],
            { noremap = true })
        vim.api.nvim_set_keymap('n', '<F11>',
            [[<cmd>lua require('dap').step_into()<CR>]],
            { noremap = true })
        vim.api.nvim_set_keymap('n', '<F12>',
            [[<cmd>lua require('dap').step_out()<CR>]],
            { noremap = true })
        vim.api.nvim_set_keymap('n', '<Leader>b',
            [[<cmd>lua require('dap').toggle_breakpoint()<CR>]],
            { noremap = true })
        vim.api.nvim_set_keymap('n', '<Leader>B',
            [[<cmd>lua require('dap').set_breakpoint()<CR>]], { noremap = true })
        vim.api.nvim_set_keymap('n', '<Leader>lp',
            [[<cmd>lua require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>]],
            { noremap = true })
        vim.api.nvim_set_keymap('n', '<Leader>dr',
            [[<cmd>lua require('dap').repl.open()<CR>]], { noremap = true })
        vim.api.nvim_set_keymap('n', '<Leader>dl',
            [[<cmd>lua require('dap').run_last()<CR>]], { noremap = true })
        vim.api.nvim_set_keymap('n', '<leader><ESC>',
            [[<cmd>lua require('dap').terminate()<CR>]], { noremap = true })
    end,
}
