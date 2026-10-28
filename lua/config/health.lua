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
  { bin = 'vtsls', why = 'typescript LSP (not a mason package; resolved from ~/.bun/bin — absence silently disables TS)' },
  { bin = 'biome', why = 'fast JS/TS/JSON formatting + lint (optional)' },
  { bin = 'nginx-language-server', why = 'nginx LSP (optional)' },
  { bin = 'nginxfmt', why = 'nginx format on <leader>ff (pip install nginx-config-formatter)' },
  { bin = 'jupyter', why = 'molten notebooks (external binary, see init.lua)' },
  { bin = 'jupytext', why = 'molten notebooks (external binary, see init.lua)' },
}

--- The biome.json root rule nvim-lint's biome_or_oxlint and conform's JS/TS
--- formatter chain both apply (lua/plugins/ui.lua, lua/plugins/formatting.lua),
--- to `anchor` (a file or a directory). The rule is shared; the anchor is not
--- — the plugins use the buffer, checkhealth uses the cwd, so the two answer
--- differently in a two-project session.
---
--- A biome.json in $HOME never counts. vim.fs.root walks upward, so that file
--- is found for every repo under home and its config (lineWidth 100, single
--- quotes, 2-space) would format and lint repos that never asked for it. Only a
--- biome.json inside the repo itself enables biome; everywhere else the chain
--- stays on prettier and the linter stays on oxlint.
---@param anchor string
---@return string|nil root dir holding biome.json, or nil when there is none
function M.biome_root(anchor)
  local root = vim.fs.root(anchor, { 'biome.json', 'biome.jsonc' })
  return root and root ~= vim.fs.normalize(vim.env.HOME or '') and root or nil
end

---@param anchor string
---@return 'biome'|'oxlint'
function M.js_linter(anchor) return M.biome_root(anchor) and 'biome' or 'oxlint' end

function M.check()
  vim.health.start 'nvim-config'
  -- Neovim version gate: config relies on 0.12 APIs (winborder, smoothscroll,
  -- vim.lsp.config, incremental selection). Older majors will silently break.
  if vim.fn.has 'nvim-0.12' == 1 then
    vim.health.ok('neovim ' .. tostring(vim.version()) .. ' (>= 0.12)')
  else
    vim.health.error('neovim ' .. tostring(vim.version()) .. ' is too old — this config needs >= 0.12', 'Upgrade Neovim')
  end
  -- Clipboard provider: unnamedplus needs xclip (X11) or wl-copy (Wayland).
  if vim.env.SSH_CONNECTION ~= nil then
    vim.health.ok 'clipboard: skipped over SSH (no forwarding)'
  elseif vim.fn.executable 'xclip' == 1 or vim.fn.executable 'wl-copy' == 1 or vim.fn.executable 'pbcopy' == 1 or vim.fn.executable 'win32yank' == 1 then
    vim.health.ok 'clipboard: provider found (unnamedplus works)'
  else
    vim.health.warn('clipboard: no provider (xclip/wl-copy/pbcopy/win32yank) — yanks stay in nvim only', 'Install xclip (X11) or wl-clipboard (Wayland)')
  end
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
  for _, bin in ipairs { 'stylua', 'lua-language-server', 'oxlint', 'prettier', 'ruff' } do
    if vim.fn.executable(mason_bin .. bin) == 1 then
      vim.health.ok('mason: ' .. bin .. ' found')
    else
      vim.health.warn('mason: ' .. bin .. ' missing', 'Run :Mason to install')
    end
  end
  -- Python LSP is a ladder (AGENTS.md trap 13): ty -> pyrefly ->
  -- pyright-langserver. Reuse the ladder's own predicate so this row can never
  -- drift from what lua/plugins/lsp.lua registers.
  local py_lsp = require('config.python_lsp').installed()
  if #py_lsp > 0 then
    vim.health.ok('python LSP: ' .. table.concat(py_lsp, ', ') .. ' on PATH (ladder: ty -> pyrefly -> pyright-langserver)')
  else
    vim.health.warn('python LSP: none of ty/pyrefly/pyright-langserver on PATH — python files get no LSP', 'uv tool install pyrefly (or npm i -g pyright)')
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
  -- debugpy cannot come from mason on a host whose python3 lacks ensurepip
  -- (Trap 4), so probe the import the adapter actually runs and give advice
  -- that works.
  local debugpy = vim.system({ 'python3', '-c', 'import debugpy' }, { text = true }):wait()
  if debugpy and debugpy.code == 0 then
    vim.health.ok 'python import: debugpy found (<leader>dc runs)'
  else
    vim.health.warn(
      'python import missing: debugpy — <leader>dc cannot launch',
      'uv pip install --system debugpy (needs write access to site-packages; not :Mason, see trap 4)'
    )
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
  -- Molten cells need these imported by the python3 host. Missing modules do
  -- NOT unregister Molten (registration follows the rplugin manifest) — they
  -- only mean :MoltenEvaluate* cannot run until the import succeeds.
  for _, mod in ipairs { 'jupyter_client', 'ipykernel' } do
    local ok = vim.system({ 'python3', '-c', 'import ' .. mod }, { text = true }):wait()
    if ok and ok.code == 0 then
      vim.health.ok('python import: ' .. mod .. ' found')
    else
      vim.health.warn(
        'python import missing: ' .. mod .. ' — Molten cells cannot run',
        'python3 -m pip install --user ' .. mod .. (mod == 'jupyter_client' and ' ipykernel' or '')
      )
    end
  end
end

return M
