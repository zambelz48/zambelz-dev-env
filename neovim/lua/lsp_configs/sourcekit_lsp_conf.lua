local nvim_lsp = require 'lspconfig'

return {
    name = 'sourcekit',
    cmd = { 'sourcekit-lsp' },
    filetypes = {
        'swift',
        'objc',
        'objcpp'
    },
    root_dir = function(filename, _)
        return nvim_lsp.util.root_pattern 'buildServer.json' (filename)
            or nvim_lsp.util.root_pattern('*.xcodeproj', '*.xcworkspace')(
            filename)
            -- better to keep it at the end, because some modularized apps contain multiple Package.swift files
            or nvim_lsp.util.root_pattern('compile_commands.json',
                'Package.swift')(filename)
            or vim.fs.dirname(vim.fs.find('.git',
                { path = filename, upward = true })[1])
    end,
    get_language_id = function(_, ftype)
        local t = { objc = 'objective-c', objcpp = 'objective-cpp' }
        return t[ftype] or ftype
    end,
}
