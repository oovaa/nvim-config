-- Test helpers for Neovim config tests
local M = {}

-- Create a temporary buffer with content
function M.create_buf(content, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  if type(content) == 'string' then
    content = vim.split(content, '\n')
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

-- Clean up buffer
function M.cleanup_buf(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

-- Spy on vim.cmd calls
function M.spy_on_cmd()
  local calls = {}
  local original = vim.cmd
  vim.cmd = function(cmd)
    table.insert(calls, cmd)
    return original(cmd)
  end
  return {
    calls = calls,
    restore = function() vim.cmd = original end,
    assert_called = function(self, pattern)
      local found = false
      for _, c in ipairs(self.calls) do
        if c:match(pattern) then found = true break end
      end
      assert(found, 'Expected vim.cmd matching "' .. pattern .. '" but got: ' .. vim.inspect(self.calls))
    end,
    assert_not_called = function(self, pattern)
      for _, c in ipairs(self.calls) do
        assert(not c:match(pattern), 'Unexpected vim.cmd matching "' .. pattern .. '": ' .. c)
      end
    end,
  }
end

-- Get plugin spec from lazy
function M.get_plugin(name)
  local lazy = require('lazy')
  return lazy.plugins()[name]
end

-- Check if a keymap exists in which-key spec
function M.has_which_key_group(prefix)
  local wk = require('which-key')
  local spec = wk.opts.spec
  for _, s in ipairs(spec) do
    if s[1] == '<leader>' .. prefix then return true end
  end
  return false
end

return M