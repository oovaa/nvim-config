-- Formatting backend registration: biome is offered where it is useful while
-- prettier remains available as the compatibility backend.
describe('formatting', function()
  it('registers biome and keeps prettier in the javascript backend list', function()
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then pcall(lazy.load, { plugins = { 'conform.nvim' } }) end
    local conform = require 'conform'
    local ft = conform.formatters_by_ft.javascript
    assert.is_table(ft)
    assert.is_true(vim.tbl_contains(ft, 'biome'))
    assert.is_true(vim.tbl_contains(ft, 'prettier'))
  end)

  it('keeps prettier for html and css', function()
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then pcall(lazy.load, { plugins = { 'conform.nvim' } }) end
    local conform = require 'conform'
    assert.is_true(vim.tbl_contains(conform.formatters_by_ft.html, 'prettier'))
    assert.is_true(vim.tbl_contains(conform.formatters_by_ft.css, 'prettier'))
  end)
end)
