return {
    name = 'ansiblels',
    cmd = { 'ansible-language-server', '--stdio' },
    filetypes = { 'yaml.ansible' },
    settings = {
        ansible = {
            ansible = {
                path = 'ansible'
            },
            executionEnvironment = {
                enabled = false
            },
            python = {
                interpreterPath = 'python'
            },
            validation = {
                enabled = true,
                lint = {
                    enabled = true,
                    path = 'ansible-lint'
                }
            }
        }
    },
    root_markers = { 'ansible.cfg', '.ansible-lint' },
}
