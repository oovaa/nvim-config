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

-- Copy the full diagnostic message under the cursor to the system clipboard
-- WHAT: Yanks the LSP/linter message at the cursor so you can paste it elsewhere
-- TO CHANGE: Use 'y' instead of '+' to copy into the default register
vim.keymap.set('n', 'gy', function()
  local lnum = vim.fn.line '.' - 1
  local col = vim.fn.col '.' - 1
  local diag = vim.diagnostic.get(0, { lnum = lnum })
  if #diag == 0 then
    vim.notify('No diagnostic on this line', vim.log.levels.INFO)
    return
  end
  table.sort(diag, function(a, b) return math.abs(a.col - col) < math.abs(b.col - col) end)
  local msg = diag[1].message
  vim.fn.setreg('+', msg)
  vim.notify('Copied diagnostic: ' .. msg:gsub('\n', ' '):sub(1, 60), vim.log.levels.INFO)
end, { desc = '[G]ank diagnostic [Y]ank to clipboard' })

-- Toggle inline color previews (colorizer plugin)
vim.keymap.set('n', '<leader>uc', '<cmd>ColorizerToggle<cr>', { desc = '[U]I [C]olorizer toggle' })

-- Switch themes with a live Telescope preview; the selection persists via the
-- theme-management in custom/ui/theme.lua.
vim.keymap.set('n', '<leader>ty', function() require('telescope.builtin').colorscheme { enable_preview = true } end, { desc = 'Switch [T]heme (preview)' })

-- Terminal mode: exit with double <Esc>
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Window navigation: switch splits with Ctrl+{h,j,k,l}
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
