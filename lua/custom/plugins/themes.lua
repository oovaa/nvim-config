-- Themes — extra colorschemes (eager rtp only, ~0.2ms each).
-- Picker is <leader>ty via themery (live preview + persistence); its list is
-- derived from installed schemes, so adding a plugin here is the only step.
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

  -- Ayu — mirage/dark/light (ayu-mirage is the popular one)
  { 'Shatur/neovim-ayu' },

  -- Material — oceanic/palenight/deep-ocean variants
  { 'marko-cerovac/material.nvim' },

  -- Monokai Pro — pro/classic/machine/ristretto/octagon/spectrum filters
  { 'loctvl842/monokai-pro.nvim' },

  -- Nordic — nord-based, minimal
  { 'AlexvZyl/nordic.nvim' },

  -- Solarized Osaka — craftzdog's solarized take
  { 'craftzdog/solarized-osaka.nvim' },

  -- VSCode — familiar dark/light
  { 'Mofiqul/vscode.nvim' },

  -- Eldritch — neon purple dark
  { 'eldritch-theme/eldritch.nvim' },

  -- Sonokai / Edge / Gruvbox Material — sainnhe family
  { 'sainnhe/sonokai' },
  { 'sainnhe/edge' },
  { 'sainnhe/gruvbox-material' },

  -- Zenbones — warm low-contrast (+ rosebones/forestbones/neobones)
  -- ponytail: lush is a hard dep — without it every *bones scheme errors.
  { 'rktjmp/lush.nvim' },
  { 'mcchrish/zenbones.nvim' },

  -- Miasma — foggy green dark
  { 'xero/miasma.nvim' },

  -- Oxocarbon — IBM carbon dark
  { 'nyoom-engineering/oxocarbon.nvim' },

  -- Modus — accessible operandi (light) / vivendi (dark)
  { 'miikanissi/modus-themes.nvim' },

  -- Bamboo — warm green dark/light
  { 'ribru17/bamboo.nvim' },

  -- Night Owl — vscode night-owl port
  { 'oxfist/night-owl.nvim' },

  -- Horizon — warm sunset
  { 'akinsho/horizon.nvim' },

  -- Jellybeans — classic vivid
  { 'wtfox/jellybeans.nvim' },

  -- Oldworld — minimal dark/light
  { 'dgox16/oldworld.nvim' },

  -- Adwaita — GNOME default look
  { 'Mofiqul/adwaita.nvim' },

  -- Themery — picker + persistence for <leader>ty. Theme list is derived
  -- from installed schemes at startup, so adding a plugin above is enough.
  {
    'zaldih/themery.nvim',
    lazy = false,
    config = function()
      -- ponytail: scan plugin dirs on disk — most theme plugins aren't on
      -- rtp yet when this config runs (149 schemes after boot vs 14 via
      -- getcompletion here). Builtins (from $VIMRUNTIME) are excluded.
      -- non_schemes are helper files under colors/ that fail :colorscheme
      -- (mini.hues variants, zenbones randomhue) and crash Themery's preview.
      local builtin = { ['catppuccin-nvim'] = true } -- helper file, not a pick
      local non_schemes = {
        minischeme = true,
        miniautumn = true,
        minispring = true,
        minisummer = true,
        miniwinter = true,
        minicyan = true,
        randomhue = true,
      }
      for _, f in ipairs(vim.fn.globpath(vim.env.VIMRUNTIME .. '/colors', '*.vim', false, true)) do
        builtin[vim.fn.fnamemodify(f, ':t:r')] = true
      end
      local seen, themes = {}, {}
      local function add(name)
        if not builtin[name] and not non_schemes[name] and not seen[name] then
          seen[name] = true
          themes[#themes + 1] = name
        end
      end
      for _, d in ipairs(vim.fn.globpath(vim.fn.stdpath 'data' .. '/lazy', '*/colors', false, true)) do
        for _, f in ipairs(vim.fn.globpath(d, '*.vim', false, true)) do
          add(vim.fn.fnamemodify(f, ':t:r'))
        end
        for _, f in ipairs(vim.fn.globpath(d, '*.lua', false, true)) do
          add(vim.fn.fnamemodify(f, ':t:r'))
        end
      end
      for _, name in ipairs(vim.fn.getcompletion('', 'color')) do
        add(name)
      end
      table.sort(themes)
      -- ponytail: horizon's light palette is missing syntax colors upstream
      -- (tint(nil) assert) while light themes leave background=light behind,
      -- so pin dark before applying instead of dropping the theme.
      for i, name in ipairs(themes) do
        if name == 'horizon' then themes[i] = { name = 'horizon', colorscheme = 'horizon', before = [[vim.opt.background = 'dark']] } end
      end
      require('themery').setup { themes = themes, livePreview = true }
    end,
  },
}
