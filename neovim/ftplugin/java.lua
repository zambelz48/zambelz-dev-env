local utils = require('utils')
local jdtls_path = utils.mise_where('http:jdtls')
if jdtls_path == nil then
  vim.notify_once('jdtls is not installed (zconf apply mise)',
    vim.log.levels.WARN)
  return
end
local launcher_jar = vim.fn.glob(jdtls_path ..
  '/plugins/org.eclipse.equinox.launcher_*.jar')
if launcher_jar == '' then
  vim.notify_once('jdtls not found in ' .. jdtls_path, vim.log.levels.WARN)
  return
end

local function config_dir()
  local uname = vim.uv.os_uname()
  if uname.sysname == 'Darwin' then
    if uname.machine == 'arm64' then
      return 'config_mac_arm'
    end
    return 'config_mac'
  end
  if uname.sysname == 'Linux' then
    return 'config_linux'
  end
  return 'config_win'
end

local jdtls = require('jdtls')
local root_dir = vim.fs.root(0, { 'gradlew', 'mvnw', 'pom.xml', '.git' })
local project = vim.fs.basename(root_dir or vim.fn.getcwd())
local workspace_dir = vim.fn.stdpath('cache') .. '/jdtls/' .. project

jdtls.start_or_attach({
  cmd = {
    'java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Xmx1g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens', 'java.base/java.util=ALL-UNNAMED',
    '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
    '-jar', launcher_jar,
    '-configuration', jdtls_path .. '/' .. config_dir(),
    '-data', workspace_dir,
  },
  root_dir = root_dir,
  capabilities = require('cmp_nvim_lsp').default_capabilities(),
  settings = {
    java = {
      references = {
        includeDecompiledSources = true,
      },
      format = {
        enabled = true,
        settings = {
          url = utils.neovim_dir() .. '/jdtls/eclipse-java-google-style.xml',
          profile = 'GoogleStyle',
        },
      },
      eclipse = {
        downloadSources = true,
      },
      maven = {
        downloadSources = true,
      },
      signatureHelp = { enabled = true },
      contentProvider = { preferred = 'fernflower' },
      completion = {
        favoriteStaticMembers = {
          'org.hamcrest.MatcherAssert.assertThat',
          'org.hamcrest.Matchers.*',
          'org.hamcrest.CoreMatchers.*',
          'org.junit.jupiter.api.Assertions.*',
          'java.util.Objects.requireNonNull',
          'java.util.Objects.requireNonNullElse',
          'org.mockito.Mockito.*',
        },
        filteredTypes = {
          'com.sun.*',
          'io.micrometer.shaded.*',
          'java.awt.*',
          'jdk.*',
          'sun.*',
        },
        importOrder = {
          'java',
          'javax',
          'com',
          'org',
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
          template = '${object.className}{${member.name()}=${member.value}, '
              .. '${otherMembers}}',
        },
        useBlocks = true,
      },
    },
  },
  init_options = {
    extendedClientCapabilities = jdtls.extendedClientCapabilities,
  },
  on_attach = function(_, bufnr)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs,
        { buf = bufnr, silent = true, desc = desc })
    end

    map('n', '<leader>lo', jdtls.organize_imports, 'Organize imports')
    map('n', '<leader>df', jdtls.test_class, 'Test class')
    map('n', '<leader>dn', jdtls.test_nearest_method, 'Test nearest method')
    map('n', '<leader>rv', jdtls.extract_variable_all, 'Extract variable')
    map('v', '<leader>rm',
      [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
      'Extract method')
    map('n', '<leader>rc', jdtls.extract_constant, 'Extract constant')
  end,
}, {
  dap = {
    hotcodereplace = 'auto',
  },
})
