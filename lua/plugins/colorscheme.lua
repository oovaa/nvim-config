-- lua/plugins/colorscheme.lua — SECTION 6.6: COLORSCHEME
-- Controls the colors and visual appearance of Neovim.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- TOKYONIGHT
  -- WHAT: A clean, dark color scheme for Neovim
  -- TO CHANGE: Change 'tokyonight-night' to 'tokyonight-storm', 'tokyonight-moon',
  --            or 'tokyonight-day' for different styles
  -- EFFECT: Changes all colors in the editor (syntax highlighting, UI, etc.)
  -- LOADING: priority=1000 ensures it loads before all other plugins
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    lazy = false, -- startup colorscheme; the theme pack lazy-loads on preview
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
        on_colors = function(colors)
          colors.border = colors.blue -- brighter UI borders
        end,
        on_highlights = function(hl, c)
          hl.WinSeparator = { fg = c.blue, bg = 'NONE' }
          hl.CursorLineNr = { fg = c.orange, bold = true }
          hl.CursorLine = { bg = '#1a1b2a' } -- subtle pop on the cursor line
          hl.FloatBorder = { fg = c.blue, bg = 'NONE' }
          hl.NormalFloat = { bg = '#16161e' } -- slightly lifted panel
        end,
      }
      -- ponytail: restore saved scheme (theme.txt) instead of forcing
      -- tokyonight-night — the early restore in custom/ui/theme.lua runs
      -- before lazy puts theme plugins on rtp, so it always fails for
      -- third-party themes; this runs after, when :colorscheme can
      -- lazy-load the saved theme's plugin. Falls back on bad names.
      local saved = nil
      pcall(function() saved = require('custom.ui.theme').get_saved() end)
      if type(saved) == 'string' then saved = saved:match '^%s*(.-)%s*$' end
      if not saved or saved == '' or not pcall(vim.cmd.colorscheme, saved) then
        vim.cmd.colorscheme 'tokyonight-night'
      end
    end,
  },
}
