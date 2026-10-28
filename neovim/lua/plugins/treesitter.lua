return {
  'nvim-treesitter/nvim-treesitter',
  commit = '728e031',
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
      'jinja',
      'jsdoc',
      'json',
      'json5',
      'jsx',
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
      'ruby',
      'rust',
      'smali',
      'scss',
      'sql',
      'ssh_config',
      'swift',
      'terraform',
      'toml',
      'tsx',
      'typescript',
      'vim',
      'vimdoc',
      'vue',
      'xml',
      'yaml',
      'zsh',
    })

    -- nvim-treesitter's main branch enables nothing by itself.
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('UserTreesitter', { clear = true }),
      callback = function(details)
        local bufnr = details.buf
        if not pcall(vim.treesitter.start, bufnr) then
          return
        end

        vim.wo[0][0].foldlevel = 99
        vim.wo[0][0].foldmethod = 'expr'
        vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.bo[bufnr].indentexpr =
        "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end
}
