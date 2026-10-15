-- Tier 1 data-safety: the tests that would lose the user's code.
-- T1.4 guards Trap 11 (a save fired mid-insert must write RAW text); T1.1 and
-- T1.2 cover auto-save's two paths; T1.7 the undofile round-trip; T1.8 the
-- E37 quit guard; T1.11 the large-file format skip.
-- Cases needing an external binary `pending()` when it is absent instead of
-- failing, so the suite stays green on machines without the toolchain.

local function tmpdir(name)
  local d = '/tmp/nvim-safety-' .. name .. '-' .. tostring(vim.uv.hrtime())
  vim.fn.mkdir(d, 'p')
  return d
end

local function need(bin)
  if vim.fn.executable(bin) == 0 then pending(bin .. ' not on PATH — data-safety case skipped') end
end

-- The real format_on_save closure from the conform spec (not a copy of it).
local function format_on_save()
  local specs = require 'plugins.formatting'
  for _, s in ipairs(specs) do
    if type(s) == 'table' and s[1] == 'stevearc/conform.nvim' then return assert(s.opts.format_on_save, 'conform spec has no format_on_save') end
  end
  error 'conform spec not found in plugins.formatting'
end

local function with_mode(mode, fn)
  local orig = vim.api.nvim_get_mode
  vim.api.nvim_get_mode = function() return { mode = mode, blocking = false } end
  local ok, err = pcall(fn)
  vim.api.nvim_get_mode = orig
  if not ok then error(err) end
end

local function scratch(ft)
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].filetype = ft
  return b
end

describe('data-safety', function()
  it('T1.4a: format_on_save stays raw in insert/select/replace modes', function()
    local fos = format_on_save()
    local b = scratch 'python'
    for _, m in ipairs { 'i', 'niI', 's', 'S', '\19', 'R' } do
      with_mode(m, function() assert.is_nil(fos(b), 'mode ' .. vim.inspect(m) .. ' must skip formatting') end)
    end
    with_mode('n', function()
      local got = fos(b)
      assert.is_table(got, 'normal mode on python must format')
      assert.are.equal(2000, got.timeout_ms)
      -- python's chain is organize-then-format: stopping early would silently
      -- drop ruff_format after the organize no-op (regression this pins).
      assert.is_false(got.stop_after_first, 'python must run the whole chain')
    end)
    with_mode('n', function()
      local jb = scratch 'javascript'
      local got = fos(jb)
      assert.is_table(got, 'normal mode on javascript must format')
      assert.is_true(got.stop_after_first, 'biome-first chains stop at the first hit')
      vim.api.nvim_buf_delete(jb, { force = true })
    end)
    with_mode('n', function() assert.is_nil(fos(scratch 'text'), 'unlisted filetypes must not format') end)
    vim.b[b].large_file_mode = true
    with_mode('n', function() assert.is_nil(fos(b), 'large files must not auto-format') end)
    vim.api.nvim_buf_delete(b, { force = true })
  end)

  it('T1.4b: a write fired mid-insert lands RAW, the next write formats', function()
    need 'ruff'
    local d = tmpdir 'trap11'
    local file = d .. '/half.py'
    vim.fn.writefile({ 'x=1' }, file)
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
    -- Headless nvim cannot hold insert mode: text inserts fine but the mode
    -- snaps back to n (even :startinsert reports n with no UI loop). So stub
    -- the single predicate the guard reads; the conform BufWritePre path,
    -- the ruff invocation and the byte comparison all stay real.
    vim.api.nvim_feedkeys('A  #half', 'x', false)
    assert.is_truthy(vim.api.nvim_get_current_line():find('x=1  #half', 1, true), 'the half-typed text must be in the buffer')
    local orig = vim.api.nvim_get_mode
    vim.api.nvim_get_mode = function() return { mode = 'i', blocking = false } end
    local ok, werr = pcall(vim.cmd, 'write')
    vim.api.nvim_get_mode = orig
    assert.is_true(ok, ':write must not error: ' .. tostring(werr))
    local raw = table.concat(vim.fn.readfile(file), '\n')
    assert.is_truthy(raw:find('x=1  #half', 1, true), 'mid-insert write must not reflow: ' .. raw)
    vim.cmd 'write'
    local cooked = table.concat(vim.fn.readfile(file), '\n')
    assert.is_truthy(cooked:find('x = 1', 1, true), 'the next save outside insert must format: ' .. cooked)
    pcall(vim.cmd, 'silent! %bwipeout!')
    vim.fn.delete(d, 'rf')
  end)

  it('T1.1: auto-save persists a normal edit with no :w', function()
    pcall(require('lazy').load, { plugins = { 'auto-save.nvim' } })
    local d = tmpdir 'autosave'
    local file = d .. '/t.txt'
    vim.fn.writefile({ 'one' }, file)
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
    vim.api.nvim_feedkeys('Ax', 'x', false)
    vim.api.nvim_feedkeys('<Esc>', 'x', false)
    local ok = vim.wait(8000, function() return table.concat(vim.fn.readfile(file), '\n'):find('onex', 1, true) ~= nil end, 100)
    assert.is_true(ok, 'auto-save must write within 8s without :w')
    pcall(vim.cmd, 'silent! %bwipeout!')
    vim.fn.delete(d, 'rf')
  end)

  it('T1.2: edits made <1s before a buffer switch survive via immediate_save', function()
    pcall(require('lazy').load, { plugins = { 'auto-save.nvim' } })
    local d = tmpdir 'immediate'
    local a, b = d .. '/a.txt', d .. '/b.txt'
    vim.fn.writefile({ 'a' }, a)
    vim.fn.writefile({ 'b' }, b)
    vim.cmd('edit ' .. vim.fn.fnameescape(a))
    vim.api.nvim_feedkeys('Ax', 'x', false)
    vim.api.nvim_feedkeys('<Esc>', 'x', false)
    vim.cmd('edit ' .. vim.fn.fnameescape(b))
    local body = table.concat(vim.fn.readfile(a), '\n')
    assert.is_truthy(body:find('ax', 1, true), 'BufLeave must save immediately, not wait out the debounce: ' .. body)
    pcall(vim.cmd, 'silent! %bwipeout!')
    vim.fn.delete(d, 'rf')
  end)

  it('T1.7: undofile restores the pre-edit text across a reopen', function()
    local d = tmpdir 'undo'
    local file = d .. '/u.txt'
    vim.fn.writefile({ 'one' }, file)
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
    vim.api.nvim_feedkeys('otwo', 'x', false)
    vim.api.nvim_feedkeys('<Esc>', 'x', false)
    vim.cmd 'write'
    pcall(vim.cmd, 'silent! %bwipeout!')
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
    vim.api.nvim_feedkeys('u', 'x', false)
    assert.are.same({ 'one' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    pcall(vim.cmd, 'silent! %bwipeout!')
    vim.fn.delete(d, 'rf')
  end)

  it('T1.8: :q with unsaved changes never silently discards them', function()
    -- vim.o.confirm is on and auto-save's QuitPre saves first, so :q on a
    -- dirty buffer succeeds by writing — E37 cannot fire in the shipped
    -- config, and a bare :q would quit nvim mid-suite. Prove the guarantee in
    -- a child instead: exit 0 plus the unsaved bytes on disk.
    assert.is_true(vim.o.confirm, 'confirm must stay on: it is the quit guard')
    local d = tmpdir 'quitguard'
    local file = d .. '/dirty.txt'
    vim.fn.writefile({ 'saved' }, file)
    local script = d .. '/quit.lua'
    vim.fn.writefile({
      "pcall(require('lazy').load, { plugins = { 'auto-save.nvim' } })",
      "vim.cmd('edit " .. vim.fn.fnameescape(file) .. "')",
      "vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved work' })",
      "local ok, err = pcall(vim.cmd, 'q')",
      "if not ok then io.stdout:write('QUIT-REFUSED:' .. tostring(err)) vim.cmd('cquit 1') end",
    }, script)
    local res = vim.system({ 'nvim', '--headless', '-c', 'luafile ' .. vim.fn.fnameescape(script), '-c', 'qa!' }, { text = true, timeout = 60000 }):wait()
    assert.are.equal(0, res.code, ':q must succeed, not refuse: ' .. (res.stdout or '') .. (res.stderr or ''))
    local body = table.concat(vim.fn.readfile(file), '\n')
    assert.is_truthy(body:find('unsaved work', 1, true), 'the quit must have saved first: ' .. body)
    vim.fn.delete(d, 'rf')
  end)
end)
