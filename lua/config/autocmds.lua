---@module 'config.autocmds'
-- Global autocommands. Plugin-scoped autocmds (LspAttach, styling tweaks)
-- live with their plugin specs in init.lua.

local large_file_size = tonumber(vim.g.large_file_size) or (1024 * 1024)

-- Highlight yanked (copied) text briefly
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Indent-guide colors (old hlchunk look): dim guides, purple current chunk.
-- Re-applied on ColorScheme so :Themery switches keep them.
local function indent_colors()
  vim.api.nvim_set_hl(0, 'SnacksIndent', { fg = '#4a4560' })
  vim.api.nvim_set_hl(0, 'SnacksIndentScope', { fg = '#806d9c' })
  vim.api.nvim_set_hl(0, 'SnacksIndentChunk', { fg = '#806d9c' })
end
vim.api.nvim_create_autocmd('ColorScheme', {
  desc = 'Keep hlchunk-style indent colors across theme switches',
  group = vim.api.nvim_create_augroup('indent-colors', { clear = true }),
  callback = indent_colors,
})
indent_colors()

-- Idle upkeep (single CursorHold handler): external-change check + diagnostic
-- float. One autocmd instead of two so idle work stays in one place.
vim.api.nvim_create_autocmd('CursorHold', {
  desc = 'Idle upkeep: checktime + diagnostic float',
  group = vim.api.nvim_create_augroup('idle-upkeep', { clear = true }),
  callback = function()
    -- Classic kickstart pattern: :checktime on idle prompts Vim to reload
    -- buffers changed on disk (vim loses track after external edits).
    pcall(vim.cmd, 'silent! checktime')
    if vim.b.large_file_mode then return end
    -- Inline diagnostic text cannot wrap in nvim, so long errors get cut at
    -- the window edge. Resting the cursor on an error opens a float with the
    -- full message, which wraps to fit the window. Close it by moving the cursor.
    -- Skip clean lines: get() with a position costs little, the float
    -- render does not. (col is not a valid get() filter — line scope only.)
    -- Skip when a float is already open so idle CursorHolds don't re-render
    -- and flicker ~4x/s on the same error line.
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
    if #vim.diagnostic.get(0, { lnum = lnum }) == 0 then return end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= '' then return end
    end
    vim.diagnostic.open_float(nil, {
      focusable = false,
      scope = 'line',
      close_events = { 'CursorMoved', 'BufLeave', 'InsertEnter' },
    })
  end,
})

-- Large file mode: protect editing responsiveness for very large files by
-- disabling expensive per-buffer features that are less useful in that context.
vim.api.nvim_create_autocmd('BufReadPre', {
  group = vim.api.nvim_create_augroup('large-file-detect', { clear = true }),
  callback = function(args)
    local name = vim.api.nvim_buf_get_name(args.buf)
    if name == '' then return end
    local ok, stat = pcall(vim.uv.fs_stat, name)
    if ok and stat and stat.size > large_file_size then vim.b[args.buf].large_file_mode = true end
  end,
})

vim.api.nvim_create_autocmd('BufReadPost', {
  group = vim.api.nvim_create_augroup('large-file-optimize', { clear = true }),
  callback = function(args)
    if not vim.b[args.buf].large_file_mode then return end
    local bo = vim.bo[args.buf]
    bo.swapfile = false
    bo.undofile = false
    bo.foldmethod = 'manual'
    bo.synmaxcol = 200
    pcall(vim.diagnostic.enable, false, { bufnr = args.buf })
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
      -- ponytail: setting filetype fires FileType by itself; the manual
      -- exec_autocmds used to double-fire the whole FileType cascade (measured).
      vim.bo[args.buf].filetype = 'typescript'
    end
  end,
})

-- Auto-reload files when changed on disk on focus/enter (idle is covered by
-- the idle-upkeep CursorHold handler above).
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  group = vim.api.nvim_create_augroup('auto-checktime', { clear = true }),
  callback = function() pcall(vim.cmd, 'silent! checktime') end,
})

-- :SudoWrite — write the current buffer as root via sudo. Classic QOL for
-- editing system files (/etc/hosts, nginx config, etc.) without leaving nvim.
-- (ponytail: sudo://% needs suda.vim, which isn't installed — sudo tee is.)
vim.api.nvim_create_user_command('SudoWrite', function(args)
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    vim.notify('SudoWrite: unnamed buffer, save normally first', vim.log.levels.ERROR)
    return
  end
  vim.cmd(('write%s !sudo tee %s >/dev/null'):format(args.bang and '!' or '', vim.fn.fnameescape(name)))
  vim.cmd('edit!')
end, { desc = 'Write current buffer via sudo', bang = true })

-- HTTP buffer mapping: <leader>hr lives ONLY in http buffers (buffer-local).
-- A lazy.nvim `keys` entry would register a global load-shim instead.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'http',
  desc = 'HTTP buffer mappings',
  group = vim.api.nvim_create_augroup('http-keymaps', { clear = true }),
  callback = function(args)
    vim.keymap.set('n', '<leader>hr', '<cmd>Rest run<cr>', { buffer = args.buf, desc = 'HTTP Request' })
  end,
})