--[[
 ================================================================================
 NEOVIM CONFIGURATION GUIDE
 ================================================================================

 This is your Neovim configuration. Every setting is explained so you can
 understand what it does, change it safely, and know the effect of your changes.

 7. vim.loader bytecode cache enabled (re-parse avoidance)
 8. lazy.nvim module cache enabled (enabled = true)
 9. Node provider disabled (joins perl/ruby)


 MEASURED STARTUP TIME: ~185ms (clean headless --startuptime; was ~250ms)

 EXTERNAL BINARIES (outside mason — reinstall manually on a new machine):
   brew: ueberzugpp (image.nvim backend), jupyter + jupytext (molten notebooks)
   ~/.local/bin: nvim (bob), yazi, tokei, bottom, hyperfine
   npm -g: none (all JS tooling via mason)

 GETTING STARTED:
   1. Read through this file top to bottom
   2. Try changing a setting and see what happens
   3. Use `:help <option>` to learn more about any option
   4. Use `:Telescope keymaps` to see all available keybindings

 LEADER KEY: <Space>

 LAYOUT (modular — plugin specs live in lua/plugins/, one file per section):
   init.lua                  this bootstrap (loader, lazy setup, builtin wiring)
   lua/config/options.lua    leader key, editor options, diagnostics
   lua/config/keymaps.lua    global keymaps (buffer nav S-h/S-l/<leader>bd here)
   lua/config/autocmds.lua   global autocommands + docker-compose filetype
   lua/config/sessions.lua   builtin sessions (replaces auto-session)
   lua/config/terminal.lua   builtin terminal + lazygit float
   lua/config/runner.lua     builtin code runner via :terminal
   lua/custom/ui/theme.lua   theme persistence + mode-colored line numbers
   lua/custom/ui/init.lua    builtin statusline/tabline/dashboard wiring
   lua/custom/plugins/       personal plugins (molten, image, qol, themes)
   lua/plugins/visual.lua       guess-indent, gitsigns, which-key, telescope
   lua/plugins/lsp.lua          mason + native vim.lsp servers
   lua/plugins/formatting.lua   actions-preview, conform
   lua/plugins/completion.lua   blink.cmp
   lua/plugins/colorscheme.lua  tokyonight (+ saved-theme restore)
   lua/plugins/editing.lua      todo, mini, ts-comments, auto-save, vtsls
   lua/plugins/treesitter.lua   treesitter, autotag
   lua/plugins/ui.lua           neo-tree, snacks, nvim-lint
   lua/plugins/navigation.lua   flash
   lua/plugins/debugging.lua    nvim-dap (python)
   lua/plugins/bookmarks.lua    telescope-vim-bookmarks
   lua/plugins/appearance.lua   render-markdown, colorizer

 Key Mappings Reference:
 ----------------------
   Leader key: <Space>

   Search:      <leader>s{f,g,p,w,/,n,r,.,c,d,k}  (<leader><leader> = find files)
   Terminal:    <leader>t{t,f,m,1,2,3,n}
   Git:         <leader>fg (LazyGit)
   Debug:       <leader>d{b,c,i,o,O,r,l,t,n,f,s}
   LSP:         K(grn,a,D), grr, gri, grd, grt, gO, gW
   Symbols:     <leader>ls, <leader>lS
   Bookmarks:   <leader>mt/mc/mj/mk/mb
   Molten:      <leader>m{i,l,v,r,h,d,n,p,o}
   Theme:       <leader>ty
   Profiling:   :StartupTime

 --]]

-- ============================================================================
-- BYTECODE CACHE (fastest, safest startup win)
-- Caches compiled Lua modules so Neovim doesn't re-parse every file on boot.
-- Requires Neovim >= 0.9. Pairs well with lazy.nvim's own module cache below.
-- NOTE: floor is effectively 0.11 — `smoothscroll` (0.10+) and `winborder`
-- (0.11+) in lua/config/options.lua are set unguarded.
-- ============================================================================
vim.loader.enable()

-- ponytail: node shim removed; tsserver_path is set explicitly in
-- typescript-tools config, and the old node->bun shim broke node formatters
-- (prettierd/prettier run via real linuxbrew node now).

-- ============================================================================
-- SECTION 1: PROVIDER DISABLES
-- ============================================================================
-- WHAT: Neovim can connect to external language tools (Python, Ruby, Perl,
--        Node.js) called "providers". Each adds startup time even if unused.
--        Disabling them speeds up startup by ~5-10ms each.
--
-- TO CHANGE:
--   - If you use Python plugins (like molten-nvim), keep python3 enabled
--   - If you use Ruby plugins, remove the ruby line
--   - If you use Perl plugins, remove the perl line
--   - Check active providers: `:checkhealth provider`
--
-- EFFECT:
--   Setting a provider to 0 = disabled (faster startup, but plugins needing it break)
--   Removing the line = provider enabled (slower startup, but plugins can use it)
-- ============================================================================
-- Core config lives in lua/config/:
--   config/options.lua  — provider disables, leader key, editor options, diagnostics
--   config/keymaps.lua  — global keymaps (plugin keymaps stay with their specs)
--   config/autocmds.lua — global autocommands
require 'config.options'
require 'config.keymaps'
require 'config.autocmds'

-- :StartupTime — profile boot time and show the 15 slowest sources,
-- then print lazy.nvim's own profile (loaded count + total ms).
-- Writes a --startuptime log and prints the tail so you can spot regressions.
vim.api.nvim_create_user_command('StartupTime', function()
  local log = vim.fn.stdpath 'cache' .. '/startup.log'
  vim.cmd('!nvim --startuptime ' .. log .. ' +q && sort -k2 ' .. log .. ' | tail -n 15')
  local ok, lazy = pcall(require, 'lazy')
  if ok then
    local s = lazy.stats()
    print(string.format('lazy.nvim: %d/%d plugins in %.1fms', s.loaded, s.count, s.startuptime))
  end
end, { desc = 'Profile Neovim startup time' })

-- THEME: persistence + mode-colored line numbers live in custom/ui/theme.lua.
-- Must run BEFORE lazy setup: restores builtin schemes early; the tokyonight
-- spec (lua/plugins/colorscheme.lua) re-restores after theme plugins are on rtp.
pcall(function() require('custom.ui.theme').setup() end)

-- NOTIFY THROTTLE (spam guard for auto-save + conform)
-- A file the formatter can't handle (e.g. badly broken json) fails on
-- EVERY auto-save, and notify_on_error would re-notify every few
-- keystrokes. First notice shows; identical repeats within 15s are
-- dropped. Manual <leader>ff still notifies when you ask for it.
-- ponytail: narrow match (only conform's failure string), global helpers
-- like this stay in init.lua so the behavior is visible in one place.
do
  local orig_notify = vim.notify
  local last_msg, last_time = nil, 0
  ---@diagnostic disable-next-line: duplicate-set-field
  function vim.notify(msg, level, opts)
    if type(msg) == 'string' and msg:match '^Formatter failed' then
      local now = vim.uv.now()
      if msg == last_msg and now - last_time < 15000 then return end
      last_msg, last_time = msg, now
    end
    return orig_notify(msg, level, opts)
  end
end

-- ============================================================================
-- SECTION 6: LAZY.NVIM PLUGIN MANAGER
-- ============================================================================
-- WHAT: Lazy.nvim manages all your plugins. It handles downloading, updating,
--        loading, and configuring them automatically.
--
-- HOW PLUGINS ARE LOADED:
--   Plugins can be loaded in different ways for performance:
--
--   event = 'VeryLazy'          Load after UI is ready (non-critical plugins)
--   event = 'InsertEnter'       Load only when entering insert mode
--   event = 'BufReadPost'       Load only when opening a file
--   ft = { 'python', 'lua' }    Load only for specific filetypes
--   cmd = { 'Telescope' }       Load only when running specific commands
--   keys = { '<leader>f' }      Load only when specific keymaps are pressed
--   lazy = false                Load immediately at startup (use sparingly!)
--
-- HOW TO ADD A NEW PLUGIN:
--   1. Find the plugin on GitHub (e.g., 'user/plugin-name')
--   2. Add it to the matching file in lua/plugins/ with the right strategy
--      (or lua/custom/plugins/ for personal one-offs)
--   3. Run `:Lazy sync` to install it
--
-- USEFUL COMMANDS:
--   :Lazy          Open the Lazy.nvim UI (see all plugins, update, clean)
--   :Lazy sync     Update all plugins
--   :Lazy clean    Remove unused plugins
--   :Lazy profile  See plugin load times
--
-- SEE: `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim
-- ============================================================================

-- Bootstrap lazy.nvim (auto-install if not present)
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- ============================================================================
-- PLUGIN LIST
-- ============================================================================
-- Specs live in lua/plugins/*.lua (one file per section) plus
-- lua/custom/plugins/*.lua (personal plugins). Each spec documents:
--   - Loading strategy (event, cmd, keys, ft, or lazy=false)
--   - Configuration (opts, config, or setup)
--   - Dependencies (other plugins needed)
--
-- TO DISABLE A PLUGIN: Set enabled = false
-- TO CHANGE LOADING: Modify the event/cmd/keys/ft
-- TO ADD CONFIGURATION: Add opts = {} or config = function() ... end
-- ============================================================================
require('lazy').setup({
  -- SECTION 6.12: CUSTOM PLUGINS + modular section specs.
  -- `{ import = 'plugins' }` auto-imports every file in lua/plugins/.
  { import = 'plugins' },
  { import = 'custom.plugins' },
}, { ---@diagnostic disable-line: missing-fields
  rocks = { enabled = false },
  -- Theme pack has no triggers so it lazy-loads on :colorscheme preview;
  -- plugins with events/keys/commands are unaffected by this default.
  defaults = { lazy = true },
  performance = {
    -- Cache compiled plugin modules so lazy.nvim doesn't re-require them on
    -- every startup. Works alongside vim.loader.enable() above.
    cache = {
      enabled = true,
    },
    rtp = {
      -- Disable unused built-in Neovim plugins for faster startup (saves 10-20ms)
      -- Names must match $VIMRUNTIME/plugin/<name>.vim (lazy skips those
      -- files); mirrors the loaded_* disables in lua/config/options.lua,
      -- which is the source of truth. tohtml is an opt package now, so it
      -- is covered by loaded_2html_plugin there, not here.
      disabled_plugins = {
        'gzip', -- Gzip file reading/writing (not needed)
        'tarPlugin', -- Tar file reading/writing (not needed)
        'tutor', -- Vim tutorial (not needed)
        'netrwPlugin', -- Netrw file browser (replaced by neo-tree)
        'matchit', -- Extended % matching (replaced by mini.ai)
        -- matchparen is kept: mini.ai/mini.surround don't replicate its
        -- matching-paren highlight under the cursor.
        'zipPlugin', -- Zip archive reading/writing (not needed)
      },
    },
  },
  -- Lazy.nvim UI configuration
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- BUILTIN UI: statusline/tabline/dashboard (replaces lualine/bufferline/alpha)
require('custom.ui.init').setup()

-- BUILTIN SESSIONS (replaces rmagatti/auto-session, zero loss via :mksession)
require 'config.sessions'

-- BUILTIN TERMINAL (replaces toggleterm.nvim + lazygit.nvim, zero loss via :terminal)
require 'config.terminal'

-- BUILTIN CODE RUNNER (replaces CRAG666/code_runner.nvim, zero loss via :terminal)
require 'config.runner'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
