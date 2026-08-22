local function gh(repo) return 'https://github.com/' .. repo end

-- [[ Yanky ]]
--  Improved yank/put: keeps a history of yanks you can cycle through or search.
--  See `:help yanky.nvim`
vim.pack.add { gh 'gbprod/yanky.nvim' }

require('yanky').setup {}

-- Register the yank history picker with Telescope (`<leader>p` below).
pcall(require('telescope').load_extension, 'yank_history')

-- Route the normal yank/put keys through Yanky so they feed the history.
vim.keymap.set({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', { desc = 'Yank' })
vim.keymap.set({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', { desc = 'Put after' })
vim.keymap.set({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', { desc = 'Put before' })

-- After a put, cycle backwards/forwards through earlier yanks.
vim.keymap.set('n', '<C-p>', '<Plug>(YankyPreviousEntry)', { desc = 'Yanky: previous entry' })
vim.keymap.set('n', '<C-n>', '<Plug>(YankyNextEntry)', { desc = 'Yanky: next entry' })

vim.keymap.set({ 'n', 'x' }, '<leader>p', function() require('telescope').extensions.yank_history.yank_history() end, { desc = 'Open Yank History' })

-- vim: ts=2 sts=2 sw=2 et
