
local utils = require('utils')

-- keymap
utils.nnoremap('<leader>gs', ':G<CR>', { silent = true })
utils.nnoremap('gds', ':Gdiffsplit<CR>', { silent = true })
utils.nnoremap('<leader>gp', ':G push<CR>', { silent = true })
utils.nnoremap('<leader>gpo', ':G push origin ')

