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

-- Restore cursor to last edit position when reopening a file.
-- Skips gitcommit/diff greps (position marks mislead there) and files
-- where the mark sits past EOF.
vim.api.nvim_create_autocmd('BufReadPost', {
  desc = 'Restore cursor to last position on file open',
  group = vim.api.nvim_create_augroup('restore-cursor', { clear = true }),
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if ft == 'gitcommit' or ft == 'gitrebase' then return end
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lines = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lines then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Indent-guide colors follow the active theme via links (old hlchunk look:
-- dim guides, accented current chunk). Re-applied on ColorScheme because
-- :colorscheme wipes custom highlights — the previous hardcoded hexes
-- (#4a4560/#806d9c) stayed tokyonight-purple on every other theme.
-- (Matches snacks' own defaults: SnacksIndent → NonText, Scope → Special.)
local function indent_colors()
  vim.api.nvim_set_hl(0, 'SnacksIndent', { link = 'NonText' })
  vim.api.nvim_set_hl(0, 'SnacksIndentScope', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'SnacksIndentChunk', { link = 'Special' })
end
vim.api.nvim_create_autocmd('ColorScheme', {
  desc = 'Keep theme-following indent colors across theme switches',
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

-- Auto-create missing parent dirs on save (e.g. editing a:new/file/that
-- doesn't exist yet). Skips remote/terminal buffers.
vim.api.nvim_create_autocmd('BufWritePre', {
  desc = 'mkdir -p the parent dir before writing a new file',
  group = vim.api.nvim_create_augroup('auto-mkdir', { clear = true }),
  callback = function(args)
    local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ':p:h')
    if dir ~= '' and vim.fn.isdirectory(dir) == 0 and not dir:match('^%w+://') then
      vim.fn.mkdir(dir, 'p')
    end
  end,
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

-- :DiffOrig — side-by-side diff of the buffer against the file on disk.
-- Classic vim QoL for "what have I changed since :w?" (gitsigns covers git,
-- this covers unsaved edits anywhere).
vim.api.nvim_create_user_command('DiffOrig', function()
  vim.cmd('vert new | set buftype=nofile | read ++edit # | 0d_ | diffthis | wincmd p | diffthis')
end, { desc = 'Diff buffer against saved file' })

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

-- docker-compose files get the docker-compose LSP (docker_compose_language_service).
-- Moved from init.lua (Section 5: Theme & Filetypes).
vim.filetype.add {
  pattern = {
    -- NOTE: vim.filetype.add anchors patterns as ^pat$ itself, so no $ here.
    -- Bare `compose` is exact-matched (else composer.yaml etc. would hit);
    -- docker-compose keeps .* for .override.yml variants.
    ['docker%-compose.*%.ya?ml'] = 'yaml.docker-compose',
    ['compose%.ya?ml'] = 'yaml.docker-compose',
    ['compose%.override%.ya?ml'] = 'yaml.docker-compose',
  },
}

-- which-key hides hints while recording/playing macros (upstream hard-code in
-- state.lua/triggers.lua via util.in_macro(), no config knob). Force it on —
-- popup is display-only, recorded keys are unaffected.
-- ponytail: monkey-patch; re-check after which-key updates (grep in_macro).
vim.api.nvim_create_autocmd('RecordingEnter', {
  desc = 'Keep which-key hints visible while recording macros',
  group = vim.api.nvim_create_augroup('which-key-in-macro', { clear = true }),
  callback = function()
    local ok, util = pcall(require, 'which-key.util')
    if ok then util.in_macro = function() return false end end
  end,
})
