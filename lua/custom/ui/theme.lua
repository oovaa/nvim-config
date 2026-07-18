---@module 'custom.ui.theme'
local M = {}

--- Setup translucent floats (colorizer is owned by the lazy plugin below).
---@return nil
function M.setup()
  -- Translucent floating windows for a "glow" feel without terminal alpha.
  vim.opt.winblend = 10
  vim.opt.pumblend = 10
end

-- ponytail: colorizer is configured by the nvim-colorizer.lua lazy plugin
-- (event BufRead) to avoid double-init and an early require at startup.
return M
