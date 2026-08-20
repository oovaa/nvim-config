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

  M.setup_mode_line_colors()
end

--- Color-code line numbers by mode: green in insert, yellow in visual,
--- theme defaults otherwise. Snapshot defaults on ColorScheme so normal mode
--- always matches the active theme (including the custom orange CursorLineNr).
---@return nil
function M.setup_mode_line_colors()
  local group = vim.api.nvim_create_augroup('ModeLineNumbers', { clear = true })

  local defaults = {}
  local function snapshot()
    defaults.LineNr = vim.api.nvim_get_hl(0, { name = 'LineNr' })
    defaults.CursorLineNr = vim.api.nvim_get_hl(0, { name = 'CursorLineNr' })
  end

  local colors
  local mode_colors = {
    i = 'green',           -- insert
    v = 'yellow',          -- visual
    V = 'yellow',          -- visual line
    ['\22'] = 'yellow',    -- visual block (CTRL-V)
  }

  local function swap(mode)
    local color_name = mode_colors[mode]
    if color_name then
      -- tokyonight loads eagerly (priority=1000); palette is only needed
      -- once the first mode change happens. Match the ACTIVE style
      -- (night/moon/storm/day) — colors.setup() defaults to moon otherwise.
      colors = colors or require('tokyonight.colors').setup {
        style = vim.g.colors_name and vim.g.colors_name:match('%-(.+)$') or 'night',
      }
      local fg = colors[color_name]
      vim.api.nvim_set_hl(0, 'LineNr', { fg = fg })
      vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = fg, bold = true })
    else
      vim.api.nvim_set_hl(0, 'LineNr', defaults.LineNr)
      vim.api.nvim_set_hl(0, 'CursorLineNr', defaults.CursorLineNr)
    end
  end

  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = snapshot })
  vim.api.nvim_create_autocmd('ModeChanged', { group = group, callback = function()
    swap(vim.fn.mode())
  end })
end

return M
