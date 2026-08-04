vim.keymap.set('n', '<Esc>', ':w<CR>', { desc = 'Save' })
vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })
vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])
