local vim = vim

return {
    'mfussenegger/nvim-jdtls',
    commit = 'c23f200',
    ft = { 'java' },
    lazy = true,
    config = function()
        local jdtls = require('jdtls')
        local cmp_nvim_lsp = require('cmp_nvim_lsp')
        local utils = require('utils')

        local function get_config_path()
            local kernel_name = utils.shell_cmd('uname -s')
            local kernel_arch = utils.shell_cmd('uname -m')

            if kernel_name == 'Darwin' then
                if kernel_arch == 'arm64' then
                    return 'config_mac_arm'
                end
                return 'config_mac'
            end

            if kernel_name == 'Linux' then
                return 'config_linux'
            end

            return 'config_win'
        end

        local z_dev_env_path = os.getenv('ZAMBELZ_DEV_ENV_PATH')
        local jdtls_path = z_dev_env_path .. '/neovim/.lsp_vendors/jdtls'
        local launcher_jar = vim.fn.glob(jdtls_path ..
            '/plugins/org.eclipse.equinox.launcher_*.jar')
        local config_path = jdtls_path .. '/' .. get_config_path()

        local project_root_dir_markers = { 'gradlew', '.git' }
        local project_root_dir = require('jdtls.setup').find_root(
            project_root_dir_markers)
        local workspace_dir = jdtls_path ..
            '/project_data/' .. vim.fn.fnamemodify(project_root_dir, ':p:h:t')

        local client_capabilities = vim.lsp.protocol.make_client_capabilities()
        local capabilities = cmp_nvim_lsp.default_capabilities(
            client_capabilities
        )

        local config = {
            capabilities = capabilities,

            -- The command that starts the language server
            -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
            cmd = {

                -- 💀
                'java', -- or '/path/to/java17_or_newer/bin/java'
                -- depends on if `java` is in your $PATH env variable and if it points to the right version.

                '-Declipse.application=org.eclipse.jdt.ls.core.id1',
                '-Dosgi.bundles.defaultStartLevel=4',
                '-Declipse.product=org.eclipse.jdt.ls.core.product',
                '-Dlog.protocol=true',
                '-Dlog.level=ALL',
                '-Xmx1g',
                '--add-modules=ALL-SYSTEM',
                '--add-opens', 'java.base/java.util=ALL-UNNAMED',
                '--add-opens', 'java.base/java.lang=ALL-UNNAMED',

                -- 💀
                '-jar', launcher_jar,
                -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
                -- Must point to the                                                     Change this to
                -- eclipse.jdt.ls installation                                           the actual version


                -- 💀
                '-configuration', config_path,
                -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^^^
                -- Must point to the                      Change to one of `linux`, `win` or `mac`
                -- eclipse.jdt.ls installation            Depending on your system.


                -- 💀
                -- See `data directory configuration` section in the README
                '-data', workspace_dir
            },

            -- 💀
            -- This is the default if not provided, you can remove it. Or adjust as needed.
            -- One dedicated LSP server & client will be started per unique root_dir
            root_dir = require('jdtls.setup').find_root({ '.git', 'mvnw',
                'gradlew',
                'pom.xml' }),

            -- Here you can configure eclipse.jdt.ls specific settings
            -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
            -- for a list of options
            settings = {
                java = {
                    references = {
                        includeDecompiledSources = true,
                    },
                    format = {
                        enabled = true,
                        settings = {
                            url = jdtls_path ..
                                "/config/intellij-java-google-style.xml",
                            profile = "GoogleStyle",
                        },
                    },
                    eclipse = {
                        downloadSources = true,
                    },
                    maven = {
                        downloadSources = true,
                    },
                    signatureHelp = { enabled = true },
                    contentProvider = { preferred = "fernflower" },
                    completion = {
                        favoriteStaticMembers = {
                            "org.hamcrest.MatcherAssert.assertThat",
                            "org.hamcrest.Matchers.*",
                            "org.hamcrest.CoreMatchers.*",
                            "org.junit.jupiter.api.Assertions.*",
                            "java.util.Objects.requireNonNull",
                            "java.util.Objects.requireNonNullElse",
                            "org.mockito.Mockito.*",
                        },
                        filteredTypes = {
                            "com.sun.*",
                            "io.micrometer.shaded.*",
                            "java.awt.*",
                            "jdk.*",
                            "sun.*",
                        },
                        importOrder = {
                            "java",
                            "javax",
                            "com",
                            "org",
                        },
                    },
                    sources = {
                        organizeImports = {
                            starThreshold = 9999,
                            staticStarThreshold = 9999,
                        },
                    },
                    codeGeneration = {
                        toString = {
                            template =
                            "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                        },
                        useBlocks = true,
                    },
                }
            },

            -- Language server `initializationOptions`
            -- You need to extend the `bundles` with paths to jar files
            -- if you want to use additional eclipse.jdt.ls plugins.
            --
            -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
            --
            -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
            init_options = {
                -- https://github.com/eclipse/eclipse.jdt.ls/wiki/Language-Server-Settings-&-Capabilities#extended-client-capabilities
                extendedClientCapabilities = jdtls.extendedClientCapabilities,
            },

            on_attach = function(_, bufnr)
                utils.lsp_shared_keymaps(bufnr)

                jdtls.setup_dap({
                    hotcodereplace = 'auto'
                })
                jdtls.setup.add_commands()

                -- https://github.com/mfussenegger/dotfiles/blob/833d634251ebf3bf7e9899ed06ac710735d392da/vim/.config/nvim/ftplugin/java.lua#L88-L94
                local opts = { silent = true, buffer = bufnr }
                vim.keymap.set('n', "<leader>lo", jdtls.organize_imports,
                    { desc = 'Organize imports', buffer = bufnr })
                -- Should 'd' be reserved for debug?
                vim.keymap.set('n', "<leader>df", jdtls.test_class, opts)
                vim.keymap.set('n', "<leader>dn", jdtls.test_nearest_method, opts)
                vim.keymap.set('n', '<leader>rv', jdtls.extract_variable_all,
                    { desc = 'Extract variable', buffer = bufnr })
                vim.keymap.set('v', '<leader>rm',
                    [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
                    { desc = 'Extract method', buffer = bufnr })
                vim.keymap.set('n', '<leader>rc', jdtls.extract_constant,
                    { desc = 'Extract constant', buffer = bufnr })
            end
        }

        jdtls.start_or_attach(config)
    end
}
