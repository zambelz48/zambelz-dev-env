return {
    name = 'prismals',
    cmd = { 'prisma-language-server', '--stdio' },
    filetypes = { 'prisma' },
    settings = {
        prisma = {
            prismaFmtBinPath = ''
        }
    }
}
