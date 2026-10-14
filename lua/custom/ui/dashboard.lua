---@module 'custom.ui.dashboard'
local M = {}

-- builtin dashboard (replaces alpha-nvim) — same header/buttons/recent as before
function M.setup_starter()
  local header = {
    '   _                ',
    '  (_) ___ __ _ _ __  ',
    "  | |/ __/ _` | '_ \\ ",
    '  | | (_| (_| | | | |',
    ' _/ |\\___\\__,_|_| |_|',
    '|__/                ',
  }
  local buttons = {
    { key = 'e', icon = '', label = 'New File', action = '<cmd>ene<CR>' },
    { key = 'f', icon = '', label = 'Find File', action = function() require('snacks').picker.files() end },
    { key = 'r', icon = '', label = 'File Explorer', action = function() require('snacks').explorer() end },
    { key = 'g', icon = '', label = 'Git (LazyGit)', action = function() vim.cmd 'terminal lazygit' end },
    {
      key = 's',
      icon = '',
      label = 'Recent Sessions',
      action = function()
        -- ponytail: restore current cwd session; if none, pick from sessions dir (readable `cd` dir, deduped)
        local function has_badd(path)
          if vim.fn.filereadable(path) ~= 1 then return false end
          for _, l in ipairs(vim.fn.readfile(path)) do
            if l:match '^badd' then return true end
          end
          return false
        end
        local function close_dashboard()
          if vim.bo.filetype == 'dashboard' then pcall(vim.cmd, 'bwipeout!') end
        end
        -- Prefer require('config.sessions') after the module API migration;
        -- retain _G fallback for reload/legacy callers.
        local sess_mod = nil
        local ok, m = pcall(require, 'config.sessions')
        if ok and type(m) == 'table' then sess_mod = m end
        local find_session_fn = (sess_mod and (sess_mod.find_session_for or sess_mod.find_session)) or _G._builtin_find_session
        local f = find_session_fn and find_session_fn(nil) or nil
        if not f then
          local sess_dir = vim.fn.stdpath 'data' .. '/sessions'
          f = sess_dir .. '/' .. vim.fn.fnamemodify(vim.uv.cwd() or vim.fn.getcwd(), ':p'):gsub('[^%w]+', '%%') .. '.vim'
        end
        if has_badd(f) then
          close_dashboard()
          vim.cmd('source ' .. vim.fn.fnameescape(f))
          return
        end
        local sess_dir = vim.fn.stdpath 'data' .. '/sessions'
        local list_fn = (sess_mod and sess_mod.session_files) or _G._builtin_session_files
        local sess_files = list_fn and list_fn(sess_dir) or {}
        local mtime, files = {}, {}
        for _, e in ipairs(sess_files) do
          mtime[e.path] = e.mtime
          files[#files + 1] = e.path
        end
        -- readable labels via `cd` line, dedup by dir (legacy %2F vs new %), skip empty.
        -- ponytail: one read per file (badd + cd label in a single scan, newest wins); split again only if session format changes.
        local seen, items, map = {}, {}, {}
        for _, path in ipairs(files) do
          if vim.fn.filereadable(path) == 1 then
            local has_b, label = false, nil
            for _, l in ipairs(vim.fn.readfile(path)) do
              if not has_b and l:match '^badd' then has_b = true end
              if not label then
                local cd = l:match '^cd%s+(.+)$'
                if cd then label = vim.fn.fnamemodify(vim.fn.expand(cd), ':p'):gsub('/+$', '') end
              end
              if has_b and label then break end
            end
            if has_b and label and (not seen[label] or mtime[path] > mtime[seen[label]]) then seen[label] = path end
          end
        end
        for label, path in pairs(seen) do
          local disp = label:gsub('^' .. vim.fn.expand '~', '~')
          items[#items + 1] = disp
          map[disp] = path
        end
        table.sort(items)
        if #items == 0 then
          vim.notify(
            'No session for ' .. (vim.uv.cwd() or vim.fn.getcwd()) .. ' — sessions are saved on quit (suppressed: ~, ~/Downloads, /etc, /tmp)',
            vim.log.levels.INFO
          )
          return
        end
        local function do_pick(choice)
          if choice and map[choice] then
            if vim.bo.filetype == 'dashboard' then pcall(vim.cmd, 'bwipeout!') end
            vim.cmd('source ' .. vim.fn.fnameescape(map[choice]))
          end
        end
        local function pick()
          vim.ui.select(items, { prompt = 'Select session:' }, function(choice) do_pick(choice) end)
        end
        pick()
      end,
    },
    { key = 'u', icon = '', label = 'Update Plugins', action = '<cmd>Lazy sync<CR>' },
    { key = 'q', icon = '', label = 'Quit', action = '<cmd>qa<CR>' },
  }
  local config_dir = vim.fn.stdpath 'config'
  local function collect_recent()
    local out, seen = {}, {}
    for _, f in ipairs(vim.v.oldfiles or {}) do
      if #out >= 9 then break end
      if f:find(config_dir, 1, true) then goto continue end
      if vim.fn.filereadable(f) == 0 then goto continue end
      local key = vim.fn.fnamemodify(f, ':.')
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = { path = f, disp = vim.fn.fnamemodify(f, ':~:.') }
      end
      ::continue::
    end
    return out
  end

  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      if vim.fn.argc() > 0 or vim.api.nvim_buf_get_name(0) ~= '' then return end
      if vim.bo.filetype ~= '' then return end
      local buf = vim.api.nvim_get_current_buf()
      local recent = collect_recent()
      local raw = {}
      vim.list_extend(raw, { '', '' })
      vim.list_extend(raw, header)
      raw[#raw + 1] = ''
      -- straight table: pad labels to fixed width so columns line up
      local function pad_disp(s, w)
        local d = vim.fn.strdisplaywidth(s)
        if d >= w then return s end
        return s .. string.rep(' ', w - d)
      end
      local label_w = 0
      for _, b in ipairs(buttons) do
        label_w = math.max(label_w, vim.fn.strdisplaywidth(b.label))
      end
      for _, b in ipairs(buttons) do
        raw[#raw + 1] = string.format('  %s  %s  %s', b.key, b.icon, pad_disp(b.label, label_w))
      end
      raw[#raw + 1] = ''
      for i, r in ipairs(recent) do
        raw[#raw + 1] = string.format('  %d  %s', i, r.disp)
      end
      raw[#raw + 1] = ''
      raw[#raw + 1] = 'neon-ui · ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch

      -- center as a block (like alpha margin 4) — not per-line, so left edge is straight
      local win = vim.api.nvim_get_current_win()
      local win_w = vim.api.nvim_win_get_width(win)
      local win_h = vim.api.nvim_win_get_height(win)
      local max_w = 0
      for _, l in ipairs(raw) do
        max_w = math.max(max_w, vim.fn.strdisplaywidth(l))
      end
      local block_pad = math.max(4, math.floor((win_w - max_w) / 2))
      local pad_top = math.max(0, math.floor((win_h - #raw) / 2) - 2)
      local lines = {}
      for _ = 1, pad_top do
        lines[#lines + 1] = ''
      end
      for _, l in ipairs(raw) do
        if l == '' then
          lines[#lines + 1] = ''
        else
          lines[#lines + 1] = string.rep(' ', block_pad) .. l
        end
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      -- highlight like alpha: header Include, footer subtle (account for pad_top)
      local hdr_start = pad_top + 3
      for i = hdr_start, hdr_start + 5 do
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Include', i - 1, block_pad, -1)
      end
      pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', #lines - 1, block_pad, -1)
      -- button rows: key char Special (then icon), then label as Function
      local btn_start = pad_top + 1 + 1 + #header + 1 -- pad_top + 2 blanks + header lines + 1 blank
      for i, b in ipairs(buttons) do
        local row = btn_start + i - 1
        -- ponytail: extmark columns are BYTE offsets, so the icon advance must be
        -- #icon, not strdisplaywidth(icon) — a nerd glyph is 3 utf-8 bytes but 1
        -- display cell, which put the label highlight 2 columns to its left.
        local icon_end = block_pad + 5 + #b.icon
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Special', row, block_pad + 2, block_pad + 3)
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Title', row, block_pad + 5, icon_end)
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Function', row, icon_end + 2, -1)
      end
      -- recent file rows: Number on the index, Directory on the rest.
      -- The blank separator after the buttons is raw index 9+#buttons, so the
      -- first recent is +#buttons from btn_start — the extra +1 here shifted
      -- every recent highlight one line down (measured: the first recent got
      -- nothing and the blank above the footer got Directory).
      for i, r in ipairs(recent) do
        local row = btn_start + #buttons + i
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Number', row, block_pad + 2, block_pad + 3)
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Directory', row, block_pad + 5, -1)
      end
      vim.bo[buf].modifiable = false
      vim.bo[buf].modified = false
      vim.bo[buf].filetype = 'dashboard'
      vim.wo.wrap = false
      vim.wo.cursorline = false

      for _, b in ipairs(buttons) do
        if type(b.action) == 'string' then
          vim.keymap.set('n', b.key, b.action, { buffer = buf, silent = true, desc = b.label })
        else
          vim.keymap.set('n', b.key, b.action, { buffer = buf, silent = true, desc = b.label })
        end
      end
      for i, r in ipairs(recent) do
        local path = r.path
        vim.keymap.set('n', tostring(i), function() vim.cmd('edit ' .. vim.fn.fnameescape(path)) end, { buffer = buf, silent = true })
      end
      -- also allow <CR> on recent line to open
      vim.keymap.set('n', '<CR>', function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local first_recent = pad_top + 2 + 6 + 1 + #buttons + 1 + 1 -- pad_top + raw index of first recent
        local idx = row - first_recent + 1
        if idx >= 1 and idx <= #recent then vim.cmd('edit ' .. vim.fn.fnameescape(recent[idx].path)) end
      end, { buffer = buf })
    end,
  })
end

-- aliases for modular entry points
M.setup = M.setup_starter
-- dashboard entry (VimEnter handler registered by setup_starter)
_G._builtin_start = function() M.setup_starter() end

return M
