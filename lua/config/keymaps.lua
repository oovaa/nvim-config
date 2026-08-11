---@module 'config.keymaps'
-- Global keymaps. Plugin-scoped mappings live with their plugin specs in
-- init.lua (lazy's `keys = {...}`) so each mapping sits next to its plugin.

-- Clear search highlighting when pressing <Esc>
-- WHAT: Removes the highlight from the last search
-- TO CHANGE: Set to a different key like <C-l> (Ctrl+L)
-- EFFECT: Pressing <Esc> in normal mode clears search highlights
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Delete previous word with Ctrl+Backspace
-- WHAT: Standard editor behavior - delete the word before cursor
-- TO CHANGE: Remove this line if you prefer default behavior
-- EFFECT: Works in both normal and insert mode
vim.keymap.set({ 'n', 'i' }, '<C-BS>', '<C-w>', { desc = 'Delete previous word' })

-- Open diagnostic quickfix list
-- WHAT: Opens a list of all diagnostics in the current buffer
-- TO CHANGE: Map to a different key like <leader>x
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Toggle inline color previews (colorizer plugin)
vim.keymap.set('n', '<leader>uc', '<cmd>ColorizerToggle<cr>', { desc = '[U]I [C]olorizer toggle' })

-- Switch themes with a live Telescope preview; the selection persists via the
-- theme-management block in init.lua.
vim.keymap.set('n', '<leader>ty', '<cmd>Telescope colorscheme<cr>', { desc = 'Switch [T]heme' })

-- Terminal mode: exit with double <Esc>
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Window navigation: switch splits with Ctrl+{h,j,k,l}
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })