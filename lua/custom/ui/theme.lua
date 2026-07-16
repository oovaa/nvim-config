---@module 'custom.ui.theme'
local M = {}

--- Setup translucent floats and inline color previews.
---@return nil
function M.setup()
  -- Translucent floating windows for a "glow" feel without terminal alpha.
  vim.opt.winblend = 10
  vim.opt.pumblend = 10

  -- Inline hex/named color previews (toggled with <leader>uc).
  local ok, colorizer = pcall(require, 'colorizer')
  if ok then
    colorizer.setup({ '*' }, {
      RGB = true,
      RRGGBB = true,
      names = true,
      css = true,
    })
  end
end

return M
