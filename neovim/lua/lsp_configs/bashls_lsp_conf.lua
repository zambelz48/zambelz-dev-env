return {
    name = 'bashls',
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh', 'zsh' },
    settings = {
        bashIde = {
            globPattern = '*@(.sh|.inc|.bash|.command|.zsh|.zshrc)'
        },
    },
    root_markers = { '.git' },
}
