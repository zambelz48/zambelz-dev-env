local vim = vim
local Mod = {}

function Mod.nnoremap(lhs, rhs, opts)
    local options = { noremap = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap('n', lhs, rhs, options)
end

function Mod.tnoremap_buf(lhs, rhs, opts)
    local options = { noremap = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_buf_set_keymap(0, 't', lhs, rhs, options)
end

function Mod.shell_cmd(cmd)
    local handle = assert(io.popen(cmd, 'r'))
    local output = assert(handle:read('*a'))
    handle:close()

    return Mod.trim(output)
end

function Mod.create_keymap(bufnr, ...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
end

function Mod.lsp_shared_keymaps(bufnr)
    local opts = { noremap = true, silent = true }

    Mod.create_keymap(bufnr, 'n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>',
        opts)
    Mod.create_keymap(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>',
        opts)
    Mod.create_keymap(bufnr, 'n', 'H', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', 'gi',
        '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<C-k>',
        '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>wa',
        '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>wr',
        '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>wl',
        '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>',
        opts)
    Mod.create_keymap(bufnr, 'n', '<leader>D',
        '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>rn',
        '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>',
        opts)
    Mod.create_keymap(bufnr, 'n', '<leader>ca',
        '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>f',
        '<cmd>lua vim.lsp.buf.format { async = true }<CR>', opts)
    Mod.create_keymap(bufnr, 'v', '<leader>ca',
        '<cmd>lua vim.lsp.buf.range_code_action()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>d',
        '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '[d',
        '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', ']d',
        '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>q',
        '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
    Mod.create_keymap(bufnr, 'n', '<leader>so',
        [[<cmd>lua require('telescope.builtin').lsp_document_symbols()<CR>]],
        opts)
end

function Mod.coding_assistant()
    local assistant = os.getenv('CODING_ASSISTANT')
    if assistant == nil then
        return 'copilot'
    end

    return assistant
end

-- Cache frequent operations
Mod.cache = setmetatable({}, {
    __index = function(t, k)
        return rawget(t, k)
    end
})

-- Memoized function for expensive operations
function Mod.memoize(func)
    local cache = {}
    return function(...)
        local args = { ... }
        local key = table.concat(args, ":")
        if cache[key] == nil then
            cache[key] = func(...)
        end
        return cache[key]
    end
end

-- More efficient shell command with timeout
function Mod.shell_cmd_with_timeout(cmd, timeout_ms)
    timeout_ms = timeout_ms or 1000 -- default 1 second timeout

    -- Use pcall to handle potential errors
    local success, result = pcall(function()
        local handle = io.popen(cmd, 'r')
        if not handle then return "" end

        local output = handle:read('*a')
        handle:close()
        return output
    end)

    if not success then
        vim.notify("Shell command failed: " .. cmd, vim.log.levels.ERROR)
        return ""
    end

    return Mod.trim(result)
end

-- Trim whitespace more efficiently
function Mod.trim(s)
    return s:match("^%s*(.-)%s*$")
end

return Mod
