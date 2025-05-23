return {
    name = 'vls',
    cmd = { 'vls' },
    filetypes = { 'vue' },
    init_options = {
        config = {
            css = {},
            emmet = {},
            html = {
                suggest = {}
            },
            javascript = {
                format = {}
            },
            stylusSupremacy = {},
            typescript = {
                format = {}
            },
            vetur = {
                completion = {
                    autoImport = false,
                    tagCasing = "kebab",
                    useScaffoldSnippets = false
                },
                format = {
                    defaultFormatter = {
                        js = "none",
                        ts = "none"
                    },
                    defaultFormatterOptions = {},
                    scriptInitialIndent = false,
                    styleInitialIndent = false
                },
                useWorkspaceDependencies = false,
                validation = {
                    script = true,
                    style = true,
                    template = true
                }
            }
        }
    },
}
