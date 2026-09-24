---@module 'custom.ui.theme'
-- Theme choice: snacks colorschemes picker (<leader>ty); boot default stays
-- tokyonight-night (see init.lua). This module: translucent floats + mode line numbers.
local M = {}

--- Setup translucent floats and inline color previews.
---@return nil
function M.setup()
  -- Translucent floating windows for a "glow" feel without terminal alpha.
  vim.opt.winblend = 10
  vim.opt.pumblend = 10

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

  local mode_colors = {
    i = 'green', -- insert
    v = 'yellow', -- visual
    V = 'yellow', -- visual line
    ['\22'] = 'yellow', -- visual block (CTRL-V)
  }

  local function swap(mode)
    local color_name = mode_colors[mode]
    if color_name then
      -- ponytail: guard tokyonight palette lookup — non-tokyonight themes
      -- like catppuccin-mocha have suffix 'mocha' which is not a valid
      -- tokyonight style (storm/night/moon/day) and crashes util.lua:22.
      -- Only query tokyonight when active scheme is tokyonight; else use
      -- hardcoded fallback so <leader>ty preview + mode switches never error.
      local fg
      if vim.g.colors_name and vim.g.colors_name:match '^tokyonight' then
        local style = vim.g.colors_name:match '%-(.+)$' or 'night'
        if style ~= 'night' and style ~= 'moon' and style ~= 'storm' and style ~= 'day' then style = 'night' end
        local ok, pal = pcall(require('tokyonight.colors').setup, { style = style })
        if ok and pal then fg = pal[color_name] end
      end
      fg = fg or (color_name == 'green' and '#9ece6a' or '#e0af68')
      vim.api.nvim_set_hl(0, 'LineNr', { fg = fg })
      vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = fg, bold = true })
    else
      vim.api.nvim_set_hl(0, 'LineNr', defaults.LineNr)
      vim.api.nvim_set_hl(0, 'CursorLineNr', defaults.CursorLineNr)
    end
  end

  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = snapshot })
  vim.api.nvim_create_autocmd('ModeChanged', { group = group, callback = function() swap(vim.fn.mode()) end })
  -- Snapshot immediately: ModeChanged can fire before the first ColorScheme
  -- (setup runs before lazy loads tokyonight); empty defaults made swap()
  -- call nvim_set_hl with nil and error at theme.lua restore path.
  snapshot()
end

return M
