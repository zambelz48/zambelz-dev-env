return {
    name = 'dockerls',
    cmd = { 'docker-langserver', '--stdio' },
    filetypes = { 'dockerfile' },
    settings = {
        docker = {
            languageserver = {
                formatter = {
                    ignoreMultilineInstructions = true,
                },
            },
        },
    },
}
