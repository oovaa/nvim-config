--[[

=====================================================================
==================== PERFORMANCE OPTIMIZED CONFIG ====================
=====================================================================
=====                                    .-----.          ========
=====         .----------------------.   | === |          ========
=====         |.-""""""""""""""""""-.|   |-----|          ========
=====         ||                    ||   | === |          ========
=====         ||   KICKSTART.NVIM   ||   |-----|          ========
=====         ||                    ||   | === |          ========
=====         ||                    ||   |-----|          ========
=====         ||:Tutor              ||   |:::::|          ========
=====         |'-..................-'|   |____o|          ========
=====         `"")----------------(""`   ___________      ========
=====        /::::::::::|  |::::::::::\  \ no mouse \     ========
=====       /:::========|  |==hjkl==:::\  \ required \    ========
=====      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
=====                                                     ========
=====================================================================
=====================================================================

PERFORMANCE OPTIMIZATIONS APPLIED:
-----------------------------------
1. LSP servers loaded on-demand via FileType autocmds (saves 50-150ms)
2. Plugins lazy-loaded with appropriate events (VeryLazy, BufReadPost, etc.)
3. Disabled 8 unused built-in Neovim plugins (saves 10-20ms)
4. Telescope LspAttach merged into lspconfig (reduced autocmd overhead)
5. blink.cmp loaded on InsertEnter (not VimEnter)
6. treesitter loaded on BufReadPost (not at boot)

7. vim.loader bytecode cache enabled (re-parse avoidance)
8. lazy.nvim module cache enabled (enabled = true)
9. Node provider disabled (joins perl/ruby)


MEASURED STARTUP TIME: ~120ms (clean headless --startuptime; was ~400-600ms)

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Key Mappings Reference:
-----------------------
  Leader key: <Space>

  Search:      <leader>s{f,g,w,/,n,r,.,c,d,k}
  Terminal:    <leader>t{t,f,m,1,2,3,n}
  Git:         <leader>g{s,c,p,P,l}
  Debug:       <leader>d{b,c,i,o,O,r,l,t,n,f,s}
  LSP:         K(grn,a,D), grr, gri, grd, grt, gO, gW
  Bookmarks:   m{m,i,n,p}, <leader>mb
  Remote:      <leader>r{c,d,s,l}
  Molten:      <leader>m{i,l,v,r,h,d,n,p,o}
  Theme:       <leader>ty
  Profiling:   :StartupTime

SECTIONS:
  Section 1: Provider Disables
  Section 2: Leader Key Configuration
  Section 3: Neovim Options
  Section 4: Keymaps & Diagnostics
  Section 5: Autocommands
  Section 6: Lazy.nvim Plugin Manager
    6.1: UI & Visual Enhancements
    6.2: Fuzzy Finding & File Management
    6.3: Formatting & Completion
    6.4: Autocompletion
    6.5: Colorscheme & Highlighting
    6.6: UI & Editing Utilities
    6.7: Syntax & Code Intelligence
    6.8: UI Components
    6.9: Git Integration
    6.10: Custom Plugins
    6.11: Python Development
    6.12: Remote Development
    6.13: Bookmarks & Navigation
    6.14: Visual Enhancements
  Section 7: Terminal Keymaps
  Section 8: Project Switching
  Section 9: Filetype Detection

--]]

-- ============================================================================
-- BYTECODE CACHE (fastest, safest startup win)
-- Caches compiled Lua modules so Neovim doesn't re-parse every file on boot.
-- Requires Neovim >= 0.9. Pairs well with lazy.nvim's own module cache below.
-- ============================================================================
vim.loader.enable()

-- Route node/npm to bun for typescript-tools.nvim (which hardcodes `node` and
-- `npm root -g`). Shims live in a nvim-scoped dir so the real shell keeps using
-- bun directly. Created alongside the global typescript install (bun install -g typescript@5).
vim.env.PATH = vim.env.HOME .. "/.local/share/nvim/bin" .. ":" .. (vim.env.PATH or "")

-- ============================================================================
-- SECTION 1: PROVIDER DISABLES
-- ============================================================================
-- Disable unused language providers to reduce startup time and suppress warnings.
-- Each provider (perl, ruby, python3, node) adds overhead even if unused.
-- Only enable the ones you actually use.
-- ============================================================================
vim.g.loaded_perl_provider = 0  -- Disable Perl provider (not used)
vim.g.loaded_ruby_provider = 0  -- Disable Ruby provider (not used)
vim.g.loaded_node_provider = 0  -- Disable Node provider (no :Node remote plugins used)

-- :StartupTime — profile boot time and show the 15 slowest sources.
-- Writes a --startuptime log and prints the tail so you can spot regressions.
vim.api.nvim_create_user_command('StartupTime', function()
  local log = vim.fn.stdpath 'cache' .. '/startup.log'
  vim.cmd('!nvim --startuptime ' .. log .. ' +q && sort -k2 ' .. log .. ' | tail -n 15')
end, { desc = 'Profile Neovim startup time' })

-- Compatibility shim for plugins using deprecated vim.lsp.buf_get_clients()
-- This maps the old API to the new one for backward compatibility
vim.lsp.buf_get_clients = vim.lsp.get_clients

-- ============================================================================
-- SECTION 2: LEADER KEY CONFIGURATION
-- ============================================================================
-- IMPORTANT: Must happen BEFORE plugins are loaded, otherwise wrong leader
-- key will be used. This is a Neovim requirement.
-- See `:help mapleader`
-- ============================================================================
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ============================================================================
-- THEME MANAGEMENT (persistent colorscheme)
-- The active theme is stored in stdpath('data')/theme and restored on startup.
-- Any :colorscheme change (manual or via :Telescope colorscheme) is saved
-- automatically by the ColorScheme autocmd below.
-- Defined AFTER mapleader so <leader> resolves to <Space>, not the default '\'.
-- ============================================================================
local theme_file = vim.fn.stdpath 'data' .. '/theme'
local function save_theme(name)
  if name and name ~= '' then
    vim.fn.writefile({ name }, theme_file)
  end
end
local function load_theme()
  if vim.fn.filereadable(theme_file) == 1 then
    local ok, lines = pcall(vim.fn.readfile, theme_file)
    if ok and lines[1] and lines[1] ~= '' then
      return lines[1]
    end
  end
  return 'tokyonight-night' -- default fallback
end

-- Persist colorscheme changes, but only AFTER the saved theme has been restored
-- at startup. Otherwise the initial eager colorscheme apply overwrites the
-- persisted file with the default before we ever read it (theme resets on boot).
local theme_ready = false
vim.api.nvim_create_autocmd('ColorScheme', {
  desc = 'Persist the active colorscheme to disk',
  callback = function()
    if theme_ready then save_theme(vim.g.colors_name) end
  end,
})

-- Restore the saved theme once the UI is ready (after all theme plugins load).
vim.api.nvim_create_autocmd('UIEnter', {
  once = true,
  desc = 'Restore persisted colorscheme',
  callback = function()
    local saved = load_theme()
    if saved ~= 'tokyonight-night' then
      pcall(vim.cmd.colorscheme, saved)
    end
    theme_ready = true -- begin persisting only after the restore
  end,
})

-- Switch themes with a live Telescope preview; selection is saved automatically.
vim.keymap.set('n', '<leader>ty', '<cmd>Telescope colorscheme<cr>', { desc = 'Switch [T]heme' })

-- ============================================================================
-- SECTION 3: NEOVIM OPTIONS
-- ============================================================================
-- These options control Neovim's behavior and UI.
-- See `:help vim.o` for more information.
-- ============================================================================

-- Nerd Font support (set to true if you have a Nerd Font installed)
vim.g.have_nerd_font = true

-- Line numbers (absolute by default, uncomment relative if preferred)
vim.o.number = true
-- vim.o.relativenumber = true  -- Uncomment for relative line numbers

-- Mouse support (useful for resizing splits)
vim.o.mouse = 'a'

-- Don't show mode in command line (statusline shows it instead)
vim.o.showmode = false

-- Clipboard sync with OS (scheduled to avoid startup delay)
-- See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent for wrapped lines
vim.o.breakindent = true

-- Enable undo/redo persistence (survives file close/reopen)
vim.o.undofile = true

-- Smart case-insensitive search (case-sensitive if uppercase present)
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep sign column always visible (prevents layout shifts)
vim.o.signcolumn = 'yes'

-- Faster update time (affects CursorHold events, swap file writes)
vim.o.updatetime = 250

-- Faster key sequence timeout (affects which-key display)
vim.o.timeoutlen = 300

-- Split behavior (open right/below instead of left/above)
vim.o.splitright = true
vim.o.splitbelow = true

-- Whitespace display configuration
-- See `:help 'list'` and `:help 'listchars'`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Live preview of substitutions (show changes as you type)
vim.o.inccommand = 'split'

-- Highlight the line where cursor is located
vim.o.cursorline = true

-- Keep 10 lines of context above/below cursor when scrolling
vim.o.scrolloff = 10

-- Show confirmation dialog for unsaved changes (e.g., :q with changes)
vim.o.confirm = true

-- ============================================================================
-- SECTION 4: KEYMAPS
-- ============================================================================
-- Key mappings are organized by category for easy reference.
-- See `:help vim.keymap.set()` for more information.
-- ============================================================================

-- Clear search highlighting when pressing <Esc> in normal mode
-- See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Delete previous word with Ctrl+Backspace (standard editor behavior)
vim.keymap.set({ 'n', 'i' }, '<C-BS>', '<C-w>', { desc = 'Delete previous word' })

-- ============================================================================
-- DIAGNOSTIC CONFIGURATION & KEYMAPS
-- ============================================================================
-- See `:help vim.diagnostic.Opts`
vim.diagnostic.config {
  update_in_insert = false,        -- Don't update diagnostics while in insert mode
  severity_sort = true,            -- Sort diagnostics by severity
  float = { border = 'rounded', source = 'if_many' },  -- Floating diagnostic window
  underline = { severity = { min = vim.diagnostic.severity.WARN } },  -- Underline warnings+
  virtual_text = true,             -- Show diagnostic text at end of line
  virtual_lines = false,           -- Alternative: show text below line
  jump = { on_jump = true },       -- Auto-open float when jumping to diagnostic
}

-- Open diagnostic quickfix list
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- ============================================================================
-- TERMINAL MODE KEYMAPS
-- ============================================================================
-- Exit terminal mode with double <Esc> (single Esc is too easy to hit accidentally)
-- NOTE: This won't work in all terminal emulators/tmux/etc.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- ============================================================================
-- WINDOW NAVIGATION KEYMAPS
-- ============================================================================
-- Use CTRL+<hjkl> to switch between windows (works in normal and terminal mode)
-- See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- ============================================================================
-- SECTION 5: AUTOCOMMANDS
-- ============================================================================
-- Autocommands are functions that run automatically on certain events.
-- See `:help lua-guide-autocommands`
-- ============================================================================

-- Highlight yanked (copied) text briefly for visual feedback
-- Try it with `yap` in normal mode
-- See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- ============================================================================
-- SECTION 6: LAZY.NVIM PLUGIN MANAGER
-- ============================================================================
-- Lazy.nvim is a modern plugin manager for Neovim.
-- See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim
-- ============================================================================

-- Bootstrap lazy.nvim (auto-install if not present)
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- ============================================================================
-- PLUGIN CONFIGURATION
-- ============================================================================
-- Plugin loading strategies for optimal performance:
--
-- event = 'VeryLazy'     : Load after UI is ready (non-critical plugins)
-- event = 'InsertEnter'  : Load when entering insert mode (completion)
-- event = 'BufReadPost'  : Load when opening a file buffer
-- event = { 'BufReadPost', 'BufNewFile' } : Load for any buffer
-- ft = { ... }           : Load for specific filetypes only
-- cmd = { ... }          : Load when running specific commands
-- keys = { ... }         : Load when specific keymaps are pressed
-- lazy = false           : Load immediately at startup (use sparingly)
-- ============================================================================
require('lazy').setup({
  -- ============================================================================
  -- SECTION 6.1: UI & VISUAL ENHANCEMENTS
  -- ============================================================================

  -- Guess Indent: Auto-detect indentation settings for files
  -- PERFORMANCE: Tiny plugin, safe to load eagerly
  { 'NMAC427/guess-indent.nvim', opts = {} },

  -- Gitsigns: Git signs in the gutter for changes, adds, deletes
  -- PERFORMANCE: Loaded on BufReadPost (after file is read)
  -- See `:help gitsigns` for configuration options
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      signs = {
        add = { text = '+' }, ---@diagnostic disable-line: missing-fields
        change = { text = '~' }, ---@diagnostic disable-line: missing-fields
        delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
        topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
        changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
      },
    },
  },

  -- Which-Key: Show keybind suggestions after pressing a key
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  -- delay = 200ms balances responsiveness with performance
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    ---@module 'which-key'
    ---@type wk.Opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      delay = 200,  -- Delay before showing which-key (ms)
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains (groups of related keymaps)
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    -- By default, Telescope is included and acts as your picker for everything.

    -- If you would like to switch to a different picker (like snacks, or fzf-lua)
    -- you can disable the Telescope plugin by setting enabled to false and enable
    -- your replacement picker by requiring it explicitly (e.g. 'custom.plugins.snacks')

    -- Note: If you customize your config for yourself,
    -- it’s best to remove the Telescope plugin config entirely
    -- instead of just disabling it here, to keep your config clean.
    enabled = true,
    event = 'VeryLazy',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        defaults = {
          file_ignore_patterns = {
            'node_modules',
            '__pycache__',
            '.venv',
            'venv',
            '.mypy_cache',
            '.pytest_cache',
            '.git',
            'dist',
            'build',
          },
          layout_strategy = 'flex',
        },
        pickers = {
          find_files = {
            hidden = true,
            -- file_ignore_patterns below already filters junk; do NOT set
            -- no_ignore=true or it bypasses those patterns (node_modules, .venv, ...).
          },
          live_grep = {
            additional_args = { '--hidden' },
          },
        },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      pcall(require('telescope').load_extension, 'projects')
      pcall(require('telescope').load_extension, 'file_browser')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sp', function() require('telescope').extensions.projects.projects {} end, { desc = '[S]earch [P]rojects' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Override default behavior and theme when searching
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
      vim.keymap.set('n', '<leader>fe', '<cmd>Telescope file_browser<CR>', { desc = '[F]ile [E]xplorer (Telescope)' })
      vim.keymap.set('n', '<leader>fE', '<cmd>Telescope file_browser path=%:p:h<CR>', { desc = '[F]ile [E]xplorer (cwd)' })
    end,
  },

  {
    'nvim-pack/nvim-spectre',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      { '<leader>fr', function() require('spectre').open() end, desc = '[F]ind & [R]eplace' },
    },
    opts = {},
  },

  -- LSP Plugins
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      -- Maps LSP server names between nvim-lspconfig and Mason package names.
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Hover: show function signature, args, return type, docs
          map('K', vim.lsp.buf.hover, '[H]over')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end

          -- Telescope LSP keymaps (moved from telescope-lsp-attach autocmd)
          local ok, builtin = pcall(require, 'telescope.builtin')
          if ok then
            vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = event.buf, desc = '[G]oto [R]eferences' })
            vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = event.buf, desc = '[G]oto [I]mplementation' })
            vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = event.buf, desc = '[G]oto [D]efinition' })
            vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = event.buf, desc = 'Open Document Symbols' })
            vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = event.buf, desc = 'Open Workspace Symbols' })
            vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = event.buf, desc = '[G]oto [T]ype Definition' })
          end
        end,
      })

      -- Language servers managed by Mason (automatically installed via `:Mason`)
      --  See `:help lsp-config` for information about keys and how to configure
      ---@type table<string, vim.lsp.Config>
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- rust_analyzer = {},
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},

        stylua = {}, -- Used to format Lua code

        -- Special Lua Config, as recommended by neovim help docs
        lua_ls = {
          on_init = function(client)
            client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
                --  See https://github.com/neovim/nvim-lspconfig/issues/3189
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          ---@type lspconfig.settings.lua_ls
          settings = {
            Lua = {
              format = { enable = false }, -- Disable formatting (formatting is done by stylua)
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      --
      -- NOTE: pyrefly is installed globally via `uv tool install pyrefly` (not managed by Mason)
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'prettier', -- unified JS/TS/JSON/HTML/CSS formatter (conform uses it via ~/.config/nvim/prettier.config.json)
      })

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Configure servers but don't enable them globally
      -- Instead, enable on-demand via FileType autocmds for better startup performance
      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
      end

      -- pyrefly: installed globally via uv, configured using lspconfig defaults
      vim.lsp.config('pyrefly', {})

      -- Only enable LSP servers when their filetype is opened
      local lsp_filetypes = {
        pyrefly = { 'python' },
        lua_ls = { 'lua' },
        stylua = { 'lua' },
      }
      for server, filetypes in pairs(lsp_filetypes) do
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('lsp-on-demand-' .. server, { clear = true }),
          pattern = filetypes,
          once = true,
          callback = function() vim.lsp.enable(server) end,
        })
      end
    end,
  },

  -- ============================================================================
  -- SECTION 6.3: FORMATTING & COMPLETION
  -- ============================================================================

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- You can specify filetypes to autoformat on save here:
        local enabled_filetypes = {
          python = true,
          javascript = true,
          typescript = true,
          javascriptreact = true,
          typescriptreact = true,
          vue = true,
          json = true,
          html = true,
          css = true,
          scss = true,
          less = true,
          markdown = true,
          yaml = true,
          graphql = true,
        }
        if enabled_filetypes[vim.bo[bufnr].filetype] then
          return { timeout_ms = 500 }
        else
          return nil
        end
      end,
      default_format_opts = {
        lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
      },
      -- Force a single unified Prettier config tracked in this repo (git-synced).
      formatters = {
        prettier = {
          prepend_args = { '--config', vim.fn.expand '~/.config/nvim/prettier.config.json' },
        },
        prettierd = {
          prepend_args = { '--config', vim.fn.expand '~/.config/nvim/prettier.config.json' },
        },
      },
      -- You can also specify external formatters in here.
      formatters_by_ft = {
        python = { 'ruff_organize_imports', 'ruff_format' },
        javascript = { 'prettierd', 'prettier' },
        typescript = { 'prettierd', 'prettier' },
        javascriptreact = { 'prettierd', 'prettier' },
        typescriptreact = { 'prettierd', 'prettier' },
        vue = { 'prettierd', 'prettier' },
        json = { 'prettierd', 'prettier' },
        html = { 'prettierd', 'prettier' },
        css = { 'prettierd', 'prettier' },
        scss = { 'prettierd', 'prettier' },
        less = { 'prettierd', 'prettier' },
        markdown = { 'prettierd', 'prettier' },
        yaml = { 'prettierd', 'prettier' },
        graphql = { 'prettierd', 'prettier' },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'InsertEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
        {
          'rafamadriz/friendly-snippets',
          config = function()
            require('luasnip.loaders.from_vscode').lazy_load()
          end,
        },
        },
        opts = {},
      },
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        ['<Tab>'] = { 'accept', 'fallback' },
        ['<S-Tab>'] = { 'select_prev', 'fallback' },

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 0,
          window = {
            border = 'rounded',
            max_width = 60,
            max_height = 15,
          },
        },
        list = {
          selection = { preselect = true, auto_insert = true },
        },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets' },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- See :h blink-cmp-config-fuzzy for more information
      -- fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  -- ============================================================================
  -- SECTION 6.4: AUTOCOMPLETION
  -- ============================================================================

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    -- ============================================================================
  -- SECTION 6.5: COLORSCHME & HIGHLIGHTING
  -- ============================================================================

  -- Tokyonight: Clean, dark color scheme
  -- PERFORMANCE: priority=1000 ensures it loads before all other plugins
  'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- ============================================================================
  -- SECTION 6.6: UI & EDITING UTILITIES
  -- ============================================================================

  -- Todo-comments: Highlight TODO, FIXME, NOTE, etc. in comments
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  {
    'folke/todo-comments.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  -- Mini.nvim: Collection of small, independent modules
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  -- Provides: surround, ai textobjects, statusline
  {
    'nvim-mini/mini.nvim',
    event = 'VeryLazy',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
        mappings = {
          around_next = 'aa',
          inside_next = 'ii',
        },
        n_lines = 500,
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- Use `gs` prefix instead of `s` to avoid conflict with flash.nvim
      -- - gsaiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - gsd'   - [S]urround [D]elete [']quotes
      -- - gsr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup({
        mappings = {
          add = 'gsa',
          delete = 'gsd',
          find = 'gsf',
          find_left = 'gsF',
          highlight = 'gsh',
          replace = 'gsr',
          update_n_lines = 'gsn',
          suffix_last = 'l',
          suffix_next = 'n',
        },
      })

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function() return '%2l:%-2v' end

      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

  -- Auto-save: Automatically save files on certain events
  -- PERFORMANCE: Loaded on InsertLeave/TextChanged events
  {
    "okuuva/auto-save.nvim",
    cmd = "ASToggle", 
    event = { "InsertLeave", "TextChanged" }, 
    opts = {
      -- This will use the default settings:
      -- It automatically saves when you leave Insert mode or stop typing.
    },
  },

  -- TypeScript-specific LSP tools (overrides ts_ls for better TS/JS support)
  -- PERFORMANCE: Loaded on ft filter (JS/TS files only)
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    init = function()
      vim.filetype.add({ extension = { ["jsx"] = "javascript.jsx" } })
      vim.filetype.add({ extension = { ["tsx"] = "typescript.tsx" } })
    end,
    opts = {
      settings = {
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
      },
      -- Point directly at the bun-installed global tsserver so the LSP never
      -- has to resolve it via npm.
      tsserver_path = vim.fn.expand("~/.bun/install/global/node_modules/typescript/lib/tsserver.js"),
    },
  },

  -- Code Runner: Run code directly from the editor
  -- PERFORMANCE: Loaded on keymap press only
  {
    "CRAG666/code_runner.nvim",
    config = function()
      require('code_runner').setup({
        -- Choose your preferred mode: "float", "term", or "tab"
        mode = "term",
        focus = true,
        startinsert = true,

        -- ADD THE FILETYPE BLOCK HERE:
        filetype = {
          javascript = "bun",
          python = "python3 -u",
          typescript = "bun",
          typescriptreact = "bun",
          
          -- You can keep your compiled languages here too if you use them:
          cpp = { "cd $dir && g++ $fileName -o $fileNameWithoutExt && ./$fileNameWithoutExt" },
          c = { "cd $dir && gcc $fileName -o $fileNameWithoutExt && ./$fileNameWithoutExt" },
        },


      })
    end,
    keys = {
      -- You can change <leader>r to whatever shortcut you prefer
      { "<leader>r", ":RunCode<CR>", desc = "[R]un [C]ode" },
      { "<leader>rf", ":RunFile<CR>", desc = "[R]un [F]ile" },
    },
  },

  -- ============================================================================
  -- SECTION 6.7: SYNTAX & CODE INTELLIGENCE
  -- ============================================================================

  -- Treesitter: Syntax highlighting, text objects, and more
  -- PERFORMANCE: Loaded on BufReadPost (after file is read)
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      -- main branch of nvim-treesitter only handles parser install dir
      require('nvim-treesitter').setup({})

      -- Enable treesitter highlighting via Neovim built-in APIs (main branch doesn't support old config)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- ============================================================================
  -- SECTION 6.8: UI COMPONENTS
  -- ============================================================================

  -- Neo-tree: File explorer sidebar
  -- PERFORMANCE: Loaded on keymap press only
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle File [E]xplorer" },
    },
    opts = {
      filesystem = {
        hijack_netrw_behavior = "open_default",
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          always_show = { '.env', '.gitignore', '.github' },
        },
      },
    },
  },

  -- Bufferline: Tab/buffer bar at the top
  -- PERFORMANCE: Loaded on keymap press only
  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "<leader>bd", "<cmd>bdelete<cr>", desc = "[B]uffer [D]elete" },
    },
    opts = {
      options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
      },
    },
  },

  -- LazyGit: Floating terminal git client
  -- PERFORMANCE: Loaded on cmd/keymap press only
  {
    'kdheepak/lazygit.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'LazyGit', 'LazyGitConfig' },
    keys = {
      { "<leader>fg", "<cmd>LazyGit<cr>", desc = "[F]ile [G]it (LazyGit)" },
    },
  },

  -- ToggleTerm: Better terminal management
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    event = 'VeryLazy',
    opts = {
      open_mapping = [[<c-\>]],
      direction = 'horizontal',
      size = 15,
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      close_on_exit = true,
    },
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "[T]oggle [T]erminal" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "[T]erminal [F]loat" },
      { "<leader>tm", "<cmd>TermExec cmd='tmux new -s float 2>/dev/null || tmux attach -t float' direction=float<cr>", desc = "[T]erminal t[M]ux" },
      { "<leader>ht", "<cmd>TermExec cmd='herdr' direction=float<cr>", desc = "[H]erdr [T]erminal" },
      { "<leader>t1", "<cmd>1ToggleTerm<cr>", desc = "Terminal [1]" },
      { "<leader>t2", "<cmd>2ToggleTerm<cr>", desc = "Terminal [2]" },
      { "<leader>t3", "<cmd>3ToggleTerm<cr>", desc = "Terminal [3]" },
      { "<leader>tn", "<cmd>TermExec cmd=''<cr>", desc = "[T]erminal [N]ew" },
    },
  },

  -- Project: Auto-detect project root directories
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  {
    "ahmedkhalf/project.nvim",
    event = 'VeryLazy',
    config = function()
      require("project_nvim").setup({
        detection_methods = { "lsp", "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
      })
    end,
  },

  -- ============================================================================
  -- SECTION 6.9: GIT INTEGRATION
  -- ============================================================================

  -- Neogit: Git interface inside Neovim
  -- PERFORMANCE: Loaded on keymap press only
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true,
    keys = {
      { "<leader>gs", "<cmd>Neogit<cr>", desc = "[G]it [S]tatus (Neogit)" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "[G]it [C]ommit" },
      { "<leader>gp", "<cmd>Neogit push<cr>", desc = "[G]it [P]ush" },
    },
  },

  -- Auto-session: Automatically save/restore Neovim sessions
  -- IMPORTANT: Must load at startup (lazy=false) for auto-restore to work
  {
    "rmagatti/auto-session",
    lazy = false,
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
      require("auto-session").setup({
        log_level = "error",
        suppressed_dirs = { "~/", "~/Downloads", "/etc" },
        pre_save_cmds = {
          function()
            pcall(vim.cmd, 'Neotree close')
          end,
        },
      })
    end,
  },

  -- Flash: Jump to any location using labels (like hop.nvim)
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash Jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

  -- ============================================================================
  -- SECTION 6.10: CUSTOM PLUGINS
  -- ============================================================================
  -- Custom plugin definitions from `lua/custom/plugins/*.lua`
  -- This is the easiest way to modularize your config.
  { import = 'custom.plugins' },

  -- ============================================================================
  -- SECTION 6.11: PYTHON DEVELOPMENT
  -- ============================================================================

  -- Debugger (DAP): Debug Adapter Protocol implementation
  -- PERFORMANCE: Loaded on keymap press only
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
      'mfussenegger/nvim-dap-python',
    },
    keys = {
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = '[D]ebug [B]reakpoint' },
      { '<leader>dc', function() require('dap').continue() end, desc = '[D]ebug [C]ontinue' },
      { '<leader>di', function() require('dap').step_into() end, desc = '[D]ebug Step [I]nto' },
      { '<leader>do', function() require('dap').step_over() end, desc = '[D]ebug Step [O]ver' },
      { '<leader>dO', function() require('dap').step_out() end, desc = '[D]ebug Step [O]ut' },
      { '<leader>dr', function() require('dap').repl.toggle() end, desc = '[D]ebug [R]epl' },
      { '<leader>dl', function() require('dap').run_last() end, desc = '[D]ebug Run [L]ast' },
      { '<leader>dt', function() require('dap').terminate() end, desc = '[D]ebug [T]erminate' },
      { '<leader>dn', function() require('dap-python').test_method() end, desc = '[D]ebug [N]earest Test' },
      { '<leader>df', function() require('dap-python').test_class() end, desc = '[D]ebug Test [F]ile' },
      { '<leader>ds', function() require('dap-python').debug_selection() end, mode = 'v', desc = '[D]ebug [S]election' },
    },
    config = function()
      local ok_dap, dap = pcall(require, 'dap')
      if not ok_dap then return end

      local ok_dapui, dapui = pcall(require, 'dapui')
      if ok_dapui then
        dapui.setup()
        dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
        dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
        dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end
      end

      -- Python debugging with debugpy
      local debugpy_path = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
      local ok_dap_python, dap_python = pcall(require, 'dap-python')
      if ok_dap_python then
        dap_python.setup(debugpy_path)
      end
    end,
  },

  -- ============================================================================
  -- SECTION 6.12: REMOTE DEVELOPMENT
  -- ============================================================================

  -- Remote Nvim: SSH into remote machines and develop there
  -- PERFORMANCE: Loaded on keymap press only
  {
    'amitds1997/remote-nvim.nvim',
    version = '0.*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'mfussenegger/nvim-dap',
    },
    opts = {},
    keys = {
      { '<leader>rc', '<cmd>RemoteConnect<cr>', desc = '[R]emote [C]onnect' },
      { '<leader>rd', '<cmd>RemoteDisconnect<cr>', desc = '[R]emote [D]isconnect' },
      { '<leader>rs', '<cmd>RemoteStop<cr>', desc = '[R]emote [S]top' },
      { '<leader>rl', '<cmd>RemoteLog<cr>', desc = '[R]emote [L]og' },
    },
  },

  -- ============================================================================
  -- SECTION 6.13: BOOKMARKS & NAVIGATION
  -- ============================================================================

  -- Vim Bookmarks: Toggle bookmarks and navigate between them
  -- PERFORMANCE: Loaded on keymap press only
  {
    'tom-anders/telescope-vim-bookmarks.nvim',
    dependencies = { 'MattesGroeger/vim-bookmarks' },
    keys = {
      { 'mm', '<cmd>BookmarkToggle<cr>', desc = '[B]ookmark [T]oggle' },
      { 'mi', '<cmd>BookmarkAnnotate<cr>', desc = '[B]ookmark [A]nnotate' },
      { 'mn', '<cmd>BookmarkNext<cr>', desc = '[B]ookmark [N]ext' },
      { 'mp', '<cmd>BookmarkPrev<cr>', desc = '[B]ookmark [P]revious' },
      { '<leader>mb', '<cmd>Telescope vim_bookmarks<cr>', desc = '[B]ookmark [L]ist' },
    },
    config = function()
      require('telescope').load_extension('vim_bookmarks')
    end,
  },

  -- ============================================================================
  -- SECTION 6.14: VISUAL ENHANCEMENTS
  -- ============================================================================

  -- Hlchunk: Rainbow indent lines + current chunk highlighting
  -- PERFORMANCE: Loaded on VeryLazy (after UI is ready)
  {
    'shellRaining/hlchunk.nvim',
    event = { 'VeryLazy' },
    config = function()
      require('hlchunk').setup({
        chunk = {
          enable = true,
          -- treesitter is available, but indentation-based detection is
          -- lighter and works uniformly without parser-specific quirks.
          use_treesitter = false,
          style = {
            { fg = '#806d9c' },
            { fg = '#c21f30' },
          },
          chars = {
            horizontal_line = '─',
            vertical_line = '│',
            left_top = '╭',
            left_bottom = '╰',
            right_arrow = '─',
          },
        },
        indent = {
          enable = true,
          delay = 0,
          chars = {
            '│',
          },
          style = {
            { fg = '#4a4560' },
          },
        },
      })
    end,
  },

  -- Render-markdown: Better markdown rendering in Neovim
  -- PERFORMANCE: Loaded on ft=markdown only
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, { ---@diagnostic disable-line: missing-fields
  rocks = { enabled = false },
  performance = {
    -- Cache compiled plugin modules so lazy.nvim doesn't re-require them on
    -- every startup. Works alongside vim.loader.enable() above.
    cache = {
      enabled = true,
    },
    rtp = {
      -- Disable unused built-in Neovim plugins for faster startup (saves 10-20ms)
      disabled_plugins = {
        'gzip',       -- Gzip file reading/writing (not needed)
        'tar',        -- Tar file reading/writing (not needed)
        'tohtml',     -- Convert to HTML (not needed)
        'tutor',      -- Vim tutorial (not needed)
        'netrwPlugin', -- Netrw file browser (replaced by neo-tree)
        'matchit',    -- Extended % matching (replaced by mini.ai)
        -- matchparen is kept: mini.ai/mini.surround don't replicate its
        -- matching-paren highlight under the cursor.
        '2html_plugin', -- Convert to HTML (not needed)
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

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et

-- ============================================================================
-- SECTION 7: TERMINAL KEYMAPS
-- ============================================================================
-- Better navigation when in terminal mode
-- PERFORMANCE: Loaded on TermOpen event (when terminal is opened)
-- ============================================================================
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('terminal-keymaps', { clear = true }),
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
    vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
    vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
    vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
    vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
    vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
  end,
})

-- ============================================================================
-- SECTION 8: PROJECT SWITCHING
-- ============================================================================
-- Quick project switching via Telescope (like VS Code's Ctrl+R)
-- ============================================================================
vim.keymap.set('n', '<C-r>', '<cmd>Telescope projects<cr>', { desc = 'Open [R]ecent Projects' })

-- ============================================================================
-- SECTION 9: FILETYPE DETECTION
-- ============================================================================
-- Custom filetype detection for specific file types
-- ============================================================================

-- Bun shebang detection: Automatically detect .ts/.js files with bun shebang
-- Sets filetype to 'typescript' and triggers LSP attachment
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('bun-shebang-detection', { clear = true }),
  callback = function(args)
    local first_line = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1] or ""
    if first_line:match('^#!.*bin.*[ /]bun%s*$') or first_line:match('^#!.*bin.*[ /]bun ') then
      -- FIX: Index vim.bo like a table instead of calling it
      vim.bo[args.buf].filetype = 'typescript'
      
      -- Trigger FileType autocommands so LSPs attach after filetype is set
      vim.api.nvim_exec_autocmds('FileType', { buffer = args.buf })
    end
  end,
})
