local nvim_lsp = require 'lspconfig'
local utils = require 'utils'

local z_dev_env_path = os.getenv('ZAMBELZ_DEV_ENV_PATH')
local omnisharp_dll_path = z_dev_env_path .. '/neovim/.lsp_vendors/omnisharp/OmniSharp.dll'

nvim_lsp.omnisharp.setup({
    cmd = { "dotnet", omnisharp_dll_path },
    filetypes = { "cs" },
    root_dir = nvim_lsp.util.root_pattern('*.sln', '*.csproj', 'omnisharp.json', "function.json"),
    settings = {
        FormattingOptions = {
            -- Enables support for reading code style, naming convention and analyzer
            -- settings from .editorconfig.
            EnableEditorConfigSupport = true,
            -- Specifies whether 'using' directives should be grouped and sorted during
            -- document formatting.
            OrganizeImports = nil,
        },
        MsBuild = {
            -- If true, MSBuild project system will only load projects for files that
            -- were opened in the editor. This setting is useful for big C# codebases
            -- and allows for faster initialization of code navigation features only
            -- for projects that are relevant to code that is being edited. With this
            -- setting enabled OmniSharp may load fewer projects and may thus display
            -- incomplete reference lists for symbols.
            LoadProjectsOnDemand = nil,
        },
        RoslynExtensionsOptions = {
            -- Enables support for roslyn analyzers, code fixes and rulesets.
            EnableAnalyzersSupport = nil,
            -- Enables support for showing unimported types and unimported extension
            -- methods in completion lists. When committed, the appropriate using
            -- directive will be added at the top of the current file. This option can
            -- have a negative impact on initial completion responsiveness,
            -- particularly for the first few completion sessions after opening a
            -- solution.
            EnableImportCompletion = nil,
            -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
            -- true
            AnalyzeOpenDocumentsOnly = nil,
        },
        Sdk = {
            -- Specifies whether to include preview versions of the .NET SDK when
            -- determining which version to use for project loading.
            IncludePrereleases = true,
        },
    },
    on_attach = function(_, bufnr)
        utils.set_omnifunc_option(bufnr)

        local opts = { noremap = true, silent = true }

        utils.create_keymap(bufnr, 'n', 'H', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
        utils.create_keymap(bufnr, 'n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)

        utils.create_keymap(bufnr, 'n', 'gd', '<cmd>lua require("omnisharp_extended").lsp_definition()<CR>', opts)
        utils.create_keymap(bufnr, 'n', '<leader>D', '<cmd>lua require("omnisharp_extended").lsp_type_definition()<CR>',
            opts)
        utils.create_keymap(bufnr, 'n', 'gr', '<cmd>lua require("omnisharp_extended").lsp_references()<CR>', opts)
        utils.create_keymap(bufnr, 'n', 'gi', '<cmd>lua require("omnisharp_extended").lsp_implementation()<CR>', opts)
    end
})
