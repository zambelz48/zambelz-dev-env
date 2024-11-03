local nvim_lsp = require 'lspconfig'

return {
    name = 'terraformls',
    cmd = { 'terraform-ls', 'serve' },
    filetypes = { 'terraform', 'terraform-vars' },
    root_dir = nvim_lsp.util.root_pattern('.terraform', '.git')
}
