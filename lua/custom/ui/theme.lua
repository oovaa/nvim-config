---@module 'custom.ui.theme'
-- Theme persistence is builtin (one file under stdpath('data')); the picker
-- is snacks.picker.colorschemes() on <leader>ty (see lua/config/keymaps.lua).
-- This module restores the saved scheme, saves on switch, and handles
-- translucent floats + mode-colored line numbers.
local M = {}

--- Path of the one-line file holding the saved colorscheme name.
---@return string
function M.theme_file() return vim.fn.stdpath 'data' .. '/theme.txt' end

--- Read the saved scheme, migrating themery's state.json once if present.
---@return string|nil
function M.get_saved()
  local f = io.open(M.theme_file(), 'r')
  if f then
    local name = f:read '*l'
    f:close()
    if type(name) == 'string' then name = name:match '^%s*(.-)%s*$' end
    if name and name ~= '' then return name end
  end
  -- ponytail: one-time migration from themery (removed); state.json holds
  -- { colorscheme = '...' }. Adopt it so existing users keep their theme.
  local legacy = vim.fn.stdpath 'data' .. '/themery/state.json'
  local lf = io.open(legacy, 'r')
  if lf then
    local raw = lf:read '*a'
    lf:close()
    local ok, data = pcall(vim.json.decode, raw)
    if ok and type(data) == 'table' and data.colorscheme and data.colorscheme ~= '' then
      pcall(M.save, data.colorscheme)
      return data.colorscheme
    end
  end
  return nil
end

--- Persist the scheme name (best-effort, never errors).
---@param name string
---@return nil
function M.save(name)
  local f = io.open(M.theme_file(), 'w')
  if f then
    f:write(name)
    f:close()
  end
end

--- Restore the saved scheme if it differs from the current one.
---@return nil
function M.restore()
  local saved = M.get_saved()
  if saved and saved ~= vim.g.colors_name then pcall(vim.cmd.colorscheme, saved) end
end

--- Setup translucent floats and inline color previews.
---@return nil
function M.setup()
  -- Translucent floating windows for a "glow" feel without terminal alpha.
  vim.opt.winblend = 10
  vim.opt.pumblend = 10

  M.restore()
  -- ponytail: save on every switch (one tiny write); restore above reads it.
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('ThemePersistence', { clear = true }),
    callback = function(ev)
      if ev.match then M.save(ev.match) end
    end,
  })

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
