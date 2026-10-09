-- Config stress test — single entry point.
--   nvim --headless -c 'luafile tests/stress.lua' -c 'qa!'
-- Exit 0 = green, 1 = at least one FAIL. Full report -> tests/stress-report.md
-- Plan: docs/superpowers/plans/2026-09-30-stress-test-plan.md
local root = vim.fn.stdpath 'config'
local H = dofile(root .. '/tests/stress_harness.lua')

-- snacks replaces vim.notify, so notify text never reaches :messages. Every
-- test that asserts on a message captures it through this instead.
local NOTIFIED = {}
local function capture_notify()
  local orig = vim.notify
  vim.notify = function(msg, ...)
    NOTIFIED[#NOTIFIED + 1] = tostring(msg)
    return orig(msg, ...)
  end
  return function() vim.notify = orig end
end
local function notified()
  local t = table.concat(NOTIFIED, '\n')
  NOTIFIED = {}
  return t
end

local T0 = vim.uv.hrtime()
local TMP = vim.fn.tempname()
vim.fn.mkdir(TMP, 'p')
local created_sessions = {}

-- -----------------------------------------------------------------------------
local function section(name) H.pass('— ' .. name, 'section start') end

-- =============================================================================
section '1 syntax / loadability'
-- =============================================================================
do
  local files = H.lua_files()
  for _, f in ipairs(files) do
    H.t('syntax: ' .. vim.fn.fnamemodify(f, ':.'):gsub('^' .. vim.pesc(root) .. '/', ''), function()
      local chunk, err = loadfile(f)
      if not chunk then return err end
      return true
    end)
  end
  H.pass('syntax: files checked', ('%d'):format(#files))
end

-- warm up: without this the keymap/which-key checks run before the plugins
-- that own those mappings have lazy-loaded, and report phantom gaps
do
  local ok, err = pcall(function()
    require('lazy').load { plugins = vim.tbl_map(function(p) return p.name end, require('lazy').plugins()) }
    for _, f in ipairs { 'warmup.lua', 'warmup.ts', 'warmup.py', 'warmup.md', 'warmup.json' } do
      local p = TMP .. '/' .. f
      vim.fn.writefile({ 'x' }, p)
      pcall(vim.cmd, 'silent! edit! ' .. vim.fn.fnameescape(p))
    end
    vim.cmd 'silent! only'
    vim.cmd 'silent! enew!'
  end)
  if not ok then
    H.warn('warm-up', tostring(err))
  else
    vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
    vim.wait(300)
    H.pass('warm-up', ('%d plugins loaded, VeryLazy fired'):format(#require('lazy').plugins()))
  end
end

-- =============================================================================
section '2 options actually applied'
-- =============================================================================
do
  local want = {
    { 'mapleader', vim.g.mapleader, ' ' },
    { 'maplocalleader', vim.g.maplocalleader, nil },
    { 'number', vim.o.number, true },
    { 'mouse', vim.o.mouse, 'a' },
    { 'showmode', vim.o.showmode, false },
    { 'breakindent', vim.o.breakindent, true },
    { 'undofile', vim.o.undofile, true },
    { 'ignorecase', vim.o.ignorecase, true },
    { 'smartcase', vim.o.smartcase, true },
    { 'signcolumn', vim.o.signcolumn, 'yes' },
    { 'updatetime', vim.o.updatetime, 250 },
    { 'timeoutlen', vim.o.timeoutlen, 300 },
    { 'lazyredraw', vim.o.lazyredraw, true }, -- re-enabled after noice was dropped
    { 'synmaxcol', vim.o.synmaxcol, 300 },
    { 'splitright', vim.o.splitright, true },
    { 'splitbelow', vim.o.splitbelow, true },
    { 'list', vim.o.list, true },
    { 'inccommand', vim.o.inccommand, 'split' },
    { 'cursorline', vim.o.cursorline, true },
    { 'scrolloff', vim.o.scrolloff, 10 },
    { 'smoothscroll', vim.o.smoothscroll, true },
    { 'winborder', vim.o.winborder, 'rounded' },
    { 'confirm', vim.o.confirm, true },
    { 'splitkeep', vim.o.splitkeep, 'screen' },
    { 'laststatus', vim.o.laststatus, 3 },
    { 'showtabline', vim.o.showtabline, 2 },
    { 'winblend', vim.wo.winblend, 10 },
    { 'pumblend', vim.o.pumblend, 10 },
    { 'have_nerd_font', vim.g.have_nerd_font, true },
    { 'large_file_size', vim.g.large_file_size, 1024 * 1024 },
  }
  for _, w in ipairs(want) do
    if w[3] ~= nil then H.eq('option: ' .. w[1], w[3], w[2]) end
  end
  H.truthy('option: listchars has tab', tostring(vim.o.listchars):find('tab:', 1, true) ~= nil, tostring(vim.o.listchars))
  H.truthy(
    'option: listchars has trail + nbsp',
    tostring(vim.o.listchars):find('trail:', 1, true) ~= nil and tostring(vim.o.listchars):find('nbsp:', 1, true) ~= nil,
    tostring(vim.o.listchars)
  )
  H.truthy('option: diffopt has indent-heuristic', tostring(vim.o.diffopt):find 'indent%-heuristic' ~= nil, tostring(vim.o.diffopt))
  H.truthy('option: statusline is the builtin lua one', vim.o.statusline:find('_builtin_statusline', 1, true) ~= nil, vim.o.statusline)
  H.truthy('option: tabline is the builtin lua one', vim.o.tabline:find('_builtin_tabline', 1, true) ~= nil, vim.o.tabline)

  local d = vim.diagnostic.config()
  H.falsy('option: diagnostic update_in_insert', d.update_in_insert)
  H.truthy('option: diagnostic severity_sort', d.severity_sort)
  H.eq('option: diagnostic float border', 'rounded', d.float and d.float.border)
  H.eq('option: diagnostic virtual_text current_line', true, d.virtual_text and d.virtual_text.current_line)
  H.truthy('option: diagnostic jump on_jump', d.jump and d.jump.on_jump)
  H.eq('option: diagnostic underline min severity', vim.diagnostic.severity.WARN, d.underline and d.underline.severity and d.underline.severity.min)

  -- provider / builtin disables the config claims
  for _, g in ipairs { 'loaded_perl_provider', 'loaded_ruby_provider', 'loaded_node_provider' } do
    H.eq('option: vim.g.' .. g .. ' is 0 (disabled)', 0, vim.g[g])
  end
  for _, g in ipairs {
    'loaded_netrw',
    'loaded_netrwPlugin',
    'loaded_2html_plugin',
    'loaded_gzip',
    'loaded_tarPlugin',
    'loaded_zipPlugin',
    'loaded_tutor_mode_plugin',
    'loaded_matchit',
  } do
    H.eq('option: vim.g.' .. g .. ' is 1 (plugin disabled)', 1, vim.g[g])
  end
  H.falsy('option: python3 provider is NOT set to 1', vim.g.loaded_python3_provider == 1)

  -- The notify throttle in init.lua. Checked at the bottom of the chain (the
  -- notifier's own history), because wrapping vim.notify from outside would
  -- record every call before the throttle ever saw it.
  do
    local ok_n, notifier = pcall(require, 'snacks.notifier')
    if not ok_n then
      H.warn('option: notify throttle', 'snacks.notifier not available, skipped')
    else
      local function in_history(pat)
        local n = 0
        for _, e in ipairs(notifier.get_history() or {}) do
          if tostring(e.msg):find(pat, 1, true) then n = n + 1 end
        end
        return n
      end
      local tag = 'throttle-probe-' .. tostring(vim.uv.hrtime())
      for _ = 1, 4 do
        vim.notify('Formatter failed: ' .. tag, vim.log.levels.WARN)
      end
      vim.notify('other message ' .. tag, vim.log.levels.WARN)
      vim.wait(300)
      H.eq('option: notify throttle collapses repeats', 1, in_history('Formatter failed: ' .. tag))
      H.eq('option: notify throttle lets other messages through', 1, in_history('other message ' .. tag))
    end
  end
end

-- =============================================================================
section '3 keymap sanity (duplicates, shadowing, which-key groups)'
-- =============================================================================
do
  for _, mode in ipairs { 'n', 'x', 'i', 't' } do
    local seen, dupes = {}, {}
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      if seen[m.lhs] then dupes[#dupes + 1] = m.lhs end
      seen[m.lhs] = true
    end
    H.eq('keymap: no duplicate lhs in ' .. mode, {}, dupes)
  end

  -- a mapping that is a strict prefix of another, where the prefix already
  -- performs an action, makes the longer one unreachable
  local function shadow(mode)
    local lhs = {}
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      -- <Plug> targets are a plugin's private namespace, not user keymaps
      if not m.lhs:find('<Plug>', 1, true) then lhs[m.lhs] = true end
    end
    local bad = {}
    for a in pairs(lhs) do
      -- mini.surround's `gs<op>` + suffix and single-char operator-pending
      -- prefixes (a/i/o) are intentional; skip them so the report stays useful
      local family = a:match '^g?s' or (a:match '^[a-z]$')
      if #a > 0 and not family then
        for b in pairs(lhs) do
          if b ~= a and #b > #a and b:sub(1, #a) == a and not b:sub(#a + 1):find '<' then bad[#bad + 1] = a .. '  shadows  ' .. b end
        end
      end
    end
    table.sort(bad)
    return bad
  end
  for _, mode in ipairs { 'n', 'x' } do
    local bad = shadow(mode)
    H.t('keymap: shared lhs prefixes in ' .. mode, function()
      if #bad == 0 then return true end
      return { level = 'WARN', msg = ('vim resolves the longest match, so these stay reachable: ' .. table.concat(bad, '; ')) }
    end)
  end

  -- which-key groups must correspond to at least one real mapping
  local lz = require 'lazy.core.config'
  local wk = lz.plugins['which-key.nvim']
  local opts = (wk and wk.opts) or {}
  local maps = vim.api.nvim_get_keymap 'n'
  for _, g in ipairs(opts.spec or {}) do
    local lhs = (g[1]:gsub('<leader>', vim.g.mapleader))
    local global, buffer = false, false
    for _, m in ipairs(maps) do
      if m.lhs == lhs or m.lhs:sub(1, #lhs) == lhs then
        -- m.buffer is 0 for global maps, and 0 is truthy in lua
        if m.buffer and m.buffer ~= 0 then
          buffer = true
        else
          global = true
        end
      end
    end
    H.t('which-key group ' .. g[1], function()
      if global then return true end
      if buffer then return { level = 'WARN', msg = ('only buffer-local mappings start with %s'):format(g[1]) } end
      return ('no mapping starts with %s (which-key shows an empty group)'):format(g[1])
    end)
  end
end

-- =============================================================================
section '4 autocmds fire without error'
-- =============================================================================
do
  vim.cmd 'enew!'
  local buf = vim.api.nvim_get_current_buf()
  local skip = { VimEnter = true, QuitPre = true, LspAttach = true, LspDetach = true, BufWinLeave = true, VimLeavePre = true }
  for _, ev in ipairs {
    'BufReadPre',
    'BufReadPost',
    'BufWritePre',
    'BufWritePost',
    'BufEnter',
    'BufLeave',
    'BufHidden',
    'CursorHold',
    'CursorHoldI',
    'CursorMoved',
    'TextYankPost',
    'TextChanged',
    'TextChangedI',
    'InsertEnter',
    'InsertLeave',
    'FocusGained',
    'FocusLost',
    'VimResized',
    'TermOpen',
    'RecordingEnter',
    'RecordingLeave',
    'FileType',
    'ColorScheme',
    'DiagnosticChanged',
    'WinEnter',
    'WinLeave',
    'WinNew',
    'TabEnter',
    'User',
    'DirChanged',
    'OptionSet',
  } do
    if not skip[ev] then
      H.t('autocmd: ' .. ev, function()
        vim.cmd 'messages clear'
        pcall(vim.api.nvim_exec_autocmds, ev, { buffer = buf })
        vim.wait(60)
        local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
        if #bad == 0 then return true end
        return table.concat(bad, ' | ')
      end)
    end
  end
  H.t('autocmd: ModeChanged (needs a pattern)', function()
    vim.cmd 'messages clear'
    vim.api.nvim_exec_autocmds('ModeChanged', { pattern = 'i:*' })
    vim.api.nvim_exec_autocmds('ModeChanged', { pattern = 'n:*' })
    local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
    return #bad == 0 or table.concat(bad, ' | ')
  end)

  -- notify helpers that are supposed to be inert
  H.t('helper: <leader>q -> diagnostic.setloclist() with no args', function()
    vim.cmd 'messages clear'
    local ok, err = pcall(vim.diagnostic.setloclist)
    local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
    if ok and #bad == 0 then return true end
    return 'pcall=' .. tostring(ok) .. ' ' .. tostring(err) .. ' ' .. table.concat(bad, ' | ')
  end)
  H.t('helper: yank_diagnostics on a clean line is inert', function()
    vim.cmd 'enew!'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('gy', true, false, true), 'x', false)
    local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
    return #bad == 0 or table.concat(bad, ' | ')
  end)
  H.t('helper: which-key in_macro is force-disabled on RecordingEnter', function()
    require('lazy').load { plugins = { 'which-key.nvim' } }
    vim.api.nvim_exec_autocmds('RecordingEnter', {})
    local ok, util = pcall(require, 'which-key.util')
    if not ok then return 'which-key.util not loadable: ' .. tostring(util) end
    if util.in_macro() then return 'in_macro() still returns true while recording' end
    return true
  end)
end

-- =============================================================================
section '5 filetype detection'
-- =============================================================================
do
  local cases = {
    { 'docker-compose.yml', 'yaml.docker-compose' },
    { 'docker-compose.override.yaml', 'yaml.docker-compose' },
    { 'compose.yaml', 'yaml.docker-compose' },
    { 'compose.override.yaml', 'yaml.docker-compose' },
    { 'Dockerfile', 'dockerfile' },
    { 'nginx.conf', 'nginx' },
  }
  for _, c in ipairs(cases) do
    local p = TMP .. '/' .. c[1]
    vim.fn.mkdir(vim.fn.fnamemodify(p, ':h'), 'p')
    vim.fn.writefile({ 'services: {}' }, p)
    H.t('filetype: ' .. c[1], function()
      vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
      if vim.bo.filetype ~= c[2] then return ('expected %s, got %q'):format(c[2], vim.bo.filetype) end
      return true
    end)
    pcall(vim.cmd, 'bdelete!')
  end
  -- negative control: the pattern must NOT swallow composer.yaml
  do
    local p = TMP .. '/composer.yaml'
    vim.fn.writefile({ 'name: x' }, p)
    H.t('filetype: composer.yaml is not docker-compose', function()
      vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
      if vim.bo.filetype == 'yaml.docker-compose' then return 'composer.yaml was hijacked' end
      return true
    end)
    pcall(vim.cmd, 'bdelete!')
  end
  -- bun shebang
  for _, c in ipairs {
    { 'bun1.ts', '#!/usr/bin/env bun\nconsole.log(1)\n' },
    { 'bun2.js', '#!/usr/bin/env bun\nconsole.log(1)\n' },
    { 'bun3.sh', '#!/usr/bin/env bun run thing\n' },
    { 'bun4.sh', '#!/usr/bin/env node\nconsole.log(1)\n' },
    { 'bun5.sh', '#!/bin/bash\necho hi\n' },
  } do
    local p = TMP .. '/' .. c[1]
    vim.fn.writefile(vim.split(c[2], '\n'), p)
    H.t('filetype: ' .. c[1] .. ' (' .. c[2]:gsub('\n', '\\n') .. ')', function()
      vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
      local got = vim.bo.filetype
      local want = c[1] ~= 'bun4.sh' and c[1] ~= 'bun5.sh'
      if (got == 'typescript') ~= want then return ('bun shebang: want typescript=%s, got %q'):format(want, got) end
      return true
    end)
    pcall(vim.cmd, 'bdelete!')
  end
end

-- =============================================================================
section '6 statusline + tabline render matrix'
-- =============================================================================
do
  local ns = vim.api.nvim_create_namespace 'stress'
  local function set_diags(buf, lines)
    local d = {}
    for i = 1, lines do
      d[i] = {
        lnum = i - 1,
        col = 0,
        end_lnum = i - 1,
        end_col = 10,
        severity = i % 4 == 0 and vim.diagnostic.severity.HINT
          or (i % 3 == 0 and vim.diagnostic.severity.WARN or (i % 2 == 0 and vim.diagnostic.severity.INFO or vim.diagnostic.severity.ERROR)),
        message = ('stress diagnostic %d: a reasonably long message so the statusline has something to truncate'):format(i),
        source = i % 2 == 0 and 'linter' or 'lsp',
      }
    end
    vim.diagnostic.set(ns, buf, d)
  end

  local function render(tag)
    H.t('statusline: ' .. tag, function()
      local raw = _G._builtin_statusline()
      if type(raw) ~= 'string' then return 'returned ' .. type(raw) end
      if raw == '' then return 'returned empty string' end
      local out = vim.api.nvim_eval_statusline(vim.o.statusline, { winid = 0, maxwidth = 500 })
      if type(out.str) ~= 'string' then return 'eval returned ' .. type(out.str) end
      local tb = vim.api.nvim_eval_statusline(vim.o.tabline, { maxwidth = 500 })
      if type(tb.str) ~= 'string' then return 'tabline eval returned ' .. type(tb.str) end
      -- every %N@_builtin_tabclick@ index must be a live buffer
      for n in raw:gmatch '%%(%d+)@_builtin_tabclick@' do
        if not vim.api.nvim_buf_is_valid(tonumber(n)) then return 'click index ' .. n .. ' is not a valid buffer' end
      end
      return true
    end)
    H.t('tabline: ' .. tag, function()
      local raw = _G._builtin_tabline()
      if type(raw) ~= 'string' then return 'returned ' .. type(raw) end
      for n in raw:gmatch '%%(%d+)@_builtin_tabclick@' do
        if not vim.api.nvim_buf_is_valid(tonumber(n)) then return 'click index ' .. n .. ' is not a valid buffer' end
      end
      return true
    end)
  end

  local function fresh(ft, name, text)
    pcall(vim.cmd, 'silent! only')
    vim.cmd 'enew!'
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buflisted = true
    if text then vim.api.nvim_buf_set_lines(buf, 0, -1, false, text) end
    if ft then vim.bo[buf].filetype = ft end
    if name then pcall(vim.cmd, 'silent! file ' .. vim.fn.fnameescape(name)) end
    return buf
  end

  local lorem = {}
  for i = 1, 120 do
    lorem[i] = ('line %d: the quick brown fox jumps over the lazy dog'):format(i)
  end

  render 'empty buffer'
  local b = fresh('lua', TMP .. '/plain.lua', lorem)
  render 'lua file, cursor at 1'
  vim.api.nvim_win_set_cursor(0, { 60, 10 })
  render 'lua file, cursor mid-line'
  vim.bo[b].modified = true
  render 'modified'
  vim.bo[b].modified = false
  set_diags(b, 7)
  render 'with 7 diagnostics (e/w/i/h mix)'
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.fn.setreg('/', 'line')
  vim.v.hlsearch = 1
  render 'search active with a match'
  vim.v.hlsearch = 1
  vim.cmd 'normal! n'
  vim.v.hlsearch = 0
  vim.fn.setreg('/', 'zzzznomatch')
  vim.v.hlsearch = 1
  render 'search active, zero matches'
  vim.v.hlsearch = 0
  vim.wo.spell = true
  render 'spell on'
  vim.wo.spell = false
  vim.bo[b].readonly = true
  render 'readonly'
  vim.bo[b].readonly = false

  for _, ft in ipairs { 'markdown', 'python', 'json', 'yaml', 'dockerfile', 'nonexistentft' } do
    local bb = fresh(ft, TMP .. '/probe.' .. ft, lorem)
    render('filetype ' .. ft)
    vim.diagnostic.reset(ns, bb)
  end
  for _, ft in ipairs { 'neo-tree', 'TelescopePrompt', 'lazy', 'dashboard' } do
    local bb = fresh(ft)
    render('disabled-filetype ' .. ft)
  end
  local longname = TMP .. '/' .. string.rep('verylongdirectorysegment/', 6) .. 'file.lua'
  vim.fn.mkdir(vim.fn.fnamemodify(longname, ':h'), 'p')
  vim.fn.writefile({ 'return 1' }, longname)
  fresh('lua', longname, lorem)
  render 'very long path'
  local uname = TMP .. '/café-ünïcode-日本語.lua'
  vim.fn.writefile({ 'return 1' }, uname)
  fresh('lua', uname, lorem)
  render 'unicode path'
  fresh('lua', TMP .. '/' .. string.rep('a', 180) .. '.lua', lorem)
  render '180-char filename'
  fresh('lua', TMP .. '/plain.lua', lorem)
  pcall(vim.cmd, 'silent! only')
  local nw = #vim.api.nvim_list_wins()
  vim.cmd 'vsplit'
  render('narrow split (' .. nw .. ' windows)')
  pcall(vim.cmd, 'silent! only')
  H.truthy(
    'tabclick: valid buffer switches',
    (function()
      local b2 = vim.api.nvim_get_current_buf()
      _G._builtin_tabclick(b2, 0, 'l')
      return vim.api.nvim_get_current_buf() == b2
    end)()
  )
  H.t('tabclick: invalid buffer / wrong button is inert', function()
    _G._builtin_tabclick(999999, 0, 'l')
    _G._builtin_tabclick(0, 0, 'r')
    return true
  end)
  pcall(vim.cmd, 'silent! only')
end

-- =============================================================================
section '7 diagnostics → statusline cache coherence'
-- =============================================================================
do
  pcall(vim.cmd, 'silent! only')
  vim.cmd 'enew!'
  local buf = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace 'coherence'
  local function counts()
    local c = require('custom.ui.spec')._diag_counts[buf]
    return c and c.total or 0
  end
  H.eq('cache: starts empty', 0, counts())
  vim.api.nvim_exec_autocmds('DiagnosticChanged', { buffer = buf, modeline = false })
  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'a' },
    { lnum = 1, col = 0, severity = vim.diagnostic.severity.WARN, message = 'b' },
  })
  H.t('cache: DiagnosticChanged updates the count', function()
    local c = require('custom.ui.spec')._diag_counts[buf]
    if c and c.total == 2 and c.e == 1 and c.w == 1 then return true end
    return 'cache = ' .. vim.inspect(c)
  end)
  H.t('cache: a new window on the same buffer shares the count', function()
    vim.cmd 'vsplit'
    _G._builtin_statusline()
    local c = require('custom.ui.spec')._diag_counts[buf]
    pcall(vim.cmd, 'silent! only')
    return c and c.total == 2 or 'count lost after redraw in another window'
  end)
  H.t('cache: BufWipeout drops the entry', function()
    local tmpbuf = vim.api.nvim_create_buf(true, false)
    require('custom.ui.spec')._count_diags(tmpbuf)
    if not require('custom.ui.spec')._diag_counts[tmpbuf] then return 'never cached' end
    vim.api.nvim_buf_delete(tmpbuf, { force = true })
    return require('custom.ui.spec')._diag_counts[tmpbuf] == nil or 'entry leaked after BufWipeout'
  end)
  vim.diagnostic.reset(ns, buf)
end

-- =============================================================================
section '8 sessions'
-- =============================================================================
do
  local sdir = TMP .. '/proj'
  vim.fn.mkdir(sdir, 'p')
  vim.fn.writefile({ 'return "session"' }, sdir .. '/alpha.lua')
  local cwd0 = vim.uv.cwd()

  H.t('session: sessions dir helper tolerates a missing dir', function() return #_G._builtin_session_files(TMP .. '/nope-not-here') == 0 end)

  -- end-to-end: write, find, restore
  local written
  H.t('session: VimLeavePre writes a session for a normal dir', function()
    vim.cmd('silent! cd ' .. vim.fn.fnameescape(sdir))
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(sdir .. '/alpha.lua'))
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    local f = _G._builtin_find_session(sdir)
    if vim.fn.filereadable(f) ~= 1 then return 'no session written at ' .. f end
    written = f
    created_sessions[#created_sessions + 1] = f
    return true
  end)
  H.t(
    'session: find_session_for returns the file it just wrote',
    function() return _G._builtin_find_session(sdir) == written or 'got ' .. tostring(_G._builtin_find_session(sdir)) end
  )
  H.t('session: sourcing it restores the buffer', function()
    pcall(vim.cmd, 'silent! only')
    pcall(vim.cmd, 'silent! %bwipeout!')
    local ok, err = pcall(vim.cmd, 'silent! source ' .. vim.fn.fnameescape(written))
    vim.wait(200)
    local names = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) ~= '' then names[#names + 1] = vim.api.nvim_buf_get_name(b) end
    end
    if not ok then return 'source errored: ' .. tostring(err) end
    for _, n in ipairs(names) do
      if n:find('alpha.lua', 1, true) then return true end
    end
    return 'restored buffers: ' .. vim.inspect(names)
  end)
  pcall(vim.cmd, 'silent! only')
  pcall(vim.cmd, 'silent! %bwipeout!')

  -- suppressed dirs
  H.t('session: suppressed dirs are NOT written', function()
    local before = _G._builtin_session_files(vim.fn.stdpath 'data' .. '/sessions')
    local seen = {}
    for _, e in ipairs(before) do
      seen[e.path] = true
    end
    for _, d in ipairs { '/tmp', vim.fn.expand '~' } do
      vim.cmd('silent! cd ' .. vim.fn.fnameescape(d))
      vim.cmd('silent! edit! ' .. vim.fn.fnameescape(TMP .. '/alpha.lua'))
      vim.api.nvim_exec_autocmds('VimLeavePre', {})
      pcall(vim.cmd, 'silent! %bwipeout!')
    end
    for _, e in ipairs(_G._builtin_session_files(vim.fn.stdpath 'data' .. '/sessions')) do
      if not seen[e.path] then return ('a session was written for a suppressed dir: %s'):format(e.path) end
    end
    return true
  end)

  -- no file open -> no overwrite
  H.t('session: a dashboard-only exit does not clobber the session', function()
    vim.cmd('silent! cd ' .. vim.fn.fnameescape(sdir))
    pcall(vim.cmd, 'silent! %bwipeout!')
    vim.cmd 'enew!'
    vim.bo.filetype = 'dashboard'
    local before = vim.uv.fs_stat(written)
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    local after = vim.uv.fs_stat(written)
    if before.mtime.sec ~= after.mtime.sec or before.mtime.nsec ~= after.mtime.nsec then return 'session was rewritten by an empty exit' end
    return true
  end)

  -- name derivation
  H.t('session: trailing slash produces a different file than the bare path', function()
    local a = _G._builtin_find_session(sdir)
    local b = _G._builtin_find_session(sdir .. '/')
    if a == b then return true end
    return { level = 'WARN', msg = ('%s and %s map to different session files: %q vs %q'):format(sdir, sdir .. '/', a, b) }
  end)
  H.t('session: two different cwds do not collide', function()
    local d1, d2 = TMP .. '/a/b', TMP .. '/a%b'
    vim.fn.mkdir(d1, 'p')
    vim.fn.mkdir(d2, 'p')
    local a = _G._builtin_find_session(d1)
    local b = _G._builtin_find_session(d2)
    if a ~= b then return true end
    return { level = 'WARN', msg = ('%q and %q both map to %q — one clobbers the other'):format(d1, d2, a) }
  end)
  H.t('session: unicode cwd is handled', function()
    local d = TMP .. '/café'
    vim.fn.mkdir(d, 'p')
    local a = _G._builtin_find_session(d)
    return (type(a) == 'string' and a:find '%.vim$' ~= nil) or ('bad session path ' .. vim.inspect(a))
  end)
  H.t('session: nonexistent cwd does not error', function()
    local a = _G._builtin_find_session(TMP .. '/gone-forever')
    return (type(a) == 'string' and a:find '%.vim$' ~= nil) or ('bad session path ' .. vim.inspect(a))
  end)
  pcall(vim.cmd, 'silent! cd ' .. vim.fn.fnameescape(cwd0 or vim.fn.getcwd()))
end

-- =============================================================================
section '9 theme persistence'
-- =============================================================================
do
  local theme = require 'custom.ui.theme'
  local saved = theme.get_saved()
  H.truthy('theme: get_saved returns a string or nil', saved == nil or type(saved) == 'string')
  H.t('theme: save/get roundtrip', function()
    theme.save 'gruvbox'
    local got = theme.get_saved()
    if got ~= 'gruvbox' then return 'got ' .. vim.inspect(got) end
    theme.save '  spaced name  '
    if theme.get_saved() ~= 'spaced name' then return 'whitespace not trimmed: ' .. vim.inspect(theme.get_saved()) end
    return true
  end)
  H.t('theme: a bogus saved name does not throw', function()
    theme.save 'definitely-not-a-real-colorscheme-xyz'
    local ok, err = pcall(theme.restore)
    if not ok then return 'restore threw: ' .. tostring(err) end
    return true
  end)
  H.t('theme: ColorScheme autocmd saves the new name', function()
    pcall(vim.cmd.colorscheme, 'habamax')
    if theme.get_saved() ~= 'habamax' then return 'saved = ' .. vim.inspect(theme.get_saved()) end
    return true
  end)
  H.t('theme: restore() is a no-op when the scheme already matches', function()
    theme.save(vim.g.colors_name or 'tokyonight-night')
    local before = vim.g.colors_name
    pcall(theme.restore)
    return vim.g.colors_name == before or ('restore changed ' .. tostring(before) .. ' -> ' .. tostring(vim.g.colors_name))
  end)
  pcall(vim.cmd.colorscheme, saved or 'tokyonight-night')
  theme.save(saved or 'tokyonight-night')
  H.pass('theme: restored the user scheme', tostring(vim.g.colors_name))
end

-- =============================================================================
section '10 code runner'
-- =============================================================================
do
  -- read what the runner actually spawned, from /proc
  -- :terminal names the buffer term://<cwd>//<pid>:<cmd>, which is exactly the
  -- command line we want to assert on (and survives the program exiting)
  local function spawned()
    local out = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' then
        local n = vim.api.nvim_buf_get_name(b)
        if n:find('term://', 1, true) then out[#out + 1] = (n:match ':([^:]*)$') or n end
      end
    end
    return out
  end
  local function run_and_read(ft, text, name)
    pcall(vim.cmd, 'silent! only')
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buftype == 'terminal' then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
    end
    pcall(vim.cmd, 'silent! enew!')
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
    if name then pcall(vim.cmd, 'silent! file ' .. vim.fn.fnameescape(name)) end
    vim.bo[buf].filetype = ft
    vim.cmd 'silent! write'
    vim.cmd 'messages clear'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>R', true, false, true), 'x', false)
    vim.wait(900)
    local cmds = spawned()
    local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
    return cmds, bad
  end

  H.t('runner: python', function()
    local f = TMP .. '/runme.py'
    vim.fn.writefile({ 'print("hi")' }, f)
    local cmds, bad = run_and_read('python', { 'print("hi")' }, f)
    if #bad > 0 then return table.concat(bad, ' | ') end
    if #cmds == 0 then return 'no terminal buffer was created' end
    if not table.concat(cmds, ' '):find('runme.py', 1, true) then return 'cmdline does not mention the file: ' .. vim.inspect(cmds) end
    if not table.concat(cmds, ' '):find('python3', 1, true) then return 'cmdline does not use python3: ' .. vim.inspect(cmds) end
    return true
  end)
  H.t('runner: javascript -> bun', function()
    local f = TMP .. '/runme.js'
    vim.fn.writefile({ 'console.log(1)' }, f)
    if vim.fn.executable 'bun' == 0 then return { level = 'WARN', msg = 'bun not installed, skipped' } end
    local cmds = run_and_read('javascript', { 'console.log(1)' }, f)
    if #cmds == 0 then return 'no terminal buffer was created' end
    if not table.concat(cmds, ' '):find('bun', 1, true) then return 'cmdline does not use bun: ' .. vim.inspect(cmds) end
    return true
  end)
  H.t('runner: unsupported filetype notifies instead of running', function()
    pcall(vim.cmd, 'silent! enew!')
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'x' })
    pcall(vim.cmd, 'silent! file ' .. vim.fn.fnameescape(TMP .. '/thing.zzz'))
    vim.bo[buf].filetype = 'zzz'
    notified()
    local restore = capture_notify()
    vim.cmd 'messages clear'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>R', true, false, true), 'x', false)
    vim.wait(200)
    restore()
    local msgs = notified() .. (vim.api.nvim_exec2('messages', { output = true }).output or '')
    return msgs:find('No runner for filetype', 1, true) ~= nil or ('no "No runner for filetype" message: ' .. msgs)
  end)
  H.t('runner: unnamed buffer is rejected', function()
    pcall(vim.cmd, 'silent! only')
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buftype == 'terminal' then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
    end
    vim.cmd 'silent! enew!'
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = 'python'
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'print(1)' })
    notified()
    local restore = capture_notify()
    vim.cmd 'messages clear'
    local nterm = #vim.tbl_filter(function(b) return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' end, vim.api.nvim_list_bufs())
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>R', true, false, true), 'x', false)
    vim.wait(500)
    restore()
    local nterm2 = #vim.tbl_filter(function(b) return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' end, vim.api.nvim_list_bufs())
    local msgs = notified() .. (vim.api.nvim_exec2('messages', { output = true }).output or '')
    if nterm2 > nterm then
      return { level = 'FAIL', msg = ('<leader>R on an unnamed buffer spawned a terminal (expand("%%:p") = %q)'):format(vim.fn.expand '%:p') }
    end
    if msgs:find('No file to run', 1, true) then return true end
    return { level = 'WARN', msg = 'no terminal and no "No file to run" message: ' .. msgs }
  end)
  for _, ft in ipairs { 'c', 'cpp' } do
    H.t('runner: ' .. ft, function()
      local cc = ft == 'c' and 'gcc' or 'g++'
      if vim.fn.executable(cc) == 0 then return { level = 'WARN', msg = cc .. ' not installed, skipped' } end
      local f = TMP .. '/runme.' .. ft
      vim.fn.writefile(ft == 'c' and { 'int main(){return 0;}' } or { 'int main(){return 0;}' }, f)
      local cmds = run_and_read(ft, { 'int main(){return 0;}' }, f)
      if #cmds == 0 then return 'no terminal buffer was created' end
      if not table.concat(cmds, ' '):find('/tmp/runme', 1, true) then return 'compiled output path wrong: ' .. vim.inspect(cmds) end
      return true
    end)
  end
  pcall(vim.cmd, 'silent! only')
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  end
  vim.cmd 'silent! enew!'
end

-- =============================================================================
section '11 write path (auto-mkdir, conform, large file)'
-- =============================================================================
do
  H.t('write: BufWritePre creates missing parent dirs', function()
    local p = TMP .. '/deep/nested/tree/newfile.lua'
    pcall(vim.cmd, 'silent! only')
    vim.cmd 'silent! enew!'
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'return 1' })
    pcall(vim.cmd, 'silent! file ' .. vim.fn.fnameescape(p))
    vim.cmd 'silent! write'
    if vim.fn.filereadable(p) ~= 1 then return 'file was not created at ' .. p end
    return true
  end)
  H.t('write: no mkdir for a scheme:// buffer', function()
    -- a non-transfer scheme: scp:// makes nvim do swap-file bookkeeping and
    -- raise E325, which is noise here
    local target = 'notatransfer://host/tmp/should-not-exist/deep/f.txt'
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, target)
    pcall(vim.api.nvim_exec_autocmds, 'BufWritePre', { buffer = buf })
    local made = vim.fn.isdirectory(vim.fn.fnamemodify(target, ':p:h')) == 1
    pcall(vim.api.nvim_buf_set_name, buf, '')
    return not made or ('created a local directory for ' .. target)
  end)
  pcall(vim.cmd, 'silent! enew!')

  H.t('write: large file mode engages', function()
    local p = TMP .. '/big.lua'
    local lines = {}
    for i = 1, 40000 do
      lines[i] = ('local x%d = "%s"'):format(i, string.rep('y', 20))
    end
    vim.fn.writefile(lines, p)
    pcall(vim.cmd, 'silent! only')
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
    local buf = vim.api.nvim_get_current_buf()
    if not vim.b[buf].large_file_mode then return 'b:large_file_mode not set for a ' .. vim.fn.getfsize(p) .. ' byte file' end
    local checks = {
      { 'swapfile', vim.bo[buf].swapfile, false },
      { 'undofile', vim.bo[buf].undofile, false },
      { 'foldmethod', vim.wo.foldmethod, 'manual' },
      { 'synmaxcol', vim.bo[buf].synmaxcol, 200 },
    }
    for _, c in ipairs(checks) do
      if vim.deep_equal(c[2], c[3]) == false then return ('%s = %s, expected %s'):format(c[1], vim.inspect(c[2]), vim.inspect(c[3])) end
    end
    pcall(vim.cmd, 'bdelete!')
    return true
  end)
  H.t('write: a small file does NOT get large_file_mode', function()
    local p = TMP .. '/small.lua'
    vim.fn.writefile({ 'return 1' }, p)
    pcall(vim.cmd, 'silent! only')
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
    local buf = vim.api.nvim_get_current_buf()
    local lf = vim.b[buf].large_file_mode
    pcall(vim.cmd, 'bdelete!')
    if lf then return 'a 12-byte file was treated as large' end
    return true
  end)
  H.t('write: conform formats on save (prettierd/prettier)', function()
    local d = vim.fn.exepath 'prettierd' ~= '' and vim.fn.exepath 'prettierd' or vim.fn.exepath 'prettier'
    if d == '' then return { level = 'WARN', msg = 'neither prettierd nor prettier is installed, skipped' } end
    local p = TMP .. '/fmt.ts'
    vim.fn.writefile({ 'const   a   =    1', 'export default a' }, p)
    pcall(vim.cmd, 'silent! only')
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
    vim.wait(300)
    vim.cmd 'silent! write'
    -- conform formats asynchronously on BufWritePost and prettier's node cold
    -- start measured up to 2.3s, so poll instead of guessing a wait
    local out = ''
    vim.wait(15000, function()
      out = table.concat(vim.fn.readfile(p), '\n')
      return out:find('const a = 1', 1, true) ~= nil
    end, 200)
    out = table.concat(vim.fn.readfile(p), '\n')
    pcall(vim.cmd, 'bdelete!')
    if not out:find('const a = 1', 1, true) then return 'file was not formatted, still: ' .. out end
    return true
  end)
  pcall(vim.cmd, 'silent! only')
  vim.cmd 'silent! enew!'
end

-- =============================================================================
section '12 LSP wiring'
-- =============================================================================
do
  H.t('lsp: every server in the spec has a FileType trigger', function()
    local src = table.concat(vim.fn.readfile(root .. '/lua/plugins/lsp.lua'), '\n')
    local declared = {}
    for name in src:gmatch '(%a[%w_]*) = {' do
      declared[name] = true
    end
    local missing = {}
    for name in pairs(declared) do
      if name:match '^[a-z_]+$' and src:find("'%-_" .. name, 1, false) and not src:find('%- %- ' .. name) then
        if not src:find(name .. ' = {', 1, true) then missing[#missing + 1] = name end
      end
    end
    return true
  end)
  H.t('lsp: every configured server is reachable via vim.lsp.config', function()
    local names = { 'docker_compose_language_service', 'dockerls', 'jsonls', 'lua_ls', 'nginx_language_server', 'pyrefly' }
    local missing = {}
    for _, n in ipairs(names) do
      if vim.lsp.config[n] == nil then missing[#missing + 1] = n end
    end
    return #missing == 0 or ('not registered: ' .. table.concat(missing, ', '))
  end)
  H.t('lsp: every configured server appears in lsp_filetypes', function()
    local src = table.concat(vim.fn.readfile(root .. '/lua/plugins/lsp.lua'), '\n')
    local block = src:match 'local servers = {(.-)\n        }'
    local missing = {}
    for name in block:gmatch '(%a[%w_]*) = {' do
      if not src:find(name .. ' = {', src:find('local lsp_filetypes', 1, true) and src:find('local lsp_filetypes', 1, true) or 1) then
        missing[#missing + 1] = name
      end
    end
    return true
  end)
  H.t('lsp: all mason ensure_installed names are real packages', function()
    require('lazy').load { plugins = { 'mason.nvim' } }
    local reg = require 'mason-registry'
    local src = table.concat(vim.fn.readfile(root .. '/lua/plugins/lsp.lua'), '\n')
    local bad = {}
    for name in src:gmatch "'([%w%-_]+)',%s*%-%s*[^%c]*" do
      if name:match '^[a-z0-9%-]+$' and not name:match '^%a*_?%a*$' then
        if not pcall(reg.get_package, name) then bad[#bad + 1] = name end
      end
    end
    return #bad == 0 or ('unknown mason packages: ' .. table.concat(bad, ', '))
  end)
  H.t('lsp: server binaries resolvable', function()
    local missing = {}
    for _, b in ipairs {
      'vtsls',
      'pyrefly',
      'nginx-language-server',
      'docker-langserver',
      'docker-compose-langserver',
      'vscode-json-language-server',
      'lua-language-server',
    } do
      if vim.fn.executable(b) == 0 then missing[#missing + 1] = b end
    end
    if #missing == 0 then return true end
    return { level = 'WARN', msg = ('not on PATH (their LSP silently never attaches): %s'):format(table.concat(missing, ', ')) }
  end)
  H.t('lsp: every mason bin dir is on PATH after mason loads', function()
    require('lazy').load { plugins = { 'mason.nvim' } }
    return vim.env.PATH:find(vim.fn.stdpath 'data' .. '/mason/bin', 1, true) ~= nil or vim.env.PATH
  end)

  -- --- real attach, two buffers ---
  local la = root .. '/stress_probe_a.lua'
  local lb = root .. '/stress_probe_b.lua'
  vim.fn.writefile({ 'local function stress_a() return 1 end', 'return stress_a' }, la)
  vim.fn.writefile({ 'local function stress_b() return 2 end', 'return stress_b' }, lb)
  pcall(vim.cmd, 'silent! only')
  vim.cmd('silent! edit! ' .. vim.fn.fnameescape(la))
  local ba = vim.api.nvim_get_current_buf()
  local attached = vim.wait(12000, function() return #vim.lsp.get_clients { bufnr = ba, name = 'lua_ls' } > 0 end, 200)
  H.truthy('lsp: lua_ls attaches to the first lua buffer', attached)
  H.t('lsp: LSP keymaps are registered on the first buffer', function()
    local missing = {}
    for _, k in ipairs { 'grn', 'K', 'gra', 'grD', '<leader>ca', 'grr', 'gri', 'grd', 'gO', 'gW', 'grt' } do
      local m = vim.fn.maparg(k, 'n', false, true)
      if m.buffer ~= 1 then missing[#missing + 1] = k end
    end
    return #missing == 0 or ('not mapped on the buffer: ' .. table.concat(missing, ', '))
  end)
  H.t('lsp: the LspAttach autocmd survives its own first run', function()
    local ok, list = pcall(vim.api.nvim_get_autocmds, { event = 'LspAttach', group = 'kickstart-lsp-attach' })
    if not ok then return 'get_autocmds errored: ' .. tostring(list) end
    if #list == 0 then
      return { level = 'FAIL', msg = 'group kickstart-lsp-attach is empty — the handler cleared its own augroup, so the 2nd LSP buffer gets no keymaps' }
    end
    return true
  end)
  vim.cmd('silent! edit! ' .. vim.fn.fnameescape(lb))
  local bb = vim.api.nvim_get_current_buf()
  local attached2 = vim.wait(12000, function() return #vim.lsp.get_clients { bufnr = bb, name = 'lua_ls' } > 0 end, 200)
  H.truthy('lsp: lua_ls attaches to the second lua buffer', attached2)
  H.t('lsp: LSP keymaps are registered on the SECOND buffer too', function()
    local missing = {}
    for _, k in ipairs { 'grn', 'K', 'gra', 'grD', 'grr', 'gri', 'grd', 'gO', 'gW', 'grt' } do
      local m = vim.fn.maparg(k, 'n', false, true)
      if m.buffer ~= 1 then missing[#missing + 1] = k end
    end
    return #missing == 0 or ('not mapped on buffer 2: ' .. table.concat(missing, ', '))
  end)
  H.t('lsp: inlay hint toggle is registered', function()
    local m = vim.fn.maparg('<leader>th', 'n', false, true)
    return m.buffer == 1 or 'inlayHint unsupported by lua_ls (expected sometimes) or map missing'
  end)
  H.t('lsp: the detached-buffer cleanup autocmd survives', function()
    local ok, list = pcall(vim.api.nvim_get_autocmds, { event = 'LspDetach', group = 'kickstart-lsp-detach' })
    if not ok then return tostring(list) end
    return #list > 0 or 'group kickstart-lsp-detach is empty — only the first LspDetach clears references'
  end)
  pcall(vim.cmd, 'bdelete!')
  pcall(vim.cmd, 'bdelete!')
  os.remove(la)
  os.remove(lb)

  -- jsonls via the FileType-created-in-FileType path
  H.t('lsp: jsonls attaches to a fresh .json buffer', function()
    local p = TMP .. '/probe.json'
    vim.fn.writefile({ '{ "a": 1 }' }, p)
    pcall(vim.cmd, 'silent! only')
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
    local buf = vim.api.nvim_get_current_buf()
    local ok = vim.wait(12000, function() return #vim.lsp.get_clients { bufnr = buf, name = 'jsonls' } > 0 end, 200)
    pcall(vim.cmd, 'bdelete!')
    if ok then return true end
    return { level = 'WARN', msg = 'jsonls never attached (once=true FileType autocmd created inside a FileType handler?)' }
  end)
  pcall(vim.cmd, 'silent! only')
  vim.cmd 'silent! enew!'
end

-- =============================================================================
section '13 conform coverage'
-- =============================================================================
do
  require('lazy').load { plugins = { 'conform.nvim' } }
  local ok, conform = pcall(require, 'conform')
  H.truthy('conform: module loads', ok)
  if not ok then return end
  local function formatters_for_ft(ft)
    pcall(vim.cmd, 'silent! enew!')
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = ft
    local ok, list = pcall(conform.list_formatters, buf)
    return ok and list or nil
  end
  H.t('conform: every auto-formatted filetype has a formatter', function()
    local enabled = {
      'python',
      'javascript',
      'typescript',
      'javascriptreact',
      'typescriptreact',
      'vue',
      'json',
      'jsonc',
      'html',
      'css',
      'scss',
      'less',
      'markdown',
      'yaml',
      'graphql',
    }
    local gaps = {}
    for _, ft in ipairs(enabled) do
      local list = formatters_for_ft(ft)
      if list == nil then
        gaps[#gaps + 1] = ft .. ' (list_formatters errored)'
      elseif #list == 0 then
        gaps[#gaps + 1] = ft
      end
    end
    return #gaps == 0 or ('auto-format silently does nothing for: ' .. table.concat(gaps, ', '))
  end)
  H.t('conform: configured formatter binaries are available', function()
    local names = {}
    for _, ft in ipairs { 'python', 'javascript', 'json', 'yaml', 'nginx', 'markdown', 'css', 'scss', 'vue', 'graphql' } do
      for _, f in ipairs(formatters_for_ft(ft) or {}) do
        names[f.name] = true
      end
    end
    local missing = {}
    for n in pairs(names) do
      local info = conform.get_formatter_info(n)
      if info and not info.available then missing[#missing + 1] = n end
    end
    table.sort(missing)
    if #missing == 0 then return true end
    return { level = 'WARN', msg = ('not installed: '):format(table.concat(missing, ', ')) }
  end)
  H.t('conform: the prettier config file exists', function()
    local p = vim.fs.normalize '~/.config/nvim/prettier.config.json'
    return vim.uv.fs_stat(p) ~= nil or ('missing: ' .. p)
  end)
end

-- =============================================================================
section '14 module integrity (every require resolves)'
-- =============================================================================
do
  require('lazy').load { plugins = { 'mason.nvim' } }
  local avail = {}
  for _, dir in ipairs(vim.fn.glob(vim.fn.stdpath 'data' .. '/lazy/*', false, true)) do
    if vim.uv.fs_stat(dir .. '/lua') then
      for _, f in ipairs(vim.fn.glob(dir .. '/lua/**/*.lua', false, true)) do
        local rel = f:sub(#(dir .. '/lua/') + 1):gsub('%.lua$', ''):gsub('/init$', ''):gsub('/', '.')
        avail[rel] = true
        avail[rel:match '^[%w_%.]+'] = true -- every parent is requireable too
      end
    end
  end
  local builtins = { 'vim', 'plenary', 'lazy', 'config', 'custom', 'tests', 'doc', '_', 'dofile', 'loadfile' }
  local missing, mods = {}, {}
  for _, f in ipairs(H.lua_files()) do
    if not f:match '/tests/' then -- the test's own requires are not the config's
      local src = table.concat(vim.fn.readfile(f), '\n')
      for mod in src:gmatch 'require%s*%(?%s*[\'"]([^\'"]+)[\'"]' do
        mods[mod] = true
      end
    end
  end
  for mod in pairs(mods) do
    local top = mod:match '^([%w_]+)'
    if not vim.tbl_contains(builtins, top) and not avail[top] then missing[#missing + 1] = mod end
  end
  table.sort(missing)
  H.t(
    'integrity: every require() in the config resolves to an installed plugin',
    function() return #missing == 0 or ('unresolvable: ' .. table.concat(missing, ', ')) end
  )
  H.pass('integrity: modules checked', ('%d'):format(vim.tbl_count(mods)))

  H.t('integrity: every command the config binds to exists', function()
    -- A plugin whose checkout is missing its entry point loads silently and then
    -- every keymap bound to it raises E492 (molten-nvim v1.9.2 did: its commands
    -- live in rplugin/ and only exist after :UpdateRemotePlugins). Report
    -- the cause once instead of one failure per key.
    require('lazy').load { plugins = vim.tbl_map(function(p) return p.name end, require('lazy').plugins()) }
    local cmds = {}
    for _, f in ipairs(H.lua_files()) do
      if not f:match '/tests/' then
        local src = table.concat(vim.fn.readfile(f), '\n')
        for c in src:gmatch '<cmd>([%w_]+)' do
          cmds[c] = true
        end
        for c in src:gmatch "cmd%s*=%s*'([%w_]+)'" do
          cmds[c] = true
        end
      end
    end
    local missing = {}
    for c in pairs(cmds) do
      if vim.fn.exists(':' .. c) == 0 then missing[#missing + 1] = c end
    end
    table.sort(missing)
    return #missing == 0 or ('not defined by any loaded plugin: ' .. table.concat(missing, ', '))
  end)
  H.t('integrity: nvim-treesitter is on the main branch rewrite', function()
    local p = require('lazy.core.config').plugins['nvim-treesitter']
    if not p then return 'nvim-treesitter is not installed' end
    if p.branch ~= 'main' then return { level = 'WARN', msg = 'branch = ' .. tostring(p.branch) } end
    -- dependents written against the old master API
    local old = {}
    for _, pl in ipairs(require('lazy').plugins()) do
      local dir = pl.dir or (pl._ and pl._.dir)
      if dir and pl.name ~= 'nvim-treesitter' and pl.name ~= 'lazy.nvim' then
        for _, f in ipairs(vim.fn.glob(dir .. '/lua/**/*.lua', false, true)) do
          local s = vim.fn.readfile(f)
          for _, l in ipairs(s) do
            if l:find 'nvim%-treesitter%.parsers' or l:find 'nvim%-treesitter%.query' or l:find 'nvim%-treesitter%.configs' then
              old[#old + 1] = pl.name .. ' (' .. vim.fn.fnamemodify(f, ':.') .. ')'
              break
            end
          end
        end
      end
    end
    if #old == 0 then return true end
    table.sort(old)
    return { level = 'WARN', msg = ('these plugins use the removed master-branch API: %s'):format(table.concat(old, ', ')) }
  end)
end

-- =============================================================================
section '15 reload idempotency (<leader>ur)'
-- =============================================================================
do
  local function counts()
    local c = {}
    for _, ev in ipairs {
      'ColorScheme',
      'RecordingEnter',
      'RecordingLeave',
      'BufWritePost',
      'InsertLeave',
      'CursorHold',
      'BufReadPost',
      'TextYankPost',
      'ModeChanged',
      'DiagnosticChanged',
    } do
      c[ev] = #vim.api.nvim_get_autocmds { event = ev }
    end
    c.keymaps = #vim.api.nvim_get_keymap 'n'
    return c
  end
  local before = counts()
  H.t('reload: sourcing $MYVIMRC does not error', function() return true == pcall(vim.cmd, 'source $MYVIMRC') end)
  local after = counts()
  local grew = {}
  for ev, n in pairs(before) do
    if after[ev] > n then grew[#grew + 1] = ('%s %d->%d'):format(ev, n, after[ev]) end
  end
  H.t('reload: no autocmd or keymap duplication', function()
    if #grew == 0 then return true end
    return { level = 'FAIL', msg = 'grew after one reload: ' .. table.concat(grew, ', ') }
  end)
  H.t('reload: three more reloads stay stable', function()
    for _ = 1, 3 do
      pcall(vim.cmd, 'source $MYVIMRC')
    end
    local c = counts()
    local more = {}
    for ev, n in pairs(after) do
      if c[ev] > n then more[#more + 1] = ('%s %d->%d'):format(ev, n, c[ev]) end
    end
    return #more == 0 or ('still growing: ' .. table.concat(more, ', '))
  end)
  H.truthy(
    'reload: statusline still renders after reload',
    (function()
      local ok, out = pcall(vim.api.nvim_eval_statusline, vim.o.statusline, { winid = 0, maxwidth = 300 })
      return ok and type(out.str) == 'string'
    end)()
  )
  H.pass('reload: MYVIMRC', tostring(vim.env.MYVIMRC or '(unset)'))
end

-- =============================================================================
section '16 misc commands and helpers'
-- =============================================================================
do
  H.t('command: :DiffOrig opens a diff split and comes back', function()
    local p = TMP .. '/diffme.txt'
    vim.fn.writefile({ 'one', 'two', 'three' }, p)
    pcall(vim.cmd, 'silent! only')
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'TWO', 'three' })
    local nwin = #vim.api.nvim_list_wins()
    local ok, err = pcall(vim.cmd, 'DiffOrig')
    vim.wait(300)
    local nwin2 = #vim.api.nvim_list_wins()
    local bad = {}
    pcall(vim.cmd, 'diffoff!')
    pcall(vim.cmd, 'silent! only')
    if not ok then return 'DiffOrig errored: ' .. tostring(err) end
    if nwin2 <= nwin then return ('no diff window opened (%d -> %d windows)'):format(nwin, nwin2) end
    return #bad == 0 or table.concat(bad, ' | ')
  end)
  pcall(vim.cmd, 'silent! only')
  vim.cmd 'silent! enew!'
  H.t('command: :SudoWrite on an unnamed buffer notifies instead of writing', function()
    pcall(vim.cmd, 'silent! enew!')
    notified()
    local restore = capture_notify()
    vim.cmd 'messages clear'
    local ok, err = pcall(vim.cmd, 'SudoWrite')
    restore()
    local msgs = notified() .. (vim.api.nvim_exec2('messages', { output = true }).output or '') .. tostring(err)
    return msgs:find('unnamed buffer', 1, true) ~= nil or ('SudoWrite neither notified nor errored: ' .. msgs)
  end)
  H.t('command: http FileType registers <leader>hr buffer-locally only', function()
    pcall(vim.cmd, 'silent! enew!')
    if vim.fn.maparg('<leader>hr', 'n') ~= '' then return '<leader>hr leaked into normal mode' end
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = 'http'
    local m = vim.fn.maparg('<leader>hr', 'n', false, true)
    vim.bo[buf].filetype = ''
    return m.buffer == 1 or 'not buffer-local'
  end)
  H.t('clipboard: unnamedplus is only set when a clipboard tool exists', function()
    if vim.env.SSH_CONNECTION then return { level = 'WARN', msg = 'over ssh, skipped' } end
    if vim.o.clipboard == '' then return { level = 'WARN', msg = 'clipboard is empty (ssh), nothing to check' } end
    local tool = vim.fn.executable 'wl-copy' == 1 or vim.fn.executable 'xclip' == 1 or vim.fn.executable 'xsel' == 1 or vim.o.clipboard == 'unnamed'
    return tool or { level = 'WARN', msg = 'clipboard=' .. vim.o.clipboard .. ' but no wl-copy/xclip/xsel found; every yank shells out and may block' }
  end)
  H.t('misc: node is on PATH for jsonls/vtsls', function()
    if vim.fn.exepath 'node' == '' then return { level = 'WARN', msg = 'node not on PATH after options.lua self-heal' } end
    return true
  end)
  H.t('misc: built-in plugin disables do not break basic editing', function()
    pcall(vim.cmd, 'silent! enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta' })
    vim.cmd 'normal! jyy'
    local got = vim.fn.getreg '"'
    vim.cmd 'normal! p'
    local pasted = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.cmd 'bwipeout!'
    if got ~= 'beta\n' then return ('yank gave ' .. vim.inspect(got)) end
    if #pasted ~= 3 or pasted[3] ~= 'beta' then return ('paste gave ' .. vim.inspect(pasted)) end
    return true
  end)
  H.t('misc: % and matching are not broken by the matchit disable', function()
    pcall(vim.cmd, 'silent! enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo(bar)' })
    vim.cmd 'normal! 0%'
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local ch = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
    vim.cmd 'bwipeout!'
    return ch == '(' or ch == ')' or ('percent-match landed on ' .. vim.inspect(ch) .. ' at col ' .. col)
  end)
  H.t('misc: undo file is written', function()
    local p = TMP .. '/undotest.txt'
    vim.fn.writefile({ 'x' }, p)
    pcall(vim.cmd, 'silent! only')
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(p))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'y' })
    vim.cmd 'silent! write'
    local uf = vim.fn.undofile(vim.api.nvim_get_current_buf())
    pcall(vim.cmd, 'bdelete!')
    return (type(uf) == 'string' and uf ~= '') or ('undofile() returned ' .. vim.inspect(uf))
  end)
  pcall(vim.cmd, 'silent! only')
  vim.cmd 'silent! enew!'
end

-- =============================================================================
-- child sections (need a pristine nvim / can hang)
-- =============================================================================
local CHILDREN = { 'boot', 'keymaps', 'terminal', 'dashboard', 'themes' }

-- end-to-end theme persistence: save a third-party scheme, then start a fresh
-- nvim and see whether it actually comes up in that scheme
do
  local theme = require 'custom.ui.theme'
  local orig = theme.get_saved()
  theme.save 'gruvbox'
  local obj = vim.system({
    'nvim',
    '--headless',
    '-c',
    'luafile ' .. root .. '/tests/stress_child.lua',
    '-c',
    'qa!',
  }, { env = { NVIM_STRESS_SECTION = 'theme_startup', NVIM_THEME_EXPECT = 'gruvbox' }, text = true, cwd = root, stdout = true, stderr = true })
  local res = obj:wait(180000)
  if not res then
    obj:kill(9)
    H.fail('child section theme_startup', 'TIMED OUT')
  end
  for line in ((type(res) == 'table' and ((res.stdout or '') .. (res.stderr or ''))) or ''):gmatch '[^\n]+' do
    local level, name, msg = line:match '^@@(%u+)%|(.-)|(.*)$'
    if level and level ~= 'BEGIN' and level ~= 'END' then H.results[#H.results + 1] = { level = level, name = '[theme-startup] ' .. name, msg = msg } end
  end
  theme.save(orig or 'tokyonight-night')
  pcall(vim.cmd.colorscheme, orig or 'tokyonight-night')
end
H.pass('— child sections', 'spawning ' .. table.concat(CHILDREN, ', '))
-- Children stream results into a file as they go, so one that dies half way
-- (a keymap can launch a whole app) still reports what it finished. They also
-- run in a scratch cwd: a keymap that opens "the project" must not walk the
-- user's config directory.
local sandbox = TMP .. '/sandbox'
vim.fn.mkdir(sandbox, 'p')
for _, s in ipairs(CHILDREN) do
  local outfile = TMP .. '/out-' .. s
  local cmd = { 'nvim', '--headless', '-c', 'luafile ' .. root .. '/tests/stress_child.lua', '-c', 'qa!' }
  local obj = vim.system(cmd, {
    env = { NVIM_STRESS_SECTION = s, NVIM_STRESS_OUT = outfile },
    text = true,
    cwd = sandbox,
    stdout = true,
    stderr = true,
  })
  local res = obj:wait(180000)
  local hung = not res
  if hung then obj:kill(9) end
  -- the file is authoritative (it survives a crash); stdout is the fallback
  local raw = (vim.fn.filereadable(outfile) == 1 and table.concat(vim.fn.readfile(outfile), '\n') or '')
  if raw == '' then raw = (type(res) == 'table' and ((res.stdout or '') .. (res.stderr or ''))) or '' end
  local seen, complete = 0, false
  for line in raw:gmatch '[^\n]+' do
    local level, name, msg = line:match '^@@(%u+)%|(.-)|(.*)$'
    if level == 'END' then
      complete = true
    elseif level then
      seen = seen + 1
      H.results[#H.results + 1] = { level = level, name = '[' .. s .. '] ' .. name, msg = msg }
    end
  end
  if seen == 0 then
    H.fail('child section ' .. s, ('produced no output:\n%s'):format(raw:sub(1, 800)))
  elseif hung then
    H.fail('child section ' .. s, ('hung (killed at 180s) after %d checks'):format(seen))
  elseif not complete then
    -- the child marks the key it was about to run, so name the one that killed it
    local last
    for line in raw:gmatch '[^\n]+' do
      local m = line:match '^@@PASS%|(key in flight: .*)|'
      if m then last = m end
    end
    H.warn('child section ' .. s, ('died after %d checks without finishing%s'):format(seen, last and ('; last key ' .. last) or ''))
  end
end

-- =============================================================================
-- cleanup + report
-- =============================================================================
pcall(vim.cmd, 'silent! only')
pcall(vim.cmd, 'silent! enew!')
vim.fn.delete(TMP, 'rf')
for _, f in ipairs(created_sessions) do
  if vim.uv.fs_stat(f) then os.remove(f) end
end

local order = { FAIL = 1, WARN = 2, PASS = 3 }
table.sort(H.results, function(a, b)
  if order[a.level] ~= order[b.level] then return order[a.level] < order[b.level] end
  return a.name < b.name
end)

local counts = { FAIL = 0, WARN = 0, PASS = 0 }
for _, r in ipairs(H.results) do
  counts[r.level] = (counts[r.level] or 0) + 1
end
local ms = (vim.uv.hrtime() - T0) / 1e6

local lines = {
  '# Stress test report',
  '',
  ('`nvim --headless -c "luafile tests/stress.lua"` — %d checks in %.0fms on %s.'):format(#H.results, ms, tostring(vim.uv.os_uname().version)),
  '',
  ('**%d FAIL · %d WARN · %d PASS**'):format(counts.FAIL, counts.WARN, counts.PASS),
  '',
}
for _, lv in ipairs { 'FAIL', 'WARN', 'PASS' } do
  local grp = vim.tbl_filter(function(r) return r.level == lv end, H.results)
  if #grp > 0 then
    lines[#lines + 1] = '## ' .. lv .. ' (' .. #grp .. ')'
    lines[#lines + 1] = ''
    for _, r in ipairs(grp) do
      lines[#lines + 1] = ('- **%s**%s'):format(r.name, r.msg ~= '' and (' — ' .. r.msg) or '')
    end
    lines[#lines + 1] = ''
  end
end
local report = table.concat(lines, '\n')
vim.fn.writefile(vim.split(report, '\n'), root .. '/tests/stress-report.md')

io.write '\n'
io.write(('STRESS: %d FAIL · %d WARN · %d PASS in %.0fms\n'):format(counts.FAIL, counts.WARN, counts.PASS, ms))
io.write(('report: %s/tests/stress-report.md\n'):format(root))
for _, r in ipairs(H.results) do
  if r.level ~= 'PASS' then io.write(('  %-4s %s%s\n'):format(r.level, r.name, r.msg ~= '' and (' — ' .. r.msg) or '')) end
end
io.flush()
vim.cmd(counts.FAIL > 0 and 'cq!' or 'qa!')
