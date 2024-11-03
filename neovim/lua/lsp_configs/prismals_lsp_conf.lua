local nvim_lsp = require 'lspconfig'

return {
    name = 'prismals',
    cmd = { 'prisma-language-server', '--stdio' },
    filetypes = { 'prisma' },
    root_dir = nvim_lsp.util.root_pattern('.git', 'package.json'),
    settings = {
        prisma = {
            prismaFmtBinPath = ''
        }
    }
}
