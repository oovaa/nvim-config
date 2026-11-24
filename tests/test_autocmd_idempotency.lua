-- Config-reload idempotency: invoking <leader>ur repeatedly must not accumulate
-- autocmds. Each autocmd must live in a named, cleared augroup.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_autocmd_idempotency.lua")' -c 'qa!'

describe('autocmd idempotency', function()
  local H = require 'tests.helpers'

  it('the reload callback 4 times does not grow named augroups', function()
    local before = H.autocmd_count()
    before[''] = nil

    local lhs = (vim.g.mapleader or ' ') .. 'ur'
    local mapping
    for _, m in ipairs(vim.api.nvim_get_keymap 'n') do
      if m.lhs == lhs then mapping = m end
    end
    assert.is_not_nil(mapping, 'normal-mode ' .. lhs .. ' mapping must exist')
    assert.is_function(mapping.callback, 'reload mapping must be a Lua callback')

    for _ = 1, 4 do
      mapping.callback()
    end
    local after = H.autocmd_count()
    after[''] = nil

    for group, count in pairs(before) do
      assert.is_true(type(group) == 'string' and group ~= '', 'tracked augroup must be a non-empty string')
      local newcount = after[group] or 0
      assert.is_true(newcount <= count, string.format('augroup %q grew: %d -> %d', group, count, newcount))
    end
    for group in pairs(after) do
      assert.is_true(type(group) == 'string' and group ~= '', 'new augroup must be a non-empty string')
    end
  end)
end)
