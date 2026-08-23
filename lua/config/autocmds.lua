---@module 'config.autocmds'
-- Global autocommands. Plugin-scoped autocmds (LspAttach, styling tweaks)
-- live with their plugin specs in init.lua.

-- Highlight yanked (copied) text briefly
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Inline diagnostic text cannot wrap in nvim, so long errors get cut at the
-- window edge. Resting the cursor on an error opens a float with the full
-- message, which wraps to fit the window. Close it by moving the cursor.
vim.api.nvim_create_autocmd('CursorHold', {
  desc = 'Show diagnostic in a wrapping float',
  callback = function()
    -- Skip clean buffers: get(0) with a position costs little, the float
    -- render does not.
    local diag = vim.diagnostic.get(0, { lnum = vim.fn.line '.' - 1, col = vim.fn.col '.' - 1 })
    if #diag == 0 then return end
    vim.diagnostic.open_float(nil, {
      focusable = false,
      close_events = { 'CursorMoved', 'BufLeave', 'InsertEnter' },
    })
  end,
})

-- Terminal buffers: jk exits to normal mode, Ctrl+H/J/K/L switches windows,
-- Ctrl+W passes through to window commands.
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('terminal-keymaps', { clear = true }),
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
    vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
    vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
    vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
    vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
    vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
  end,
})

-- Bun shebang detection: files with #!/usr/bin/env bun are TypeScript, so the
-- TS LSP and formatting work correctly.
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('bun-shebang-detection', { clear = true }),
  callback = function(args)
    local first_line = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1] or ''
    if first_line:match '^#!.*bin.*[ /]bun%s*$' or first_line:match '^#!.*bin.*[ /]bun ' then
      vim.bo[args.buf].filetype = 'typescript'

      -- Trigger FileType autocommands so LSPs attach after filetype is set
      vim.api.nvim_exec_autocmds('FileType', { buffer = args.buf })
    end
  end,
})
