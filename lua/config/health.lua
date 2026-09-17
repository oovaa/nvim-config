---@module 'config.health'
-- Custom health check: `:checkhealth config`
-- Verifies external tools this config depends on. Add a row when you add a
-- hard dependency; keep it to things that break workflows when missing.

local M = {}

local required = {
  { bin = 'git', why = 'gitsigns, blame.nvim, lazy.nvim updates' },
  { bin = 'rg', why = 'telescope live_grep, grug-far' },
  { bin = 'node', why = 'LSP servers' },
}

local optional = {
  { bin = 'bun', why = 'JS/TS tooling, vtsls install' },
  { bin = 'python3', why = 'molten-nvim, neotest-python, pyrefly' },
  { bin = 'make', why = 'telescope-fzf-native build' },
  { bin = 'fd', why = 'telescope find_files speed' },
  { bin = 'lazygit', why = '<leader>fg float' },
  { bin = 'cmake', why = 'telescope-fzf-native build' },
  { bin = 'docker', why = 'dockerls, docker_compose_language_service (optional)' },
  { bin = 'pyrefly', why = 'python LSP' },
}

function M.check()
  vim.health.start 'nvim-config'
  for _, t in ipairs(required) do
    if vim.fn.executable(t.bin) == 1 then
      vim.health.ok(t.bin .. ' found (' .. t.why .. ')')
    else
      vim.health.error(t.bin .. ' missing — ' .. t.why, 'Install ' .. t.bin)
    end
  end
  for _, t in ipairs(optional) do
    if vim.fn.executable(t.bin) == 1 then
      vim.health.ok(t.bin .. ' found (' .. t.why .. ')')
    else
      vim.health.warn(t.bin .. ' missing — ' .. t.why, 'Install ' .. t.bin)
    end
  end
  local mason_bin = vim.fn.stdpath('data') .. '/mason/bin/'
  for _, bin in ipairs({ 'stylua', 'oxlint', 'prettier', 'ruff' }) do
    if vim.fn.executable(mason_bin .. bin) == 1 then
      vim.health.ok('mason: ' .. bin .. ' found')
    else
      vim.health.warn('mason: ' .. bin .. ' missing', 'Run :Mason to install')
    end
  end
  local debugpy = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
  if vim.fn.executable(debugpy) == 1 then
    vim.health.ok('mason: debugpy venv found')
  else
    vim.health.warn('mason: debugpy venv missing', 'Run :Mason to install debugpy')
  end
  if vim.fn.executable('ueberzugpp') == 1 then
    vim.health.ok('image backend: ueberzugpp found')
  else
    vim.health.warn('image backend: ueberzugpp missing — image.nvim falls back to kitty graphics',
      'Install ueberzugpp for terminals without kitty graphics')
  end
  if (tonumber(vim.g.large_file_size) or 0) > 0 then
    vim.health.ok('large_file_size = ' .. vim.g.large_file_size)
  else
    vim.health.error('vim.g.large_file_size unset', 'Set it in lua/config/options.lua')
  end
end

return M
