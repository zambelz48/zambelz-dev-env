return {
    'norcalli/nvim-colorizer.lua',
    commit = 'a065833',
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "ColorizerToggle", "ColorizerAttachToBuffer", "ColorizerDetachFromBuffer", "ColorizerReloadAllBuffers" },
    config = function()
        require('colorizer').setup()
    end
}
