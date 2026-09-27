-- Surgical cleanup assertions.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!'
describe('surgical cleanup', function()
  local H = require('tests.helpers')
  describe('M1 actions-preview', function()
    it('uses the snacks backend, not telescope', function()
      local code = H.code()
      local spec = code:match "'aznhe21/actions%-preview%.nvim'.-\n  %},"
      assert.is_not_nil(spec, 'actions-preview spec should exist')
      assert.is_truthy(spec:match "backend%s*=%s*{%s*'snacks'", 'backend must be snacks')
      assert.is_nil(spec:match 'telescope', 'no telescope string in the actions-preview block')
    end)
  end)
end)
