-- Formatting backend registration: biome leads JS/TS/JSON only inside a
-- biome-configured repo, prettier remains the backend everywhere else.
describe('formatting', function()
  -- Anchored at /tmp, not tempname(): a $TMPDIR under this home would find
  -- ~/biome.json through the upward root walk and flip the fixtures.
  local function tmpdir()
    local dir = ('/tmp/nvim-format-test-%d'):format(vim.uv.hrtime())
    vim.fn.mkdir(dir, 'p')
    return dir
  end

  -- Resolves the configured chain for a buffer living in `dir`, the way conform
  -- does (init.lua: list_formatters_for_buffer calls ft_formatters(bufnr)).
  local function formatters_in(dir)
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then pcall(lazy.load, { plugins = { 'conform.nvim' } }) end
    local conform = require 'conform'
    local prev = vim.api.nvim_get_current_buf()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_name(bufnr, dir .. '/probe.js')
    local ft = conform.formatters_by_ft.javascript
    ft = type(ft) == 'function' and ft(bufnr) or ft
    vim.api.nvim_set_current_buf(prev)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    assert.is_table(ft)
    return ft
  end

  it('formats javascript with biome when the repo has a biome config', function()
    local dir = tmpdir()
    vim.fn.writefile({ '{}' }, dir .. '/biome.json')
    local ft = formatters_in(dir)
    assert.is_true(vim.tbl_contains(ft, 'biome'))
    assert.is_true(vim.tbl_contains(ft, 'prettier'))
    vim.fn.delete(dir, 'rf')
  end)

  it('uses only biome and prettier in a biome-configured repo', function()
    local dir = tmpdir()
    vim.fn.writefile({ '{}' }, dir .. '/biome.json')
    local ft = formatters_in(dir)
    assert.same({ 'biome', 'prettier' }, ft, 'biome repo chain must have no unreachable organizer entry')
    vim.fn.delete(dir, 'rf')
  end)

  it('formats javascript with prettier only when the repo has no biome config', function()
    local dir = tmpdir()
    assert.is_nil(vim.fs.root(dir, { 'biome.json', 'biome.jsonc' }), 'a parent of /tmp configures biome')
    local ft = formatters_in(dir)
    assert.is_false(vim.tbl_contains(ft, 'biome'))
    assert.is_true(vim.tbl_contains(ft, 'prettier'))
    vim.fn.delete(dir, 'rf')
  end)

  it('never picks up a biome.json in $HOME', function()
    local health = require 'config.health'
    -- Fixture HOME, never the real one: writing $HOME/biome.json changes
    -- format/lint selection for every repo below it if cleanup is interrupted.
    local home = tmpdir()
    vim.fn.writefile({ '{}' }, home .. '/biome.json')
    local real_home = vim.env.HOME
    vim.env.HOME = home
    local ok, err = pcall(function()
      -- the home config exists in the fixture; it must not enable biome anywhere
      assert.equals(vim.fs.normalize(home), vim.fs.normalize(vim.fs.root(home .. '/probe.js', { 'biome.json' })))
      assert.is_nil(health.biome_root(home .. '/probe.js'))
      assert.equals('oxlint', health.js_linter(home .. '/probe.js'))
    end)
    vim.env.HOME = real_home
    vim.fn.delete(home, 'rf')
    assert.is_true(ok, tostring(err))
  end)

  it('keeps prettier for html and css', function()
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then pcall(lazy.load, { plugins = { 'conform.nvim' } }) end
    local conform = require 'conform'
    assert.is_true(vim.tbl_contains(conform.formatters_by_ft.html, 'prettier'))
    assert.is_true(vim.tbl_contains(conform.formatters_by_ft.css, 'prettier'))
  end)
end)
