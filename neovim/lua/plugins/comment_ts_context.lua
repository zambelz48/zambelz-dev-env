return {
  'JoosepAlviste/nvim-ts-context-commentstring',
  commit = '6141a40',
  lazy = true,
  opts = {
    enable_autocmd = false,
  },
  init = function()
    -- Native `gc` asks for 'commentstring' here; resolve it from the
    -- treesitter context (plugin wiki: native commenting in Neovim 0.10).
    local get_option = vim.filetype.get_option
    vim.filetype.get_option = function(filetype, option)
      if option == 'commentstring' then
        local commentstring = require('ts_context_commentstring.internal')
            .calculate_commentstring()
        if commentstring then
          return commentstring
        end
      end
      return get_option(filetype, option)
    end
  end,
}
