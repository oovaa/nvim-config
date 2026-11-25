-- Builtin UI behavior (lua/custom/ui/): which buffer the tabline marks current,
-- and that the saved colorscheme comes back. Both are silent when they break.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_builtin_ui.lua")" -c 'qa!'

local helpers = require 'tests.helpers'

describe('builtin tabline', function()
  local tabline = require 'custom.ui.tabline'

  --- Payload of one buffer's entry in a rendered tabline. An entry is
  --- `%<bufnr>@_builtin_tabclick@<hl> <idx> <name>...%X%*`; slicing one buffer
  --- out beats matching the whole escape soup, which is not a contract.
  local function entry(s, buf) return s:match('%%' .. buf .. '@BuiltinTabclick@(.-)%%X') end

  it('marks the current buffer selected and follows a switch or a click', function()
    assert.is_function(_G._builtin_tabline, 'premise: tabline must be wired by custom.ui.init')
    assert.is_function(_G._builtin_tabclick)
    tabline.setup_bufferline()

    -- real files in /tmp, not scratch buffers: a scratch buffer is unlisted and
    -- the tabline only walks buflisted ones.
    local dir = ('/tmp/nvim-tabline-test-%d'):format(vim.uv.hrtime())
    vim.fn.mkdir(dir, 'p')
    vim.fn.writefile({ '# alpha' }, dir .. '/alpha.md')
    vim.fn.writefile({ '# beta' }, dir .. '/beta.md')
    vim.cmd.edit(vim.fn.fnameescape(dir .. '/alpha.md'))
    local alpha = vim.api.nvim_get_current_buf()
    vim.cmd.edit(vim.fn.fnameescape(dir .. '/beta.md'))
    local beta = vim.api.nvim_get_current_buf()

    local s = _G._builtin_tabline()
    assert.is_truthy(entry(s, beta), 'beta must have an entry')
    assert.is_truthy(entry(s, beta):match '%#TabLineSel#', 'the current buffer is the selected one')
    assert.is_truthy(entry(s, alpha):match '%#TabLine#', 'other buffers use the plain group')
    assert.is_nil(entry(s, alpha):match '%#TabLineSel#', 'only one entry may be selected')

    -- a modified buffer gets its own dot, in the Sel variant while current
    vim.api.nvim_buf_set_lines(alpha, 0, -1, false, { '# alpha edited' })
    s = _G._builtin_tabline()
    assert.is_truthy(entry(s, alpha):match '●', 'a modified buffer is dotted')
    assert.is_truthy(entry(s, alpha):match '%#TabLineMod#', 'unselected dot uses TabLineMod')

    vim.api.nvim_set_current_buf(alpha)
    s = _G._builtin_tabline()
    assert.is_truthy(entry(s, alpha):match '%#TabLineSel#', 'the mark follows the current buffer')
    assert.is_truthy(entry(s, alpha):match '%#TabLineModSel#', 'the current dot uses TabLineModSel')
    assert.is_truthy(entry(s, beta):match '%#TabLine#', 'the old current buffer loses the mark')

    _G._builtin_tabclick(beta, 1, 'l')
    assert.equals(beta, vim.api.nvim_get_current_buf(), 'left click switches to that buffer')
    assert.is_truthy(entry(_G._builtin_tabline(), beta):match '%#TabLineSel#', 'the mark follows the click')
    _G._builtin_tabclick(alpha, 1, 'r')
    assert.equals(beta, vim.api.nvim_get_current_buf(), 'a right click must not switch')

    pcall(vim.api.nvim_buf_delete, alpha, { force = true })
    pcall(vim.api.nvim_buf_delete, beta, { force = true })
    vim.fn.delete(dir, 'rf')
  end)
end)

describe('theme restore', function()
  local theme = require 'custom.ui.theme'

  it('puts the saved colorscheme back over whatever is active', function()
    -- both schemes are core runtime ones whose colors_name is their own name
    -- (tokyonight would report 'tokyonight-moon' and make the assert read the
    -- plugin instead of the restore).
    for _, name in ipairs { 'default', 'habamax' } do
      assert.is_true(pcall(vim.cmd.colorscheme, name), name .. ' must be loadable')
    end
    local original_scheme, original_saved = vim.g.colors_name, theme.get_saved()

    local ok, err = pcall(function()
      vim.cmd.colorscheme 'habamax'
      -- what a fresh session finds: theme.txt written by the previous one
      theme.save 'default'
      theme.restore()
      assert.equals('default', vim.g.colors_name, 'restore() must put the saved scheme back')
    end)

    -- ThemePersistence writes on every switch, so undo the scheme first and the
    -- file second, or the cleanup leaves this host's theme changed.
    if original_scheme then pcall(vim.cmd.colorscheme, original_scheme) end
    if original_saved then
      theme.save(original_saved)
    else
      vim.fn.delete(theme.theme_file())
    end
    assert.is_truthy(ok, tostring(err))
  end)
end)

describe('dashboard projects', function()
  local M = require 'custom.ui.dashboard'
  local S = require 'config.sessions'

  local function tmpdir()
    -- unique, non-suppressed fixture: suppressed cwds have no sessions at all
    local dir = helpers.fixture_path 'nvim-dash-test'
    vim.fn.mkdir(dir, 'p')
    return dir
  end

  local function short(path) return (path:gsub('^' .. vim.pesc(vim.fn.expand '~'), '~')) end

  local function write_session(path, cd, with_badd)
    local lines = { 'cd ' .. cd }
    if with_badd ~= false then lines[#lines + 1] = 'badd +1 file' end
    vim.fn.writefile(lines, path)
    return path
  end

  --- Render the dashboard through its real VimEnter handler, with the
  --- production cwd-session lookup replaced by `find_result`.
  local function render(find_result)
    -- the Resume row is gated on the canonical suppression predicate; run from
    -- a real (non-suppressed) cwd so the stubbed find can be exercised at all.
    local cwd_fx = helpers.fixture_path 'dash-render-cwd'
    vim.fn.mkdir(cwd_fx, 'p')
    local orig_cwd = vim.fn.getcwd()
    vim.cmd('cd ' .. vim.fn.fnameescape(cwd_fx))
    -- drop deleted-file litter from earlier blocks: wiping a dashboard lands on
    -- such a buffer and nvim prints E211 while re-entering it
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= '' and vim.fn.filereadable(name) == 0 and vim.bo[b].filetype ~= 'dashboard' then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
    end
    local orig_find = S.find_session_for
    S.find_session_for = function() return find_result end
    local ok, res = pcall(function()
      M.setup_starter()
      local cb
      for _, a in ipairs(vim.api.nvim_get_autocmds { event = 'VimEnter' }) do
        if a.group_name == 'BuiltinDashboard' and type(a.callback) == 'function' then cb = a.callback end
      end
      assert.is_function(cb, 'dashboard VimEnter handler must be registered')
      vim.cmd 'enew'
      cb()
      return vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end)
    S.find_session_for = orig_find
    vim.cmd('cd ' .. vim.fn.fnameescape(orig_cwd))
    helpers.remove_fixture(cwd_fx)
    assert.is_truthy(ok, tostring(res))
    return res
  end

  local function row_index(lines, needle)
    for i, l in ipairs(lines) do
      if l:find(needle, 1, true) then return i end
    end
  end

  local function wipe_dashboard_buffers()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == 'dashboard' then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
    end
  end

  it('get_resume_for yields the S row only for a restorable path', function()
    local dir = tmpdir()
    local sess = write_session(dir .. '/resume.vim', vim.fn.expand '~')
    local readable = function(p) return vim.fn.filereadable(p) == 1 end
    local row = M.get_resume_for(function() return sess end, readable)
    assert.is_not_nil(row, 'a restorable session gets a button')
    assert.equals('S', row.key)
    assert.equals(vim.fn.nr2char(0xf017), row.icon)
    assert.is_true(row.label:find('Resume', 1, true) ~= nil, 'the label contains Resume')
    assert.is_true(row.label:find('Resume: ~', 1, true) ~= nil, 'the label comes from the session cd line')
    assert.is_function(row.action)
    assert.is_nil(M.get_resume_for(function() return nil end, readable), 'no path, no row')
    assert.is_nil(M.get_resume_for(function() return sess end, function() return false end), 'unreadable session, no row')
    assert.equals(vim.fn.stdpath 'data' .. '/sessions', M.sessions_dir())
    helpers.remove_fixture(dir)
  end)

  it('renders the Resume row first only when the cwd session is restorable', function()
    local dir = tmpdir()
    local sess = write_session(dir .. '/resume.vim', vim.fn.expand '~')
    local nobadd = write_session(dir .. '/nobadd.vim', vim.fn.expand '~', false)
    local labels = { 'New File', 'Find File', 'File Explorer', 'Git (LazyGit)', 'Recent Projects', 'Update Plugins', 'Quit' }
    local function assert_button_layout(lines, first_row)
      local row = first_row
      for _, lab in ipairs(labels) do
        assert.equals(row, row_index(lines, lab), lab .. ' must render directly below the previous button row')
        row = row + 1
      end
    end

    local with = render(sess)
    local i_resume = row_index(with, 'Resume:')
    local i_new = row_index(with, 'New File')
    assert.is_not_nil(i_resume, 'a restorable session adds the Resume row')
    assert.equals(i_new - 1, i_resume, 'Resume must be the first button row')
    assert_button_layout(with, i_new)

    local without = render(nil)
    assert.is_nil(row_index(without, 'Resume:'), 'no session, no Resume row anywhere')
    assert_button_layout(without, row_index(without, 'New File'))

    local gated = render(nobadd)
    assert.is_nil(row_index(gated, 'Resume:'), 'a session without badd must not produce a Resume row')

    wipe_dashboard_buffers()
    helpers.remove_fixture(dir)
  end)

  it('s picker consumes list_projects order and restores in place', function()
    local dir = tmpdir()
    local orig_cwd = vim.fn.getcwd()
    local zzz = dir .. '/zzz.vim' -- newest first, deliberately not alphabetical
    local aaa = dir .. '/aaa.vim'
    vim.fn.writefile({ 'cd ' .. dir }, zzz)
    vim.fn.writefile({ 'cd ' .. dir, 'badd +1 x' }, aaa)
    render(nil)
    local s_map
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if m.lhs == 's' then s_map = m.callback end
    end
    assert.is_function(s_map, 'the s button must be mapped in the dashboard buffer')

    local captured_dir, captured_items, captured_prompt, on_choice
    local orig_list, orig_select = S.list_projects, vim.ui.select
    S.list_projects = function(d)
      captured_dir = d
      return {
        { label = zzz, path = zzz, mtime = 2 },
        { label = aaa, path = aaa, mtime = 1 },
      }
    end
    vim.ui.select = function(items, opts, cb)
      captured_items, captured_prompt, on_choice = items, opts.prompt, cb
    end
    local ok, err = pcall(s_map)
    vim.ui.select, S.list_projects = orig_select, orig_list
    assert.is_truthy(ok, tostring(err))
    assert.equals(M.sessions_dir(), captured_dir, 'the picker must read the dashboard sessions dir')
    assert.equals('Select session:', captured_prompt)
    assert.same({ short(zzz), short(aaa) }, captured_items, 'items keep list_projects (recency) order, no alphabetical re-sort')

    ok, err = pcall(on_choice, captured_items[1], 1)
    local picked_cwd = vim.fn.getcwd()
    pcall(vim.fn.chdir, orig_cwd)
    assert.is_truthy(ok, tostring(err))
    assert.equals(vim.fn.fnamemodify(dir, ':p'), vim.fn.fnamemodify(picked_cwd, ':p'), 'picking sources the session, whose cd moves nvim in place')

    wipe_dashboard_buffers()
    helpers.remove_fixture(dir)
  end)

  it('s picker keys duplicate long labels by index so neither action is lost', function()
    local dir = tmpdir()
    local first, second = dir .. '/first.vim', dir .. '/second.vim'
    vim.fn.writefile({ 'let g:deep_fix_dash_pick = 1' }, first)
    vim.fn.writefile({ 'let g:deep_fix_dash_pick = 2' }, second)
    render(nil)
    local s_map
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if m.lhs == 's' then s_map = m.callback end
    end
    assert.is_function(s_map, 'the s button must be mapped in the dashboard buffer')

    local label = dir .. '/same/long/project/label'
    local items, on_choice = nil, nil
    local orig_list, orig_select = S.list_projects, vim.ui.select
    S.list_projects = function()
      return {
        { label = label, path = first, mtime = 2 },
        { label = label, path = second, mtime = 1 },
      }
    end
    vim.ui.select = function(is, _, cb)
      items, on_choice = is, cb
    end
    local ok, err = pcall(s_map)
    vim.ui.select, S.list_projects = orig_select, orig_list
    assert.is_truthy(ok, tostring(err))
    assert.equals(2, #items, 'both long projects must remain listed')
    assert.equals(items[1], items[2], 'premise: their clipped display labels collide')
    assert.is_truthy(items[1]:find('same/long/project/label', 1, true), 'display text must keep the project tail')

    ok, err = pcall(on_choice, label, 2)
    assert.is_truthy(ok, tostring(err))
    assert.equals(2, vim.g.deep_fix_dash_pick or 0, 'the second duplicate label must source its own session')
    vim.g.deep_fix_dash_pick = nil
    wipe_dashboard_buffers()
    helpers.remove_fixture(dir)
  end)

  it('s picker drops stale temp sessions even from an unfiltered list source', function()
    local dir = tmpdir()
    local live = helpers.fixture_path 'dash-live'
    local stale_cd = vim.fn.tempname()
    local orig_list, orig_select = S.list_projects, vim.ui.select
    S.list_projects = function()
      return {
        { label = live, path = dir .. '/live.vim', mtime = 2 },
        { label = stale_cd, path = dir .. '/stale.vim', mtime = 1 },
      }
    end
    local captured
    vim.ui.select = function(items) captured = items end
    render(nil)
    local s_map
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if m.lhs == 's' then s_map = m.callback end
    end
    local ok, err = pcall(s_map)
    vim.ui.select, S.list_projects = orig_select, orig_list
    assert.is_truthy(ok, tostring(err))
    assert.same({ short(live) }, captured, 'a stale temp cwd must not be a dashboard choice')
    helpers.remove_fixture(live)
    wipe_dashboard_buffers()
    helpers.remove_fixture(dir)
  end)

  it('shortens the home prefix only at a path boundary', function()
    local dir = tmpdir()
    local home = vim.fn.expand '~'
    local readable = function() return true end
    local sibling = write_session(dir .. '/sibling.vim', home .. '2')
    local row = M.get_resume_for(function() return sibling end, readable)
    assert.is_truthy(row, 'a restorable home-sibling session still gets a row')
    assert.is_truthy(row.label:find(home .. '2', 1, true), 'a sibling like /home/omar2 must keep its full path: ' .. row.label)
    assert.is_nil(row.label:find('~2', 1, true), 'no bogus ~2 rewriting: ' .. row.label)
    local child = write_session(dir .. '/child.vim', home .. '/projects/x')
    local child_row = M.get_resume_for(function() return child end, readable)
    assert.is_truthy(child_row.label:find('~/projects/x', 1, true), 'a real home child still shortens to ~: ' .. child_row.label)
    helpers.remove_fixture(dir)
  end)

  it('g reuses one lazygit float buffer and job across repeated presses', function()
    render(nil)
    local g
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if m.lhs == 'g' then g = m.callback end
    end
    assert.is_function(g, 'the g button must be mapped in the dashboard buffer')

    -- start from an empty shared float slot; clear fields in place (terminal.lua
    -- holds a reference to this table, so replacing it would orphan the state).
    local state = _G._builtin_terminal_state
    local function close_floats()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(w).relative ~= '' then pcall(vim.api.nvim_win_close, w, true) end
      end
    end
    close_floats()
    if state then
      local f = state.float
      if f.buf and vim.api.nvim_buf_is_valid(f.buf) then pcall(vim.api.nvim_buf_delete, f.buf, { force = true }) end
      f.buf, f.win, f.cmd, f.job = nil, nil, nil, nil
    end

    local real_jobstart, starts = vim.fn.jobstart, 0
    vim.fn.jobstart = function()
      starts = starts + 1
      return 42000 + starts
    end
    local float = _G._builtin_terminal_state.float
    local ok, err = pcall(function()
      g() -- open
      local buf1, job1 = float.buf, float.job
      assert.is_number(buf1, 'g must open a float buffer')
      assert.is_true(vim.api.nvim_buf_is_valid(buf1), 'g must open a valid float buffer')
      assert.equals(42001, job1, 'g must start exactly one terminal job')
      g() -- hide
      g() -- reopen the same buffer
      assert.equals(buf1, float.buf, 'repeated g presses must reuse the same float buffer')
      assert.equals(job1, float.job, 'repeated g presses must reuse the same terminal job')
      assert.equals(1, starts, 'g must not spawn a second terminal job')
    end)
    vim.fn.jobstart = real_jobstart
    vim.cmd 'stopinsert'
    close_floats()
    if float.buf and vim.api.nvim_buf_is_valid(float.buf) then pcall(vim.api.nvim_buf_delete, float.buf, { force = true }) end
    assert.is_truthy(ok, tostring(err))
    wipe_dashboard_buffers()
  end)

  it('drops a float whose job exited so a same-command press spawns a fresh job', function()
    render(nil)
    local g
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if m.lhs == 'g' then g = m.callback end
    end
    assert.is_function(g, 'the g button must be mapped in the dashboard buffer')

    local state = _G._builtin_terminal_state
    local function close_floats()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(w).relative ~= '' then pcall(vim.api.nvim_win_close, w, true) end
      end
    end
    close_floats()
    local float = state.float
    if float.buf and vim.api.nvim_buf_is_valid(float.buf) then pcall(vim.api.nvim_buf_delete, float.buf, { force = true }) end
    float.buf, float.win, float.cmd, float.job = nil, nil, nil, nil

    local real_jobstart, starts, on_exit = vim.fn.jobstart, 0, nil
    vim.fn.jobstart = function(_, opts)
      starts = starts + 1
      on_exit = opts and opts.on_exit
      return 43000 + starts
    end
    local ok, err = pcall(function()
      g()
      local buf1, job1 = float.buf, float.job
      assert.is_number(buf1, 'g must open a float buffer')
      assert.is_function(on_exit, 'jobstart must register an exit handler')
      on_exit(job1)
      assert.is_nil(float.buf, 'an exited job must clear the float buffer slot')
      assert.is_nil(float.job, 'an exited job must clear the job slot')
      g()
      assert.equals(2, starts, 'same-command press after exit must spawn a fresh job')
      assert.is_true(float.buf ~= buf1, 'the dead buffer must not be reused')
    end)
    vim.fn.jobstart = real_jobstart
    vim.cmd 'stopinsert'
    close_floats()
    if float.buf and vim.api.nvim_buf_is_valid(float.buf) then pcall(vim.api.nvim_buf_delete, float.buf, { force = true }) end
    float.buf, float.win, float.cmd, float.job = nil, nil, nil, nil
    assert.is_truthy(ok, tostring(err))
    wipe_dashboard_buffers()
  end)

  it('fits 40/60/80 columns with a long cwd without truncating actions or offsets', function()
    local dir = tmpdir()
    local long_cwd = dir .. '/' .. string.rep('x', 200)
    local sess = write_session(dir .. '/long.vim', long_cwd)
    local real_width = vim.api.nvim_win_get_width
    local ok, err = pcall(function()
      for _, w in ipairs { 40, 60, 80 } do
        vim.api.nvim_win_get_width = function() return w end
        local lines = render(sess)
        for i, l in ipairs(lines) do
          local cells = vim.fn.strdisplaywidth(l)
          assert.is_true(cells <= w, ('line %d is %d cells wide in a %d-column window: %s'):format(i, cells, w, l))
        end
        assert.is_truthy(row_index(lines, 'Resume'), 'the Resume row must still render at width ' .. w)

        local newfile_line, newfile_row
        for i, l in ipairs(lines) do
          if l:find('New File', 1, true) then
            newfile_line, newfile_row = l, i
            break
          end
        end
        assert.is_truthy(newfile_line, 'New File button must render at width ' .. w)
        local label_col = newfile_line:find('New File', 1, true) - 1
        for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
          if m[2] == newfile_row - 1 and m[4].hl_group == 'Function' then assert.equals(label_col, m[3], 'the label highlight must stay at the byte offset') end
        end

        local s_map
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
          if m.lhs == 'S' then s_map = m.callback end
        end
        assert.is_function(s_map, 'Resume key must be mapped at width ' .. w)
        local cmds, real_cmd = {}, vim.cmd
        vim.cmd = function(c) cmds[#cmds + 1] = c end
        local ok_act, act_err = pcall(s_map)
        vim.cmd = real_cmd
        assert.is_truthy(ok_act, tostring(act_err))
        assert.is_true(vim.tbl_contains(cmds, 'source ' .. vim.fn.fnameescape(sess)), 'Resume must source the full session path')
      end
    end)
    vim.api.nvim_win_get_width = real_width
    assert.is_truthy(ok, tostring(err))
    wipe_dashboard_buffers()
    helpers.remove_fixture(dir)
  end)
end)

describe('statusline progress invalidation', function()
  local statusline = require 'custom.ui.statusline'

  it('refreshes idle output on progress events, throttled to one redrawstatus burst', function()
    assert.is_true(#vim.api.nvim_get_autocmds { group = 'BuiltinUIProgress' } > 0, 'BuiltinUIProgress group must be registered')

    local prev = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)

    local real_status, real_pstatus, real_cmd = vim.lsp.status, vim.ui.progress_status, vim.cmd
    local status_value = 'PROGRESS-IDLE-SENTINEL'
    local redraws = 0
    vim.lsp.status = function() return status_value end
    vim.ui.progress_status = function() return '' end
    vim.cmd = function(arg)
      if type(arg) == 'string' and arg:find('redrawstatus', 1, true) then
        redraws = redraws + 1
      else
        return real_cmd(arg)
      end
    end

    local ok, err = pcall(function()
      -- Seed a fresh idle cache so the baseline render reuses it.
      statusline._progress = { at = vim.uv.now(), s = status_value }
      local before = _G._builtin_statusline()
      assert.is_truthy(before:find('PROGRESS-IDLE-SENTINEL', 1, true), 'premise: statusline shows cached idle progress')

      status_value = 'PROGRESS-BUSY-SENTINEL'
      -- A burst of progress events: each invalidates, only one redraw scheduled.
      for _ = 1, 4 do
        vim.api.nvim_exec_autocmds('LspProgress', {})
      end
      vim.api.nvim_exec_autocmds('Progress', {})
      assert.equals(0, statusline._progress.at, 'progress events invalidate the cache')
      vim.wait(200) -- let the throttled timer fire; no cursor move in between

      local after = _G._builtin_statusline()
      assert.is_truthy(after:find('PROGRESS-BUSY-SENTINEL', 1, true), 'progress event must refresh statusline output')
      assert.equals(1, redraws, 'a burst of progress events must schedule exactly one redrawstatus')
    end)

    vim.lsp.status, vim.ui.progress_status, vim.cmd = real_status, real_pstatus, real_cmd
    statusline._progress = { at = 0, s = '' }
    vim.api.nvim_set_current_buf(prev)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    assert.is_truthy(ok, tostring(err))
  end)

  it('caches search count per position but recomputes the index on a column move', function()
    local prev = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'alpha beta gamma', 'second line' })
    vim.api.nvim_set_current_buf(buf)
    local win = vim.api.nvim_get_current_win()
    local old_reg, old_hls = vim.fn.getreg '/', vim.o.hlsearch
    local real_searchcount, calls = vim.fn.searchcount, 0
    vim.o.hlsearch = true
    vim.fn.setreg('/', 'beta')
    -- Delegate to the real searchcount: its `current` is relative to the cursor
    -- column, so a stub that ignores the column would mask the regression.
    vim.fn.searchcount = function(opts)
      calls = calls + 1
      return real_searchcount(opts)
    end
    local ok, err = pcall(function()
      statusline._search[win] = nil
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      local first = _G._builtin_statusline()
      assert.equals(1, calls, 'the first render must compute the search count')
      assert.is_truthy(first:find('0/1', 1, true), 'cursor before the match shows index 0: ' .. first)

      _G._builtin_statusline() -- pure redraw, same cursor position
      assert.equals(1, calls, 'a pure redraw at the same position must reuse the cached segment')

      vim.api.nvim_win_set_cursor(win, { 1, 6 })
      local moved = _G._builtin_statusline()
      assert.equals(2, calls, 'a same-line column move must invalidate the cache')
      assert.is_truthy(moved:find('1/1', 1, true), 'cursor inside the match must show index 1: ' .. moved)

      _G._builtin_statusline() -- pure redraw at the new position
      assert.equals(2, calls, 'a pure redraw at the new position must reuse the cached segment')

      vim.api.nvim_win_set_cursor(win, { 2, 0 })
      _G._builtin_statusline()
      assert.equals(3, calls, 'a different line must also invalidate the cache')
    end)
    vim.fn.searchcount = real_searchcount
    vim.o.hlsearch = old_hls
    vim.fn.setreg('/', old_reg)
    statusline._search[win] = nil
    vim.api.nvim_set_current_buf(prev)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    assert.is_truthy(ok, tostring(err))
  end)
end)
