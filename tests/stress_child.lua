-- Stress-test child process. Dispatched by $NVIM_STRESS_SECTION from
-- tests/stress.lua so destructive sections (real terminals, :colorscheme,
-- dashboard rewrite) get a clean nvim and can be killed by a timeout.
--
--   nvim --headless -c 'luafile tests/stress_child.lua'
--
local H = dofile(vim.fn.stdpath 'config' .. '/tests/stress_harness.lua')
local section = vim.env.NVIM_STRESS_SECTION or '?'

-- Watchdog: whatever happens, this nvim exits on its own. Generous on purpose —
-- the keymaps section lazy-loads most of the plugin tree and waits on each
-- mapping, which takes well over 25s. The parent enforces its own timeout.
local watchdog = (vim.uv or vim.loop).new_timer()
watchdog:start(150000, 0, function()
  vim.schedule(function() vim.cmd 'cq!' end)
end)

local function scratch()
  vim.cmd 'enew!'
  return vim.api.nvim_get_current_buf()
end

-- stub anything that would block on human input
local function stub_input()
  vim.ui.input = function(_, cb)
    if cb then cb '' end
  end
  vim.ui.select = function(_, _, cb)
    if cb then cb(nil) end
  end
end

-- =============================================================================
local S = {}

-- -----------------------------------------------------------------------------
S.boot = function()
  -- 1. clean startup: drain :messages, anything error-level is a boot bug
  vim.cmd 'messages clear'
  vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
  vim.wait(200)
  local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
  H.t('boot: no errors in :messages', function()
    if #bad == 0 then return true end
    return table.concat(bad, ' | ')
  end)

  -- 2. lazy + core wiring is live
  H.truthy('boot: lazy.nvim setup', pcall(require, 'lazy'))
  local ok, lazy = pcall(require, 'lazy')
  H.truthy('boot: lazy reports plugin stats', ok and type(lazy.stats()) == 'table')
  H.truthy('boot: builtin statusline fn', type(_G._builtin_statusline) == 'function')
  H.truthy('boot: builtin tabline fn', type(_G._builtin_tabline) == 'function')
  H.truthy('boot: builtin tabclick fn', type(_G._builtin_tabclick) == 'function')
  H.truthy('boot: builtin UI setup()', pcall(function() require('custom.ui.init').setup() end))

  -- 3. StartupTime command exists and is a real user command
  H.truthy('boot: :StartupTime exists', vim.fn.exists ':StartupTime' == 2)
  H.truthy('boot: :SudoWrite exists', vim.fn.exists ':SudoWrite' == 2)
  H.truthy('boot: :DiffOrig exists', vim.fn.exists ':DiffOrig' == 2)

  -- 4. health check: no ERROR rows
  vim.cmd 'checkhealth config'
  local hbuf
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local okb = pcall(vim.api.nvim_buf_get_lines, b, 0, 40, false)
    if okb then
      for _, l in ipairs(vim.api.nvim_buf_get_lines(b, 0, 60, false)) do
        if l:match 'nvim%-config' then
          hbuf = b
          break
        end
      end
    end
  end
  if not hbuf then
    H.fail('health: checkhealth config produced a buffer', 'no buffer contains the nvim-config section')
    return
  end
  local lines = vim.api.nvim_buf_get_lines(hbuf, 0, -1, false)
  local errs = {}
  for _, l in ipairs(lines) do
    if l:match '%- ERROR' or l:match '^ERROR' then errs[#errs + 1] = l:match '^%s*(.-)%s*$' end
  end
  H.t('health: no ERROR rows', function()
    if #errs == 0 then return true end
    return table.concat(errs, ' | ')
  end)
  H.pass('health: row count', ('%d health rows checked'):format(#lines))
  pcall(vim.api.nvim_buf_delete, hbuf, { force = true })
end

-- -----------------------------------------------------------------------------
S.keymaps = function()
  stub_input()
  vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
  scratch()

  -- keys that are exercised in their own dedicated section
  local SKIP = {
    ['<C-\\>'] = true,
    ['q'] = true,
    ['<leader>ur'] = true,
    ['<leader>tt'] = true,
    ['<leader>tf'] = true,
    ['<leader>fg'] = true,
    ['<leader>tm'] = true,
    ['<leader>t1'] = true,
    ['<leader>t2'] = true,
    ['<leader>t3'] = true,
    ['<leader>tn'] = true,
    -- molten needs a live jupyter kernel plus image.nvim (cond=false headless,
    -- so the rplugin host tracebacks in the sandbox). Skipped here; the
    -- integrity test in tests/stress.lua still asserts every bound Molten
    -- command exists, which is what caught the MoltenHide rename.
    ['<leader>mi'] = true,
    ['<leader>ml'] = true,
    ['<leader>mv'] = true,
    ['<leader>mr'] = true,
    ['<leader>mh'] = true,
    ['<leader>md'] = true,
    ['<leader>mn'] = true,
    ['<leader>mp'] = true,
    ['<leader>mo'] = true,
    -- these launch a whole app against a real project: neotest walks the cwd
    -- for test files, grug-far and refactoring need a real buffer, dap opens
    -- its ui. Headless in a sandbox they either hang or kill the child, and
    -- they tell us nothing about the mapping itself. <leader>R is covered by
    -- the runner section of tests/stress.lua.
    ['<leader>tr'] = true,
    ['<leader>ts'] = true,
    ['<leader>to'] = true,
    ['<leader>fr'] = true,
    ['<leader>rr'] = true,
  }

  -- Vim's own defaults ([a ]a [A ]A are arglist navigation, [<C-L>]<C-L> are
  -- loclist file jumps) legitimately error in an empty scratch buffer, so only
  -- mappings this config or its plugins added are under test.
  local is_default = function(m) return type(m.desc) == 'string' and m.desc:sub(1, 1) == ':' end
  -- <Plug> targets are a plugin's private namespace, never pressed directly
  -- (<Plug>PlenaryTestFile runs a test harness and takes the process down)
  local is_plug = function(m) return m.lhs:find('<Plug>', 1, true) ~= nil end

  local seen = {}
  for _, mode in ipairs { 'n', 'x', 'v' } do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local key = mode .. '|' .. m.lhs
      if not seen[key] then
        -- SKIP uses '<leader>' form; live lhs has it resolved to mapleader
        local skipped = SKIP[m.lhs] or SKIP[m.lhs:gsub('^' .. vim.g.mapleader, '<leader>')]
        if not skipped and not is_default(m) and not is_plug(m) then
          seen[key] = true
          H.t(string.format('keymap %s %s', mode, m.lhs), function()
            H.pass('key in flight: ' .. key)
            scratch()
            vim.wait(40) -- let anything queued by the previous key land first
            vim.cmd 'messages clear'
            local keys = vim.api.nvim_replace_termcodes(m.lhs, true, false, true)
            vim.api.nvim_feedkeys(keys, 'x', false)
            vim.wait(120)
            local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
            vim.wait(60)
            vim.cmd 'messages clear' -- discard late fallout before the next key
            -- the diagnostic yank maps notify INFO when the line is clean
            if #bad == 0 then return true end
            return table.concat(bad, ' | ')
          end)
        end
      end
    end
  end
  H.pass('keymap count', ('%d unique mappings invoked'):format(vim.tbl_count(seen)))

  -- gitsigns requires a real repo; the maps above already errored in a scratch
  -- buffer if the require path were broken, so just assert the module loads
  H.t('keymap: gitsigns module loadable', function()
    require('lazy').load { plugins = { 'gitsigns.nvim' } }
    return type(require('gitsigns').nav_hunk) == 'function'
  end)
end

-- -----------------------------------------------------------------------------
S.terminal = function()
  stub_input()
  local T = {} -- record state across steps
  local function has_terminal_win()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == 'terminal' then return true end
    end
    return false
  end

  local function feed(lhs)
    vim.cmd 'messages clear'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'x', false)
    vim.wait(250)
    return H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
  end

  local function cleanup()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative ~= '' then pcall(vim.api.nvim_win_close, w, true) end
    end
    pcall(vim.cmd, 'silent! only')
  end

  -- <leader>tt : open, close, reopen the SAME buffer without spawning a 2nd job
  T.horiz = nil
  local e1 = feed '<leader>tt'
  H.t('terminal: <leader>tt opens without error', function() return #e1 == 0 or table.concat(e1, ' | ') end)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == 'terminal' then T.horiz = vim.api.nvim_win_get_buf(w) end
  end
  H.truthy('terminal: <leader>tt produced a terminal buffer', T.horiz ~= nil)
  local job = T.horiz and vim.b[T.horiz].terminal_job_id
  H.truthy('terminal: terminal has a live job', job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1, 'job already dead')

  feed '<leader>tt' -- close
  local still = false
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == T.horiz then still = true end
  end
  H.falsy('terminal: <leader>tt closes the window', still)
  H.truthy('terminal: buffer survives the close', vim.api.nvim_buf_is_valid(T.horiz or -1))

  feed '<leader>tt' -- reopen
  local reopened, job2 = nil, nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == T.horiz then reopened = w end
  end
  job2 = T.horiz and vim.b[T.horiz].terminal_job_id
  H.truthy('terminal: reopen reuses the buffer (no second job)', reopened ~= nil and job2 == job)
  vim.wait(300)
  H.truthy('terminal: reused job is still alive', vim.fn.jobwait({ job }, 0)[1] == -1)

  -- C-\ closes it
  local e2 = feed '<C-\\>'
  H.t('terminal: C-\\ closes the horiz terminal', function() return #e2 == 0 or table.concat(e2, ' | ') end)
  local gone = true
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == T.horiz then gone = false end
  end
  H.truthy('terminal: horiz window is gone after C-\\', gone)

  -- C-\ with nothing open reopens the last kind
  local e3 = feed '<C-\\>'
  H.t('terminal: C-\\ reopens when nothing is visible', function() return #e3 == 0 or table.concat(e3, ' | ') end)
  local any = false
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == 'terminal' then any = true end
  end
  H.truthy('terminal: C-\\ reopened a terminal', any)

  -- stale window: :bd the terminal buffer so the window shows something else
  local tbuf
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' and vim.b[b].terminal_job_id == job then tbuf = b end
  end
  if tbuf then pcall(vim.cmd, 'silent! bdelete! ' .. tbuf) end
  local e4 = feed '<leader>tt'
  H.t('terminal: <leader>tt recovers from a :bd-ed terminal buffer', function() return #e4 == 0 or table.concat(e4, ' | ') end)
  H.truthy('terminal: a terminal window exists again', has_terminal_win())
  cleanup()

  -- ---- float ----
  scratch()
  local before = vim.api.nvim_get_current_buf()
  local e5 = feed '<leader>tf'
  H.t('terminal: <leader>tf opens without error', function() return #e5 == 0 or table.concat(e5, ' | ') end)
  local fw
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= '' then fw = w end
  end
  H.truthy('terminal: <leader>tf created a float window', fw ~= nil)
  if fw then
    local fbuf = vim.api.nvim_win_get_buf(fw)
    T.float = fbuf
    H.truthy('terminal: float buffer is a terminal buffer', vim.bo[fbuf].buftype == 'terminal')
    H.truthy('terminal: float terminal has a live job', vim.b[fbuf].terminal_job_id ~= nil and vim.fn.jobwait({ vim.b[fbuf].terminal_job_id }, 0)[1] == -1)
    H.truthy('terminal: original buffer NOT clobbered by the float', vim.api.nvim_buf_is_valid(before) and vim.bo[before].buftype == '')
    local e6 = feed '<leader>tf'
    H.t('terminal: <leader>tf closes the float', function() return #e6 == 0 or table.concat(e6, ' | ') end)
    local stillopen = false
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative ~= '' then stillopen = true end
    end
    H.falsy('terminal: no float left after toggle off', stillopen)
  end

  -- a second, DIFFERENT command into the same float buffer
  local e7 = feed '<leader>fg'
  H.t('terminal: <leader>fg (lazygit) without error', function() return #e7 == 0 or table.concat(e7, ' | ') end)
  if T.float then
    local fbuf
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative ~= '' then fbuf = vim.api.nvim_win_get_buf(w) end
    end
    H.t('terminal: <leader>fg reuses the float buffer', function()
      if fbuf ~= T.float then return 'float buffer is ' .. tostring(fbuf) .. ', previous was ' .. tostring(T.float) end
      return true
    end)
    H.truthy('terminal: reused float buffer is a terminal buffer', vim.bo[T.float].buftype == 'terminal')
  end
  cleanup()

  -- last-window case: the terminal IS the only window
  pcall(vim.cmd, 'silent! only')
  feed '<leader>tt'
  pcall(vim.cmd, 'silent! only')
  local termwins = 0
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == 'terminal' then termwins = termwins + 1 end
  end
  if termwins > 0 then
    pcall(vim.cmd, 'silent! only')
    local e8 = feed '<C-\\>'
    H.t('terminal: C-\\ with a single terminal window (E444 path)', function()
      if #e8 == 0 then return true end
      return table.concat(e8, ' | ')
    end)
  end
  cleanup()

  -- no buffer leak across many toggles
  local t0 = #vim.api.nvim_list_bufs()
  for _ = 1, 6 do
    feed '<leader>tt'
    feed '<leader>tt'
  end
  cleanup()
  local t1 = #vim.api.nvim_list_bufs()
  H.t('terminal: 12 toggles leak at most 1 buffer', function()
    if t1 - t0 <= 1 then return true end
    return { level = 'WARN', msg = ('buffers %d -> %d'):format(t0, t1) }
  end)
end

-- -----------------------------------------------------------------------------
S.dashboard = function()
  stub_input()
  local spec = require 'custom.ui.spec'

  -- the real handler is once=true and already fired, so it is gone. Re-run
  -- setup_starter() on a fresh copy of the module to get an equivalent one back,
  -- then delete it again so the test leaves no autocmd behind.
  package.loaded['custom.ui.spec'] = nil
  require('custom.ui.spec').setup_starter()
  local cb, aid
  -- nvim 0.12 reports file=nil for lua-created autocmds, so take the newest one
  for _, a in ipairs(vim.api.nvim_get_autocmds { event = 'VimEnter' }) do
    if type(a.callback) == 'function' then
      cb, aid = a.callback, a.id
    end
  end
  if aid then pcall(vim.api.nvim_del_autocmd, aid) end
  H.truthy('dashboard: VimEnter handler is registered', type(cb) == 'function')
  if not cb then return end

  local function build(oldfiles)
    scratch()
    vim.bo.filetype = ''
    vim.v.oldfiles = oldfiles or {}
    -- mimic `nvim` with no args
    pcall(vim.cmd, 'argdelete *')
    pcall(cb)
    return vim.api.nvim_get_current_buf()
  end

  -- ---- no recents ----
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local f1 = dir .. '/alpha.lua'
  local f2 = dir .. '/beta.lua'
  vim.fn.writefile({ 'return 1' }, f1)
  vim.fn.writefile({ 'return 2' }, f2)

  local buf = build {}
  H.eq('dashboard: filetype is dashboard', 'dashboard', vim.bo[buf].filetype)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  H.truthy('dashboard: has content', #lines > 8)
  H.truthy('dashboard: buffer is not modifiable', vim.bo[buf].modifiable == false)
  H.truthy('dashboard: no crash with zero recents', true)

  local function find_line(pattern)
    for i, l in ipairs(lines) do
      if l:find(pattern, 1, true) then return i, l end
    end
  end
  -- synID() only reflects computed syntax and headless never redraws, so read
  -- the highlight extmarks the dashboard actually writes. Query the whole
  -- buffer and filter here: a single-row range to nvim_buf_get_extmarks
  -- drops marks that share the row. end_col 0 means "to end of line".
  local function hls(buf, row0)
    local out = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
      if m[2] == row0 then out[m[4].hl_group] = { col0 = m[3], end_col = m[4].end_col } end
    end
    return out
  end
  local function groups(buf, row0)
    local set = {}
    for g in pairs(hls(buf, row0)) do
      set[g] = true
    end
    return set
  end
  local function sorted_groups(buf, row0)
    local t = vim.tbl_keys(groups(buf, row0))
    table.sort(t)
    return t
  end
  local hi, hline = find_line 'New File'
  H.truthy('dashboard: New File button rendered', hi ~= nil)
  if hi then
    local col = hline:find('New File', 1, true)
    local row = hls(buf, hi - 1)
    H.t('dashboard: the button row has all three highlight groups', function()
      for _, g in ipairs { 'Special', 'Title', 'Function' } do
        if not row[g] then return ('row %d is missing %s (has %s)'):format(hi, g, vim.inspect(vim.tbl_keys(row))) end
      end
      return true
    end)
    H.eq('dashboard: the Function highlight starts on the label', col - 1, row.Function and row.Function.col0)
  end
  local gh = find_line '  _   '
  H.truthy('dashboard: ascii header present', gh ~= nil)
  if gh then
    H.eq('dashboard: header line is highlighted as Include', { 'Include' }, sorted_groups(buf, gh - 1))
    H.eq('dashboard: footer line is highlighted as Comment', { 'Comment' }, sorted_groups(buf, #lines - 1))
  end

  H.truthy(
    'dashboard: every button key is mapped',
    (function()
      for _, k in ipairs { 'e', 'f', 'r', 'g', 's', 'u', 'q' } do
        if vim.fn.maparg(k, 'n', false, true).buffer ~= 1 then return false end
      end
      return true
    end)(),
    'a button key is missing its buffer-local map'
  )

  pcall(vim.api.nvim_buf_delete, buf, { force = true })

  -- ---- with recents ----
  buf = build { f1, f2, f1 } -- duplicate + one repeated
  lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local a1 = find_line 'alpha.lua'
  local a2 = find_line 'beta.lua'
  H.truthy('dashboard: recents listed', a1 ~= nil and a2 ~= nil)
  H.eq('dashboard: duplicate recents deduped', 1, #vim.tbl_filter(function(l) return l:find('alpha.lua', 1, true) ~= nil end, lines))
  do
    -- pins the bug: recent highlights used to land one line low
    local wrong = {}
    for i = 0, 1 do
      local row0 = a1 - 1 + i
      local g = groups(buf, row0)
      if not g.Directory or not g.Number then wrong[#wrong + 1] = ('1-based line %d has %s'):format(row0 + 1, vim.inspect(sorted_groups(buf, row0))) end
    end
    H.t('dashboard: every recent row carries its own highlight', function() return #wrong == 0 or table.concat(wrong, ' | ') end)
    H.eq('dashboard: the blank line below the recents is unhighlighted', {}, sorted_groups(buf, a2))
  end
  H.truthy('dashboard: <CR> mapped on the dashboard', vim.fn.maparg('<CR>', 'n', false, true).buffer == 1)
  -- pressing <CR> on a recent row must open that file
  if a1 then
    pcall(vim.api.nvim_win_set_cursor, 0, { a1, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)
    vim.wait(300)
    H.t('dashboard: <CR> on a recent row opens the file', function()
      local name = vim.api.nvim_buf_get_name(0)
      if name:find('alpha.lua', 1, true) then return true end
      return 'current buffer is ' .. vim.inspect(name)
    end)
  end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(dir, 'rf')

  -- ---- <leader>s must survive whatever is in the sessions dir ----
  pcall(vim.cmd, 'messages clear')
  scratch()
  local ok = pcall(function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>s', true, false, true), 'x', false) end)
  vim.wait(400)
  H.t('dashboard: <leader>s is inert-safe (no sessions, no picker crash)', function()
    local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
    if ok and #bad == 0 then return true end
    return 'ok=' .. tostring(ok) .. ' ' .. table.concat(bad, ' | ')
  end)
end

-- -----------------------------------------------------------------------------
-- $NVIM_THEME_EXPECT: name the parent saved to theme.txt before spawning us
S.theme_startup = function()
  H.eq('theme: saved scheme is applied on a fresh start', vim.env.NVIM_THEME_EXPECT or '?', tostring(vim.g.colors_name))
  H.truthy('theme: statusline highlights were rebuilt for it', vim.fn.hlexists 'SL_a_normal' == 1)
end

-- -----------------------------------------------------------------------------
S.themes = function()
  local names = {}
  for _, f in ipairs(vim.api.nvim_get_runtime_file('colors/*.vim', true)) do
    names[#names + 1] = f:match 'colors/(.+)\\.vim$'
  end
  for _, f in ipairs(vim.api.nvim_get_runtime_file('colors/*.lua', true)) do
    names[#names + 1] = f:match 'colors/(.+)\\.lua$'
  end
  table.sort(names)
  H.pass('themes: discovered', ('%d colorschemes on rtp'):format(#names))

  scratch()
  for _, name in ipairs(names) do
    H.t('theme: ' .. name, function()
      vim.cmd 'messages clear'
      pcall(vim.cmd.colorscheme, name)
      if not vim.g.colors_name then return { level = 'WARN', msg = 'colorscheme did not set g.colors_name' } end
      -- mode-colored line numbers (the tokyonight.colors.setup crash site)
      pcall(vim.api.nvim_exec_autocmds, 'ModeChanged', { pattern = 'i:*' })
      pcall(vim.api.nvim_exec_autocmds, 'ModeChanged', { pattern = 'n:*' })
      -- statusline + tabline must re-derive their highlights and render
      local sl = _G._builtin_statusline()
      if type(sl) ~= 'string' then return 'statusline returned ' .. type(sl) end
      local out = vim.api.nvim_eval_statusline(vim.o.statusline, { winid = 0, maxwidth = 300 })
      if type(out.str) ~= 'string' then return 'statusline eval returned ' .. type(out.str) end
      local tb = vim.api.nvim_eval_statusline(vim.o.tabline, { maxwidth = 300 })
      if type(tb.str) ~= 'string' then return 'tabline eval returned ' .. type(tb.str) end
      local bad = H.error_text(vim.api.nvim_exec2('messages', { output = true }).output or '')
      if #bad == 0 then return true end
      return table.concat(bad, ' | ')
    end)
  end

  -- back to a known-good scheme
  pcall(vim.cmd.colorscheme, 'tokyonight-night')
  H.pass('themes: restored tokyonight-night', tostring(vim.g.colors_name))
end

-- =============================================================================
local ok, err = pcall(S[section])
if not ok then H.fail('section ' .. section .. ' crashed', err) end
H.flush()
