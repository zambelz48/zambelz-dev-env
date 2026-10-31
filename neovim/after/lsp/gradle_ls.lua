local server = require('utils').neovim_dir()
    .. '/.lsp_vendors/vscode-gradle/gradle-language-server/build/install'
    .. '/gradle-language-server/bin/gradle-language-server'

return {
  cmd = { server },
}
