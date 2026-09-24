---@module 'tests.helpers'
-- Location-agnostic config reader for specs: concatenates init.lua + every
-- lua/**/*.lua so string assertions survive file moves (modular split).

local M = {}

function M.read(path) return table.concat(vim.fn.readfile(path), '\n') end

function M.all()
  local root = vim.fn.stdpath 'config'
  local parts = { M.read(root .. '/init.lua') }
  local files = vim.fn.glob(root .. '/lua/**/*.lua', false, true)
  table.sort(files)
  for _, f in ipairs(files) do
    parts[#parts + 1] = M.read(f)
  end
  return table.concat(parts, '\n')
end

--- Same as all() but with `--` comments stripped (checks code, not prose).
--- Strips both `--[[ ]]` blocks (whose continuation lines lack a `--`
--- prefix) and trailing line comments.
function M.code() return M.all():gsub('%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', '') end

return M
