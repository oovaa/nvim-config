-- Config-source idempotency: sourcing $MYVIMRC repeatedly must not accumulate
-- autocmds. Each autocmd must live in a named, cleared augroup.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_autocmd_idempotency.lua")' -c 'qa!'

describe('autocmd idempotency', function()
  local H = require 'tests.helpers'

  it('sourcing MYVIMRC 4 times does not grow named augroups', function()
    local before = H.autocmd_count()
    before[''] = nil
    for _ = 1, 4 do
      vim.cmd('source ' .. vim.env.MYVIMRC)
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
