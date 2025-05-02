return {
    name = 'gradle_ls',
    cmd = { 'gradle-language-server' },
    filetypes = { 'groovy' },
    init_options = {
        settings = {
            gradleWrapperEnabled = true
        }
    },
}
