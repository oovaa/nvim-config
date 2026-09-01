---@module 'custom.ui.spec'
local M = {}

-- builtin statusline (replaces lualine.nvim) — tokyonight-night, same sections as before
function M.setup_lualine()
  vim.o.laststatus = 3
  vim.o.showmode = false

  local function define_hl()
    local ok, mod = pcall(require, 'tokyonight.colors')
    local c
    if ok then
      local style = vim.g.colors_name and vim.g.colors_name:match '%-(.+)$' or 'night'
      -- ponytail: tokyonight-moon vs night etc have different palettes; matching active style keeps statusline in sync
      if style ~= 'night' and style ~= 'storm' and style ~= 'moon' and style ~= 'day' then style = 'night' end
      c = mod.setup { style = style }
    else
      c = {
        blue = '#7aa2f7', green = '#9ece6a', yellow = '#e0af68', magenta = '#bb9af7',
        red = '#f7768e', green1 = '#73daca', black = '#1d202f', fg_gutter = '#3b4261',
        bg_statusline = '#16161e', fg_sidebar = '#a9b1d6',
      }
    end
    local function hl(name, bg, fg, gui)
      vim.api.nvim_set_hl(0, name, { bg = bg, fg = fg, bold = gui == 'bold' })
    end
    -- tokyonight lualine theme: a=mode pill, b=branch/diff/diag, c=filename
    hl('SL_a_normal', c.blue, c.black, 'bold'); hl('SL_b_normal', c.fg_gutter, c.blue)
    hl('SL_a_insert', c.green, c.black, 'bold'); hl('SL_b_insert', c.fg_gutter, c.green)
    hl('SL_a_visual', c.magenta, c.black, 'bold'); hl('SL_b_visual', c.fg_gutter, c.magenta)
    hl('SL_a_replace', c.red, c.black, 'bold'); hl('SL_b_replace', c.fg_gutter, c.red)
    hl('SL_a_command', c.yellow, c.black, 'bold'); hl('SL_b_command', c.fg_gutter, c.yellow)
    hl('SL_a_terminal', c.green1, c.black, 'bold'); hl('SL_b_terminal', c.fg_gutter, c.green1)
    hl('SL_c', c.bg_statusline, c.fg_sidebar)
    hl('SL_lsp', c.bg_statusline, '#9ece6a')
    -- diff colors
    hl('SL_diff_add', c.fg_gutter, '#449dab'); hl('SL_diff_change', c.fg_gutter, '#6183bb'); hl('SL_diff_delete', c.fg_gutter, '#914c54')
  end
  define_hl()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = define_hl })

  local mode_map = {
    n = 'NORMAL', i = 'INSERT', v = 'VISUAL', V = 'V-LINE', ['\22'] = 'V-BLOCK',
    c = 'COMMAND', R = 'REPLACE', t = 'TERMINAL', nt = 'TERMINAL',
  }
  local function mode_hl_key(m)
    if m:find('^[iI]') then return 'insert'
    elseif m:find('^[vV\22]') then return 'visual'
    elseif m:find('^R') then return 'replace'
    elseif m:find('^c') then return 'command'
    elseif m:find('^t') then return 'terminal'
    else return 'normal' end
  end

  _G._builtin_statusline = function()
    -- disabled filetypes like lualine: neo-tree / TelescopePrompt / lazy / dashboard
    local ft = vim.bo.filetype
    if ft == 'neo-tree' or ft == 'TelescopePrompt' or ft == 'lazy' or ft == 'dashboard' then
      return '%#SL_c# %f %*'
    end
    local raw = vim.fn.mode()
    local mode = mode_map[raw] or raw:upper()
    local key = mode_hl_key(raw)
    local hl_a = '%#SL_a_' .. key .. '#'
    local hl_b = '%#SL_b_' .. key .. '#'
    local hl_c = '%#SL_c#'

    -- branch
    local branch = vim.b.gitsigns_head or vim.g.gitsigns_head or ''
    local branch_s = branch ~= '' and (' ' .. branch) or ''
    -- diff (gitsigns_status_dict)
    local diff_s = ''
    local d = vim.b.gitsigns_status_dict
    if d then
      local parts = {}
      if d.added and d.added > 0 then parts[#parts + 1] = '%#SL_diff_add#+' .. d.added .. '%#SL_b_' .. key .. '#' end
      if d.changed and d.changed > 0 then parts[#parts + 1] = '%#SL_diff_change#~' .. d.changed .. '%#SL_b_' .. key .. '#' end
      if d.removed and d.removed > 0 then parts[#parts + 1] = '%#SL_diff_delete#-' .. d.removed .. '%#SL_b_' .. key .. '#' end
      diff_s = table.concat(parts, ' ')
    end
    -- diagnostics — Nerd Fonts v3 (old / codepoints often missing → '?') — this is the 'problems in current file'
    local diags = vim.diagnostic.get(0)
    local cnt = { 0, 0, 0, 0 }
    for _, v in ipairs(diags) do cnt[v.severity] = (cnt[v.severity] or 0) + 1 end
    local icons = { ' ', ' ', ' ', ' ' }
    local diag_parts = {}
    for i = 1, 4 do if cnt[i] > 0 then diag_parts[#diag_parts + 1] = icons[i] .. cnt[i] end end
    local diag_s = table.concat(diag_parts, ' ')

    local b_parts = {}
    if branch_s ~= '' then b_parts[#b_parts + 1] = branch_s end
    if diff_s ~= '' then b_parts[#b_parts + 1] = diff_s end
    if diag_s ~= '' then b_parts[#b_parts + 1] = diag_s end
    local b_s = table.concat(b_parts, '  ')

    -- filename path=1 with symbols
    local fname = vim.fn.expand '%:~:.'
    if fname == '' then fname = '[No Name]' end
    if vim.bo.modified then fname = fname .. ' [+]' end
    if vim.bo.readonly then fname = fname .. ' 󰌾' end

    -- lsp
    local clients = vim.lsp.get_clients { bufnr = 0 }
    local lsp_s = #clients == 0 and '' or '%#SL_lsp#󰄶 ' .. clients[1].name .. hl_c

    local enc = (vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding)
    local ff = vim.bo.fileformat
    local ft_s = vim.bo.filetype

    -- sections mirror lualine: a=mode | b=branch/diff/diag | c=filename | x=lsp/enc/ff/ft | y=progress | z=location
    -- lualine had no separators
    local left = hl_a .. ' ' .. mode .. ' ' .. hl_b .. (b_s ~= '' and ' ' .. b_s .. ' ' or ' ')
    local center = hl_c .. ' ' .. fname .. ' '
    local right_x = hl_c .. (lsp_s ~= '' and ' ' .. lsp_s .. ' ' or ' ') .. enc .. ' ' .. ff .. (ft_s ~= '' and ' ' .. ft_s or '') .. ' '
    local right_y = hl_b .. ' %p%% '
    local right_z = hl_a .. ' %l:%c ' .. '%*'
    return left .. center .. '%=' .. right_x .. right_y .. right_z
  end
  vim.o.statusline = '%!v:lua._builtin_statusline()'
end

-- builtin tabline (replaces bufferline.nvim) — buffers as tabs, diagnostics + modified dot
function M.setup_bufferline()
  local function define_hl()
    -- ponytail: adaptive dot fg + seamless bg — TabLine* bg may be nil (transparent themes)
    local sel = vim.api.nvim_get_hl(0, { name = 'TabLineSel' })
    local norm = vim.api.nvim_get_hl(0, { name = 'TabLine' })
    local function fg_for(bg)
      if not bg then return '#9ece6a' end
      local r = math.floor(bg / 65536) % 256
      local g = math.floor(bg / 256) % 256
      local b = bg % 256
      local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
      -- light bg -> dark green for contrast, dark bg -> light green
      if luma > 140 then return '#005f00' else return '#9ece6a' end
    end
    local function set_mod(name, bg)
      local fg = fg_for(bg)
      if bg then
        vim.api.nvim_set_hl(0, name, { fg = fg, bg = string.format('#%06x', bg), bold = true })
      else
        -- transparent theme: no bg so dot inherits TabLine bg, clear stale bg
        vim.api.nvim_set_hl(0, name, { fg = fg, bold = true })
        -- nvim_set_hl without bg keeps old bg; force clear
        local cur = vim.api.nvim_get_hl(0, { name = name })
        if cur.bg then vim.api.nvim_set_hl(0, name, { fg = fg, bg = nil, bold = true }) end
      end
    end
    set_mod('TabLineMod', norm.bg)
    set_mod('TabLineModSel', sel.bg)
  end
  define_hl()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = define_hl })
  _G._builtin_tabline = function()
    local s = ''
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
        if name == '' then name = '[No Name]' end
        local is_cur = buf == vim.api.nvim_get_current_buf()
        local hl = is_cur and '%#TabLineSel#' or '%#TabLine#'
        local tab_hl_name = is_cur and 'TabLineSel' or 'TabLine'
        local d = vim.diagnostic.get(buf)
        local cnt = { 0, 0, 0, 0 }
        for _, v in ipairs(d) do cnt[v.severity] = cnt[v.severity] + 1 end
        local icons = { '', '', '', '' }
        local diag = ''
        for i = 1, 4 do if cnt[i] > 0 then diag = diag .. icons[i] .. cnt[i] .. ' ' end end
        local mod_hl = is_cur and '%#TabLineModSel#' or '%#TabLineMod#'
        local mod = vim.bo[buf].modified and ' ' .. mod_hl .. '●' .. hl or ''
        s = s .. hl .. ' ' .. name .. mod .. (diag ~= '' and ' ' .. diag or '') .. ' %*'
      end
    end
    return s .. '%#TabLineFill#%='
  end
  vim.o.showtabline = 2
  vim.o.tabline = '%!v:lua._builtin_tabline()'
end

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
    { key = 'f', icon = '', label = 'Find File', action = '<cmd>Telescope find_files<CR>' },
    { key = 'r', icon = '', label = 'File Explorer', action = '<cmd>Neotree toggle<CR>' },
    { key = 'g', icon = '', label = 'Git (LazyGit)', action = function() if vim.fn.exists ':LazyGit' == 2 then vim.cmd 'LazyGit' else vim.cmd 'terminal lazygit' end end },
    { key = 's', icon = '', label = 'Recent Sessions', action = function()
      -- ponytail: restore current cwd session; if none, pick from sessions dir (readable `cd` dir, deduped)
      local function has_badd(path)
        if vim.fn.filereadable(path) ~= 1 then return false end
        for _, l in ipairs(vim.fn.readfile(path)) do if l:match('^badd') then return true end end
        return false
      end
      local f = _G._builtin_find_session and _G._builtin_find_session(nil) or nil
      if not f then
        local sess_dir = vim.fn.stdpath 'data' .. '/sessions'
        f = sess_dir .. '/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p'):gsub('[^%w]+', '%%') .. '.vim'
      end
      if has_badd(f) then pcall(vim.cmd, 'silent! Neotree close'); vim.cmd('source ' .. vim.fn.fnameescape(f)); return end
      local sess_dir = vim.fn.stdpath 'data' .. '/sessions'
      local files = vim.fn.glob(sess_dir .. '/*.vim', false, true)
      -- readable labels via `cd` line, dedup by dir (legacy %2F vs new %), skip empty
      local seen, items, map = {}, {}, {}
      for _, path in ipairs(files) do
        if has_badd(path) then
          local label = nil
          for _, l in ipairs(vim.fn.readfile(path)) do
            local cd = l:match('^cd%s+(.+)$')
            if cd then label = vim.fn.fnamemodify(vim.fn.expand(cd), ':p'):gsub('/+$', ''); break end
          end
          if label and not seen[label] then
            seen[label] = path
            -- keep newest mtime when duplicate (legacy vs new)
            -- we already iterate glob sorted; dedup by first seen but prefer newer: compare mtime if duplicate
          end
        end
      end
      -- second pass: resolve newest per label
      for _, path in ipairs(files) do
        if has_badd(path) then
          local label = nil
          for _, l in ipairs(vim.fn.readfile(path)) do local cd = l:match('^cd%s+(.+)$'); if cd then label = vim.fn.fnamemodify(vim.fn.expand(cd), ':p'):gsub('/+$',''); break end end
          if label and seen[label] then
            if vim.fn.getftime(path) > vim.fn.getftime(seen[label]) then seen[label] = path end
          end
        end
      end
      for label, path in pairs(seen) do
        local disp = label:gsub('^' .. vim.fn.expand('~'), '~')
        items[#items + 1] = disp
        map[disp] = path
      end
      table.sort(items)
      if #items == 0 then vim.notify('No session for ' .. vim.fn.getcwd() .. ' — sessions are saved on quit (suppressed: ~, ~/Downloads, /etc, /tmp)', vim.log.levels.INFO) return end
      local function do_pick(choice) if choice and map[choice] then pcall(vim.cmd, 'silent! Neotree close'); vim.cmd('source ' .. vim.fn.fnameescape(map[choice])) end end
      local function pick()
        vim.ui.select(items, { prompt = 'Select session:' }, function(choice) do_pick(choice) end)
      end
      if pcall(require, 'telescope') then
        local pickers, finders, conf = require('telescope.pickers'), require('telescope.finders'), require('telescope.config').values
        pickers.new({}, { prompt_title = 'Sessions', finder = finders.new_table { results = items }, sorter = conf.generic_sorter({}), previewer = false, attach_mappings = function(_, m)
          m('i', '<CR>', function(pb) local sel = require('telescope.actions.state').get_selected_entry(); require('telescope.actions').close(pb); do_pick(sel[1]) end)
          m('n', '<CR>', function(pb) local sel = require('telescope.actions.state').get_selected_entry(); require('telescope.actions').close(pb); do_pick(sel[1]) end)
          return true end }):find()
      else pick() end
    end },
    { key = 'u', icon = '', label = 'Update Plugins', action = '<cmd>Lazy sync<CR>' },
    { key = 'q', icon = '', label = 'Quit', action = '<cmd>qa<CR>' },
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
      -- if `nvim` was launched with no args and a non-empty session exists for this cwd,
      -- the session autocmd (init.lua) already restored it — skip dashboard
      do
        local f = _G._builtin_find_session and _G._builtin_find_session(nil) or (_G._builtin_session_file and _G._builtin_session_file() or nil)
        if f and not (_G._builtin_suppressed_dir and _G._builtin_suppressed_dir()) and vim.fn.filereadable(f) == 1 then
          local has = false
          for _, l in ipairs(vim.fn.readfile(f)) do if l:match('^badd') then has = true; break end end
          if has then return end
        end
      end
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
      for _, b in ipairs(buttons) do label_w = math.max(label_w, vim.fn.strdisplaywidth(b.label)) end
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
      for _, l in ipairs(raw) do max_w = math.max(max_w, vim.fn.strdisplaywidth(l)) end
      local block_pad = math.max(4, math.floor((win_w - max_w) / 2))
      local pad_top = math.max(0, math.floor((win_h - #raw) / 2) - 2)
      local lines = {}
      for _ = 1, pad_top do lines[#lines + 1] = '' end
      for _, l in ipairs(raw) do
        if l == '' then lines[#lines + 1] = ''
        else lines[#lines + 1] = string.rep(' ', block_pad) .. l end
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      -- highlight like alpha: header Include, footer subtle (account for pad_top)
      local hdr_start = pad_top + 3
      for i = hdr_start, hdr_start + 5 do pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Include', i - 1, block_pad, -1) end
      pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', #lines - 1, block_pad, -1)
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

return M
