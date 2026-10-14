---@module 'config.python_lsp'
-- Python LSP ladder: ty -> pyrefly -> pyright-langserver, first hit on PATH
-- wins (AGENTS.md trap 13). The CHOICE lives here so tests/test_python_tools.lua
-- can drive it with a mocked vim.fn.executable; lua/plugins/lsp.lua keeps only
-- the registration (filetypes, root markers, vim.lsp.config).
-- ponytail: executable() only — no spawn, no vim.system, no PATH probing, so
-- the ladder is a pure function of what `resolve` is told is installed.

local M = {}

--- Ladder order. `bin` is what must be on PATH; `name` is the vim.lsp.config
--- key, which differs for pyright (its binary is pyright-langserver).
local LADDER = {
  { name = 'ty', bin = 'ty', cmd = { 'ty', 'server' } },
  { name = 'pyrefly', bin = 'pyrefly', cmd = { 'pyrefly', 'lsp' }, settings = { python = { pyrefly = { typeCheckingMode = 'default' } } } },
  { name = 'pyright', bin = 'pyright-langserver', cmd = { 'pyright-langserver', '--stdio' } },
}

--- The one executable() predicate resolve() and installed() share, so the
--- health row and :NvimCheckPythonLsp can never drift from the selection.
local function on_path(bin) return vim.fn.executable(bin) == 1 end

--- Which of the three binaries are on PATH, in ladder order.
---@return string[]
function M.installed()
  local found = {}
  for _, s in ipairs(LADDER) do
    if on_path(s.bin) then found[#found + 1] = s.bin end
  end
  return found
end

--- The server the ladder selects, or nil when none of the three is installed.
---@return {name: string, cmd: string[], settings: table|nil}|nil
function M.resolve()
  for _, s in ipairs(LADDER) do
    if on_path(s.bin) then return vim.deepcopy { name = s.name, cmd = s.cmd, settings = s.settings } end
  end
end

return M
