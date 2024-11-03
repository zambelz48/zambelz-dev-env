return {
    name = 'yamlls',
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = {
        'yaml',
        'yaml.docker-compose'
    },
    settings = {
        redhat = {
            telemetry = {
                enabled = false
            }
        }
    }
}
