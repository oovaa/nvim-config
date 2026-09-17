-- Themes — extra colorschemes (eager rtp only, ~0.2ms each).
-- Picker is <leader>ty via themery (live preview + persistence); its list is
-- derived from installed schemes, so adding a plugin here is the only step.
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

  -- Vague — minimal neutral (vague)
  { 'vague2k/vague.nvim' , lazy = true },

  -- Flexoki — best light theme (flexoki-dark / flexoki-light)
  { 'kepano/flexoki-neovim', name = 'flexoki' , lazy = true },

  -- Lackluster — monochrome minimal (lackluster / lackluster-hack / lackluster-mint)
  { 'slugbyte/lackluster.nvim' , lazy = true },

  -- Ayu — mirage/dark/light (ayu-mirage is the popular one)
  { 'Shatur/neovim-ayu' , lazy = true },

  -- Material — oceanic/palenight/deep-ocean variants
  { 'marko-cerovac/material.nvim' , lazy = true },

  -- Monokai Pro — pro/classic/machine/ristretto/octagon/spectrum filters
  { 'loctvl842/monokai-pro.nvim' , lazy = true },

  -- Nordic — nord-based, minimal
  { 'AlexvZyl/nordic.nvim' , lazy = true },

  -- Solarized Osaka — craftzdog's solarized take
  { 'craftzdog/solarized-osaka.nvim' , lazy = true },

  -- VSCode — familiar dark/light
  { 'Mofiqul/vscode.nvim' , lazy = true },

  -- Eldritch — neon purple dark
  { 'eldritch-theme/eldritch.nvim' , lazy = true },

  -- Sonokai / Edge / Gruvbox Material — sainnhe family
  { 'sainnhe/sonokai' , lazy = true },
  { 'sainnhe/edge' , lazy = true },
  { 'sainnhe/gruvbox-material' , lazy = true },

  -- Zenbones — warm low-contrast (+ rosebones/forestbones/neobones)
  -- ponytail: lush is a hard dep — without it every *bones scheme errors.
  { 'rktjmp/lush.nvim' , lazy = true },
  { 'mcchrish/zenbones.nvim' , lazy = true },

  -- Miasma — foggy green dark
  { 'xero/miasma.nvim' , lazy = true },

  -- Oxocarbon — IBM carbon dark
  { 'nyoom-engineering/oxocarbon.nvim' , lazy = true },

  -- Modus — accessible operandi (light) / vivendi (dark)
  { 'miikanissi/modus-themes.nvim' , lazy = true },

  -- Bamboo — warm green dark/light
  { 'ribru17/bamboo.nvim' , lazy = true },

  -- Night Owl — vscode night-owl port
  { 'oxfist/night-owl.nvim' , lazy = true },

  -- Horizon — warm sunset
  { 'akinsho/horizon.nvim' , lazy = true },

  -- Jellybeans — classic vivid
  { 'wtfox/jellybeans.nvim' , lazy = true },

  -- Oldworld — minimal dark/light
  { 'dgox16/oldworld.nvim' , lazy = true },

  -- Adwaita — GNOME default look
  { 'Mofiqul/adwaita.nvim' , lazy = true },

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
      for f, ft in vim.fs.dir(vim.env.VIMRUNTIME .. '/colors') do
        if ft == 'file' then
          local n = f:match('^(.+)%.vim$')
          if n then builtin[n] = true end
        end
      end
      local seen, themes = {}, {}
      local function add(name)
        if not builtin[name] and not non_schemes[name] and not seen[name] then
          seen[name] = true
          themes[#themes + 1] = name
        end
      end
      local lazy_dir = vim.fn.stdpath 'data' .. '/lazy'
      for entry in vim.fs.dir(lazy_dir) do
        local cd = lazy_dir .. '/' .. entry .. '/colors'
        if vim.uv.fs_stat(cd) then
          for f, ft in vim.fs.dir(cd) do
            if ft == 'file' then
              local n = f:match('^(.+)%.vim$') or f:match('^(.+)%.lua$')
              if n then add(n) end
            end
          end
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
