-- Themes — extra colorschemes (all lazy=false so they appear in :colorscheme / <leader>ty picker immediately).
-- ponytail: each is just a colors/*.vim + lua/ dir; load cost is ~0.5ms (rtp prepend only) — no startup modules run until you :colorscheme it.
-- Telescope picker is <leader>ty (live preview, persists via custom/ui/theme.lua). Try :colorscheme catppuccin-mocha etc.
---@module 'lazy'
---@type LazySpec
return {
  -- Catppuccin — 4 flavours: catppuccin-latte, frappe, macchiato, mocha (mocha is the dark one)
  { 'catppuccin/nvim', name = 'catppuccin', lazy = false, priority = 1000 },

  -- Rosé Pine — main / moon / dawn (dawn is light)
  { 'rose-pine/neovim', name = 'rose-pine', lazy = false, priority = 1000 },

  -- Gruvbox — retro, gruvbox / gruvbox-contrast
  { 'ellisonleao/gruvbox.nvim', lazy = false, priority = 1000 },

  -- Kanagawa — wave / dragon / lotus (lotus is light)
  { 'rebelot/kanagawa.nvim', lazy = false, priority = 1000 },

  -- OneDark — darker / dark / cool / deep / warm / warmer + onedark_vivid
  { 'navarasu/onedark.nvim', lazy = false, priority = 1000 },

  -- Nightfox — nightfox / dayfox / dawnfox / duskfox / nordfox / terafox / carbonfox
  { 'EdenEast/nightfox.nvim', lazy = false, priority = 1000 },

  -- Everforest — everforest (hard/medium/soft bg via setup)
  { 'sainnhe/everforest', lazy = false, priority = 1000 },

  -- Dracula — dracula / dracula-soft
  { 'Mofiqul/dracula.nvim', lazy = false, priority = 1000 },

  -- Github — github_dark / github_light / github_dark_dimmed etc.
  { 'projekt0n/github-nvim-theme', name = 'github-theme', lazy = false, priority = 1000 },

  -- Melange — warm, melange / melange_dark
  { 'savq/melange-nvim', lazy = false, priority = 1000 },

  -- Poimandres — deep blue-green
  { 'olivercederborg/poimandres.nvim', lazy = false, priority = 1000 },
}
