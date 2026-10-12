-- Behavior tests for the hand-required config modules that previously had
-- nothing but `assert.has_no_error(require ...)`: sessions and runner.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_config_modules.lua")' -c 'qa!'

local function scratch_dir()
  local d = vim.fn.tempname()
  vim.fn.mkdir(d, 'p')
  return d
end

describe('config.sessions', function()
  local session_file = _G._builtin_session_file
  local session_files = _G._builtin_session_files

  it('exports its helpers for the dashboard session picker', function()
    assert.is_function(session_file, 'must export the path builder')
    assert.is_function(session_files, 'must export the listing fn')
    assert.is_function(_G._builtin_find_session)
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
    -- live there; it is removed again at the end.
    local dir = scratch_dir()
    local target = dir .. '/proj'
    vim.fn.mkdir(target, 'p')
    local p = vim.fn.stdpath 'data' .. '/sessions/zz-test-' .. vim.fn.sha256(dir):sub(1, 8) .. '.vim'
    vim.fn.mkdir(vim.fn.stdpath 'data' .. '/sessions', 'p')
    local fd = assert(io.open(p, 'w'))
    fd:write('badd 1\n' .. 'cd ' .. target .. '\n')
    fd:close()

    assert.equals(p, _G._builtin_find_session(target), 'should find the session whose cd matches the cwd')
    vim.fn.delete(p)
    vim.fn.delete(dir, 'rf')
  end)

  it('registers exactly one VimLeavePre writer so reload cannot stack it', function()
    -- AGENTS.md trap 2: <leader>ur re-sources the config; a nameless augroup
    -- would stack a second writer and clobber the session on every reload.
    local aus = vim.api.nvim_get_autocmds { event = 'VimLeavePre', group = 'BuiltinSessions' }
    assert.equals(1, #aus, 'BuiltinSessions must hold exactly one autocmd')
  end)

  it('writes a session on exit, but not for a fileless buffer', function()
    local home = vim.fn.getcwd()
    local dir = scratch_dir()
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
    vim.fn.delete(dir, 'rf')
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
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
