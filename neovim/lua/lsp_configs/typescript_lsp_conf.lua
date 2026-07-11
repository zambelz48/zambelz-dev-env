return {
  name = 'tsgo',
  cmd = { 'tsc', '--lsp', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  {
    typescript = {
      inlayHints = {
        enumMemberValues = {
          enabled = true
        },
        functionLikeReturnTypes = {
          enabled = true
        },
        parameterNames = {
          enabled = "literals",
          suppressWhenArgumentMatchesName = true
        },
        parameterTypes = {
          enabled = true
        },
        propertyDeclarationTypes = {
          enabled = true
        },
        variableTypes = {
          enabled = true
        }
      }
    }
  }
}
