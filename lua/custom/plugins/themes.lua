-- Themes — extra colorschemes (eager rtp only, ~0.2ms each; lazy=true hides
-- flavors from getcompletion so <leader>ty can't preview them — see
-- docs/superpowers/plans/2026-09-05-nvim-perf.md).
-- Telescope picker is <leader>ty (live preview, persists via custom/ui/theme.lua).
---@module 'lazy'
---@type LazySpec
return {
  -- Catppuccin — 4 flavours: catppuccin-latte, frappe, macchiato, mocha (mocha is the dark one)
  { 'catppuccin/nvim', name = 'catppuccin' },

  -- Rosé Pine — main / moon / dawn (dawn is light)
  { 'rose-pine/neovim', name = 'rose-pine' },

  -- Gruvbox — retro, gruvbox
  { 'ellisonleao/gruvbox.nvim' },

  -- Kanagawa — wave / dragon / lotus (lotus is light)
  { 'rebelot/kanagawa.nvim' },

  -- OneDark — darker / dark / cool / deep / warm / warmer + onedark_vivid
  { 'navarasu/onedark.nvim' },

  -- Nightfox — nightfox / dayfox / dawnfox / duskfox / nordfox / terafox / carbonfox
  { 'EdenEast/nightfox.nvim' },

  -- Everforest — everforest (hard/medium/soft bg via setup)
  { 'sainnhe/everforest' },

  -- Dracula — dracula / dracula-soft
  { 'Mofiqul/dracula.nvim' },

  -- Github — github_dark / github_light / github_dark_dimmed etc.
  { 'projekt0n/github-nvim-theme', name = 'github-theme' },

  -- Melange — warm, melange
  { 'savq/melange-nvim' },

  -- Poimandres — deep blue-green
  { 'olivercederborg/poimandres.nvim' },

  -- Cyberdream — modern neon (cyberdream / cyberdream-light)
  { 'scottmckendry/cyberdream.nvim' },

  -- Vague — minimal neutral (vague)
  { 'vague2k/vague.nvim' },

  -- Flexoki — best light theme (flexoki-dark / flexoki-light)
  { 'kepano/flexoki-neovim', name = 'flexoki' },

  -- Lackluster — monochrome minimal (lackluster / lackluster-hack / lackluster-mint)
  { 'slugbyte/lackluster.nvim' },
}