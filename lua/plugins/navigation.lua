-- lua/plugins/navigation.lua — SECTION 6.11: NAVIGATION
-- Plugins for jumping around your code and files.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- FLASH.NVIM
  -- WHAT: Jump to any visible location using labeled targets (like hop.nvim)
  -- TO CHANGE: Remove if you prefer sneak or easymotion
  -- EFFECT: Press s to see jump labels; press the label letter to jump there
  --         Press S for treesitter-aware jumps (jumps to function/class boundaries)
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash Jump' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
    },
  },
}
