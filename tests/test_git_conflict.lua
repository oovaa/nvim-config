-- E2E: merge-conflict handling through a real git merge. The plugin must load
-- when a file buffer opens (BufReadPre), detect the conflicted buffer via git,
-- install its buffer-local maps, and `co` must resolve to "ours" — ending in
-- the right bytes on disk.
-- The inner nvim runs under a PTY (`script`): the plugin parses buffers from
-- its decoration provider, which only runs on screen redraw — never under
-- --headless. pending() where git/script are missing instead of failing.
describe('git-conflict', function()
  it('detects a real merge conflict on open and resolves it with co', function()
    if vim.fn.executable 'git' == 0 then pending 'git not available' end
    if vim.fn.executable 'script' == 0 then pending 'util-linux script not available (needed for the PTY)' end

    local d = '/tmp/nvim-gitconflict-' .. tostring(vim.uv.hrtime())
    local repo = d .. '/repo'
    vim.fn.mkdir(repo, 'p')

    local function git(...)
      local res = vim.system({ 'git', '-C', repo, '-c', 'user.email=test@test', '-c', 'user.name=test', ... }, { text = true }):wait()
      assert.are.equal(0, res.code, 'git ' .. table.concat({ ... }, ' ') .. ' failed: ' .. (res.stderr or ''))
      return res.stdout
    end

    git('init', '-q', '-b', 'main')
    local file = repo .. '/notes.txt'
    vim.fn.writefile({ 'base line' }, file)
    git('add', '-A')
    git('commit', '-qm', 'base')
    git('checkout', '-q', '-b', 'side')
    vim.fn.writefile({ 'theirs line' }, file)
    git('commit', '-qam', 'side')
    git('checkout', '-q', 'main')
    -- main needs its own commit or the merge would fast-forward
    vim.fn.writefile({ 'ours line' }, file)
    git('commit', '-qam', 'main')
    -- A conflicting merge exits 1 and leaves the markers on disk.
    local merge = vim.system({ 'git', '-C', repo, '-c', 'user.email=test@test', '-c', 'user.name=test', 'merge', 'side' }, { text = true }):wait()
    assert.are.equal(1, merge.code, 'merge should conflict: ' .. (merge.stdout or '') .. (merge.stderr or ''))

    local result = d .. '/result.txt'
    local driver = d .. '/driver.lua'
    vim.fn.writefile(
      vim.split(
        ([==[
local function fail(msg)
  vim.fn.writefile({ 'FAIL: ' .. msg }, 'RESULT_PATH')
  vim.cmd 'cquit 1'
end
local ok, err = pcall(function()
  -- detection: plugin loaded on BufReadPre and git listed the buffer as
  -- conflicted (conflict_count errors until the first parse, so pcall it)
  local detected = vim.wait(20000, function()
    vim.cmd 'redraw'
    local gc = package.loaded['git-conflict']
    if not gc then return false end
    local ok_count, count = pcall(gc.conflict_count, 0)
    return ok_count and count > 0
  end, 200)
  if not detected then
    local gc = package.loaded['git-conflict']
    local count = gc and select(2, pcall(gc.conflict_count, 0))
    fail('no conflict detected (loaded=' .. tostring(gc ~= nil) .. ', count=' .. tostring(count) .. ')')
  end
  -- the decoration provider's parse fires GitConflictDetected, which installs
  -- the buffer-local mappings
  local mapped = vim.wait(10000, function()
    vim.cmd 'redraw'
    return vim.b.conflict_mappings_set == true
  end, 200)
  if not mapped then fail 'buffer-local conflict mappings never installed' end
  local m = vim.fn.maparg('co', 'n', false, true)
  if m.lhs ~= 'co' or m.buffer ~= 1 then fail('co is not a buffer-local mapping here: ' .. vim.inspect(m)) end
  -- resolve the first conflict keeping ours
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys('co', 'x', false)
  local joined = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  if joined:find('<<<<<<<', 1, true) or joined:find('>>>>>>>', 1, true) then fail('markers survived co: ' .. joined) end
  if not joined:find('ours line', 1, true) then fail('co did not keep ours: ' .. joined) end
  vim.cmd 'write'
end)
if not ok then fail(tostring(err)) end
vim.fn.writefile({ 'OK' }, 'RESULT_PATH')
]==]):gsub('RESULT_PATH', result),
        '\n'
      ),
      driver
    )

    -- TERM must be real inside the PTY; the outer headless nvim may not have one.
    local env = vim.fn.environ()
    env.TERM = 'xterm-256color'
    local inner = ('%s %s -c "luafile %s" -c "qa!"'):format(vim.v.progpath, vim.fn.fnameescape(file), driver)
    local res = vim.system({ 'script', '-qec', inner, '/dev/null' }, { cwd = repo, env = env, text = true, timeout = 120000 }):wait()
    local report = table.concat(vim.fn.readfile(result), ' ')
    assert.are.equal(0, res.code, 'inner nvim failed: ' .. report .. '\n' .. (res.stdout or ''):sub(-2000) .. (res.stderr or ''))
    assert.are.equal('OK', report, 'driver did not finish clean: ' .. report)
    assert.are.same({ 'ours line' }, vim.fn.readfile(file), 'the resolved file on disk must keep ours')
    vim.fn.delete(d, 'rf')
  end)
end)
