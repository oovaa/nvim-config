-- Behavior tests for the hand-required config modules that previously had
-- nothing but `assert.has_no_error(require ...)`: sessions and runner.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_config_modules.lua")' -c 'qa!'

local helpers = require 'tests.helpers'

local function scratch_dir()
  local d = vim.fn.tempname()
  vim.fn.mkdir(d, 'p')
  return d
end

describe('config.sessions', function()
  local sessions = require 'config.sessions'
  local session_file = sessions.session_file_for
  local session_files = sessions.session_files
  local is_suppressed = sessions.is_suppressed

  it('exports its helpers for the dashboard session picker', function()
    assert.is_function(session_file, 'must export the path builder')
    assert.is_function(session_files, 'must export the listing fn')
    assert.is_function(sessions.find_session_for)
    assert.is_function(is_suppressed, 'must export the shared suppression predicate')
    -- compat shim remains usable
    assert.is_function(_G._builtin_find_session)
  end)

  it('normalizes suppression: trailing slashes, sibling prefixes, home vs child', function()
    assert.is_true(is_suppressed '/tmp', 'exact /tmp')
    assert.is_true(is_suppressed '/tmp/', 'one trailing slash')
    assert.is_true(is_suppressed '/tmp///', 'many trailing slashes')
    assert.is_false(is_suppressed '/tmp-other', 'a sibling prefix is not the temp root')
    assert.is_false(is_suppressed '/tmp-other/child')
    local home = vim.fn.expand '~'
    assert.is_true(is_suppressed(home), 'exact home')
    assert.is_true(is_suppressed(home .. '/'), 'home with trailing slash')
    assert.is_false(is_suppressed(home .. '/projects/x'), 'a home child is not suppressed')
    assert.is_true(is_suppressed(vim.fn.expand '~/Downloads'), 'exact Downloads')
    assert.is_false(is_suppressed(vim.fn.expand '~/Downloads/x'), 'a Downloads child is not suppressed')
    assert.is_true(is_suppressed '/etc')
    assert.is_false(is_suppressed '/etc/hosts', 'an /etc child is not suppressed')
  end)

  it('uses a custom TMPDIR subtree, but TMPDIR=/ must not suppress every cwd', function()
    local original = vim.env.TMPDIR
    local custom = helpers.fixture_path 'tmpdir-root'
    vim.fn.mkdir(custom, 'p')
    local plain = helpers.fixture_path 'under-root'
    local ok, err = pcall(function()
      vim.env.TMPDIR = custom
      assert.is_true(is_suppressed(custom), 'exact custom temp root')
      assert.is_true(is_suppressed(custom .. '/nested/child'), 'custom temp subtree')
      assert.is_false(is_suppressed(custom .. '-sibling'), 'sibling of the custom temp root')
      assert.is_true(is_suppressed '/tmp', 'exact /tmp stays suppressed via the explicit set')
      assert.is_false(is_suppressed '/tmp/scratch', '/tmp is no longer the temp root')
      vim.env.TMPDIR = '/'
      assert.is_false(is_suppressed(plain .. '/child'), 'TMPDIR=/ must not suppress every cwd')
      assert.is_false(is_suppressed(plain), 'nor an unrelated cwd')
    end)
    if original then
      vim.env.TMPDIR = original
    else
      vim.env.TMPDIR = nil
    end
    helpers.remove_fixture(custom)
    assert.is_true(ok, tostring(err))
  end)

  it('names a session per cwd under stdpath(data)/sessions', function()
    local p = session_file '/home/omar'
    assert.is_truthy(p:find(vim.fn.stdpath 'data' .. '/sessions/', 1, true), 'must live in the sessions dir')
    assert.equals('.vim', p:sub(-4), 'must end in .vim')
  end)

  it('normalizes trailing slashes so /a/b and /a/b/ share one session', function()
    assert.equals(session_file '/tmp/opencode', session_file '/tmp/opencode/')
    assert.equals(session_file '/tmp/opencode///', session_file '/tmp/opencode')
  end)

  it('stays collision-free for paths that escape to the same string', function()
    -- /a/b and /a%b both escape to %a%b; the sha256 suffix keeps them apart
    assert.is_not.equals(session_file '/tmp/a/b', session_file '/tmp/a%b')
  end)

  it('does not treat a subdir of a suppressed dir as suppressed', function()
    -- sessions.lua matches ~/, ~/Downloads, /etc, /tmp exactly, never subdirs,
    -- so working in ~/projects/* or /tmp/* still gets its own session.
    assert.is_not.equals(session_file '/tmp', session_file '/tmp/opencode')
    assert.is_not.equals(session_file(vim.fn.expand '~'), session_file(vim.fn.expand '~' .. '/.config'))
  end)

  it('lists session files newest-first and skips non-.vim', function()
    local dir = scratch_dir()
    local function touch(name, mtime)
      local p = dir .. '/' .. name
      local fd = assert(io.open(p, 'w'))
      fd:write 'badd 1\n'
      fd:close()
      vim.uv.fs_utime(p, mtime, mtime)
      return p
    end
    local old = touch('old-one.vim', 1000000)
    local new = touch('new-one.vim', 2000000)
    touch('ignore.txt', 3000000)

    local paths = vim.tbl_map(function(e) return e.path end, session_files(dir))
    assert.same({ new, old }, paths, 'must be mtime desc and only .vim files')
    vim.fn.delete(dir, 'rf')
  end)

  it('returns {} for a missing sessions dir instead of erroring', function() assert.same({}, session_files(scratch_dir() .. '/does/not/exist')) end)

  it('finds an existing session by its cd line', function()
    -- find_session_for only scans the real sessions dir, so the fixture has to
    -- live there; it is removed again at the end. The target cwd must be outside
    -- the temp tree now that find_session_for honours suppression.
    local target = helpers.fixture_path 'find-session-proj'
    vim.fn.mkdir(target, 'p')
    local p = vim.fn.stdpath 'data' .. '/sessions/zz-test-' .. vim.fn.sha256(target):sub(1, 8) .. '.vim'
    vim.fn.mkdir(vim.fn.stdpath 'data' .. '/sessions', 'p')
    local fd = assert(io.open(p, 'w'))
    fd:write('badd 1\n' .. 'cd ' .. target .. '\n')
    fd:close()

    assert.equals(p, sessions.find_session_for(target), 'should find the session whose cd matches the cwd')
    -- old global access path still works during transition
    assert.equals(p, _G._builtin_find_session(target))
    vim.fn.delete(p)
    helpers.remove_fixture(target)
  end)

  it('does not revive a suppressed cwd from an old session file', function()
    -- A stale session written before temp suppression existed must not be
    -- rediscovered: find_session_for still returns a path (callers expect one),
    -- but never a scan hit for a suppressed cwd.
    local dir = vim.fn.stdpath 'data' .. '/sessions'
    vim.fn.mkdir(dir, 'p')
    local temp_cwd = vim.fn.tempname()
    vim.fn.mkdir(temp_cwd, 'p')
    local legacy = dir .. '/legacy-suppressed-' .. vim.fn.sha256(temp_cwd):sub(1, 8) .. '.vim'
    vim.fn.writefile({ 'badd +1 x', 'cd ' .. temp_cwd }, legacy)
    local got = sessions.find_session_for(temp_cwd)
    vim.fn.delete(legacy)
    vim.fn.delete(temp_cwd, 'rf')
    assert.is_not.equals(legacy, got, 'a suppressed cwd must not scan-hit an old session')
  end)

  it('registers exactly one VimLeavePre writer so reload cannot stack it', function()
    -- AGENTS.md trap 2: <leader>ur re-sources the config; a nameless augroup
    -- would stack a second writer and clobber the session on every reload.
    local aus = vim.api.nvim_get_autocmds { event = 'VimLeavePre', group = 'BuiltinSessions' }
    assert.equals(1, #aus, 'BuiltinSessions must hold exactly one autocmd')
  end)

  it('writes a session on exit, but not for a fileless buffer', function()
    local home = vim.fn.getcwd()
    -- must be outside the temp tree: temp cwds are intentionally suppressed now;
    -- unique basename so parallel runs cannot collide on stdpath('data').
    local dir = helpers.fixture_path 'session-write-test'
    vim.fn.mkdir(dir, 'p')
    local file = dir .. '/main.lua'
    vim.fn.writefile({ 'return 1' }, file)

    -- no real file buffer open -> must NOT write (dashboard-only state)
    vim.cmd('cd ' .. vim.fn.fnameescape(dir))
    vim.cmd 'enew'
    local ghost = session_file(dir)
    vim.fn.delete(ghost)
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    assert.is_nil(vim.uv.fs_stat(ghost), 'must not write a session for a fileless buffer')

    -- a real file buffer open -> must write
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.bo.swapfile = false
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    assert.is_not_nil(vim.uv.fs_stat(ghost), 'must write a session when a file buffer is open')

    -- restore, and keep the test nvim from persisting this scratch session
    vim.cmd('cd ' .. vim.fn.fnameescape(home))
    vim.fn.delete(ghost)
    helpers.remove_fixture(dir)
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
  end)
end)

describe('sessions.list_projects', function()
  local sessions = require 'config.sessions'
  -- deterministic mtimes via fs_utime; writefile alone can give equal times
  local function write_session(dir, name, lines, mtime)
    local p = dir .. '/' .. name
    vim.fn.writefile(lines, p)
    vim.uv.fs_utime(p, mtime, mtime)
    return p
  end

  it('returns {} on a missing dir and on an empty dir', function()
    assert.same({}, sessions.list_projects(scratch_dir() .. '/does/not/exist'))
    assert.same({}, sessions.list_projects(scratch_dir()))
  end)

  it('lists newest-first, deduped by cwd, newest mtime wins', function()
    local dir = scratch_dir()
    local first, other, nobadd = helpers.fixture_path 'lp-first', helpers.fixture_path 'lp-other', helpers.fixture_path 'lp-no-badd'
    local a = write_session(dir, 'a.vim', { 'badd +1 file', 'cd ' .. first }, 1000000)
    local b = write_session(dir, 'b.vim', { 'badd +2 other', 'cd ' .. first }, 2000000)
    local list = sessions.list_projects(dir)
    assert.equals(1, #list, 'same cwd dedupes to one project')
    assert.equals(first, list[1].label)
    assert.equals(b, list[1].path, 'the newest file wins the dedupe')

    -- a different cwd at an even newer mtime must land above it
    local c = write_session(dir, 'c.vim', { 'badd +3 third', 'cd ' .. other }, 3000000)
    list = sessions.list_projects(dir)
    assert.equals(2, #list)
    assert.equals(c, list[1].path, 'newest mtime first')
    assert.equals(other, list[1].label)

    -- the dashboard's has_badd contract: no badd line, no resume row
    write_session(dir, 'd.vim', { 'cd ' .. nobadd }, 4000000)
    assert.equals(2, #sessions.list_projects(dir), 'session without badd must be skipped')
    helpers.remove_fixture(first)
    helpers.remove_fixture(other)
    helpers.remove_fixture(nobadd)
    vim.fn.delete(dir, 'rf')
  end)

  it('breaks equal-mtime ties by path ascending', function()
    local dir = scratch_dir()
    local tsta, tstb = helpers.fixture_path 'lp-tsta', helpers.fixture_path 'lp-tstb'
    local a = write_session(dir, 'zz.vim', { 'badd +1 f', 'cd ' .. tsta }, 5000000)
    local b = write_session(dir, 'aa.vim', { 'badd +1 f', 'cd ' .. tstb }, 5000000)
    assert.same({
      { label = tstb, path = b, mtime = 5000000 },
      { label = tsta, path = a, mtime = 5000000 },
    }, sessions.list_projects(dir), 'same mtime -> lexicographically smaller path wins')
    helpers.remove_fixture(tsta)
    helpers.remove_fixture(tstb)
    vim.fn.delete(dir, 'rf')
  end)

  it('breaks dedupe ties on equal mtime by path ascending', function()
    local dir = scratch_dir()
    local cwd = helpers.fixture_path 'lp-dedupe'
    write_session(dir, 'zz.vim', { 'badd +1 f', 'cd ' .. cwd }, 5000000)
    local b = write_session(dir, 'aa.vim', { 'badd +1 f2', 'cd ' .. cwd }, 5000000)
    local list = sessions.list_projects(dir)
    assert.equals(1, #list)
    assert.equals(b, list[1].path, 'equal mtime dedupe -> lexicographically smaller path wins')
    helpers.remove_fixture(cwd)
    vim.fn.delete(dir, 'rf')
  end)

  it('%-containing cd paths round-trip to the real cwd label', function()
    local dir = scratch_dir()
    local pct = helpers.fixture_path 'a%20test'
    write_session(dir, 'c.vim', { 'cd ' .. pct, 'badd +1 x' }, 1000000)
    local labels = {}
    for _, e in ipairs(sessions.list_projects(dir)) do
      labels[#labels + 1] = e.label
    end
    assert.is_truthy(vim.tbl_contains(labels, pct), 'expanded cd text preserved verbatim')
    helpers.remove_fixture(pct)
    vim.fn.delete(dir, 'rf')
  end)

  it('drops stale sessions whose cd is a suppressed temp path', function()
    local dir = scratch_dir()
    local good = helpers.fixture_path 'lp-live'
    local stale_cd = vim.fn.tempname()
    local stale = write_session(dir, 'stale.vim', { 'badd +1 f', 'cd ' .. stale_cd }, 9000000)
    local kept = write_session(dir, 'kept.vim', { 'badd +1 f', 'cd ' .. good }, 8000000)
    local list = sessions.list_projects(dir)
    local labels, paths = {}, {}
    for _, e in ipairs(list) do
      labels[#labels + 1] = e.label
      paths[#paths + 1] = e.path
    end
    assert.is_false(vim.tbl_contains(labels, stale_cd), 'temp cwd must not be a project choice')
    assert.is_false(vim.tbl_contains(paths, stale), 'its session file must be gone too')
    assert.is_true(vim.tbl_contains(labels, good), 'a live cwd stays')
    assert.equals(kept, list[1].path)
    helpers.remove_fixture(good)
    vim.fn.delete(dir, 'rf')
  end)
end)

describe('config.terminal', function()
  it('binds every terminal key with a callable handler', function()
    for _, lhs in ipairs {
      '<leader>tt',
      '<leader>tf',
      '<leader>fg',
      '<leader>tm',
      '<leader>t1',
      '<leader>t2',
      '<leader>t3',
      '<leader>tn',
      '<leader>t-',
      '<leader>tv',
    } do
      local m = vim.fn.maparg(lhs, 'n', false, true)
      assert.is_function(m and m.callback, lhs .. ' should be mapped to a Lua function')
      assert.is_truthy(m.desc, lhs .. ' should be documented')
    end
    local c = vim.fn.maparg('<c-\\>', 'n', false, true)
    assert.is_function(c and c.callback, '<c-\\> should toggle the last terminal')
    local t = vim.fn.maparg('<c-\\>', 't', false, true)
    assert.is_function(t and t.callback, '<c-\\> should also work in terminal mode')
  end)

  it('reuses one terminal buffer across toggles and restores the window count', function()
    local tt = vim.fn.maparg('<leader>tt', 'n', false, true)
    local before = #vim.api.nvim_list_wins()
    local bufs_before = #vim.api.nvim_list_bufs()

    tt.callback()
    assert.equals(before + 1, #vim.api.nvim_list_wins(), 'should open a terminal window')
    local terms = vim.tbl_filter(function(b) return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == 'terminal' end, vim.api.nvim_list_bufs())
    assert.equals(1, #terms, 'should create exactly one terminal buffer')

    tt.callback()
    assert.equals(before, #vim.api.nvim_list_wins(), 'second toggle should close the window')
    assert.equals(bufs_before + 1, #vim.api.nvim_list_bufs(), 'buffer should be reused, not recreated')
  end)
end)

describe('config.runner', function()
  it('binds <leader>R and <leader>rf with callable, documented handlers', function()
    for _, lhs in ipairs { '<leader>R', '<leader>rf' } do
      local m = vim.fn.maparg(lhs, 'n', false, true)
      assert.is_function(m and m.callback, lhs .. ' should be mapped to a Lua function')
      assert.is_truthy(m.desc and m.desc:match '%[R%]un', lhs .. ' should be documented: ' .. tostring(m.desc))
    end
  end)

  it('warns instead of opening a terminal for an unknown filetype', function()
    local f = vim.fn.tempname() .. '.unknownext'
    vim.fn.writefile({ 'x' }, f)
    vim.cmd.edit(vim.fn.fnameescape(f))
    vim.bo.filetype = 'definitelynotarunner'

    local msgs, before = {}, #vim.api.nvim_list_wins()
    local real_notify = vim.notify
    vim.notify = function(msg) table.insert(msgs, msg) end
    local ok, err = pcall(vim.fn.maparg('<leader>R', 'n', false, true).callback)
    vim.notify = real_notify
    assert.is_true(ok, tostring(err))

    assert.equals(1, #msgs, 'should notify exactly once')
    assert.is_truthy(msgs[1]:match 'No runner for filetype: definitelynotarunner', msgs[1])
    assert.equals(before, #vim.api.nvim_list_wins(), 'must not open a window')
    vim.fn.delete(f)
  end)

  it('warns when there is no file to run', function()
    vim.cmd 'enew'
    vim.bo.filetype = 'lua'
    assert.equals('', vim.fn.expand '%:p', 'precondition: unnamed buffer has no path')

    local msgs = {}
    local real_notify = vim.notify
    vim.notify = function(msg) table.insert(msgs, msg) end
    local ok, err = pcall(vim.fn.maparg('<leader>R', 'n', false, true).callback)
    vim.notify = real_notify
    assert.is_true(ok, tostring(err))
    assert.equals('No file to run', msgs[1])
  end)
end)

describe('global user commands', function()
  it('DiffOrig reads the current buffer file when the alternate buffer differs', function()
    local dir = scratch_dir()
    local alternate = dir .. '/alternate.txt'
    local current = dir .. '/current.txt'
    vim.fn.writefile({ 'ALTERNATE-ONLY-CONTENT' }, alternate)
    vim.fn.writefile({ 'CURRENT-ONLY-CONTENT' }, current)
    vim.cmd.edit(vim.fn.fnameescape(alternate))
    vim.cmd.edit(vim.fn.fnameescape(current))
    assert.equals(current, vim.api.nvim_buf_get_name(0), 'premise: current buffer is the second file')

    -- capture the command the user command actually builds: relying on `#`
    -- inside the scratch window is fragile (the alternate may point elsewhere).
    local command = vim.api.nvim_get_commands({}).DiffOrig
    assert.is_function(command and command.callback, ':DiffOrig must be a registered user command')
    local captured, real_cmd = nil, vim.cmd
    vim.cmd = function(arg)
      if type(arg) == 'string' and arg:find('++edit', 1, true) then
        captured = arg
      else
        return real_cmd(arg)
      end
    end
    local ok, err = pcall(command.callback)
    vim.cmd = real_cmd
    vim.fn.delete(dir, 'rf')
    assert.is_truthy(ok, tostring(err))
    assert.is_truthy(captured, 'DiffOrig must build a :read command')
    assert.is_truthy(captured:find(vim.fn.fnameescape(current), 1, true), 'the command must name the current file explicitly: ' .. captured)
    assert.is_falsy(captured:find('++edit #', 1, true), 'the command must not depend on the alternate buffer: ' .. captured)
  end)

  it('clears the old startup log before profiling and sorts durations numerically', function()
    local command = vim.api.nvim_get_commands({}).StartupTime
    assert.is_function(command and command.callback, ':StartupTime must be a registered user command')
    local log = vim.fn.stdpath 'cache' .. '/startup.log'
    local events = {}
    local real_cmd, real_delete = vim.cmd, vim.fn.delete
    vim.fn.delete = function(path)
      events[#events + 1] = { kind = 'delete', path = path }
      return 0
    end
    vim.cmd = function(arg)
      if type(arg) == 'string' and arg:find('--startuptime', 1, true) then
        events[#events + 1] = { kind = 'cmd', cmd = arg }
      else
        return real_cmd(arg)
      end
    end
    local ok, err = pcall(command.callback)
    vim.cmd, vim.fn.delete = real_cmd, real_delete
    assert.is_truthy(ok, tostring(err))
    assert.equals('delete', events[1] and events[1].kind, 'the old log must be removed before profiling')
    assert.equals(log, events[1] and events[1].path, 'the startup log path must be cleared')
    local profile = events[2] and events[2].cmd
    assert.is_truthy(profile and profile:find('--startuptime', 1, true), 'must run nvim --startuptime: ' .. tostring(profile))
    assert.is_truthy(profile and profile:find('sort -k2,2nr', 1, true), 'must sort numerically descending on column 2: ' .. tostring(profile))
    assert.is_true(profile:find('--startuptime', 1, true) < profile:find('sort -k2,2nr', 1, true), 'profile before sorting')
  end)
end)
