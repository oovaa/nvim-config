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
end)
