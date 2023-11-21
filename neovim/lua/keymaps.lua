
local utils = require('utils')

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

