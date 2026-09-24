-- Themes — extra colorschemes (eager rtp only, ~0.2ms each).
-- Picker is <leader>ty via snacks.picker.colorschemes() (LazyVim default,
-- live preview included); persistence is builtin in custom/ui/theme.lua.
-- Adding a plugin here is the only step to offer a new scheme.
---@module 'lazy'
---@type LazySpec
return {
  -- Catppuccin — 4 flavours: catppuccin-latte, frappe, macchiato, mocha (mocha is the dark one)
  { 'catppuccin/nvim', name = 'catppuccin' , lazy = true },

  -- Rosé Pine — main / moon / dawn (dawn is light)
  { 'rose-pine/neovim', name = 'rose-pine' , lazy = true },

  -- Gruvbox — retro, gruvbox
  { 'ellisonleao/gruvbox.nvim' , lazy = true },

  -- Kanagawa — wave / dragon / lotus (lotus is light)
  { 'rebelot/kanagawa.nvim' , lazy = true },

  -- OneDark — darker / dark / cool / deep / warm / warmer + onedark_vivid
  { 'navarasu/onedark.nvim' , lazy = true },

  -- Nightfox — nightfox / dayfox / dawnfox / duskfox / nordfox / terafox / carbonfox
  { 'EdenEast/nightfox.nvim' , lazy = true },

  -- Everforest — everforest (hard/medium/soft bg via setup)
  { 'sainnhe/everforest' , lazy = true },

  -- Dracula — dracula / dracula-soft
  { 'Mofiqul/dracula.nvim' , lazy = true },

  -- Github — github_dark / github_light / github_dark_dimmed etc.
  { 'projekt0n/github-nvim-theme', name = 'github-theme' , lazy = true },

  -- Melange — warm, melange
  { 'savq/melange-nvim' , lazy = true },

  -- Poimandres — deep blue-green
  { 'olivercederborg/poimandres.nvim' , lazy = true },

  -- Cyberdream — modern neon (cyberdream / cyberdream-light)
  { 'scottmckendry/cyberdream.nvim' , lazy = true },

  -- Flexoki — best light theme (flexoki-dark / flexoki-light)
  { 'kepano/flexoki-neovim', name = 'flexoki' , lazy = true },

  -- Trimmed 2026-09: 36 → 13 schemes (faster sync).
  -- Restore any line below to re-add (uncomment + `:Lazy sync`).
  -- -- Vague — minimal neutral (vague)
  -- { 'vague2k/vague.nvim' , lazy = true },
  -- -- Lackluster — monochrome minimal
  -- { 'slugbyte/lackluster.nvim' , lazy = true },
  -- -- Ayu — mirage/dark/light
  -- { 'Shatur/neovim-ayu' , lazy = true },
  -- -- Material — oceanic/palenight/deep-ocean variants
  -- { 'marko-cerovac/material.nvim' , lazy = true },
  -- -- Monokai Pro — pro/classic/machine/ristretto/octagon/spectrum filters
  -- { 'loctvl842/monokai-pro.nvim' , lazy = true },
  -- -- Nordic — nord-based, minimal
  -- { 'AlexvZyl/nordic.nvim' , lazy = true },
  -- -- Solarized Osaka — craftzdog's solarized take
  -- { 'craftzdog/solarized-osaka.nvim' , lazy = true },
  -- -- VSCode — familiar dark/light
  -- { 'Mofiqul/vscode.nvim' , lazy = true },
  -- -- Eldritch — neon purple dark
  -- { 'eldritch-theme/eldritch.nvim' , lazy = true },
  -- -- Sonokai / Edge / Gruvbox Material — sainnhe family
  -- { 'sainnhe/sonokai' , lazy = true },
  -- { 'sainnhe/edge' , lazy = true },
  -- { 'sainnhe/gruvbox-material' , lazy = true },
  -- -- Zenbones — warm low-contrast (lush is a hard dep, keep both)
  -- { 'rktjmp/lush.nvim' , lazy = true },
  -- { 'mcchrish/zenbones.nvim' , lazy = true },
  -- -- Miasma — foggy green dark
  -- { 'xero/miasma.nvim' , lazy = true },
  -- -- Oxocarbon — IBM carbon dark
  -- { 'nyoom-engineering/oxocarbon.nvim' , lazy = true },
  -- -- Modus — accessible operandi (light) / vivendi (dark)
  -- { 'miikanissi/modus-themes.nvim' , lazy = true },
  -- -- Bamboo — warm green dark/light
  -- { 'ribru17/bamboo.nvim' , lazy = true },
  -- -- Night Owl — vscode night-owl port
  -- { 'oxfist/night-owl.nvim' , lazy = true },
  -- -- Horizon — warm sunset (colors file errors upstream, skipped)
  -- { 'akinsho/horizon.nvim' , lazy = true },
  -- -- Jellybeans — classic vivid
  -- { 'wtfox/jellybeans.nvim' , lazy = true },
  -- -- Oldworld — minimal dark/light
  -- { 'dgox16/oldworld.nvim' , lazy = true },
  -- -- Adwaita — GNOME default look
  -- { 'Mofiqul/adwaita.nvim' , lazy = true },
}
