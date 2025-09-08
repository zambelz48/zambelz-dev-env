local vim = vim

return {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    commit = 'fee71c1',
    lazy = false,
    build = ':TSUpdate',
    config = function()
        require('nvim-treesitter').install({
            'asm',
            'bash',
            'c',
            'c_sharp',
            'cmake',
            'cpp',
            'css',
            'dart',
            'diff',
            'dockerfile',
            'editorconfig',
            'git_rebase',
            'gitcommit',
            'gitignore',
            'go',
            'gomod',
            'gowork',
            'graphql',
            'groovy',
            'hcl',
            'html',
            'http',
            'java',
            'javadoc',
            'javascript',
            'jsdoc',
            'json',
            'json5',
            'jsonc',
            'kotlin',
            'lua',
            'luadoc',
            'make',
            'markdown',
            'markdown_inline',
            'mermaid',
            'ninja',
            'passwd',
            'php',
            'prisma',
            'properties',
            'proto',
            'python',
            'query',
            'regex',
            'robots',
            'ruby',
            'rust',
            'smali',
            'scss',
            'sql',
            'ssh_config',
            'swift',
            'terraform',
            'tmux',
            'toml',
            'tsx',
            'typescript',
            'vim',
            'vimdoc',
            'vue',
            'xml',
            'yaml',
        })

        -- To make new nvim-treesitter (from 'main' branch) works
        vim.api.nvim_create_autocmd("FileType", {
            callback = function(details)
                local bufnr = details.buf

                -- try to start treesitter which enables syntax highlighting
                if not pcall(vim.treesitter.start, bufnr) then
                    -- Exit if treesitter was unable to start
                    return
                end

                -- Use regex based syntax-highlighting as fallback as some plugins might need it
                vim.bo[bufnr].syntax = "on"

                vim.wo.foldlevel = 99
                vim.wo.foldmethod = "expr"
                -- Use treesitter for folds
                vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"

                -- Use treesitter for indentation
                vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end,
        })
    end
}
