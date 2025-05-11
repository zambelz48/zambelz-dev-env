local vim = vim
local dap = require 'dap'
local z_dev_env_path = os.getenv('ZAMBELZ_DEV_ENV_PATH')

-- Signs (TODO: 'vim.fn.sign_define' won't changed the text in neovim 0.12)
vim.fn.sign_define('DapBreakpoint', { text = '󰻃' })
vim.fn.sign_define('DapStopped', { text = '󰜴' })

-- Adapter Configurations

-- C/C++/Rust
local codelldb_executable = z_dev_env_path .. '/neovim/.dap/vscode-codelldb/extension/adapter/codelldb'
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
local js_debug_server_file = z_dev_env_path .. '/neovim/.dap/vscode-js-debug/src/dapDebugServer.js'
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

-- nvim-dap-ui setup
local nvim_dap_ui = require 'dapui'
nvim_dap_ui.setup(
    {
        controls = {
            element = "repl",
            enabled = true,
            icons = {
                disconnect = "",
                pause = "",
                play = "",
                run_last = "",
                step_back = "",
                step_into = "",
                step_out = "",
                step_over = "",
                terminate = ""
            }
        },
        element_mappings = {},
        expand_lines = true,
        floating = {
            border = "single",
            mappings = {
                close = { "q", "<Esc>" }
            }
        },
        force_buffers = true,
        icons = {
            collapsed = "",
            current_frame = "",
            expanded = ""
        },
        layouts = { {
            elements = { {
                id = "scopes",
                size = 0.25
            }, {
                id = "breakpoints",
                size = 0.25
            }, {
                id = "stacks",
                size = 0.25
            }, {
                id = "watches",
                size = 0.25
            } },
            position = "left",
            size = 40
        }, {
            elements = { {
                id = "repl",
                size = 0.5
            }, {
                id = "console",
                size = 0.5
            } },
            position = "bottom",
            size = 10
        } },
        mappings = {
            edit = "e",
            expand = { "<CR>", "<2-LeftMouse>" },
            open = "o",
            remove = "d",
            repl = "r",
            toggle = "t"
        },
        render = {
            indent = 1,
            max_value_lines = 100
        }
    }
)

dap.listeners.before.attach.dapui_config = function()
    nvim_dap_ui.open()
end
dap.listeners.before.launch.dapui_config = function()
    nvim_dap_ui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
    nvim_dap_ui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
    nvim_dap_ui.close()
end

-- dap virtual text setup
local nvim_dap_virtual_text = require 'nvim-dap-virtual-text'
nvim_dap_virtual_text.setup({
    enabled = true,                        -- enable this plugin (the default)
    enabled_commands = true,               -- create commands DapVirtualTextEnable, DapVirtualTextDisable, DapVirtualTextToggle, (DapVirtualTextForceRefresh for refreshing when debug adapter did not notify its termination)
    highlight_changed_variables = true,    -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
    highlight_new_as_changed = false,      -- highlight new variables in the same way as changed variables (if highlight_changed_variables)
    show_stop_reason = true,               -- show stop reason when stopped for exceptions
    commented = false,                     -- prefix virtual text with comment string
    only_first_definition = true,          -- only show virtual text at first definition (if there are multiple)
    all_references = false,                -- show virtual text on all all references of the variable (not only definitions)
    clear_on_continue = false,             -- clear virtual text on "continue" (might cause flickering when stepping)

    --- A callback that determines how a variable is displayed or whether it should be omitted
    --- @param variable Variable https://microsoft.github.io/debug-adapter-protocol/specification#Types_Variable
    --- @param buf number
    --- @param stackframe dap.StackFrame https://microsoft.github.io/debug-adapter-protocol/specification#Types_StackFrame
    --- @param node userdata tree-sitter node identified as variable definition of reference (see `:h tsnode`)
    --- @param options nvim_dap_virtual_text_options Current options for nvim-dap-virtual-text
    --- @return string|nil A text how the virtual text should be displayed or nil, if this variable shouldn't be displayed
    display_callback = function(variable, buf, stackframe, node, options)
    -- by default, strip out new line characters
      if options.virt_text_pos == 'inline' then
        return ' = ' .. variable.value:gsub("%s+", " ")
      else
        return variable.name .. ' = ' .. variable.value:gsub("%s+", " ")
      end
    end,

    -- position of virtual text, see `:h nvim_buf_set_extmark()`, default tries to inline the virtual text. Use 'eol' to set to end of line
    virt_text_pos = vim.fn.has 'nvim-0.10' == 1 and 'inline' or 'eol',

    -- experimental features:
    all_frames = false,                    -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
    virt_lines = false,                    -- show virtual lines instead of virtual text (will flicker!)
    virt_text_win_col = nil,               -- position the virtual text at a fixed window column (starting from the first text column)
})

-- dap mappings
vim.api.nvim_set_keymap('n', '<F5>', [[<cmd>lua require('dap').continue()<CR>]],
    { noremap = true })
vim.api.nvim_set_keymap('n', '<F10>', [[<cmd>lua require('dap').step_over()<CR>]],
    { noremap = true })
vim.api.nvim_set_keymap('n', '<F11>', [[<cmd>lua require('dap').step_into()<CR>]],
    { noremap = true })
vim.api.nvim_set_keymap('n', '<F12>', [[<cmd>lua require('dap').step_out()<CR>]],
    { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>b',
    [[<cmd>lua require('dap').toggle_breakpoint()<CR>]], { noremap = true })
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

-- dapui mappings
vim.api.nvim_set_keymap('n', '<leader>dt',
    [[<cmd>lua require('dapui').toggle()<CR>]], { noremap = true })
