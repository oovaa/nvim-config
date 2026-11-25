-- nvim-lint config: biome lints JS/TS only inside a biome-configured project,
-- oxlint stays the single JS/TS linter everywhere else (never both at once).
describe('lint', function()
  local function lint_mod()
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then pcall(lazy.load, { plugins = { 'nvim-lint' } }) end
    return require 'lint'
  end

  -- Anchored at /tmp, not vim.fn.tempname(): tempname() honours $TMPDIR, and a
  -- $TMPDIR under a biome-configured home would flip the fixtures for reasons
  -- unrelated to the code.
  local function tmpdir()
    local dir = ('/tmp/nvim-lint-test-%d'):format(vim.uv.hrtime())
    vim.fn.mkdir(dir, 'p')
    return dir
  end

  -- Resolves the configured javascript linter for a buffer living in `dir`,
  -- the way nvim-lint's try_lint does (lookup_linter: call function linters).
  local function js_linter_in(dir)
    local lint = lint_mod()
    local prev = vim.api.nvim_get_current_buf()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_name(bufnr, dir .. '/probe.js')
    local linter = lint.linters[lint.linters_by_ft.javascript[1]]
    if type(linter) == 'function' then linter = linter() end
    vim.api.nvim_set_current_buf(prev)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return linter
  end

  -- The biome branch is returned as a copy with `cwd` pinned, so compare the
  -- linter's own fields against the nvim-lint module, cwd excluded.
  local function linter_fields(linter)
    local copy = vim.deepcopy(linter)
    copy.cwd = nil
    return copy
  end

  it('lints javascript with biome when the project has a biome config', function()
    local dir = tmpdir()
    vim.fn.writefile({ '{}' }, dir .. '/biome.json')
    local linter = js_linter_in(dir)
    assert.same(linter_fields(require 'lint.linters.biomejs'), linter_fields(linter))
    vim.fn.delete(dir, 'rf')
  end)

  it('lints javascript with oxlint when the project has no biome config', function()
    local dir = tmpdir()
    -- premise guard: the upward root walk must find nothing, or this test is
    -- measuring the fixture, not the config
    assert.is_nil(vim.fs.root(dir, { 'biome.json', 'biome.jsonc' }), 'a parent of /tmp configures biome')
    local linter = js_linter_in(dir)
    assert.same(linter_fields(require 'lint.linters.oxlint'), linter_fields(linter))
    vim.fn.delete(dir, 'rf')
  end)

  it('runs biome from the buffer project root, not from nvim cwd', function()
    local dir = tmpdir()
    vim.fn.writefile({ '{}' }, dir .. '/biome.json')
    local linter = js_linter_in(dir)
    -- biome resolves its config from cwd: run from a foreign root it aborts
    -- with exit 1 and nvim-lint's ignore_exitcode swallows it into zero
    -- diagnostics instead of an error.
    assert.equals(dir, linter.cwd)
    -- copy, not mutation: lint.lua stamps `name` on whatever table it is given
    assert.is_nil(require('lint.linters.biomejs').cwd)
    vim.fn.delete(dir, 'rf')
  end)

  it('resolves one linter per JS/TS filetype, and the two branches differ', function()
    local lint = lint_mod()
    for _, ft in ipairs { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' } do
      local names = lint._resolve_linter_by_ft(ft)
      assert.equals(1, #names, ft .. ' resolves ' .. #names .. ' linters: ' .. vim.inspect(names))
    end
    assert.same({ 'ruff' }, lint._resolve_linter_by_ft 'python')

    local biome_dir, plain_dir = tmpdir(), tmpdir()
    vim.fn.writefile({ '{}' }, biome_dir .. '/biome.json')
    assert.is_false(vim.deep_equal(js_linter_in(biome_dir), js_linter_in(plain_dir)))
    vim.fn.delete(biome_dir, 'rf')
    vim.fn.delete(plain_dir, 'rf')
  end)

  it('health uses the same biome root rule, cwd-anchored', function()
    local health = require 'config.health'
    local biome_dir, plain_dir = tmpdir(), tmpdir()
    vim.fn.writefile({ '{}' }, biome_dir .. '/biome.json')
    assert.equals('biome', health.js_linter(biome_dir .. '/probe.js'))
    assert.equals('oxlint', health.js_linter(plain_dir .. '/probe.js'))
    vim.fn.delete(biome_dir, 'rf')
    vim.fn.delete(plain_dir, 'rf')
  end)

  it('ignores a biome.json in $HOME, for a buffer under it', function()
    local health = require 'config.health'
    -- Fixture HOME only: the real $HOME must never get a biome.json from a test.
    local home = tmpdir()
    vim.fn.writefile({ '{}' }, home .. '/biome.json')
    local real_home = vim.env.HOME
    vim.env.HOME = home
    local ok, err = pcall(function()
      -- ~/biome.json exists in the fixture, so the upward root walk would
      -- otherwise enable biome for every repo under home.
      assert.equals(vim.fs.normalize(home), vim.fs.normalize(vim.fs.root(home .. '/x/probe.js', { 'biome.json' })))
      assert.is_nil(health.biome_root(home .. '/x/probe.js'))
      assert.equals('oxlint', health.js_linter(home .. '/x/probe.js'))
    end)
    vim.env.HOME = real_home
    vim.fn.delete(home, 'rf')
    assert.is_true(ok, tostring(err))
  end)

  it('skips BufWritePost lint in raw modes but keeps InsertLeave and manual lint', function()
    local lint = lint_mod()
    -- premise: the lint-on-save group owns the BufWritePost callback
    local autocmds = vim.api.nvim_get_autocmds { group = 'lint-on-save' }
    assert.is_true(#autocmds > 0, 'lint-on-save group must be registered')
    local callback
    for _, a in ipairs(autocmds) do
      local evs = type(a.event) == 'table' and a.event or { a.event }
      if vim.tbl_contains(evs, 'BufWritePost') then callback = a.callback end
    end
    assert.is_function(callback, 'BufWritePost lint callback must exist')

    local real_try, real_mode = lint.try_lint, vim.api.nvim_get_mode
    local calls = 0
    lint.try_lint = function() calls = calls + 1 end
    local buf = vim.api.nvim_create_buf(false, true)
    local ok, err = pcall(function()
      local function set_mode(m)
        vim.api.nvim_get_mode = function() return { mode = m, blocking = false } end
      end
      local function fire(event) callback { buf = buf, event = event } end

      -- Raw modes: BufWritePost writes the buffer untouched; InsertLeave still lints.
      for _, m in ipairs { 'i', 'niI', 's', 'S', '\19', 'R', 'Rc' } do
        set_mode(m)
        calls = 0
        fire 'BufWritePost'
        assert.equals(0, calls, 'BufWritePost must skip lint in mode ' .. vim.inspect(m))
        calls = 0
        fire 'InsertLeave'
        assert.equals(1, calls, 'InsertLeave must lint even in mode ' .. vim.inspect(m))
      end

      -- Normal mode: BufWritePost lints as before.
      set_mode 'n'
      calls = 0
      fire 'BufWritePost'
      assert.equals(1, calls, 'BufWritePost must lint in normal mode')

      -- Manual lint calls try_lint directly, with no mode guard in the way.
      calls = 0
      lint.try_lint()
      assert.equals(1, calls, 'manual lint must still run')
    end)
    vim.api.nvim_get_mode = real_mode
    lint.try_lint = real_try
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    assert.is_truthy(ok, tostring(err))
  end)

  it('lints the event buffer even when another buffer is current', function()
    local lint = lint_mod()
    local callback
    for _, a in ipairs(vim.api.nvim_get_autocmds { group = 'lint-on-save' }) do
      local evs = type(a.event) == 'table' and a.event or { a.event }
      if vim.tbl_contains(evs, 'BufWritePost') then callback = a.callback end
    end
    assert.is_function(callback, 'BufWritePost lint callback must exist')

    local dir = tmpdir()
    local target = dir .. '/probe.sql'
    vim.fn.writefile({ 'select 1;' }, target)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, target)
    local other = vim.api.nvim_create_buf(false, true)
    local prev = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(other)

    local real_try, real_mode = lint.try_lint, vim.api.nvim_get_mode
    local seen_buf, seen_name = nil, nil
    lint.try_lint = function()
      seen_buf = vim.api.nvim_get_current_buf()
      for _, a in ipairs(lint.linters.sqruff.args) do
        if type(a) == 'function' then seen_name = a() end
      end
    end
    vim.api.nvim_get_mode = function() return { mode = 'n', blocking = false } end
    local ok, err = pcall(function()
      callback { buf = buf, event = 'BufWritePost' }
      assert.equals(buf, seen_buf, 'lint must run in the event buffer, not the buffer on screen')
      assert.equals(target, seen_name, 'sqruff file-path args must name the lint target')
    end)
    vim.api.nvim_get_mode, lint.try_lint = real_mode, real_try
    vim.api.nvim_set_current_buf(prev)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    pcall(vim.api.nvim_buf_delete, other, { force = true })
    vim.fn.delete(dir, 'rf')
    assert.is_truthy(ok, tostring(err))
  end)
end)
