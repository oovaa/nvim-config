-- nvim-lint config: biome lints JS/TS only inside a biome-configured project,
-- oxlint stays the single JS/TS linter everywhere else (never both at once).
describe('lint', function()
  local function lint_mod()
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then pcall(lazy.load, { plugins = { 'nvim-lint' } }) end
    return require 'lint'
  end

  -- Resolves the configured javascript linter for a buffer living in `dir`,
  -- the way nvim-lint's try_lint does (lookup_linter: call function linters).
  local function js_linter_in(dir)
    local lint = lint_mod()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_name(bufnr, dir .. '/probe.js')
    local linter = lint.linters[lint.linters_by_ft.javascript[1]]
    if type(linter) == 'function' then linter = linter() end
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return linter
  end

  local function tmpdir()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    return dir
  end

  it('lints javascript with biome when the project has a biome config', function()
    local dir = tmpdir()
    vim.fn.writefile({ '{}' }, dir .. '/biome.json')
    local linter = js_linter_in(dir)
    assert.same(require 'lint.linters.biomejs', linter)
    assert.same({ 'lint' }, linter.args)
  end)

  it('lints javascript with oxlint when the project has no biome config', function()
    local linter = js_linter_in(tmpdir())
    assert.same(require 'lint.linters.oxlint', linter)
    assert.same({ '--format', 'github' }, linter.args)
  end)

  it('never configures two javascript linters (no duplicate diagnostics)', function()
    local lint = lint_mod()
    for _, ft in ipairs { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' } do
      local names = lint.linters_by_ft[ft]
      assert.is_table(names)
      assert.equals(1, #names, ft .. ' has ' .. #names .. ' linters')
    end
    assert.same({ 'ruff' }, lint.linters_by_ft.python)
  end)
end)
