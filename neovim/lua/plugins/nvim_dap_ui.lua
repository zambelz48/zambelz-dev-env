local vim = vim

return {
    'rcarriga/nvim-dap-ui',
    commit = 'cf91d5e',
    dependencies = {
        'mfussenegger/nvim-dap',
        'nvim-neotest/nvim-nio',
    },
    config = function()
        local dap = require('dap')
        local nvim_dap_ui = require('dapui')

        nvim_dap_ui.setup({
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
        })

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

        -- dapui mappings
        vim.api.nvim_set_keymap('n', '<leader>dt',
            [[<cmd>lua require('dapui').toggle()<CR>]], { noremap = true })

        -- reset dapui sizes on nvim-tree close
        local nvim_tree_api = require("nvim-tree.api")
        local Event = nvim_tree_api.events.Event
        nvim_tree_api.events.subscribe(Event.TreeClose, function()
            if require("dap").session() then
                require("dapui").open({ reset = true })
            end
        end)
    end
}
