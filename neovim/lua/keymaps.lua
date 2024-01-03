local utils = require('utils')

-- quickfix list keymaps
utils.nnoremap('<leader>co', ':copen<CR>', { silent = true })
utils.nnoremap('[q', ':cprev<CR>', { silent = true })
utils.nnoremap(']q', ':cnext<CR>', { silent = true })
utils.nnoremap('<leader>k', ':call setqflist([], "r")')

-- fugitive keymaps
utils.nnoremap('<leader>gs', ':G<CR>', { silent = true })
utils.nnoremap('<leader>gl', ':G log<CR>', { silent = true })
utils.nnoremap('<leader>glo', ':G log --oneline<CR>', { silent = true })
utils.nnoremap('<leader>ga', ':Gwrite<CR>', { silent = true })
utils.nnoremap('gds', ':Gdiffsplit<CR>', { silent = true })
utils.nnoremap('<leader>gp', ':G push<CR>', { silent = true })
utils.nnoremap('<leader>gpo', ':G push origin ')

-- eslint keymaps
utils.nnoremap('<leader>EF', ':EslintFixAll<CR>', { silent = true })

--- copilot keymaps
vim.keymap.set('i', '<C-J>', 'copilot#Accept("<CR>")', {
	expr = true,
	replace_keycodes = false
})
vim.g.copilot_no_tab_map = true

