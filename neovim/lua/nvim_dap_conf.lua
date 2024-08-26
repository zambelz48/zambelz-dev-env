local dap = require 'dap'
local z_dev_env_path = os.getenv('ZAMBELZ_DEV_ENV_PATH')

-- Signs
vim.fn.sign_define('DapBreakpoint', { text = '󰻃' })
vim.fn.sign_define('DapStopped', { text = '󰜴' })

require('dap.ext.vscode').load_launchjs(nil, {
    lldb = { 'c', 'cpp', 'rust' }
})

dap.adapters.lldb = {
    type = 'server',
    port = "${port}",
    executable = {
        command = z_dev_env_path .. '/neovim/.dap/vscode-codelldb/extension/adapter/codelldb',
        args = { "--port", "${port}" }
    }
}

dap.adapters.dart = {
    type = 'executable',
    command = 'dart',
    args = { 'debug_adapter' },
}

dap.adapters.flutter = {
    type = 'executable',
    command = 'flutter',
    args = { 'debug_adapter' },
}

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

-- dap vertual text setup
local nvim_dap_virtual_text = require 'nvim-dap-virtual-text'
nvim_dap_virtual_text.setup()

-- Mappings
-- dap
vim.api.nvim_set_keymap('n', '<F5>', [[<cmd>lua require('dap').continue()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F10>', [[<cmd>lua require('dap').step_over()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F11>', [[<cmd>lua require('dap').step_into()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<F12>', [[<cmd>lua require('dap').step_out()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>b', [[<cmd>lua require('dap').toggle_breakpoint()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>B', [[<cmd>lua require('dap').set_breakpoint()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>lp',
    [[<cmd>lua require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>dr', [[<cmd>lua require('dap').repl.open()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>dl', [[<cmd>lua require('dap').run_last()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<leader><ESC>', [[<cmd>lua require('dap').terminate()<CR>]], { noremap = true })

-- dapui
vim.api.nvim_set_keymap('n', '<leader>dt', [[<cmd>lua require('dapui').toggle()<CR>]], { noremap = true })
