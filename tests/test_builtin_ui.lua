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

    ok, err = pcall(on_choice, captured_items[1])
    local picked_cwd = vim.fn.getcwd()
    pcall(vim.fn.chdir, orig_cwd)
    assert.is_truthy(ok, tostring(err))
    assert.equals(vim.fn.fnamemodify(dir, ':p'), vim.fn.fnamemodify(picked_cwd, ':p'), 'picking sources the session, whose cd moves nvim in place')

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
end)
