---@module 'custom.ui.statusline'
local M = {}

-- Render-path cache: statusline/tabline evaluate on every redraw, so per-buffer
-- diagnostic counts + first LSP name are cached and refreshed on events only.
-- ponytail: global per-buffer cache; per-win only if multi-window counts ever diverge.
M._diag_counts = {} -- [bufnr] = { e, w, i, h, total }
M._lsp_name = { buf = -1, name = '' }
-- Search-count cache: searchcount() scans the buffer, so only recompute when
-- the pattern, buffer content, or cursor line changed — pure redraws reuse.
M._search = { key = nil, s = '' }
-- Filetype icons: resolved from nvim-web-devicons once it's loaded (never
-- proactively required — that would pull it onto the startup path), then
-- cached with a per-ft highlight in the icon's own color. Cleared on
-- ColorScheme since :colorscheme wipes custom highlights.
M._icons = {} -- [ft] = icon-segment string or false
M._bar_bg = nil

function M._count_diags(buf)
  local sev = vim.diagnostic.severity
  local c = { e = 0, w = 0, i = 0, h = 0, total = 0 }
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    c.total = c.total + 1
    if d.severity == sev.ERROR then
      c.e = c.e + 1
    elseif d.severity == sev.WARN then
      c.w = c.w + 1
    elseif d.severity == sev.INFO then
      c.i = c.i + 1
    else
      c.h = c.h + 1
    end
  end
  M._diag_counts[buf] = c
  return c
end

function M._refresh_lsp(buf)
  local name = ''
  local ok, clients = pcall(vim.lsp.get_clients, { bufnr = buf })
  if ok and clients and #clients > 0 then name = clients[1].name or '' end
  M._lsp_name = { buf = buf, name = name }
end

do
  local grp = vim.api.nvim_create_augroup('BuiltinUICache', { clear = true })
  vim.api.nvim_create_autocmd('DiagnosticChanged', { group = grp, callback = function(ev) M._count_diags(ev.buf) end })
  vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach', 'BufEnter' }, {
    group = grp,
    callback = function(ev)
      local b = ev.buf or vim.api.nvim_get_current_buf()
      M._refresh_lsp(b)
      M._count_diags(b)
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, { group = grp, callback = function(ev) M._diag_counts[ev.buf] = nil end })
end
-- builtin statusline (replaces lualine.nvim) — tokyonight-night, same sections as before
function M.setup_lualine()
  vim.o.laststatus = 3
  vim.o.showmode = false

  local function define_hl()
    -- ponytail: accents come from the active theme's live highlights, so the
    -- statusline follows every <leader>ty pick; hexes are last-resort only.
    -- Links are followed (gruvbox links Function -> GruvboxGreen etc).
    local function raw_hl(name)
      local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name })
      if ok and h then return h end
      return {}
    end
    -- ponytail: nvim_get_hl sometimes returns color *names* ('none', 'bg'..);
    -- resolve those, never let format() see a string (crashed melange).
    local function hex(v)
      if type(v) == 'string' then
        if v == 'none' or v == 'bg' or v == 'fg' then return nil end
        local ok, n = pcall(vim.api.nvim_get_color_by_name, v)
        if not ok or type(n) ~= 'number' or n < 0 then return nil end
        v = n
      end
      return v and string.format('#%06x', v) or nil
    end
    local function fg_of(name, depth)
      if (depth or 0) > 4 then return nil end
      local h = raw_hl(name)
      local fg = hex(h.fg)
      if fg then return fg end
      if h.link then return fg_of(h.link, (depth or 0) + 1) end
      return nil
    end
    local function bgfg_of(name, depth)
      if (depth or 0) > 4 then return nil, nil end
      local h = raw_hl(name)
      local bg, fg = h.bg, h.fg
      if h.link and (not bg or not fg) then
        local lb, lf = bgfg_of(h.link, (depth or 0) + 1)
        bg = bg or lb
        fg = fg or lf
      end
      if h.reverse then
        bg, fg = fg, bg
      end
      return hex(bg), hex(fg)
    end
    local function bar_colors()
      local bg, fg = bgfg_of 'StatusLine'
      if not bg or not fg then
        local nbg, nfg = bgfg_of 'Normal'
        bg = bg or nbg
        fg = fg or nfg
      end
      return bg or '#16161e', fg or '#a9b1d6'
    end
    -- Sections get their own color weight: mode pill (accent bg), lifted
    -- middle (branch/diff/diag), flat filename — all derived from the
    -- theme's own StatusLine/Normal colors, so every <leader>ty pick
    -- re-colors the bar with zero hardcoded hexes (fallbacks excepted).
    local bar_bg, bar_fg = bar_colors()
    M._bar_bg = bar_bg
    M._icons = {} -- stale per-ft highlights died with the colorscheme; re-resolve lazily
    -- blend two #rrggbb colors; t=0 → a, t=1 → b
    local function blend(a, b, t)
      local function ch(h, i) return tonumber(h:sub(i, i + 1), 16) end
      local r = math.floor(ch(a, 2) + (ch(b, 2) - ch(a, 2)) * t + 0.5)
      local g = math.floor(ch(a, 4) + (ch(b, 4) - ch(a, 4)) * t + 0.5)
      local bl = math.floor(ch(a, 6) + (ch(b, 6) - ch(a, 6)) * t + 0.5)
      return string.format('#%02x%02x%02x', r, g, bl)
    end
    local mid_bg = blend(bar_bg, bar_fg, 0.1) -- subtle lift for the b section
    local c = {
      blue = fg_of 'Function' or '#7aa2f7',
      green = fg_of 'String' or '#9ece6a',
      magenta = fg_of 'Statement' or '#bb9af7',
      red = fg_of 'DiagnosticError' or '#f7768e',
      yellow = fg_of 'DiagnosticWarn' or '#e0af68',
      cyan = fg_of 'Identifier' or '#73daca',
      lsp = fg_of 'DiagnosticOk' or '#9ece6a',
      -- hints are the least urgent, so they take Comment's muted grey rather
      -- than another accent (Identifier resolves to the same magenta as
      -- Statement in most themes, which made hint and branch look identical).
      hint = fg_of 'Comment' or '#565f89',
    }
    local modes = {
      normal = c.blue,
      insert = c.green,
      visual = c.magenta,
      replace = c.red,
      command = c.yellow,
      terminal = c.cyan,
    }
    local function hl(name, bg, fg, gui) vim.api.nvim_set_hl(0, name, { bg = bg, fg = fg, bold = gui == 'bold' }) end
    -- a=mode pill (accent bg, bar text), b=lifted middle, c=flat filename.
    -- Every color comes from the theme's live highlights (accents via
    -- fg_of, base via bar_colors); fallbacks only fire when a theme
    -- omits the group entirely.
    for key, accent in pairs(modes) do
      hl('SL_a_' .. key, accent, bar_bg, 'bold')
      hl('SL_b_' .. key, mid_bg, bar_fg)
    end
    hl('SL_c', bar_bg, bar_fg)
    hl('SL_lsp', bar_bg, c.lsp)
    -- diff colors + search count sit inside the lifted b section / next to
    -- the filename, so they share mid_bg to avoid a patchwork bar
    hl('SL_diff_add', mid_bg, c.lsp)
    hl('SL_diff_change', mid_bg, c.blue)
    hl('SL_diff_delete', mid_bg, c.red)
    -- search count ([cur/total], only visible while searching)
    hl('SL_search', mid_bg, c.yellow)
    -- ponytail: severity is the one thing you read at a glance, so each level
    -- gets its own theme accent (error bold). Branch too, so the middle isn't
    -- one flat run of text.
    hl('SL_branch', mid_bg, c.magenta)
    hl('SL_diag_e', mid_bg, c.red, 'bold')
    hl('SL_diag_w', mid_bg, c.yellow)
    hl('SL_diag_i', mid_bg, c.blue)
    hl('SL_diag_h', mid_bg, c.hint)
  end
  define_hl()
  -- ponytail: augroups matter here — `<leader>ur` re-runs setup(), and
  -- ungrouped autocmds accumulated one copy per reload (measured: 3 reloads
  -- turned 1 RecordingLeave handler into 5).
  local grp = vim.api.nvim_create_augroup('BuiltinStatusline', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = grp, callback = define_hl })
  vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group = grp,
    callback = function() vim.cmd 'redrawstatus' end,
  })

  local mode_map = {
    n = 'NORMAL',
    i = 'INSERT',
    v = 'VISUAL',
    V = 'V-LINE',
    ['\22'] = 'V-BLOCK',
    c = 'COMMAND',
    R = 'REPLACE',
    t = 'TERMINAL',
    nt = 'TERMINAL',
    no = 'OP-PENDING',
    nov = 'OP-PENDING',
    noV = 'OP-PENDING',
    ['no\22'] = 'OP-PENDING',
    s = 'SELECT',
    S = 'SELECT-LINE',
    ['\19'] = 'SELECT-BLOCK',
  }
  local function mode_hl_key(m)
    if m:find '^[iI]' then
      return 'insert'
    elseif m:find '^[vV\22]' then
      return 'visual'
    elseif m:find '^R' then
      return 'replace'
    elseif m:find '^c' then
      return 'command'
    elseif m:find '^t' then
      return 'terminal'
    else
      return 'normal'
    end
  end
  -- %-escape user text before it joins the statusline (which re-parses % items)
  local function esc(s) return (s:gsub('%%', '%%%%')) end

  _G._builtin_statusline = function()
    -- disabled filetypes like lualine: lazy / dashboard
    -- (kept non-empty: the stress render matrix requires a string here; on an
    -- unnamed buffer %f is empty so this is just a tinted blank, by design)
    local ft = vim.bo.filetype
    if ft == 'lazy' or ft == 'dashboard' then return '%#SL_c# %f %*' end
    local raw = vim.fn.mode()
    local mode = mode_map[raw] or raw:upper()
    local key = mode_hl_key(raw)
    local hl_a = '%#SL_a_' .. key .. '#'
    local hl_b = '%#SL_b_' .. key .. '#'
    local hl_c = '%#SL_c#'

    -- branch
    local branch = vim.b.gitsigns_head or vim.g.gitsigns_head or ''
    -- branch glyph as a codepoint, not a literal PUA char (invisible in source)
    local branch_s = branch ~= '' and ('%#SL_branch#' .. vim.fn.nr2char(0xe0a0) .. ' ' .. esc(branch) .. hl_b) or ''
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
    -- diagnostics — cached counts (refreshed on DiagnosticChanged), not get() per redraw
    local buf0 = vim.api.nvim_get_current_buf()
    local cnt = M._diag_counts[buf0] or M._count_diags(buf0)
    -- nerd glyphs with per-severity color so severity reads without counting
    local icons = vim.g.have_nerd_font and { vim.fn.nr2char(0xf057), vim.fn.nr2char(0xf071), vim.fn.nr2char(0xf05a), vim.fn.nr2char(0xf0eb) }
      or { 'E', 'W', 'I', 'H' }
    local diag_parts = {}
    if cnt.e > 0 then diag_parts[#diag_parts + 1] = '%#SL_diag_e#' .. icons[1] .. cnt.e .. hl_b end
    if cnt.w > 0 then diag_parts[#diag_parts + 1] = '%#SL_diag_w#' .. icons[2] .. cnt.w .. hl_b end
    if cnt.i > 0 then diag_parts[#diag_parts + 1] = '%#SL_diag_i#' .. icons[3] .. cnt.i .. hl_b end
    if cnt.h > 0 then diag_parts[#diag_parts + 1] = '%#SL_diag_h#' .. icons[4] .. cnt.h .. hl_b end
    local diag_s = table.concat(diag_parts, ' ')

    local b_parts = {}
    if branch_s ~= '' then b_parts[#b_parts + 1] = branch_s end
    if diff_s ~= '' then b_parts[#b_parts + 1] = diff_s end
    if diag_s ~= '' then b_parts[#b_parts + 1] = diag_s end
    local b_s = table.concat(b_parts, '  ')

    -- macro recording — vim.fn.reg_recording() is '' when idle, register when recording;
    -- reg_executing() likewise during @-playback (recording only —
    -- playback indicator added since long 1000@q runs otherwise show nothing).
    local rec = vim.fn.reg_recording()
    local exe = vim.fn.reg_executing()
    local macro_s = rec ~= '' and ('%#SL_diff_delete#◉ @' .. rec .. hl_b) or (exe ~= '' and ('%#SL_diff_delete#▶ @' .. exe .. hl_b) or '')

    -- filename path=1 with symbols; terminal buffers show a short command
    -- name instead of the raw term://... job URL (term_title defaults to
    -- the URL itself, so treat that as absent and use the part after the
    -- last colon, basename-d for paths: 'echo hi', 'zsh', 'lazygit').
    local fname
    if vim.bo.buftype == 'terminal' then
      local title = vim.b.term_title
      local raw = vim.api.nvim_buf_get_name(buf0)
      if not title or title == '' or title == raw then title = raw:match ':([^:]*)$' or raw end
      fname = vim.fn.fnamemodify(title, ':t')
      if fname == '' then fname = 'terminal' end
    else
      fname = vim.fn.expand '%:~:.'
      if fname == '' then fname = '[No Name]' end
    end
    fname = esc(fname)
    if vim.bo.modified then fname = fname .. ' [+]' end
    if vim.bo.readonly then fname = fname .. ' ' .. vim.fn.nr2char(0xf033e) end
    -- spell flag mirrors the <leader>us toggle (visible state, only when on)
    if vim.wo.spell then fname = fname .. ' %#SL_search#SPELL' .. hl_c end

    -- search count, [cur/total] — only while hlsearch is on.
    -- Cached on pattern + buffer content + cursor line; pure redraws reuse
    -- the last segment instead of re-scanning the buffer.
    local pat = vim.v.hlsearch == 1 and vim.fn.getreg '/' or ''
    local cur = vim.api.nvim_win_get_cursor(0)
    local skey = pat .. '\0' .. buf0 .. '\0' .. (vim.b[buf0].changedtick or 0) .. '\0' .. cur[1] .. ',' .. cur[2]
    if pat ~= '' and skey ~= M._search.key then
      local s = ''
      local ok, sc = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
      if ok and sc and sc.total and sc.total > 0 then
        local cur = sc.incomplete == 1 and '?' or sc.current
        s = '%#SL_search# ' .. cur .. '/' .. sc.total .. ' ' .. hl_c
      end
      M._search = { key = skey, s = s }
    elseif pat == '' then
      M._search = { key = skey, s = '' }
    end
    local search_s = M._search.s

    -- lsp — cached first-client name (refreshed on LspAttach/Detach/BufEnter)
    if M._lsp_name.buf ~= buf0 then M._refresh_lsp(buf0) end
    -- Prefer LSP progress while a server is busy; fall back to vim.ui's
    -- Progress-event summary (0.12) when LSP is idle, then to the client name.
    local prog = vim.lsp.status()
    if prog == '' then prog = vim.ui.progress_status() end
    prog = prog:gsub('%%', '%%%%')
    local lsp_s = prog ~= '' and ('%#SL_lsp#' .. prog .. hl_c)
      or (M._lsp_name.name == '' and '' or '%#SL_lsp#' .. vim.fn.nr2char(0xf0136) .. ' ' .. M._lsp_name.name .. hl_c)

    local ft_s = vim.bo.filetype

    -- filetype icon in its own color (devicons resolves only after something
    -- loads it — snacks dep covers the explorer path; never required here).
    local icon_s = ''
    if ft_s ~= '' and vim.bo.buftype == '' then
      if M._icons[ft_s] == nil and package.loaded['nvim-web-devicons'] then
        local ok, dev = pcall(require, 'nvim-web-devicons')
        if ok then
          local icon, color = dev.get_icon_by_filetype(ft_s)
          if icon then
            if color then
              local safe = ft_s:gsub('%W', '_')
              pcall(vim.api.nvim_set_hl, 0, 'SL_ft_' .. safe, { fg = color, bg = M._bar_bg })
              M._icons[ft_s] = '%#SL_ft_' .. safe .. '#' .. icon .. ' ' .. hl_c
            else
              M._icons[ft_s] = icon .. ' '
            end
          else
            M._icons[ft_s] = false
          end
        else
          M._icons[ft_s] = false
        end
      end
      if M._icons[ft_s] then icon_s = M._icons[ft_s] end
    end

    -- sections mirror lualine: a=mode | b=branch/diff/diag | c=filename | x=lsp/enc/ff/ft | y=progress | z=location
    -- lualine had no separators; %< truncates the filename side first in narrow splits
    local left = hl_a .. ' ' .. mode .. ' ' .. hl_b .. (macro_s ~= '' and ' ' .. macro_s .. ' ' or '') .. (b_s ~= '' and ' ' .. b_s .. ' ' or ' ')
    local center = hl_c .. ' %<' .. icon_s .. fname .. ' ' .. search_s
    local right_x = hl_c .. (lsp_s ~= '' and ' ' .. lsp_s .. ' ' or ' ') .. (ft_s ~= '' and ' ' .. ft_s or '') .. ' '
    local right_y = hl_c .. ' %p%% '
    local right_z = hl_a .. ' %l/%L:%c ' .. '%*'
    return left .. center .. '%=' .. right_x .. right_y .. right_z
  end
  vim.o.statusline = '%!v:lua._builtin_statusline()'
end

-- aliases for modular entry points
M.setup = M.setup_lualine

return M
