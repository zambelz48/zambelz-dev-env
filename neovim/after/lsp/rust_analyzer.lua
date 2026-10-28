return {
  settings = {
    ['rust-analyzer'] = {
      checkOnSave = true,
      cargo = {
        allFeatures = true,
      },
      procMacro = {
        enable = true,
      },
      imports = {
        granularity = {
          group = 'module',
        },
        prefix = 'self',
      },
      inlayHints = {
        lifetimeElisionHints = {
          enable = true,
          useParameterNames = true,
        },
      },
    },
  },
}
