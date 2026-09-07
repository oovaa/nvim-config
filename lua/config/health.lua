---@module 'config.health'
-- Custom health check: `:checkhealth config.health`
-- Verifies external tools this config depends on. Add a row when you add a
-- hard dependency; keep it to things that break workflows when missing.

local M = {}

local tools = {
  { bin = 'git', why = 'gitsigns, blame.nvim, lazy.nvim updates' },
  { bin = 'rg', why = 'telescope live_grep, grug-far' },
  { bin = 'bun', why = 'JS/TS tooling, vtsls install' },
  { bin = 'node', why = 'LSP servers' },
  { bin = 'python3', why = 'molten-nvim, neotest-python, pyrefly' },
  { bin = 'make', why = 'telescope-fzf-native build' },
}

function M.check()
  vim.health.start 'nvim-config'
  for _, t in ipairs(tools) do
    if vim.fn.executable(t.bin) == 1 then
      vim.health.ok(t.bin .. ' found (' .. t.why .. ')')
    else
      vim.health.warn(t.bin .. ' missing — ' .. t.why, 'Install ' .. t.bin)
    end
  end
  if (tonumber(vim.g.large_file_size) or 0) > 0 then
    vim.health.ok('large_file_size = ' .. vim.g.large_file_size)
  else
    vim.health.error('vim.g.large_file_size unset', 'Set it in lua/config/options.lua')
  end
end

return M
