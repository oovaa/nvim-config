---@module 'config.health'
-- Custom health check: `:checkhealth config`
-- Verifies external tools this config depends on. Add a row when you add a
-- hard dependency; keep it to things that break workflows when missing.

local M = {}

local required = {
  { bin = 'git', why = 'gitsigns, blame.nvim, lazy.nvim updates' },
  { bin = 'rg', why = 'snacks grep, grug-far' },
  { bin = 'node', why = 'LSP servers' },
}

local optional = {
  { bin = 'bun', why = 'JS/TS tooling, vtsls install' },
  { bin = 'python3', why = 'molten-nvim, neotest-python, pyrefly/ty' },
  { bin = 'make', why = 'LuaSnip jsregexp build' },
  { bin = 'fd', why = 'snacks picker speed' },
  { bin = 'lazygit', why = '<leader>fg float' },
  { bin = 'docker', why = 'dockerls, docker_compose_language_service (optional)' },
  { bin = 'pyrefly', why = 'python LSP (optional; uv tool install pyrefly)' },
  { bin = 'ty', why = 'fast python LSP fallback (optional)' },
  { bin = 'biome', why = 'fast JS/TS/JSON formatting + lint (optional)' },
  { bin = 'nginx-language-server', why = 'nginx LSP (optional)' },
  { bin = 'nginxfmt', why = 'nginx format on <leader>ff (pip install nginx-config-formatter)' },
}

--- The biome.json root rule nvim-lint's biome_or_oxlint applies
--- (lua/plugins/ui.lua), applied to `anchor` (a file or a directory). The rule
--- is shared; the anchor is not — the linter uses the buffer, checkhealth uses
--- the cwd, so the two answer differently in a two-project session.
---@param anchor string
---@return 'biome'|'oxlint'
function M.js_linter(anchor) return vim.fs.root(anchor, { 'biome.json', 'biome.jsonc' }) and 'biome' or 'oxlint' end

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
  local mason_bin = vim.fn.stdpath 'data' .. '/mason/bin/'
  for _, bin in ipairs { 'stylua', 'oxlint', 'prettier', 'ruff' } do
    if vim.fn.executable(mason_bin .. bin) == 1 then
      vim.health.ok('mason: ' .. bin .. ' found')
    else
      vim.health.warn('mason: ' .. bin .. ' missing', 'Run :Mason to install')
    end
  end
  -- nvim-treesitter compiles every grammar with the tree-sitter CLI
  -- (`tree-sitter build`, install.lua:do_compile), which itself needs a C
  -- toolchain. No CLI => :TSInstall dies at spawn, whatever cc says.
  if vim.fn.executable 'tree-sitter' == 1 then
    vim.health.ok 'tree-sitter found (nvim-treesitter parser builds; its CLI compiles with a C toolchain)'
  else
    vim.health.warn(
      'tree-sitter missing — nvim-treesitter cannot build parsers',
      'npm i -g tree-sitter-cli (or brew install tree-sitter, or :Mason install tree-sitter-cli)'
    )
  end
  -- nvim-lint picks the JS/TS linter per buffer (biome_or_oxlint in ui.lua),
  -- so this row answers for this cwd only: :checkhealth runs with its own
  -- report buffer current, so there is no user buffer to ask about.
  local biome_root = M.js_linter(vim.uv.cwd()) == 'biome'
  if biome_root and vim.fn.executable 'biome' == 0 and vim.fn.filereadable './node_modules/.bin/biome' == 0 then
    vim.health.warn(
      'JS/TS lint for this cwd: biome — the project configures biome but the binary is missing, so every save errors',
      'Install biome on PATH or in ./node_modules/.bin'
    )
  else
    vim.health.ok(
      'JS/TS lint for this cwd: '
        .. (biome_root and 'biome' or 'oxlint')
        .. ' ('
        .. (biome_root and 'biome.json in project root' or 'no biome.json in project root')
        .. ')'
    )
  end
  local debugpy = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
  if vim.fn.executable(debugpy) == 1 then
    vim.health.ok 'mason: debugpy venv found'
  else
    vim.health.warn('mason: debugpy venv missing', 'Run :Mason to install debugpy')
  end
  if vim.fn.executable 'ueberzugpp' == 1 then
    vim.health.ok 'image backend: ueberzugpp found'
  else
    vim.health.warn('image backend: ueberzugpp missing — image.nvim falls back to kitty graphics', 'Install ueberzugpp for terminals without kitty graphics')
  end
  if (tonumber(vim.g.large_file_size) or 0) > 0 then
    vim.health.ok('large_file_size = ' .. vim.g.large_file_size)
  else
    vim.health.error('vim.g.large_file_size unset', 'Set it in lua/config/options.lua')
  end
  -- Molten requires these imported by the python3 host: try a dry import,
  -- surfaced as optional because Molten is a personal/output workflow.
  for _, mod in ipairs { 'jupyter_client', 'ipykernel' } do
    local ok = vim.system({ 'python3', '-c', 'import ' .. mod }, { text = true }):wait()
    if ok and ok.code == 0 then
      vim.health.ok('python import: ' .. mod .. ' found')
    else
      vim.health.warn(
        'python import missing: ' .. mod .. ' — Molten registration disabled',
        'python3 -m pip install --user ' .. mod .. (mod == 'jupyter_client' and ' ipykernel' or '') .. ' then :UpdateRemotePlugins'
      )
    end
  end
end

return M
