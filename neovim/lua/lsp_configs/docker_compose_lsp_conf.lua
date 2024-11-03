local nvim_lsp = require 'lspconfig'

return {
    name = 'docker_compose_language_service',
    cmd = { 'docker-compose-langserver', '--stdio' },
    filetypes = { 'yaml.docker-compose' },
    single_file_support = true,
    root_dir = nvim_lsp.util.root_pattern('docker-compose.yaml')
}
