---@module 'custom.ui.spec'
-- Thin facade kept for backwards compatibility with callers/tests that still
-- require('custom.ui.spec'). It delegates to the split modules created for T3.
local statusline = require('custom.ui.statusline')
local tabline = require('custom.ui.tabline')
local dashboard = require('custom.ui.dashboard')

local M = statusline
M.setup_lualine = statusline.setup_lualine
M.setup_bufferline = tabline.setup_bufferline
M.setup_starter = dashboard.setup_starter

return M