---@module 'custom.ui.init'
-- BUILTIN UI wiring (replaces bufferline/lualine/alpha — no plugin, zero loss).
-- statusline/tabline/dashboard via lua/custom/ui/spec.lua (pure nvim 0.12).
-- Split from init.lua. Required after lazy.nvim setup (see init.lua).

local M = {}

function M.setup()
  pcall(function() require('custom.ui.spec').setup_lualine() end)
  pcall(function() require('custom.ui.spec').setup_bufferline() end)
  pcall(function() require('custom.ui.spec').setup_starter() end)
end

return M
