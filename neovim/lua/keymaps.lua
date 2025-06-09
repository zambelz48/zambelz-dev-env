local utils = require('utils')

-- quickfix list keymaps
utils.nnoremap('<leader>co', ':copen<CR>', { silent = true })
utils.nnoremap('[q', ':cprev<CR>', { silent = true })
utils.nnoremap(']q', ':cnext<CR>', { silent = true })
utils.nnoremap('<leader>k', ':call setqflist([], "r")<CR> :ccl<CR>',
    { silent = true })

-- fugitive keymaps
utils.nnoremap('<leader>gs', ':G<CR>', { silent = true })
utils.nnoremap('<leader>gl', ':G log<CR>', { silent = true })
utils.nnoremap('<leader>glo', ':G log --oneline<CR>', { silent = true })
utils.nnoremap('<leader>ga', ':Gwrite<CR>', { silent = true })
utils.nnoremap('gds', ':Gdiffsplit<CR>', { silent = true })
utils.nnoremap('<leader>gp', ':G push<CR>', { silent = true })
utils.nnoremap('<leader>gpo', ':G push origin ')

-- markdown previewer keymaps
utils.nnoremap('<leader>mp', ':MarkdownPreview<CR>', { silent = true })
utils.nnoremap('<leader>mps', ':MarkdownPreviewStop<CR>', { silent = true })
