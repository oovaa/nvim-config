---@module 'custom.ui'
local M = {}

local theme = require 'custom.ui.theme'
local spec = require 'custom.ui.spec'

--- Smooth-cursor highlight: brighten CursorLine briefly on movement.
local function setup_smooth_cursor()
  local grp = vim.api.nvim_create_augroup('neon-smooth-cursor', { clear = true })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = grp,
    callback = function()
      vim.cmd 'hi! CursorLine gui=bold'
      vim.defer_fn(function() vim.cmd 'hi! CursorLine gui=NONE' end, 120)
    end,
  })
end

--- Smooth-cursor highlight: brighten CursorLine briefly on movement.
function M.setup_smooth_cursor()
  setup_smooth_cursor()
end

return M
