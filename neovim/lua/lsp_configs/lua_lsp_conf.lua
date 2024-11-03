local nvim_lsp = require 'lspconfig'

return {
    name = 'lua_ls',
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    single_file_support = true,
    root_dir = nvim_lsp.util.root_pattern('.luarc.json', '.luarc.jsonc',
        '.luacheckrc', '.stylua.toml', 'stylua.toml',
        'selene.toml', 'selene.yml', '.git')
}
