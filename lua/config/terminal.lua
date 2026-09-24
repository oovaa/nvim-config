---@module 'config.terminal'
-- BUILTIN TERMINAL (replaces toggleterm.nvim + lazygit.nvim, zero loss via :terminal)
-- Split from init.lua. Required after lazy.nvim setup (see init.lua).
-- ponytail: :terminal + TermOpen autocmd (lua/config/autocmds.lua) already handles jk/C-hjkl

-- ponytail: single reusable buf per kind; hide/show = close win, keep buf (no new split each time)
local horiz = { buf = nil, win = nil }
local float = { buf = nil, win = nil }
local last = 'horiz' -- ponytail: C-\ targets last opened kind (like toggleterm)
local function is_win_valid(w) return w and vim.api.nvim_win_is_valid(w) end
local function is_buf_valid(b) return b and vim.api.nvim_buf_is_valid(b) end
local function toggle_horiz(cmd)
  last = 'horiz'
  if is_win_valid(horiz.win) then
    if vim.api.nvim_win_get_buf(horiz.win) == horiz.buf then
      -- ponytail: pcall — hiding the last window errors E444; leave it visible
      if pcall(vim.api.nvim_win_close, horiz.win, true) then horiz.win = nil end
      return
    end
    horiz.win = nil -- stale: window survived (:bd) showing another buffer; fall through to re-show
  end
  -- also handle case win was closed manually (buf still valid)
  if is_buf_valid(horiz.buf) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_buf(w) == horiz.buf then vim.api.nvim_set_current_win(w); vim.cmd.startinsert(); horiz.win = w; return end end
    vim.cmd 'botright split'
    vim.cmd 'resize 15'
    vim.api.nvim_win_set_buf(0, horiz.buf)
    horiz.win = vim.api.nvim_get_current_win()
    vim.cmd.startinsert()
  else
    vim.cmd('botright split | terminal ' .. cmd)
    vim.cmd 'resize 15'
    horiz.buf = vim.api.nvim_get_current_buf()
    horiz.win = vim.api.nvim_get_current_win()
    vim.cmd.startinsert()
  end
end
local function toggle_float(cmd)
  last = 'float'
  if is_win_valid(float.win) then
    if vim.api.nvim_win_get_buf(float.win) == float.buf then
      pcall(vim.api.nvim_win_close, float.win, true)
      float.win = nil
      return
    end
    float.win = nil -- stale window; fall through to re-show
  end
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  if is_buf_valid(float.buf) then
    float.win = vim.api.nvim_open_win(float.buf, true, { relative = 'editor', width = width, height = height, row = row, col = col, style = 'minimal', border = 'rounded' })
    vim.cmd.startinsert()
  else
    float.buf = vim.api.nvim_create_buf(false, true)
    float.win = vim.api.nvim_open_win(float.buf, true, { relative = 'editor', width = width, height = height, row = row, col = col, style = 'minimal', border = 'rounded' })
    vim.fn.jobstart(cmd, { term = true })
    vim.cmd.startinsert()
  end
end
local function new_horiz(cmd)
  vim.cmd('botright split | terminal ' .. cmd)
  vim.cmd 'resize 15'
  vim.cmd.startinsert()
end
vim.keymap.set('n', '<leader>tt', function() toggle_horiz(vim.o.shell) end, { desc = '[T]oggle [T]erminal' })
vim.keymap.set('n', '<leader>tf', function() toggle_float(vim.o.shell) end, { desc = '[T]erminal [F]loat' })
vim.keymap.set('n', '<leader>fg', function() toggle_float('lazygit') end, { desc = '[F]ind Lazy[G]it' })
vim.keymap.set('n', '<leader>tm', function() toggle_float('tmux new -s float 2>/dev/null || tmux attach -t float') end, { desc = '[T]erminal t[M]ux' })
vim.keymap.set('n', '<leader>ht', function() toggle_float('herdr') end, { desc = '[H]erdr [T]erminal' })
vim.keymap.set('n', '<leader>t1', function() new_horiz(vim.o.shell) end, { desc = 'Terminal [1]' })
vim.keymap.set('n', '<leader>t2', function() new_horiz(vim.o.shell) end, { desc = 'Terminal [2]' })
vim.keymap.set('n', '<leader>t3', function() new_horiz(vim.o.shell) end, { desc = 'Terminal [3]' })
vim.keymap.set('n', '<leader>tn', function() new_horiz(vim.o.shell) end, { desc = '[T]erminal [N]ew' })
local function toggle_last()
  -- ponytail: C-\ mirrors toggleterm — if any terminal visible, hide it; else reopen last kind
  -- ponytail: neo-tree float focused → just dismiss the explorer, leave terminals alone
  local cur = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(cur).relative ~= '' and vim.bo[vim.api.nvim_win_get_buf(cur)].filetype == 'neo-tree' then
    pcall(vim.api.nvim_win_close, cur, true)
    return
  end
  -- ponytail: every close is pcall — closing the last window errors (E444, e.g. terminal + neo-tree float only)
  local seen = false
  local function hide(win, buf)
    if not is_win_valid(win) then return false end
    -- ponytail: stale win (:bd swapped in another buffer) must not be closed
    if buf ~= nil and vim.api.nvim_win_get_buf(win) ~= buf then return false end
    seen = true
    return pcall(vim.api.nvim_win_close, win, true)
  end
  if hide(float.win, float.buf) then float.win = nil; return end
  if hide(horiz.win, horiz.buf) then horiz.win = nil; return end
  -- also hunt for manually-opened wins still showing our bufs
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if b == float.buf and hide(w, float.buf) then return end
    if b == horiz.buf and hide(w, horiz.buf) then horiz.win = nil; return end
  end
  if seen then return end -- terminal visible but unclosable (last window) — leave it
  if last == 'float' then toggle_float(vim.o.shell) else toggle_horiz(vim.o.shell) end
end
vim.keymap.set({ 'n', 't' }, '<c-\\>', toggle_last, { desc = 'Toggle Terminal' })
